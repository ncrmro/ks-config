---
name: ks-experimental
description: "Land a coupled change that touches both Keystone and ks-config — Keystone goes to its `experimental` branch, ks-config locks against the new rev and pushes to its working branch."
---

# ks-experimental

> **Active branch (until this notice is removed):** Keystone work goes to `milestone/M10-V2-os-agents`, not `experimental`. ks-config tracks `main`. Where the steps below say `experimental` / `experimental/ks-config-local-keystone-devbox`, read `milestone/M10-V2-os-agents` / `main`.

Use this skill when a change requires edits in **both** the Keystone library (option schema, modules, helpers, tests) **and** the ks-config consumer flake (host config, host registry, agenix-secrets, binary assets). Examples: adding a new option that's set in ks-config, fixing a module bug that ks-config relies on, extending host taxonomy, adding new agenix patterns.

If the change is purely in one repo, use the normal ks-dev or ks-engineer flow instead — this skill exists to coordinate the two-repo dance, the lock bump, and the verification.

## Repos and conventions

- **Keystone working copy:** `~/repos/ncrmro/ks-config/keystone` (gitignored, the path `bin/ks-dev` discovers first via `--override-input keystone path:...`). Other checkouts at `~/repos/ncrmro/keystone` and `~/.keystone/repos/ncrmro/keystone` exist for unrelated work — **do not touch them**.
- **Keystone branch:** always `experimental`. Never push to `main` from this skill.
- **ks-config working copy:** `~/repos/ncrmro/ks-config` (the parent of the Keystone checkout above).
- **ks-config branch:** `experimental/ks-config-local-keystone-devbox` is the default working branch. Stay on it unless the user explicitly names a different one.
- **Remotes:** keystone → `git@github.com:ncrmro/keystone.git`. ks-config → `git@github.com:ncrmro/ks-config.git`.

## Steps

### 1. Confirm scope and plan first

Use the `deepplan` skill (or write the plan inline) before touching files. The plan should name every Keystone file and every ks-config file you intend to change, plus the verification commands you'll run. **Do not improvise mid-change** — coupled changes across two repos are easy to corrupt.

### 2. Snapshot starting state

```bash
cd ~/repos/ncrmro/ks-config/keystone && git log --oneline -1 && git status -s
cd ~/repos/ncrmro/ks-config            && git log --oneline -1 && git status -s
```

Record both HEAD shas. If either tree has unrelated dirty files (e.g. `agents/drago/SYSTEM.md`, `home-manager/ncrmro/base.nix`), **leave them alone** — never `git add -A` and never `git stash` other people's work.

### 3. Edit Keystone first

Make all Keystone edits in `~/repos/ncrmro/ks-config/keystone`. Conventions:

- Match the existing module style — read neighbouring files for argument shape (`{ config, lib, pkgs, ... }` vs `{ lib, ... }`) and use the same `lib.` prefix vs `with lib;` pattern the file already uses.
- When extending a submodule, use the `types.submodule ({ name, ... }: { options = { ... }; })` form if any default needs to reference the entry's own attribute key.
- For new files, run `git add -N <path>` before any `nix flake check` so the flake's source snapshot picks them up.

### 4. Verify Keystone

```bash
cd ~/repos/ncrmro/ks-config/keystone
nix-instantiate --parse <each-touched-file> > /dev/null      # quick syntax pass
nix flake check 2>&1 | tail -25
```

The following Keystone flake-checks are **pre-existing failures** unrelated to this skill — confirm they're the same ones before and after your change, then ignore them:

- `agent-evaluation` — references the removed `"notes"` capability.
- `template-evaluation` — references the renamed `keystone.projects.enable` option.

Any *new* failure in the checks you added (or in a check your change should have affected) is a real bug — stop and fix.

### 5. Commit + push Keystone

The pre-commit hook needs tools from the devshell, so commits must run through it:

```bash
cd ~/repos/ncrmro/ks-config/keystone
nix develop --command bash -c "git add <files...> && git commit -m '<conventional commit message>' && git push origin experimental"
```

- Conventional Commit (`feat(...)`, `fix(...)`, `refactor(...)`, etc.).
- Body explains the user-visible behavior change, not the diff.
- Trailer: `Co-Authored-By: Claude <coder>@anthropic.com` per your session's identity.
- Stage explicit filenames — never `git add -A`.

Record the resulting Keystone commit SHA — the ks-config commit will reference it.

### 6. Re-lock ks-config

```bash
cd ~/repos/ncrmro/ks-config
nix flake update keystone
```

The lock should advance from the previous Keystone SHA to the one you just pushed. If it doesn't, the push didn't succeed (or you're locking against `main` accidentally) — stop and diagnose.

### 7. Edit ks-config

Apply the ks-config side of the change: new entries that consume the Keystone option, new agenix secrets, new binary assets under top-level dirs like `hardware-keys/`, etc.

If the change involves binary files (handle files, etc.), copy them with `cp -p` to preserve mtimes and permissions, and `git add -N` before `nix flake check`.

### 8. Verify ks-config

Two verification levels — run **both**:

- **With overrides** (matches what `bin/ks-dev` actually does):
  ```bash
  cd ~/repos/ncrmro/ks-config
  nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.outPath \
    --override-input keystone "path:$(realpath keystone)" \
    --override-input agenix-secrets "path:$(realpath agenix-secrets)"
  ```
- **From the lock alone** (matches what a fresh deploy would do):
  ```bash
  nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.outPath
  ```

The two store paths typically differ (path: vs github: inputs hash differently) but both should succeed. If only the override version evaluates, the Keystone push didn't land or the lock didn't update.

Run the host-specific spot checks the plan defined (e.g., `nix eval --json .#nixosConfigurations.<host>.config.systemd.user.services --apply 'svcs: builtins.filter (n: <pattern>) (builtins.attrNames svcs)'`).

### 9. Commit + push ks-config

```bash
cd ~/repos/ncrmro/ks-config
git add <files...>
git commit -m "<conventional commit, e.g. chore(deps): bump keystone for <feature>>"
git push origin HEAD
```

If the change is a multi-step feature (schema + binary assets + host wiring), prefer **one squashed commit on the working branch** rather than multiple small commits, unless the user explicitly asks for finer-grained history.

### 10. Deploy verification (optional, by user)

Don't run `bin/ks-dev` for any remote host yourself — it needs the user's hardware key for root SSH. Note in your handoff which hosts the user should redeploy:

- `bin/ks-dev` (local workstation) — fast smoke test if the change affects workstation.
- `bin/ks-dev ocean` / `bin/ks-dev mercury` / `bin/ks-dev ncrmro-laptop` — remote deploys.

## Guardrails

- **Never `git add -A`** in either repo — stage by explicit filename. Unrelated working-tree edits (drago SYSTEM.md, home-manager base.nix) belong to the user.
- **Never push to `main` / `master`** in either repo. Keystone work goes to `experimental`. ks-config work goes to `experimental/ks-config-local-keystone-devbox` (or another branch the user names).
- **Use the local Keystone checkout** at `~/repos/ncrmro/ks-config/keystone`. The other two Keystone checkouts are for unrelated work and may be on different branches.
- **`nix develop --command`** for any Keystone commit. Skipping it bypasses the pre-commit hook and the next commit will fail with "shellcheck is not installed" or similar.
- **Pre-existing flake-check failures** (`agent-evaluation`, `template-evaluation`) stay pre-existing. Do not try to fix them as part of this change.
- **Binary assets** go under flat top-level dirs in ks-config (e.g. `hardware-keys/`, never under `keys/` or `secrets/` which have established meanings) — match the existing top-level layout (`agents/`, `hosts/`, `home-manager/`, `modules/`, …).
- **Don't deploy.** `bin/ks-dev <remote>` needs the user's YubiKey for root SSH. The user runs the deploy themselves; this skill stops at the push.

## When to escalate

- The Keystone push fails for a reason other than missing devshell tools — likely something needs `nix develop` differently or the hook is rejecting the diff. Don't `--no-verify`; fix the underlying issue.
- The ks-config eval (step 8, override version) fails after a Keystone push that itself succeeded — the lock probably didn't advance. Re-run `nix flake update keystone` and re-verify.
- A new flake-check failure appears that wasn't in the pre-existing list — stop, investigate, do not commit.
- The user names a branch other than `experimental` for Keystone or asks to push to a `feat/...` branch in ks-config — follow what they said; treat the conventions above as defaults, not laws.
