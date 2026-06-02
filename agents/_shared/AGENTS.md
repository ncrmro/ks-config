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

Repositories clone to `~/repos/{owner}/{repo}/`. Main checkouts stay on the default branch. Implementation work happens in git worktrees at `~/repos/{owner}/{repo}/worktrees/{branch}/`.

# Project navigation

Use `rg` (ripgrep) with `--type` filters to search code efficiently. Use `jq` or `yq` to inspect JSON and YAML files rather than reading them whole — check top-level keys first with `jq keys` or `yq keys`, then extract only what you need. Search git history with `git log -G` or `git grep` when tracing requirements or past decisions. When a project defines requirement IDs (e.g., `REQ-001`), use them as anchors in specs, tests, and code comments so related artifacts can be found with `rg "REQ-001"` — add IDs to new tests and comments when they trace back to a requirement.
