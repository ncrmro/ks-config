---
name: ks-host-sync
description: "Bring every host (workstation, laptop, ocean) onto ks-config's canonical branch with matching flake.lock — merge stray branches, refresh vega/plouton/keystone locks, switch each host, verify per-host closures, then ask about cleaning up the leftover repos / worktrees / stale branches."
---

# ks-host-sync

Use this skill when the fleet's ks-config state has drifted — different hosts on different branches, stale flake locks, transient milestone branches that need folding back. The goal is **every host on `main` with the same `flake.lock`**, so any host can drive `bin/ks-dev <target>` and produce the same closure.

Typical triggers:

- Different hosts are on different branches (master vs milestone/X vs feature/Y).
- `flake.lock` is stale relative to upstream tips of `vega`, `plouton`, `keystone`.
- A milestone branch (e.g. `milestone/M10-V2-os-agents` on ks-config) is done and should be folded into `main`.
- A repo rename happened (the ks-config rename from `nixos-config` is the prior example).
- New host added and needs to catch up.

If only **one** of those is true and it's narrow (e.g. just a lock bump), this skill is overkill — do it directly. This skill exists for **multi-step fleet-wide reconciliation** that ends in a clean, uniform state.

## Repos and conventions

- **ks-config canonical branch:** `main`. Every host's main checkout sits on `main`. The flake input pin for keystone moves to whatever the canonical-for-now keystone branch is (today: `milestone/M10-V2-os-agents`); ks-config itself stays on `main`.
- **Vega is "super experimental":** commits go straight to `main`; no PR ceremony required.
- **Plouton:** main branch is canonical.
- **Keystone:** main checkout stays on default branch; milestone work lives in `~/repos/ncrmro/worktrees/keystone/<branch>/`. The ks-dev ancestor check in `bin/ks-dev` skips the local override if the local HEAD doesn't contain the locked rev, so a `~/repos/ncrmro/keystone` on `main` is fine even when ks-config locks keystone at a milestone branch.
- **Remotes:**
  - ks-config → `git@github.com:ncrmro/ks-config.git` (github)
  - vega → `https://git.ncrmro.com/ncrmro/vega.git` (forgejo — `gh` CLI does NOT work; push directly)
  - plouton → `git+ssh://forgejo@git.ncrmro.com:2222/ncrmro/plouton.git` (forgejo, private)
  - keystone → `git@github.com:ncrmro/keystone.git` (github)
- **Layout:** `~/repos/ncrmro/<repo>/` per [[project navigation]] convention. Worktrees at `~/repos/ncrmro/worktrees/<repo>/<branch-with-slashes>/`.

## Steps

### 1. Survey the fleet

Inspect every host's ks-config state and identify divergence. Run this from workstation:

```bash
for host in ncrmro-workstation ncrmro-laptop ocean; do
  if [ "$host" = "ncrmro-workstation" ]; then
    cd ~/repos/ncrmro/ks-config
    echo "host=ncrmro-workstation branch=$(git branch --show-current) tip=$(git rev-parse --short HEAD) keystone=$(jq -r .nodes.keystone.locked.rev flake.lock | cut -c1-8) vega=$(jq -r .nodes.vega.locked.rev flake.lock | cut -c1-8) plouton=$(jq -r .nodes.plouton.locked.rev flake.lock | cut -c1-8)"
    echo "  worktrees:"; git worktree list | sed 's/^/    /'
  else
    ssh "$host" 'cd ~/repos/ncrmro/ks-config && \
      echo "host=$(hostname) branch=$(git branch --show-current) tip=$(git rev-parse --short HEAD) keystone=$(jq -r .nodes.keystone.locked.rev flake.lock | cut -c1-8) vega=$(jq -r .nodes.vega.locked.rev flake.lock | cut -c1-8) plouton=$(jq -r .nodes.plouton.locked.rev flake.lock | cut -c1-8)"
      echo "  remote=$(git remote get-url origin)"
      echo "  worktrees:"; git worktree list | sed "s/^/    /"
      echo "  local branches:"; git branch -vv | sed "s/^/    /"'
  fi
done
```

Record:

- Which hosts are on which branch.
- Which locks differ from the workstation's or from upstream tips.
- Any worktrees or local branches that look stale.
- Any remote URL mismatches (e.g. an old name post-rename).

Also fetch each repo's origin so you have visibility on upstream:

```bash
for repo in ks-config keystone vega plouton; do
  git -C ~/repos/ncrmro/"$repo" fetch origin --prune --quiet
  echo "$repo origin/main tip: $(git -C ~/repos/ncrmro/"$repo" log --oneline origin/main -1 2>/dev/null | head -1)"
done
```

**Also inspect agent-asset symlinks across the fleet.** Keystone's home-manager activation (`modules/terminal/agents/assets.nix`) installs per-tool home-dir paths (`~/.claude/CLAUDE.md`, `~/.claude/skills`, `~/.gemini/GEMINI.md`, etc.) as symlinks into the active consumer flake's `agents/` tree, but **refuses to clobber a pre-existing regular file or non-empty directory** at any of those paths. The refusal logs (`keystone-agent-asset-symlinks: refusing to replace ...`) scroll past in long rebuild output and are easy to miss — see `ks-config/AGENTS.md` § "Agent-asset symlinks" for the full link table and the per-host fix. This frequently surfaces on hosts where keystone dev mode previously wrote concrete files. Check every host directly:

```bash
for host in ncrmro-workstation ncrmro-laptop ocean; do
  echo "=== $host ==="
  cmd='for p in .claude/CLAUDE.md .gemini/GEMINI.md .codex/AGENTS.md \
              .claude/skills .claude/agents .gemini/skills .codex/skills .agents/skills; do
         full="$HOME/$p"
         if [ -L "$full" ]; then kind=symlink; extra=$(readlink "$full")
         elif [ -d "$full" ] && [ -n "$(ls -A "$full" 2>/dev/null)" ]; then kind=BLOCKED-dir;  extra="$(ls -A "$full" | wc -l) entries"
         elif [ -d "$full" ]; then kind=empty-dir;  extra="-"
         elif [ -f "$full" ]; then kind=BLOCKED-file; extra="-"
         else kind=missing; extra="-"
         fi
         printf "  %-26s %-14s %s\n" "$p" "$kind" "$extra"
       done'
  if [ "$host" = "$(hostname)" ]; then bash -c "$cmd"; else ssh "$host" "$cmd"; fi
done
```

Anything reported as `BLOCKED-file` or `BLOCKED-dir` will silently skip during home-manager activation and the on-disk content will rot relative to ks-config. Record the offenders per host — they get fixed in §9 cleanup. (`empty-dir` is harmless; the activation script auto-converts those.)

### 2. Fold stray branches back to `main` (if any)

If a host (or origin) carries a transient branch like `milestone/<slug>` or `experimental/<slug>` that should land on `main`, merge it on workstation:

```bash
cd ~/repos/ncrmro/ks-config
git fetch origin --quiet
git checkout main
git pull --ff-only

# Preview conflicts before committing:
git merge-tree main origin/<transient-branch> | grep -E '^changed in both|<<<<<<<' | head

git merge --no-ff --no-edit origin/<transient-branch> \
  -m "merge: fold <transient-branch> work onto main

<2-3 line summary of what's coming in>
The transient <transient-branch> ks-config branch is retired in the cleanup phase."
```

Conflict resolution heuristic:

- `AGENTS.md`, `flake.nix`, `flake.lock`, `bin/ks-dev`, `hosts/common/*` → typically prefer the incoming side (`--theirs`) if the transient branch is where the new work happened.
- Files only touched on `main` (e.g. unrelated drago config changes) → prefer `main` (`--ours`).

If the merge doesn't fold cleanly (genuine semantic conflict, not just text), STOP and ask the user — fleet-sync isn't the time to invent merge semantics.

### 3. Refresh flake locks

```bash
cd ~/repos/ncrmro/ks-config
nix flake update vega plouton keystone
```

Verify each rev moved (or didn't, if already at tip):

```bash
jq -r '.nodes | to_entries[] | select(.key=="vega" or .key=="plouton" or .key=="keystone") | "\(.key)\t\(.value.locked.rev)"' flake.lock
```

Commit:

```bash
git commit -am "chore(deps): bump <inputs> to current tips

<one-line per input explaining what advanced or recording 'no diff' for inputs already at tip>"
```

**Important caveat — verify the new vega/plouton/keystone tips actually build before relying on them.** Build vega standalone first; rollup errors there elide their root cause inside `nix log` so it's faster to spot in a direct shell:

```bash
cd ~/repos/ncrmro/vega
nix build --no-link --print-out-paths '.#packages.x86_64-linux.vega'
```

If it fails, fix the source repo first (vega is "commit straight to main"; for other repos use their normal flow) and re-bump the lock. Don't sync hosts onto a broken lock.

### 4. Doc sweeps (when applicable)

Only when the sync involves a name change (branch rename, repo rename, skill rename, etc.). Skip otherwise.

Search both repos for the old name:

```bash
rg -nI '<old-name>' ~/repos/ncrmro/ks-config ~/repos/ncrmro/vega | grep -v '\.git/'
```

Then sweep. Be careful about **different senses** of the same string — e.g. `experimental` as a branch name vs. `experimental-features = nix-command flakes` (Nix config) or "experimental devbox spike" (descriptive). Only the branch-name sense should be touched.

### 5. Push to origin

```bash
cd ~/repos/ncrmro/ks-config
git push origin main
```

If you also touched a sibling repo (vega/plouton/keystone), push it too. Confirm origin tracks updated:

```bash
git ls-remote origin refs/heads/main | cut -f1 | cut -c1-12
```

### 6. Switch each host's checkout to `main`

Run from workstation against each remote host:

```bash
# Laptop — typical case, simple checkout switch:
ssh ncrmro-laptop '
  cd ~/repos/ncrmro/ks-config
  git fetch origin --prune --quiet
  git checkout main 2>/dev/null || git checkout -b main origin/main
  git pull --ff-only
  git status -sb
'

# Ocean — currently on a transient branch (e.g. milestone/X):
ssh ocean '
  cd ~/repos/ncrmro/ks-config
  git fetch origin --prune --quiet
  git checkout main 2>/dev/null || git checkout -b main origin/main
  git pull --ff-only
  git status -sb
'
```

If the repo was also renamed (e.g. `nixos-config` → `ks-config`), update remote URLs on each host **before** the fetch:

```bash
ssh <host> 'cd ~/repos/ncrmro/ks-config && git remote set-url origin git@github.com:ncrmro/ks-config.git'
```

`git remote set-head origin -a` after the fetch points local `origin/HEAD` at the new default branch.

### 7. Verify per-host closure builds

**Two-stage gate. Do not build anything unprompted.** Closure builds are slow and the user often won't want them — e.g. a doc-only catch-up doesn't need a fleet rebuild to prove correctness.

**Stage 1 — ask whether to build at all.** Use `AskUserQuestion` with a single yes/no question, and **the default / recommended answer is No**. Phrase it so the user can confirm the sync is done without any build at all.

**Stage 2 — only if the answer is yes, follow up with the full host list.** Enumerate available hosts:

```bash
cd ~/repos/ncrmro/ks-config
nix eval --json '.#nixosConfigurations' --apply 'builtins.attrNames' | jq -r '.[]'
```

Then present every name from that list as its own option in a second `AskUserQuestion` (multi-select). Do NOT preselect. Only build what the user picks.

Build each chosen host's toplevel **from workstation** (so the closure is built once and substitutable). Use plain `nix build` rather than `bin/ks-dev` — `bin/ks-dev` pre-warms SSH which prompts for YubiKey even in `--build` mode:

```bash
cd ~/repos/ncrmro/ks-config
for host in <user-selected hosts>; do
  echo "=== building $host ==="
  nix build --no-link --print-out-paths ".#nixosConfigurations.$host.config.system.build.toplevel" 2>&1 | tail -2
done
```

Any failure here means the locks are wrong somehow — go back to step 3 (or fix the underlying repo).

### 8. Commit anything still uncommitted

Before asking about cleanup, **make sure every file change you made during the sync is committed**:

```bash
cd ~/repos/ncrmro/ks-config
git status -sb           # expect a clean tree
cd ~/repos/ncrmro/vega
git status -sb           # also clean
```

If anything's still dirty (lock bumps you forgot to commit, doc edits, etc.), commit and push them now before continuing. The cleanup step in §9 mutates local state (deletes branches, removes worktrees) — leaving uncommitted work in flight risks losing it.

### 9. **Ask the user about cleanup of the leftover out-of-scope items**

Once the fleet is on `main` with matching locks and every change is committed, surface the residual state that the sync produced or uncovered. Use `AskUserQuestion` (multi-select) and present the categories the user can pick from. **Do NOT delete anything until the user explicitly approves.**

Common categories to offer:

1. **Retire transient ks-config branches on origin.** If §2 merged a `milestone/<slug>` or `experimental/<slug>` branch into main, delete it from origin:
   ```bash
   git push origin --delete <transient-branch>
   ```
   And prune local refs on every host:
   ```bash
   for host in workstation laptop ocean; do
     ssh "$host" 'cd ~/repos/ncrmro/ks-config && git fetch origin --prune'
   done
   ```

2. **Remove worktrees no longer needed.** If a milestone or feature branch had a worktree at `~/repos/ncrmro/worktrees/<repo>/<branch>/`, and the branch has been folded:
   ```bash
   git worktree remove ~/repos/ncrmro/worktrees/<repo>/<branch>/
   ```

3. **Delete stale local branches.** On workstation (and any host that has them), branches like `archive/<old-name>` with `origin: gone`, or `feat/*` already merged into `main`:
   ```bash
   git branch --merged main         # show what's safely deletable
   git branch -D <branch>           # one at a time, confirm each
   ```

4. **Drop the previous default branch** (if a default-branch rename was part of the sync, e.g. `master` → `main`). Once the user has flipped the github default to the new name:
   ```bash
   git push origin --delete master
   ```

5. **Sweep remaining cosmetic doc artifacts.** Stale filesystem paths (`/home/ncrmro/<old-name>/...`), old skill names referenced from prompts, etc. These often surface during §4's sweep but get deferred.

6. **Unblock agent-asset symlinks.** For each `BLOCKED-file` or `BLOCKED-dir` entry from the §1 symlink survey, back it up so the next home-manager activation can install the symlink. Empty dirs do NOT need cleanup — activation `rmdir`s them automatically.

   ```bash
   # Per host, for each blocked path (substitute the actual paths reported in §1):
   ssh <host> '
     ts=$(date -Idate)
     for p in <list of blocked paths reported in §1>; do
       link="$HOME/$p"
       [ -L "$link" ] && continue
       [ ! -e "$link" ] && continue
       if [ -d "$link" ] && [ -z "$(ls -A "$link")" ]; then rmdir "$link"; continue; fi
       mv "$link" "$link.bak.$ts"
     done
   '
   ```

   The user re-runs `bin/ks-dev <host>` in §10 to re-activate; the symlinks will appear on the next pass. Leave the `*.bak.<date>` artifacts for the user to inspect — don't delete them as part of the sync.

Report exactly what's a candidate, what command you'd run, and what's left over. Wait for the user's per-item decision. They may say "yes do all", "only #1 and #2", or "skip — I'll do it myself".

### 10. Deploy (handed back to user)

The closures from §7 are materialized in the nix store but not activated. The user activates with their YubiKey:

```bash
bin/ks-dev ocean       # touch YubiKey ×2
bin/ks-dev mercury     # if applicable
bin/ks-dev             # local workstation
```

**Don't run `bin/ks-dev <remote>` yourself** — the SSH pre-warm needs the user's hardware key. Stop at the push + close-out report.

## Guardrails

- **Always commit before cleanup** (§8). The cleanup step mutates local state aggressively.
- **Never force-push** to `main`. The fold + lock-bump path here is purely fast-forward + merge commits.
- **`gh pr create` does NOT work for vega/plouton** (forgejo, not github). For ks-config it does. For vega, push directly to `main` per the "super experimental" convention.
- **`git add -A` is forbidden.** Stage by explicit filename in every commit step.
- **`--no-verify` is forbidden.** Pre-commit hooks need nixfmt/shellcheck from the devshell; use `nix shell nixpkgs#shellcheck -c git commit ...` if shellcheck isn't on PATH outside devshell.
- **Verify before push.** Step 7 must pass for every relevant host before any `git push origin main`.
- **Don't sync onto a broken lock.** If vega/plouton/keystone tip fails to build, fix the source repo first.
- **Local keystone overrides:** the ks-dev ancestor check already guards against silent-downgrade — but if your sync involves making the canonical keystone branch newer than `main`, make sure each host's `~/repos/ncrmro/keystone` is either on `main` (the ancestor check then correctly skips) or on the canonical-for-now branch.

## When to escalate

- §2's merge has a real semantic conflict (not just text) — stop and ask the user.
- §3's vega/plouton/keystone tip fails to build and the cause isn't obvious from a 5-minute look — flag to the user; they may want to launch a dedicated subagent to repair the source repo.
- §6's `git pull --ff-only` reports "non-fast-forward" on any host — a host has local commits on the active branch you didn't expect. Inspect those commits with the user before doing anything.
- §7 fails for one host but not the others — host-specific config issue, not a sync problem. Hand back to the user with the eval error.
- Any operation refuses with HTTP 422 from github — typically means a protected/default branch can't be deleted. Confirm the prerequisite (e.g. default-branch flip) is done.
