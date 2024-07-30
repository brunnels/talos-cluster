#!/bin/bash
# WARNING Flux will try to interpolate this file so be aware of clashing variable names within curly braces
set -e # abort on errors
set -u # abort on unset variables

function LOG() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

OUTPUT_DIR="${1:-/backup}"
SECRET_NAME="${2:-${SECRET_DOMAIN//./-}}-production-tls"
NAMESPACE="${3:-network}"
REPLICATION_SOURCE="${4:-prod-cert-backup}"
SECRET="$(kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o yaml 2>/dev/null || echo "missing")"
MANUAL="manual-$EPOCHSECONDS"

if [ "$SECRET" == "missing" ]; then
    if [ -f "$OUTPUT_DIR/$SECRET_NAME.yaml" ]; then
        LOG "Restoring backup file '$OUTPUT_DIR/$SECRET_NAME.yaml'"
        kubectl apply -f <(awk '!/^ *(resourceVersion|uid): [^ ]+$/' "$OUTPUT_DIR/$SECRET_NAME.yaml")
    else
        LOG "Secret '$SECRET_NAME' in namespace '$NAMESPACE' doesn't exist but there is no backup file to restore"
    fi
else
    LOG "Exporting secret '$SECRET_NAME' in namespace '$NAMESPACE' to '$OUTPUT_DIR/$SECRET_NAME.yaml'"
    echo "$SECRET" > "$OUTPUT_DIR/backup.yaml"
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
fi
