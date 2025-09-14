# crunchy-postgres

## Postgres Clusters

### Disabling successfulJobsHistoryLimit

```sh
kubectl get cronjob --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name" --no-headers | \
grep -E 'repo[0-9]+-(diff|full|incr)$' | \
xargs -n2 sh -c 'kubectl patch cronjob $1 -n $0 --type=merge -p "{\"spec\": {\"successfulJobsHistoryLimit\": 0}}"'
```

### Boostraping new cluster

If this is the first time you are creating a Postgres cluster in this namespace, you will need to patch with the following:
```shell
kubectl patch postgrescluster downloads -n downloads --type='json' -p='[{"op": "remove", "path": "/spec/dataSource"}]'
```

After the initial creation, you can remove this patch by reconciling the kustomization:
```shell
flux -n downloads reconcile kustomization pgo-cluster
```
