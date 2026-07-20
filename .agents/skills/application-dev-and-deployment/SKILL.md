---
name: application-dev-and-deployment
description: App dev and deployment pattern — devenv for local dev, flake-built binaries and OCI images, Kubernetes deploys direct or (future) via Argo. Use when adding, building, or deploying an app.
---

# Application development and deployment

One pattern, three stages, each with its own reference:

1. **Local dev** — `devenv up` runs the app and its processes; the cluster
   is never part of the inner loop. → `references/development.devenv.md`
2. **Build** — the flake is the single build entry point: `packages.<app>`
   (binary) and `packages.<app>-container` (OCI image, content-addressed
   tag). → `references/build.flakes.md`
3. **Deploy** — the app repo owns its manifests and deploy script; images
   are pushed to the Forgejo registry (content-addressed tag) and the
   cluster pulls them via an imagePullSecret — no host ssh/sudo surface.
   → `references/deploy.kubernetes.md`
   GitOps/Argo is the intended future shape. → `references/deploy.gitops.md`

## App repo layout

```
<app>/
  code/flake.nix        # packages.<app>, packages.<app>-container
  k8s/                  # kustomize: namespace, deployment, service, ingress, pvc
  bin/kdeploy           # build → registry push → rollout
  devenv.nix            # dev shell + process-compose processes
  devenv.yaml           # pinned nixpkgs input
```

## Division of responsibility

- The **fleet/infra config repo** owns the cluster itself: k8s
  distribution, ingress controller, cert-manager, storage classes, any
  host-service bridges.
- **App repos** own their Deployment/Service/Ingress/PVC and deploy
  script. Nothing app-specific lives in the infra repo.
- When an app migrates from a host workload into the cluster, remove its
  host-bridge entry — a leftover bridge ingress claims the hostname and
  502s against the dead host port.
