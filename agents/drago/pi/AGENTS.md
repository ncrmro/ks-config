# Shared-surface tracking

- For issue-backed work, post `Work Started` and `Work Update` comments on the source issue.
- Treat issues, pull requests, milestones, and boards as the canonical public record.

# Commit format

- Use Conventional Commits: `type(scope): subject`.
- Valid types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`, `perf`, `build`.
- Each commit SHOULD represent one logical change.

# Prose

Be succinct. Sentence-case headings, ISO 8601 dates.

# Code comments

Comments explain **why**, not what. Use prefixes for special cases: `SECURITY:` names the specific attack vector mitigated, `CRITICAL:` flags a cross-module invariant that breaks silently if violated, `TODO:` states the consequence of leaving the gap.

Don't reference the current PR, fix, or session in source comments (`PR #X`, "the bug we just fixed", "what Copilot flagged"). That context belongs in commit messages and PR descriptions, which travel with the change. Source comments outlive their PR — references rot.

Don't pre-emptively document trade-offs you didn't take. Defending a decision against an imaginary reviewer in a paragraph block is clutter; if a real reviewer pushes back, address it in the PR conversation. Non-obvious decisions get one sentence; obvious ones get nothing.

# Nix dev shells

All repos use `flake.nix` with a dev shell providing project dependencies. Run commands via `nix develop -c <cmd>` or from a direnv-activated shell (`.envrc` with `use flake`; run `direnv allow` before first use). To add a missing tool, add it to `devShells.default.buildInputs` in `flake.nix`. Never run `playwright install` — the devshell provides browsers via `playwright-driver.browsers`; pin `@playwright/test` to match `nix eval --raw nixpkgs#playwright-driver.version`.

# Process compose

In `process-compose.yaml`, assign ports dynamically using the `env_cmds` block (e.g., `DB_PORT: "shuf -i 10000-60000 -n 1"`). Reference these variables with `$${VAR}` (double-dollar) in process commands and environment — single `${VAR}` resolves at parse time and produces empty values. Set `PC_NO_SERVER=1` in the `environment` block unless the API server is needed; when it is, use `--use-uds` for Unix domain socket instead of TCP. Never launch the TUI — use the CLI with `-o json`. Read logs with `--tail N --log-no-color`, never `-f`.

# Git repos

Repositories clone to `~/repos/{owner}/{repo}/`. Main checkouts stay on the default branch. Implementation work happens in git worktrees at `~/.worktrees/{owner}/{repo}/{branch}/`.

# Project navigation

Use `rg` (ripgrep) with `--type` filters to search code efficiently. Use `jq` or `yq` to inspect JSON and YAML files rather than reading them whole — check top-level keys first with `jq keys` or `yq keys`, then extract only what you need. Search git history with `git log -G` or `git grep` when tracing requirements or past decisions. When a project defines requirement IDs (e.g., `REQ-001`), use them as anchors in specs, tests, and code comments so related artifacts can be found with `rg "REQ-001"` — add IDs to new tests and comments when they trace back to a requirement.

---

# OS agent overlay: drago

# drago — ks-config agent instructions

Per-agent overlay loaded on top of the repo-wide `ks-config/AGENTS.md`
and the keystone conventions cascade. Rules here are drago-specific
behaviours for work in this repo.

## Session-End PR Comment Audit

1. Before ending any session that involved work on a pull request, drago
   MUST audit every PR touched during the session for unresolved review
   comments and ensure each has been addressed.
2. The audit MUST cover both human and bot reviewers (Copilot, CodeRabbit,
   etc.). Bot reviews are not optional — they catch real bugs and ignoring
   them defeats the gate.
3. The audit MUST be performed via:
   - `gh api repos/{owner}/{repo}/pulls/{number}/reviews` — per-review
     summaries (state, submitter, body)
   - `gh api repos/{owner}/{repo}/pulls/{number}/comments` — line-level
     review comments
   These commands are the source of truth — do NOT rely on memory of what
   was reviewed during the session.
4. Every review comment MUST have either:
   - a corresponding fix commit pushed to the PR branch, OR
   - a reply explaining why the comment was deferred or rejected (out of
     scope, incorrect suggestion, would introduce regression, etc.)
5. If the user has explicitly authorized leaving comments open, that
   authorization MUST be quoted verbatim in the session summary.
6. If the audit surfaces comments drago did not previously see (e.g. a
   review was submitted while drago was working), those MUST be triaged
   before the session is considered complete. Handing back a "ready to
   merge" PR with unread review comments is an integrity failure — the
   user trusted the report; the report was wrong.
7. The audit applies to PRs drago authored AND PRs drago commented on
   during the session, including PRs opened by other agents that drago
   reviewed or amended.

## Worktrees and direnv

1. When creating a new git worktree (anywhere under `~/.worktrees/` or
   otherwise), drago MUST run `direnv allow` in the worktree directory
   IMMEDIATELY after `git worktree add`, before issuing any further
   commands in that directory.
2. After `direnv allow`, drago SHOULD prefer `direnv exec . <cmd>` over
   `nix develop -c <cmd>` for agent-issued commands inside the worktree.
   direnv caches the activated environment keyed on `flake.lock`; `nix
   develop -c` rebuilds it per call and is meaningfully slower across
   the long-running multi-step workflows drago typically executes.
3. `nix develop -c <cmd>` remains acceptable as a fallback when direnv
   has not yet been allowed for a directory, or when the host repo
   does not use direnv. It is functionally equivalent — only slower.
4. Auto-`direnv allow` is permissible for worktrees of repositories
   whose main checkout already has an allowed, reviewed `.envrc` —
   the worktree's `.envrc` is the same file. For worktrees of repos
   drago has not previously interacted with, drago MUST inspect the
   `.envrc` (typically `use flake` plus optional layout helpers)
   before allowing.
5. Each `Bash` tool call gets a fresh shell that does not persist
   `cd` state. To run a command inside the activated worktree env in
   a single Bash call, chain explicitly:
   `cd <worktree> && direnv exec . <cmd>`.