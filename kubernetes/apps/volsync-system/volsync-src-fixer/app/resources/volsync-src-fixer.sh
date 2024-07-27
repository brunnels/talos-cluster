#!/bin/bash
set -e

function LOG() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

get_pods() {
    kubectl get pods -A --field-selector=status.phase!=Running -l app.kubernetes.io/created-by=volsync -o json 2>/dev/null | \
      jq -c '.items[] | select(.metadata.name | startswith("volsync-src")) | [.metadata.name, .metadata.namespace, .metadata.labels."job-name"]' | \
      sed -e 's/\[//g' -e 's/\]//g' -e 's/\"//g'
}
PODS=($(get_pods))
for POD in "${PODS[@]}"; do
    POD=(${POD//,/ })
    POD_NAME="${POD[0]}"
    NAMESPACE="${POD[1]}"
    PVC_NAME="${POD[2]}"
    echo "Found stuck pod '$POD_NAME' in namespace '$NAMESPACE' using pvc '$PVC_NAME'"
    kubectl -n "$NAMESPACE" delete pvc "$PVC_NAME" --wait=false
    LOG "Deleted pvc '$PVC_NAME'"
    kubectl -n "$NAMESPACE" delete pod "$POD_NAME"
    LOG "Deleted pod '$POD_NAME in namespace '$NAMESPACE'"
done
