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
