# Deploying to Kubernetes

No staging tier, no GitOps controller (yet — see deploy.gitops.md): the
app repo owns its manifests (`k8s/`, kustomize) and a `bin/kdeploy`
script that does build → push → rollout → verify.

## The path: registry push

The nix-built image is pushed to the Forgejo container registry with its
content-addressed tag; the cluster pulls it like any other image. No ssh
or sudo on the node — the only credentials involved are a registry token
locally and an imagePullSecret in the app namespace.

```sh
archive=$(nix build --print-out-paths .#<app>-container --no-link)
tag=$(nix eval --raw .#<app>-container.imageTag)
skopeo copy --dest-creds "<user>:${FORGEJO_TOKEN}" \
  "docker-archive:${archive}" "docker://<registry>/<owner>/<app>:${tag}"
kubectl -n <app> create secret docker-registry forgejo-regcred \
  --docker-server=<registry> --docker-username=<user> \
  --docker-password="$FORGEJO_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
kubectl kustomize k8s/ | sed "s|:__TAG__|:${tag}|g" | kubectl apply -f -
kubectl -n <app> rollout status deploy/<app> --timeout=300s
curl -fsS https://<app>.<domain>/healthz
```

- Manifests reference `<image>:__TAG__`; kdeploy substitutes the real tag
  at apply time. A changed tag is what drives the rollout — identical
  content produces the same tag and no restart.
- `imagePullPolicy: IfNotPresent`: content-addressed tags are immutable,
  a cached image is always correct.
- The Deployment lists `imagePullSecrets: [forgejo-regcred]`; kdeploy
  refreshes that secret from `FORGEJO_TOKEN` on every run (the registry
  rejects anonymous pulls).
- `FORGEJO_TOKEN` needs package read/write scope; without it kdeploy
  falls back to an existing `skopeo login` for the push but fails fast if
  the pull secret is missing.
- The registry is tailnet-only (ingress whitelist); both the pushing
  workstation and the pulling node are on the tailnet.

## Manifest conventions (k8s/)

- One namespace per app.
- Single-writer state (SQLite etc.): `replicas: 1`, `strategy: Recreate`,
  PVC on the `zfs-block-nvme` storage class, `securityContext.fsGroup` for volume
  writes, and a `nodeSelector` pin to the node holding the data.
- Ingress: the cluster ingress class + preinstalled wildcard TLS secret;
  restrict private apps with a source-range whitelist (e.g. the tailnet
  CIDRs).
- Pods reach host-local services via the node's stable (tailnet) IP —
  never `127.0.0.1` or `host.containers.internal`.

## Troubleshooting

- Pull failures (`ErrImagePull`/`ImagePullBackOff`): check the pull
  secret exists in the app namespace and the token still has package
  scope; confirm the tag exists with
  `skopeo inspect --no-tags docker://<registry>/<owner>/<app>:<tag>`.
- No rollout: the tag didn't change (content identical) — compare
  `nix eval --raw .#<app>-container.imageTag` with the running pod image.
- 502 on the app hostname: stale host-service bridge ingress claiming the
  hostname, or the app ingress is missing (`kubectl get ingress -A`).
- Seeding state: find the PV's local mountpoint
  (`kubectl get pv -o yaml | grep -A2 local:`), copy files in with the
  deployment scaled to 0, chown to the pod's fsGroup.
