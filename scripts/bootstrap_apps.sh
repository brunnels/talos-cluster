#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

export LOG_LEVEL="debug"
export ROOT_DIR="$(git rev-parse --show-toplevel)"

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

# Gets all the app namespaces from the apps directory
function get_namespaces() {
    log debug "Getting namespaces"

    local -r apps_dir="${ROOT_DIR}/kubernetes/${CLUSTER}"
    local namespaces=()

    if [[ ! -d "${apps_dir}" ]]; then
        log error "Directory does not exist" "directory=${apps_dir}"
        return
    fi

    for app in "${apps_dir}"/*/; do
        namespace=$(basename "${app}")
        namespaces+=("\"${namespace}\"")
    done

    export NAMESPACES=$(IFS=, ; echo "${namespaces[*]}")
}

# CRDs to be applied before the helmfile charts are installed
function apply_crds() {
    log debug "Applying CRDs"

    local -r crds_file="${ROOT_DIR}/bootstrap/helmfile.d/00-crds.yaml"

    if [[ ! -f "${crds_file}" ]]; then
        log error "File does not exist" "file=${crds_file}"
    fi

    if ! helmfile --file "${crds_file}" template  | kubectl apply --server-side --filename -; then
        log error "Failed to apply CRDs"
    fi

    log info "CRDs applied successfully"
}

# Resources to be applied before the helmfile charts are installed
function apply_resources() {
    log debug "Applying resources"

    local -r resources_file="${ROOT_DIR}/bootstrap/resources.yaml.j2"

    if ! output=$(render_template "${resources_file}") || [[ -z "${output}" ]]; then
        exit 1
    fi

#    echo "${output}" > "${ROOT_DIR}/bootstrap/resources.yaml"

    if echo "${output}" | kubectl diff --filename - &>/dev/null; then
        log info "Resources are up-to-date"
        return
    fi

    if echo "${output}" | kubectl apply --server-side --filename - &>/dev/null; then
        log info "Resources applied"
    else
        log error "Failed to apply resources"
    fi
}

# Sync Helm releases
function sync_helm_releases() {
    log debug "Syncing Helm releases"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.d/01-apps.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log error "File does not exist" "file=${helmfile_file}"
    fi

#    helmfile --file "${helmfile_file}" template > helm-releases-subst.yaml

    if ! helmfile --file "${helmfile_file}" sync --hide-notes; then
        log error "Failed to sync Helm releases"
    fi

    log info "Helm releases synced successfully"
}

function main() {
    check_env KUBECONFIG TALOSCONFIG CLUSTER
    check_cli helmfile kubectl kustomize talhelper yq minijinja envsubst akeyless

    get_namespaces
    add_cluster_settings_to_env

    # Apply resources and Helm releases
    wait_for_nodes
    apply_crds
    apply_resources
    sync_helm_releases
    log info "Congrats! The cluster is bootstrapped and Flux is syncing the Git repository"
}

main "$@"
