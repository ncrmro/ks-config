---
name: platform-devenv
description: "Devenv-based dev environments — devenv.nix layout, process model gotchas, when to pick devenv vs a plain flake devShell"
---

Use this when:

- A repo's `.envrc` is `use devenv` (or you're migrating one to it).
- You're authoring `devenv.nix` / `devenv.yaml` and need to know what defaults bite (notably `process.manager.implementation = "native"` with broken `--detach` in 2.0.3).
- A repo is mixed: production package via `flake.nix` (consumed by ks-config), dev shell via devenv. Both conventions apply.

Skip this when the repo only has `flake.nix` with `devShells.default` — use [tool.nix-devshell.md](tool.nix-devshell.md) directly.

## Supporting references

- **devenv 2.x conventions and gotchas**: [tool.devenv.md](tool.devenv.md) — file layout, `.gitignore` entries, process vs task distinction, the native-manager `--detach` bug, minimal correct snippet.
- **Flake-based dev shells**: [tool.nix-devshell.md](tool.nix-devshell.md) — the older default, still used by ks-config, keystone, plouton.

## What this skill does NOT cover

- NixOS module wiring for production services — that's the flake's `nixosModules.default` output, untouched by the devenv migration.
- Process-compose authoring outside of devenv — devenv's process-compose backend honours a subset of process-compose's schema via `process.managers.process-compose.settings`, but only as overrides on `processes.<name>` entries devenv generates.
