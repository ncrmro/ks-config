# Agent context

This repo is the ncrmro fleet's **keystone-systems shared config**. Read
README.md first; docs/migration-to-keystone-systems.md explains what the
legacy flake provided and where it went (all legacy code is on `main`).

## Rules

- `keystone.yaml` is the single source of truth. After editing it, run
  `scripts/generate-config.sh` and commit `keystone.json` alongside it —
  Nix reads only the JSON.
- Secrets are agenix files in `secrets/`; recipients derive from the key
  registry in keystone.yaml. Never commit plaintext secrets.
- Host dirs under `hosts/` are placeholders until the keystone-systems os
  flake's storage/secure-boot port lands — this branch is VM-harness-only
  and must not be deployed to real hosts.
- Verify changes with the VM harness: `nix flake show`, then
  `nix run .#vm-<host>` or `nix run .#fleet` (ports in docs/vm-fleet.md).
- The keystone-services/terminal/desktop inputs are absolute local paths
  under `~/repos/keystone-systems/` until those repos publish; keystone-os
  is pinned to `github:keystone-systems/os/feat/fleet-harness?dir=code`.
