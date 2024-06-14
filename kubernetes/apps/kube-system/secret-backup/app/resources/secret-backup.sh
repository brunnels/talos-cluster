#!/bin/bash
# WARNING Flux will try to interpolate this file so be aware of clashing variable names within curly braces
set -e # abort on errors
set -u # abort on unset variables

SECRET_NAMES="${1:-${SECRET_NAMES}}"
OUTPUT_DIR="${2:-${OUTPUT_DIR}}"
NAMESPACE="${3:-${NAMESPACE}}"
REPLICATION_SOURCE="${4:-${REPLICATION_SOURCE}}"
MANUAL="manual-$EPOCHSECONDS"
SECRET_NAMES_A=($(echo "$SECRET_NAMES" | tr ',' '\n'))

function LOG() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

get_namespaces() {
    kubectl get ns --no-headers -o custom-columns=":metadata.name"
}

get_secret() {
    kubectl get secrets -n "$1" "$2" -o yaml 2>/dev/null \
    | sed '/^  uid: /d; /^  resourceVersion: /d; /^  creationTimestamp: /d; /^  selfLink: /d; /^status:$/Q;' \
    || true
}

start_manual_sync() {
    LOG "Starting manual sync of ReplicationSource '$REPLICATION_SOURCE'"
    kubectl -n "$NAMESPACE" patch replicationsources "$REPLICATION_SOURCE" --type merge -p '{"spec":{"trigger":{"manual":"'$MANUAL'"}}}' &>/dev/null
    LOG "Waiting up to 5 minutes for manual sync trigger '$MANUAL' to complete"
    CHECKS=0
    LAST_MANUAL_SYNC=""
    while [ "$LAST_MANUAL_SYNC" != "$MANUAL" ] && [ $CHECKS -lt 25 ]; do
        CHECKS=$((CHECKS+1))
        sleep 5
        LAST_MANUAL_SYNC="$(kubectl -n "$NAMESPACE" get replicationsource "$REPLICATION_SOURCE" --template '{{.status.lastManualSync}}')"
    done
    kubectl -n "$NAMESPACE" patch replicationsources "$REPLICATION_SOURCE" --type json -p '[{"op": "remove", "path": "/spec/trigger/manual"}]' &>/dev/null
    LOG "Manual sync trigger '$LAST_MANUAL_SYNC' on ReplicationSource '$REPLICATION_SOURCE' completed"
}

for SN in "${SECRET_NAMES_A[@]}"; do
    FOUND="false"
    RESTORED="false"
    for NS in $(get_namespaces); do
        SECRET="$(get_secret $NS $SN)"
        if [ "$SECRET" != "" ]; then
            LOG "Exporting secret '$SN' in namespace '$NS' to '$OUTPUT_DIR/$NS/$SN.yaml'"
            echo "$SECRET" > "$OUTPUT_DIR/$NS/$SN.yaml"
            FOUND="true"
        elif [ -f "$OUTPUT_DIR/$NS/$SN.yaml" ]; then
            LOG "Restoring backup file '$OUTPUT_DIR/$NS/$SN.yaml'"
            kubectl apply -f "$OUTPUT_DIR/$NS/$SN.yaml"
            RESTORED="true"
        fi
    done
    if [ "$RESTORED" == "false" ]; then
        if [ "$FOUND" == "false" ]; then
            LOG "Secret '$SN' not found in any namespace and there is no backup file to restore"
        else
            start_manual_sync
        fi
    fi
done
