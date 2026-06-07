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

New repos use **devenv** (`devenv.nix` + `devenv.yaml` + `.envrc` with `use devenv`; run `direnv allow` before first use). Add tools to `packages = with pkgs; [ ... ]` in `devenv.nix`. Pin `inputs.nixpkgs.url` in `devenv.yaml` to a specific rev (e.g. `github:cachix/devenv-nixpkgs/<rev>`) — bumping it forces from-source rebuilds of anything not in the binary cache. Never run `playwright install` — the devshell provides browsers via `playwright-driver.browsers`; pin `@playwright/test` to match `nix eval --raw nixpkgs#playwright-driver.version`.

Legacy repos may still use `flake.nix` with `use flake`; tools live in `devShells.default.buildInputs`. Same playwright rule applies.

# Process compose

devenv has process-compose built in — declare processes in `devenv.nix` as `processes.<name>.exec = "..."`, then `devenv up` (foreground) or `devenv up -d` (detached). `devenv processes down` stops them. Don't write a standalone `process-compose.yaml` — devenv generates one at `$PC_CONFIG_FILES` and exposes the UDS at `$PC_SOCKET_PATH` (no TCP server, no TUI).

Process-compose settings live under `process.managers.process-compose.settings`. For dynamic port assignment, use `env_cmds` there (e.g. `env_cmds.DB_PORT = "shuf -i 10000-60000 -n 1"`). **Do not** also list the var in the process's `environment` block — that triggers parse-time `${VAR}` substitution which produces an empty value. env_cmds vars are exported into process-compose's own env and inherited by child processes automatically; the child reads them like any other env var.

Inspect state via the CLI inside the devenv shell — `process-compose` isn't on the host PATH. Find the socket with `find /run/user/$UID -maxdepth 2 -name pc.sock`, then `devenv shell -- process-compose process list -u "$SOCK" --use-uds -o json`. Read logs with `--tail N --log-no-color`, never `-f`. Avoid `readiness_probe.http_get.port` for dynamic-port processes — that field isn't Go-templated, so `{{.VAR}}` is interpreted literally; use an `exec` probe instead, or skip the probe.

# Project navigation

Use `rg` (ripgrep) with `--type` filters to search code efficiently. Use `jq` or `yq` to inspect JSON and YAML files rather than reading them whole — check top-level keys first with `jq keys` or `yq keys`, then extract only what you need. Search git history with `git log -G` or `git grep` when tracing requirements or past decisions. When a project defines requirement IDs (e.g., `REQ-001`), use them as anchors in specs, tests, and code comments so related artifacts can be found with `rg "REQ-001"` — add IDs to new tests and comments when they trace back to a requirement.
