---
name: keystone-development
description: Develop ks-config and its Keystone integration, including local input overrides, targeted flake updates, host validation, and Ocean cluster operations. Use for Keystone-bound or ks-config infrastructure work.
---

# Keystone development

## Repository boundaries

- `ks-config` is the consumer flake and deployment entry point. Host-specific
  configuration, secrets wiring, and local compatibility adapters belong here.
- The preferred local Keystone checkout is `../keystone`; `./keystone` is a
  legacy fallback. Reusable platform changes ultimately belong upstream.
- Until a Keystone-bound change is ready to upstream, keep module work under
  `modules/keystone/` and mark it `TODO(upstream-keystone):` with its intended
  destination. Do not edit the sibling Keystone checkout unless explicitly
  requested.
- Keep project-specific skills in this repository's `.agents/`; keep reusable
  personal skills in `~/repos/ncrmro/.agents`.

## Build and deployment workflow

- Use `./bin/ks-dev --build [host]` to validate with local Keystone and
  agenix-secrets overrides without activation.
- Use `./bin/ks-dev [host]` to deploy with those overrides. A completed command
  means deployment finished; proceed directly to service verification.
- Locked builds and deployments use the flake inputs. If an upstream Keystone
  schema changes, commit and push Keystone first, then run only
  `nix flake update keystone` here.
- Never run bare `nix flake update`; update only the inputs intentionally in
  scope.
- Preserve unrelated work in both repositories and keep cross-repository
  changes in discrete commits.

## Ocean Kubernetes

- `k8s-cluster/` owns core K3s HelmChart custom resources and supporting
  resources. It is applied through Ocean's kubeconfig, not through a root SSH
  deployment.
- Run `devenv shell -- k8s-apply-secrets` first to decrypt agenix-managed
  Kubernetes Secret manifests directly into the API, then run
  `devenv shell -- k8s-apply` for charts and dependent resources.
- Both commands support `--dry-run`, validate Ocean's API endpoint, and default
  to `~/.kube/config.ocean.yml`.
- Ocean keeps OpenEBS ZFS LocalPV and the `zfs-block-nvme` storage class;
  Longhorn is not part of this cluster.

## Host investigation

Check `/etc/hostname` before diagnosing a service. Use `systemctl` and
`journalctl` directly for readable state. When privileged output is required
and sudo is unavailable, prepare a narrowly scoped `/tmp` collection script for
the user instead of asking them to copy commands and logs repeatedly.
