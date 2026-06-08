## Experimental keystone directories

This directory has two roles:
- The top-level `*.nix` files are stable consumer-side adapters for this repo.
- The mirrored `os/`, `server/`, `desktop/`, and `terminal/` directories are import shims whose `default.nix` files point at those stable adapters.
- Nested directories under `modules/keystone/` are reserved for experimental keystone copies, forks, and scratch variants.

Use experimental directories here when you need fast, unstable iteration that should not churn the canonical `../keystone` checkout. Keep `../keystone` as the primary stable checkout and as the source of the GitHub `keystone` flake input.

Rules:
- Do not retarget the root `keystone` flake input to an experimental directory here.
- Do not treat code in an experimental directory as promoted upstream code by default.
- When an experiment proves out, move the reusable result into `../keystone`, push it there, and update `flake.lock` in this repo with the normal targeted workflow.

## Holding area for keystone-bound changes

When a fix belongs upstream in keystone but there is no time to round-trip
through `../keystone` (edit → push → `nix flake update keystone` → commit
`flake.lock`), stage it locally in ks-config as a holding area so local work is
unblocked. Mark every such change with a `TODO(upstream-keystone):` comment that
names the keystone destination, so the later port is mechanical.

Place holding-area changes by shape, mirroring keystone's own layout:
- **Module / option changes** → `modules/keystone/` (an experimental copy or
  fork as described above), destined for keystone's `modules/`.
- **Package overrides / overlays** → `overlays/keystone/`, listed in
  `overlays/default.nix` next to `inputs.keystone.overlays.default`, destined for
  keystone's overlay set. Example:
  `overlays/keystone/weasyprint-darwin-tests.nix`.
- **Profiles / agent assets** → the matching tree under `agents/`.

Host- or user-specific values (paths, hostnames, identities) are NOT
keystone-bound — keep them in the consumer host config (e.g.
`home-manager/ncrmro/<host>.nix`) even when they exist to work around an upstream
default. Example: `keystone.terminal.bridl.configDir` on `unsup-macbook` is set
host-side because keystone cannot derive the checkout path in
standalone-home-manager mode.
