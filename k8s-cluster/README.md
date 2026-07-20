# Ocean K3s cluster

This directory is the source of truth for Ocean's core K3s add-ons and their
supporting cluster resources. K3s's Helm Controller installs the charts from
`HelmChart` custom resources; the devenv commands apply those resources with
`kubectl`.

From the repository root:

```bash
# Validate without changing the cluster.
devenv shell -- k8s-apply-secrets --dry-run
devenv shell -- k8s-apply --dry-run

# Apply encrypted Secrets first, then charts and dependent resources.
devenv shell -- k8s-apply-secrets
devenv shell -- k8s-apply
```

Both commands default to `~/.kube/config.ocean.yml`. Set `KUBECONFIG` to use
another Ocean admin kubeconfig. The commands refuse to run when the selected
context does not point at `https://100.64.0.6:6443`; set
`K8S_EXPECTED_SERVER` only when Ocean's API endpoint intentionally changes.

Encrypted Secret manifests live in the private agenix checkout under
`secrets/k8s/ocean/*.yaml.age`. `AGENIX_SECRETS_DIR` can select a checkout
explicitly. The secret command decrypts each document into memory and pipes it
directly to the API; it never writes plaintext Secret YAML to disk.

The apply commands intentionally do not prune resources that disappear from
this directory. Remove obsolete resources explicitly after reviewing the live
object and its dependents.
