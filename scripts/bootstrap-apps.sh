#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

export LOG_LEVEL="debug"
export ROOT_DIR="$(git rev-parse --show-toplevel)"
export ROOK_DISK="/dev/nvme0n1"

# Disks in use by rook-ceph must be wiped before Rook is installed
function wipe_rook_disks() {
    log debug "Wiping Rook disks"

    # Skip disk wipe if Rook is detected running in the cluster
    # TODO: Is there a better way to detect Rook / OSDs?
    if kubectl --namespace rook-ceph get kustomization rook-ceph &>/dev/null; then
        log warn "Rook is detected running in the cluster, skipping disk wipe"
        return
    fi

    if ! nodes=$(talosctl config info --output json 2>/dev/null | jq --exit-status --raw-output '.nodes | join(" ")') || [[ -z "${nodes}" ]]; then
        log error "No Talos nodes found"
    fi

    log debug "Talos nodes discovered" "nodes=${nodes}"

    # Wipe disks on each node that match the ROOK_DISK environment variable
    for node in ${nodes}; do
        if ! disks=$(talosctl --nodes "${node}" get disk --output json 2>/dev/null \
            | jq --exit-status --raw-output --slurp '. | map(select(.spec.dev_path == env.ROOK_DISK) | .metadata.id) | join(" ")') || [[ -z "${nodes}" ]];
        then
            log error "No disks found" "node=${node}" "model=${ROOK_DISK}"
        fi

        log debug "Talos node and disk discovered" "node=${node}" "disks=${disks}"

        # Wipe each disk on the node
        for disk in ${disks}; do
            if talosctl --nodes "${node}" wipe disk "${disk}" &>/dev/null; then
                log info "Disk wiped" "node=${node}" "disk=${disk}"
            else
                log error "Failed to wipe disk" "node=${node}" "disk=${disk}"
            fi
        done
    done
}

# Talos requires the nodes to be 'Ready=False' before applying resources
function wait_for_nodes() {
    log debug "Waiting for nodes to be available"

    # Skip waiting if all nodes are 'Ready=True'
    if kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        log info "Nodes are available and ready, skipping wait for nodes"
        return
    fi

    # Wait for all nodes to be 'Ready=False'
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
        log info "Nodes are not available, waiting for nodes to be available. Retrying in 10 seconds..."
        sleep 10
    done
}

# The application namespaces are created before applying the resources
function apply_namespaces() {
    log debug "Applying namespaces"

    local -r apps_dir="${ROOT_DIR}/kubernetes/apps"

    if [[ ! -d "${apps_dir}" ]]; then
        log error "Directory does not exist" "directory=${apps_dir}"
    fi

    for app in "${apps_dir}"/*/; do
        namespace=$(basename "${app}")

        # Check if the namespace resources are up-to-date
        if kubectl get namespace "${namespace}" &>/dev/null; then
            log info "Namespace resource is up-to-date" "resource=${namespace}"
            continue
        fi

        # Apply the namespace resources
        if kubectl create namespace "${namespace}" --dry-run=client --output=yaml \
            | kubectl apply --server-side --filename - &>/dev/null;
        then
            log info "Namespace resource applied" "resource=${namespace}"
        else
            log error "Failed to apply namespace resource" "resource=${namespace}"
        fi
    done
}

# ConfigMaps to be applied before the helmfile charts are installed
function apply_configmaps() {
    log debug "Applying ConfigMaps"

    local -r configmaps=(
        "${ROOT_DIR}/kubernetes/components/common/cluster-settings.yaml"
    )

    for configmap in "${configmaps[@]}"; do
        if [ ! -f "${configmap}" ]; then
            log warn "File does not exist" file "${configmap}"
            continue
        fi

        # Check if the configmap resources are up-to-date
        if kubectl --namespace flux-system diff --filename "${configmap}" &>/dev/null; then
            log info "ConfigMap resource is up-to-date" "resource=$(basename "${configmap}" ".yaml")"
            continue
        fi

        # Apply configmap resources
        if kubectl --namespace flux-system apply --server-side --filename "${configmap}" &>/dev/null; then
            log info "ConfigMap resource applied successfully" "resource=$(basename "${configmap}" ".yaml")"
        else
            log error "Failed to apply ConfigMap resource" "resource=$(basename "${configmap}" ".yaml")"
        fi
    done
}

# SOPS secrets to be applied before the helmfile charts are installed
function apply_sops_secrets() {
    log debug "Applying secrets"

    local -r secrets=(
        "${ROOT_DIR}/bootstrap/github-deploy-key.sops.yaml"
        "${ROOT_DIR}/kubernetes/components/common/cluster-secrets.sops.yaml"
        "${ROOT_DIR}/kubernetes/components/common/sops-age.sops.yaml"
    )

    for secret in "${secrets[@]}"; do
        if [ ! -f "${secret}" ]; then
            log warn "File does not exist" "file=${secret}"
            continue
        fi

        # Check if the secret resources are up-to-date
        if sops exec-file "${secret}" "kubectl --namespace flux-system diff --filename {}" &>/dev/null; then
            log info "Secret resource is up-to-date" "resource=$(basename "${secret}" ".sops.yaml")"
            continue
        fi

        # Apply secret resources
        if sops exec-file "${secret}" "kubectl --namespace flux-system apply --server-side --filename {}" &>/dev/null; then
            log info "Secret resource applied successfully" "resource=$(basename "${secret}" ".sops.yaml")"
        else
            log error "Failed to apply secret resource" "resource=$(basename "${secret}" ".sops.yaml")"
        fi
    done
}

# cert-manager certificates to be applied before the helmfile charts are installed
function apply_certs() {
    local -r certs_dir="${ROOT_DIR}/bootstrap/certs"

    if [[ ! -d "${certs_dir}" ]]; then
        log debug "Certs directory does not exist, skipping apply_certs" "directory=${certs_dir}"
    else
        log debug "Applying certificates"
        local -r certs="$(find ${certs_dir} -type f -name '*.sops.yaml')"
        for cert in $certs; do
            # Check if the certificate resources are up-to-date
            if sops exec-file "${cert}" "kubectl --namespace cert-manager diff --filename {}" &>/dev/null; then
                log info "Certificate resource is up-to-date" "resource=$(basename "${cert}" ".sops.yaml")"
                continue
            fi

            # Apply certificate resources
            if sops exec-file "${cert}" "kubectl --namespace cert-manager apply --server-side --filename {}" &>/dev/null; then
                log info "Certificate resource applied successfully" "resource=$(basename "${cert}" ".sops.yaml")"
            else
                log error "Failed to apply certificate resource" "resource=$(basename "${cert}" ".sops.yaml")"
            fi
        done
    fi
}

# Apply Helm releases using helmfile
function apply_helm_releases() {
    log debug "Applying Helm releases with helmfile"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log error "File does not exist" "file=${helmfile_file}"
    fi

    if ! helmfile --file "${helmfile_file}" apply --hide-notes --skip-diff-on-install --suppress-diff --suppress-secrets; then
        log error "Failed to apply Helm releases"
    fi

    log info "Helm releases applied successfully"
}

function main() {
    check_cli helmfile kubectl kustomize sops talhelper yq

    # Apply resources and Helm releases
    wait_for_nodes
    apply_namespaces
    apply_configmaps
    apply_sops_secrets

    if [[ -f "$(dirname "${0}")/extras.sh" ]]; then
        source "$(dirname "${0}")/extras.sh"
        extras_before_helm_releases
    fi

    apply_helm_releases

    if [[ -f "$(dirname "${0}")/extras.sh" ]]; then
        extras_after_helm_releases
    fi

    log info "Congrats! The cluster is bootstrapped and Flux is syncing the Git repository"
}

main "$@"
