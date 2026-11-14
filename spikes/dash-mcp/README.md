# dash-mcp

Spike — a fleet-wide **project** dashboard with an MCP surface for
centralized agent tracking across a Keystone fleet.

## Naming

- **Project** is the operational primitive this spike tracks — slug, status,
  owner agent, milestones, repos, reports.
- **Mission** is reserved for the Keystone-voice narrative artifact
  (`~/notes/projects/<slug>/mission.md`) — Purpose / Core Values / Scope. Each
  project row points at its mission file via `mission_md_path`; the notebook
  keeps ownership of the narrative.
- **Task** is the future addition — actionable work items (review PR, reply
  to issue, decide, etc.) that span providers. Sketched in
  `docs/proposals.md` (Schema v2), not yet implemented.

## Context

The Keystone OS-agents stack (`~/.keystone/repos/ncrmro/keystone/modules/os/agents/`)
runs per-host agent users with a task-loop + scheduler model. Durable
per-project narratives already live in `~/notes/projects/<slug>/mission.md`,
but there is no shared surface where every agent on every host can report
progress against a project, and no central place to view project state across
the fleet.

This spike prototypes that surface as a Bun workspace:

- **web** — Astro dashboard listing projects, reports, hosts, and agents
- **mcp** — MCP stdio server installable at host or user scope; the surface
  agents call into to report progress
- **server** — Bun HTTP API backed by Drizzle ORM + libSQL (sqld); single source
  of truth for the dashboard and the MCP tools
- **db** — workspace package holding the Drizzle schema, exported to server and
  any future consumers

Once the shape stabilizes, these graduate into Keystone modules + DeepWork jobs.

## Prior art

- [`ncrmro/notes#1` Product Agent Goals](https://git.ncrmro.com/ncrmro/notes/issues/1)
  enumerates the active product projects (Meze, Catalyst, Keystone, Plant
  Caravan) that the dashboard surfaces first.
- [`ncrmro/notes#5` Executive Assistant](https://git.ncrmro.com/ncrmro/notes/issues/5)
  defines the utility-agent surface (events, contacts, priorities, reading,
  socials) that should eventually appear alongside product projects.
- [`ncrmro/notes#10` Vega Agent Architecture](https://git.ncrmro.com/ncrmro/notes/issues/10)
  describes the internal project-acceleration agent, the `claude --agent <name>`
  CLI surface, and per-agent MCP config generation. Links downstream to
  `ncrmro/keystone#280` and `#281`.
- `ncrmro/vega#1` (private) — internal Vega tracker.
- `~/notes/projects/agents/mission.md` — composable prompt architecture and
  Luce↔Drago handoff protocol. Establishes the principle that agents collaborate
  on projects through typed artifacts; this spike is the typed-artifact store.

## Architecture

```
  ┌──────────────────────────────┐
  │ host A: claude --agent drago │──────┐
  │ host B: codex --agent luce   │──┐   │   stdio JSON-RPC
  │ host C: gemini  --agent vega │┐ │   │
  └──────────────────────────────┘│ │   │
                                  │ │   │
                                  ▼ ▼   ▼
                          ┌────────────────────┐
                          │  @dash-mcp/mcp     │   one MCP server per shell;
                          │  (stdio)           │   identity from $HOSTNAME +
                          └─────────┬──────────┘   $KS_AGENT/$USER
                                    │ HTTP
                                    ▼
                          ┌────────────────────┐
                          │ @dash-mcp/server   │   Bun.serve + Drizzle
                          │ (Bun)              │
                          └─────────┬──────────┘
                                    │ libSQL HTTP
                                    ▼
                          ┌────────────────────┐
                          │   sqld (libSQL)    │   .data/dash-mcp.db
                          └────────────────────┘
                                    ▲
                                    │ HTTP
                          ┌────────────────────┐
                          │  @dash-mcp/web     │   Astro SSR dashboard
                          │  (Astro + Node)    │
                          └────────────────────┘
```

`sqld`, `server`, and `web` are all long-running and orchestrated with
`process-compose` (see `code/process-compose.yaml`).

## Project data model

Adds dashboard fields (status, milestones, reports) and fleet attribution
(host, agent) on top of the notebook's narrative `mission.md`.

| Table              | Notes |
| ------------------ | ----- |
| `project`          | `slug`, `title`, `purpose`, `status` (`proposed\|active\|blocked\|done\|archived`), `owner_agent`, `mission_md_path` (pointer to notebook narrative), timestamps |
| `project_value`    | per-project core values (mirrors `mission.md` "Core Values") |
| `project_scope`    | per-project in/out scope items (mirrors `mission.md` "Scope") |
| `milestone`        | per-project milestones with due date and status |
| `project_repo`     | per-project repo links (normalized `gh:`/`fj:` refs, URL, optional label) |
| `project_report`   | append-only progress: `kind` (`work_started\|work_update\|blocked\|done\|note`), `summary`, `refs[]` (normalized `gh:`/`fj:` refs or file paths), `host_id`, `agent_id` |
| `host`             | `hostname`, `first_seen`, `last_seen` |
| `agent`            | `name`, `host_id`, `first_seen`, `last_seen` (composite-unique on `(name, host_id)`) |

Inserting a `project_report` upserts the host + agent rows and bumps
`last_seen`, so `/hosts` and `/agents` reflect activity automatically.

## MCP tools

Implemented in `code/mcp/src/tools.ts`:

| Tool             | Purpose |
| ---------------- | ------- |
| `project_list`   | List projects (filter by `status`) |
| `project_get`    | Project detail + report timeline |
| `project_create` | Create a project with values, scope, owner, mission narrative path |
| `project_update` | Patch title/purpose/status/owner/missionMdPath |
| `project_report` | Append a progress report — `host` and `agent` are auto-injected |

Identity resolution order (`code/mcp/src/identity.ts`):

- `host`: `$DASH_MCP_HOST` → `$HOSTNAME` → `os.hostname()` → `"unknown-host"`
- `agent`: `$DASH_MCP_AGENT` → `$KS_AGENT` → `$AGENT_NAME` → `$USER` → `"unknown-agent"`

Server URL: `$DASH_MCP_SERVER_URL` or `http://127.0.0.1:$DASH_MCP_PORT` (default
port `7878`).

## MCP install patterns

The reference fleet is two agents on two hosts:

| Agent  | Host                 | Project ownership          |
| ------ | -------------------- | -------------------------- |
| `drago`| `ncrmro-workstation` | Keystone, Plant Caravan    |
| `luce` | `ocean`              | ks.systems                 |

The seed (`db/seeds/projects.json`) writes a few starter reports under each
identity so `/hosts` and `/agents` reflect that layout out of the box.

### User-level (today)

Add a `mcpServers` entry to each agent's `~/.claude.json` pointing at the
workspace bin and the running server. The `DASH_MCP_AGENT` env baked into the
entry is the identity each report will land under:

```json
// ~ncrmro-workstation/.claude.json — drago's shell
{
  "mcpServers": {
    "dash-mcp": {
      "command": "bun",
      "args": ["run", "/home/ncrmro/.../spikes/dash-mcp/code/mcp/src/index.ts"],
      "env": {
        "DASH_MCP_SERVER_URL": "http://ocean.<tailnet>:<server-port>",
        "DASH_MCP_HOST": "ncrmro-workstation",
        "DASH_MCP_AGENT": "drago"
      }
    }
  }
}
```

```json
// ~ocean/.claude.json — luce's shell
{
  "mcpServers": {
    "dash-mcp": {
      "command": "bun",
      "args": ["run", "/home/ncrmro/.../spikes/dash-mcp/code/mcp/src/index.ts"],
      "env": {
        "DASH_MCP_SERVER_URL": "http://127.0.0.1:<server-port>",
        "DASH_MCP_HOST": "ocean",
        "DASH_MCP_AGENT": "luce"
      }
    }
  }
}
```

Notes:

- `<server-port>` today is whatever the `./pc` wrapper allocated into
  `.ports.env`. For real use, pin a fixed port (drop `shuf` from `./pc`) or
  promote the server behind a systemd unit on `ocean`.
- Per `keystone` rules 17–21, each `~/.claude.json` MUST be **merged** by a
  home-manager activation script — never written as `home.file."...".text`,
  which would create an immutable symlink Claude Code can't update.

### Quickest path — `bin/dash-claude` wrapper

For local testing without touching `~/.claude.json`, `code/bin/dash-claude`
writes a one-shot MCP config to `mktemp` and execs `claude --mcp-config <that>`:

```bash
cd spikes/dash-mcp/code
./bin/dash-claude --agent drago --host ncrmro-workstation
./bin/dash-claude --agent luce  --host ocean
./bin/dash-claude --agent drago --host ncrmro-workstation --strict -- \
    -p "List dash-mcp projects" --output-format json
./bin/dash-claude --agent drago --host ncrmro-workstation --dry-run
```

The wrapper reads `SERVER_PORT` out of `.ports.env`, so `./pc up -D` must have
been run first. The temp config is cleaned up on exit via `trap`. Pass
`--strict` to forward `--strict-mcp-config` (only `dash-mcp` is exposed; the
user's own `mcpServers` are ignored for that invocation). Pass `--dry-run` to
print the resolved config and argv without launching claude.

### Host-level (future)

When the spike graduates, agent-scoped MCP configs go through
`keystone.os.agents.<name>.mcp.servers` in `~/.keystone/repos/ncrmro/keystone/modules/os/agents/`,
which the existing `agentctl` MCP-config publisher already wires into each
agent user's shell. The fleet definition for `drago` and `luce` already lives
in `tests/module/agent-evaluation.nix`; adding a `dash-mcp` server entry there
plus a token under `keystone.keys` lets every adopter pick it up.

## Running the spike

Devshell + workspace install:

```bash
cd spikes/dash-mcp/code
direnv allow                    # or: nix develop
bun install
bun run db:generate             # drizzle-kit emits SQL migrations
```

All process-compose commands go through the local `./pc` wrapper, which:

- allocates a random port for `sqld`, `server`, and `web` on first `up`,
  persists them to `./.ports.env`, and re-sources that file on every
  subsequent invocation so logs/list/down see the same ports;
- pins process-compose's API socket to `$XDG_RUNTIME_DIR/dash-mcp-spike.pc.sock`
  (the worktree path is longer than Linux's 108-byte `AF_UNIX` limit).

Bring up sqld + migrate + server + web:

```bash
./pc up -D --tui=false
./pc process list -o json | jq '.[] | {name, status, is_ready}'
cat .ports.env                 # SQLD_HTTP_PORT, SERVER_PORT, WEB_PORT, …
```

Smoke test:

```bash
set -a && source .ports.env && set +a

curl -sS "http://127.0.0.1:${SERVER_PORT}/healthz"

curl -sS -X POST "http://127.0.0.1:${SERVER_PORT}/api/projects" \
  -H 'content-type: application/json' \
  -d '{
    "slug": "keystone",
    "title": "Keystone",
    "purpose": "Self-sovereign NixOS infrastructure platform.",
    "status": "active",
    "missionMdPath": "projects/keystone/mission.md",
    "values": ["Operational rigor over novelty", "Conventions as code"],
    "scopeIn": ["NixOS modules", "DeepWork jobs"],
    "scopeOut": ["Vendor lock-in"]
  }' | jq

# Append a report via the MCP tool — host/agent injected from env
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"project_report","arguments":{"slug":"keystone","kind":"work_update","summary":"Scaffolded dash-mcp spike","refs":["gh:ncrmro/nixos-config"]}}}'
  sleep 0.5
) | DASH_MCP_SERVER_URL="http://127.0.0.1:${SERVER_PORT}" \
    DASH_MCP_HOST="$(hostname)" \
    DASH_MCP_AGENT="${USER}" \
    bun run mcp/src/index.ts

curl -sS "http://127.0.0.1:${SERVER_PORT}/api/projects/keystone" | jq '.reports'
```

Then open `http://127.0.0.1:${WEB_PORT}/` — the project and report show up on
`/`, and `/hosts` + `/agents` list the reporting host/agent.

Inspecting logs (per the global process-compose rule against `-f`, the `./pc`
wrapper exposes the same `-n` flag the upstream CLI uses for tailing):

```bash
./pc process logs sqld   -n 100
./pc process logs server -n 100
./pc process logs web    -n 100
```

Tear down:

```bash
./pc down
rm -f .ports.env .pc.sock      # optional; freed automatically
```

### Note on `env_cmds`

The keystone process-compose convention recommends a top-level `env_cmds:`
block (`PORT: "shuf -i 10000-60000 -n 1"`) with `$${VAR}` interpolation. The
process-compose version in `pkgs.process-compose` at the time of this spike
did **not** honor that substitution — `${VAR}` references resolved to empty
strings in both `command:` and `environment:` fields. The `./pc` wrapper +
`.ports.env` workaround is functionally equivalent and gets the spike
running today; once the convention's prerequisites land in nixpkgs, swap
in the `env_cmds` form.

## Conventions enforced

- Bun workspace under `code/` with a flake devshell providing `bun`, `nodejs_22`,
  `process-compose`, `sqld`, `sqlite`, `jq`. Per `process.keystone-development`
  rules 1 and 5.
- `process-compose.yaml` uses `env_cmds` with `shuf` for dynamic ports, `$${VAR}`
  double-dollar interpolation, and `PC_NO_SERVER=1`. Per global Process Compose
  rules.
- Drizzle schema is the single source of truth for the DB; zod validators are
  separate request-shape contracts. Drizzle-inferred row types are re-exported
  from `@dash-mcp/db`.
- Refs in `project_report.refs[]` use the keystone-normalized form: `gh:owner/repo#n`,
  `fj:owner/repo#n`, or `gh:owner/repo` / `fj:owner/repo` for repo-only. Per
  `process.keystone-development` rules 16–18.

## Open questions / next steps

- **Auth.** v1 is loopback-only. The obvious next step is Tailscale + a
  per-host agenix secret (`agent-<name>-dash-mcp-token` or a single
  `dash-mcp-fleet-token`). Out of scope for the spike.
- **Promotion path.** Once stable: package `@dash-mcp/mcp` as a Nix derivation,
  expose `keystone.services.dashMcp = { enable, listenAddress, … }`, and add a
  `keystone.os.agents.<name>.mcp.servers."dash-mcp"` factory so any agent's
  MCP config picks it up automatically.
- **Alignment with Vega.** Vega is the project-acceleration agent; dash-mcp is
  the surface it (and every other agent) reports into. Vega-specific tools
  (e.g. `project_audit`, `project_plan`) can layer on top of the current
  data model without schema changes.
- **`sqld` packaging.** This spike depends on `pkgs.sqld`; if that disappears
  from nixpkgs upstream, fall back to embedded libSQL inside the server and
  keep the separate-process topology behind the same `DATABASE_URL` env var.
- **Web SSR vs static.** Currently `output: "server"` with the Node adapter so
  the `[slug]` dynamic route works. If we revisit, a static + client-fetch
  build is also viable.
