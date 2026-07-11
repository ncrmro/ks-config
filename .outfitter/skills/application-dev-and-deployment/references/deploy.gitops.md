# GitOps deployment (future: Argo CD)

Not implemented yet. This records the intended shape so direct-deploy
decisions today don't block it.

## Target model

- An Argo CD (or comparable) controller in the cluster watches a deploy
  branch/path; `kubectl` leaves the human loop entirely.
- The app repo keeps owning its manifests — Argo points one `Application`
  at each app repo's `k8s/` (or at a small fleet-owned app-of-apps that
  references them).
- Images arrive via the registry path only (see deploy.kubernetes.md
  fallback) — containerd import is invisible to GitOps. CI builds the
  flake image, pushes `sha-<rev>`, and updates the image tag in the
  manifests (commit or image-updater).

## What must stay true for the migration to be trivial

1. Manifests remain plain kustomize in-repo — no imperative kubectl-only
   state (the current `set image` step becomes a committed tag bump).
2. Image tags stay content-addressed/commit-addressed — `latest` is never
   referenced by a Deployment.
3. Secrets never enter manifests; the fleet's secret backend (agenix →
   cluster secrets, or external-secrets later) stays the boundary.
4. `kdeploy` keeps its build/push halves separable so CI can reuse them
   with the apply half dropped.

## Open questions

- App-of-apps in the fleet config repo vs per-repo Applications.
- Image tag bumps: Argo CD Image Updater vs a CI commit into the manifest.
- Whether the dev fleet VMs get a throwaway Argo to exercise the flow
  before it owns prod.
