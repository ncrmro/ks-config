# Deploying to Kubernetes directly

No staging tier, no GitOps controller (yet — see deploy.gitops.md): the
app repo owns its manifests (`k8s/`, kustomize) and a `bin/kdeploy`
script that does build → deliver → rollout → verify.

## Fast path: containerd import (no registry round-trip)

Stream the nix-built image straight into the containerd instance kubelet
reads from:

```sh
archive=$(nix build --print-out-paths .#<app>-container --no-link)
tag=$(nix eval --raw .#<app>-container.imageTag)
ssh <node> 'sudo ctr -n k8s.io images import -' < "$archive"
kubectl apply -k k8s/
kubectl -n <app> set image deploy/<app> <app>="<registry>/<owner>/<app>:${tag}"
kubectl -n <app> rollout status deploy/<app> --timeout=180s
curl -fsS https://<app>.<domain>/healthz
```

- `-n k8s.io` is mandatory — kubelet only sees that containerd namespace.
- `imagePullPolicy: IfNotPresent` so imported images are used without
  registry auth.
- Import reaches ONE node; fine for single-node or node-pinned apps. For
  multi-node scheduling use the registry path.

## Fallback: registry push

`kdeploy --push`: `skopeo copy` the archive to the registry (tags `latest`
+ `sha-<rev>`, token auth via env) — required when any node must pull.

## Manifest conventions (k8s/)

- One namespace per app.
- Single-writer state (SQLite etc.): `replicas: 1`, `strategy: Recreate`,
  PVC on the local-storage class, `securityContext.fsGroup` for volume
  writes, and a `nodeSelector` pin to the node holding the data.
- Ingress: the cluster ingress class + preinstalled wildcard TLS secret;
  restrict private apps with a source-range whitelist (e.g. the tailnet
  CIDRs).
- Pods reach host-local services via the node's stable (tailnet) IP —
  never `127.0.0.1` or `host.containers.internal`.

## Troubleshooting

- What kubelet sees: `ssh <node> 'sudo ctr -n k8s.io images ls | grep <app>'`.
- No rollout: the tag didn't change (content identical) — compare
  `nix eval --raw .#<app>-container.imageTag` with the running pod image.
- 502 on the app hostname: stale host-service bridge ingress claiming the
  hostname, or the app ingress is missing (`kubectl get ingress -A`).
- Seeding state: find the PV's local mountpoint
  (`kubectl get pv -o yaml | grep -A2 local:`), copy files in with the
  deployment scaled to 0, chown to the pod's fsGroup.
