# one liner to delete all not running pods

```shell
kubectl get po -A --no-headers | awk '{if ($4 != "Running") print $1, $2}' | xargs -l bash -c 'kubectl -n $0 delete pod $1'
```

# check un-resolved kustomizations and helmreleases
```shell
flux get kustomizations --status-selector=ready=false -A && flux get helmreleases --status-selector=ready=false -A
```

# clear ceph alerts
```shell
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l 'app=rook-ceph-tools' -o jsonpath='{.items[*].metadata.name}') -- ceph crash archive-all
```
