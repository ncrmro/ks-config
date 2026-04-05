# Historical note: Keystone submodule migration

## Status
Obsolete. nixos-config now consumes `keystone` via `github:ncrmro/keystone`, and local development happens in the sibling checkout at `../keystone`.

## Problem Summary

We migrated local `modules/keystone/` content to the dedicated `keystone` repository. The migration itself succeeded:

1. ✅ Copied all files to keystone repo
2. ✅ Committed and pushed to github.com/ncrmro/keystone
3. ✅ Removed local `modules/keystone/` directory
4. ✅ Updated references from `outputs.nixosModules.keystone-desktop` to `inputs.keystone.nixosModules.keystoneDesktop`
5. ✅ Updated references from `outputs.homeManagerModules.keystone-*` to `inputs.keystone.homeModules.keystone*`

## Current Issue

The rejected approach used `path:./.submodules/keystone`, which did not work because:

- Nix's `path:` fetcher copies the git tree to the store
- Git submodules appear as empty directories in the store (submodule content is not included)
- Result: `error: path '.../source/.submodules/keystone/flake.nix' does not exist`

This happens even with a clean git tree (all changes committed).

## Outcome

- `flake.nix` uses `github:ncrmro/keystone`.
- Local Keystone edits should happen in `../keystone`.
- nixos-config should not carry a tracked `.submodules/keystone` gitlink.

## Current guidance

1. Edit Keystone in `../keystone`.
2. Verify with `ks build` or `keystone-dev --build`.
3. Commit and push in `../keystone`.
4. Run `nix flake update keystone` in nixos-config to relock.

## Keystone Repo State

Commits pushed to github.com/ncrmro/keystone:
- `c9b5633` - feat(flake): export keystoneTerminal and keystoneDesktop homeModules
- `fd8a8d7` - feat(flake): export keystoneDesktop module
- `e50d231` - chore: remove orphaned submodule reference
- `ff2f8a7` - feat(desktop): migrate modules from nixos-config
