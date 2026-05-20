# Proposals: agent notification flows

Concrete examples of how an agent (drago, luce, or any future identity) can
use `dash-mcp` together with existing Keystone surfaces — `keystone.os.notifications`,
`notify-send`, `agentctl mail`, the issue-journal convention — to surface
project / repo / issue / milestone state without forcing the user to poll a
dashboard.

The premise is that **dash-mcp is the canonical event store** (missions +
reports keyed by host + agent) and the existing Keystone surfaces are the
**delivery channels** (terminal banner, desktop toast, agent inbox, Forgejo
comment). Each proposal pairs a trigger with a channel and shows the exact
data path.

## Channel inventory

| Channel | API | Latency | Audience |
| ------- | --- | ------- | -------- |
| `keystone.os.notifications.items` | Add an `{id, title, body, markerFile}` entry. Fires at interactive shell login when `markerFile` is absent. | Next shell login | User on the host |
| `/var/lib/keystone/<id>` marker file | Touch from a root systemd unit to clear a banner; absence triggers it. | Immediate (next desktop poll) | User on the host |
| `notify-send` (libnotify) | `notify-send -u <urgency> -t <ms> "<title>" "<body>"` from any user shell with `DISPLAY`/`WAYLAND_DISPLAY`. | Real-time | Active desktop session |
| `agentctl <agent> mail` | Stalwart-backed structured email between agents and the human. | Seconds | Owning agent's inbox |
| `process.issue-journal` (Forgejo/GitHub) | `gh`/`fj` comment on a tracked issue. | Real-time | All issue watchers |
| `dash-mcp` web dashboard | Astro SSR over the libSQL store. | Real-time on refresh | Anyone with the URL |

## Proposal 1 — Owned-missions login digest

**Trigger**: a daily systemd timer at 06:00 local.

**Flow**:

1. The timer runs `dash-mcp digest --agent $AGENT --host $HOST`, a small
   wrapper that calls `mission_list({status:"active"})` over the MCP and
   filters to `owner_agent == $AGENT`.
2. For each owned mission it pulls `mission_get(slug)` and renders an
   ASCII block: title, top-of-list in-progress milestone, last report
   timestamp.
3. The digest is written to `/var/lib/keystone/dash-mcp-digest-$AGENT`
   (via a root unit) and the body is also fed into a generated
   `keystone.os.notifications.items` entry whose `markerFile` is
   `/var/lib/keystone/dash-mcp-digest-$AGENT-ack`.
4. At next shell login the banner fires. The user runs
   `dash-mcp digest --ack` to touch the ack marker; the banner stops.

**Why this is efficient**: a single MCP round-trip per agent per day, no
polling from the human, and the banner only appears when there's something
new to acknowledge.

```
┌──────────────────────────────────────────────────────────┐
│  drago — owned missions (2026-05-20)                     │
├──────────────────────────────────────────────────────────┤
│  ◐ Keystone           Stabilize agentctl + per-agent MCP │
│                       last report 6h ago                 │
│  ○ Plant Caravan      Indoor sensor v1 (in_progress)     │
│                       no reports in 3d ← stale           │
│  Run `dash-mcp digest --ack` to dismiss.                 │
└──────────────────────────────────────────────────────────┘
```

## Proposal 2 — Milestone-flip desktop toast

**Trigger**: any `mission_update` that transitions a milestone from
non-`done` → `done`, or a `mission_report` with `kind=done`.

**Flow**:

1. dash-mcp server adds a post-write hook (`server/src/hooks.ts`) that
   compares the previous and new milestone status.
2. On a transition to `done`, the server enqueues a notification record
   to a `notification_outbox` table with `(host, agent, kind, title, body)`.
3. A per-host `dash-mcp-notifier.service` (systemd user unit) tails the
   outbox over the MCP using a new `notification_drain` tool. For each
   row matching its `$HOST` + `$AGENT`, it runs
   `notify-send -u normal -t 4000 "✓ <mission>" "<milestone>"`.
4. The drain marks the row delivered so other hosts/agents don't repeat
   the toast for the same event.

**Why this is efficient**: the outbox decouples the event from the
delivery — laptops that are offline catch up the next time the notifier
service wakes. The same outbox can later feed a `keystone.os.notifications`
banner for headless hosts.

## Proposal 3 — Issue → mission report bridge

**Trigger**: Forgejo / GitHub webhook on issue or PR events (opened,
labeled, closed, reviewed).

**Flow**:

1. dash-mcp adds an HTTP endpoint `POST /webhooks/forgejo` and
   `POST /webhooks/github` that accepts the standard webhook payload.
2. The handler maps the event to a `mission_report`:
   - Look up the mission by `repo` join (`mission_repo.ref`).
   - Build `summary` from the event (e.g. `"PR #42 opened by drago: feat: hosts page"`).
   - Set `refs` to the normalized form (`fj:ncrmro/keystone#42`) per
     `process.keystone-development` rules 16-18.
   - Attribute `host` + `agent` from the event payload (the bot user maps
     to the agent that owns the linked repo).
3. The web dashboard now shows the issue/PR in the mission's report
   timeline alongside agent-authored reports.
4. When the same agent later posts a Work Started/Work Update comment on
   the issue via the `process.issue-journal` convention, the agent's
   `mission_report` MCP call carries the same `refs`. Deduplication is by
   `(mission_id, kind, refs[0], created_at within 60s)`.

**Why this is efficient**: one source of truth for "what happened on this
project this week" instead of three different surfaces (Forgejo issue
log, agent notes, dashboard) that drift apart.

## Proposal 4 — Blocked-mission login warning

**Trigger**: any mission with `status=blocked` OR a `mission_report` with
`kind=blocked` in the last 24h that has not been resolved by a subsequent
`work_update` / `done`.

**Flow**:

1. Same timer as Proposal 1, but a separate "blocked" pass runs every
   hour.
2. For each blocking condition it writes a `keystone.os.notifications.items`
   entry with `urgency=critical` styling (red ANSI) and `markerFile =
   /var/lib/keystone/dash-mcp-blocked-<mission_slug>`.
3. The marker is cleared by the server when a `work_update` lands that
   references the same mission, OR when the user runs
   `dash-mcp ack blocked <slug>`.

**Why this is efficient**: blocking conditions are rare and high-signal;
they earn a critical-urgency banner without the noise of per-event toasts.
A blocked mission across the fleet pages every owner at every host they
log into until it's resolved.

## Proposal 5 — Repo-activity attribution

**Trigger**: the daily digest pass (Proposal 1) extended with repo
context.

**Flow**:

1. For each mission, query the linked repos and run
   `git -C ~/repos/<owner>/<repo> log --since=24h --pretty=oneline`
   filtered to the agent's authored commits.
2. If commits are present but no `mission_report` lands for the same
   mission in the same window, surface a low-priority banner: *"You
   committed to <repo> but did not file a mission report — run
   `dash-claude --agent <name>` to draft one."*
3. The pass is local-only (no network) — it just reconciles git log
   against the dash-mcp report stream.

**Why this is efficient**: turns missing reports into a feedback loop the
user can act on inside a shell, with no extra tracking infrastructure.
Plays well with the existing `~/repos/<owner>/<repo>` convention.

## Proposal 6 — Inter-agent handoff via `agentctl mail`

**Trigger**: a `mission_update` that changes `owner_agent` from A to B,
OR an explicit `mission_handoff` MCP tool call (future addition).

**Flow**:

1. dash-mcp's update handler computes a handoff summary: mission slug,
   purpose, in-progress milestones, last 5 reports.
2. It shells out to `agentctl <new_owner> mail send` with a structured
   subject (`[dash-mcp] handoff: <slug>`) and the summary as the body.
3. The new owner's `task-loop` picks up the message at its next tick —
   already documented in `~/.keystone/repos/ncrmro/keystone/modules/os/agents/AGENTS.md`
   under `agentctl <agent> email`.
4. The handoff also writes a `mission_report` (`kind=note`) so the
   timeline shows when ownership changed and to whom.

**Why this is efficient**: piggybacks on the agent inbox loop that
already exists; no new daemon, no new schedule. Email-as-protocol is
heavyweight for chatty events but right-sized for handoffs.

## Proposal 7 — Stale-mission self-archive prompt

**Trigger**: nightly. Mission with `status=active` and no report in 30+
days.

**Flow**:

1. dash-mcp surfaces a `mission_list_stale(threshold_days=30)` MCP tool.
2. A nightly DeepWork job runs the equivalent of Proposal 1 but for
   stale missions and asks the agent (via the same `dash-claude` wrapper)
   to either:
   - Post a `mission_report` justifying why it's still active, or
   - Patch the mission to `status=archived` with a closing summary.
3. The agent's decision is itself a report; the dashboard's stale
   indicator clears.

**Why this is efficient**: the inventory cleans itself instead of relying
on the human to spring-clean. The agent is doing what it's already good
at — synthesizing recent activity — and the work product (a report or
an archive) is the same artifact the dashboard already understands.

## Proposed schema v2: project / milestone / task

The current `mission` table conflates two things: a Keystone-style mission
statement (purpose / values / scope — the brand-voice artifact in
`~/notes/projects/<name>/mission.md`) and the operational rollup the
dashboard actually cares about. They should split.

- **Project** is the operational primitive — what dash-mcp tracks.
- **Mission** stays in Keystone's voice as a narrative file inside the
  project (literally `project.mission_md_path` or similar), not its own
  database row.
- **Milestone** is the planning rollup inside a project.
- **Task** is the actionable unit — a decision or action (human or agent),
  often with a source ref into an external provider (GitHub issue, Forgejo
  PR, Slack thread, email, calendar event, agent handoff). Tasks are the
  level at which "reply to this PR review", "decide on the
  database-vendor swap", "ack the agentctl rollout" all live next to each
  other in one timeline.

### Tables

```ts
project
  id, slug (unique), title, status (proposed|active|blocked|done|archived)
  owner_agent (nullable), created_at, updated_at
  mission_md_path (nullable) — pointer to the narrative file in notes

project_value     id, project_id, text
project_scope     id, project_id, kind (in|out), text
project_repo      id, project_id, ref, url, label

milestone
  id, project_id, title, target_at (nullable),
  status (planned|in_progress|blocked|done|cancelled)

task
  id, project_id, milestone_id (nullable)
  title, body (nullable)
  kind (review|reply|decide|implement|triage|ack|other)
  status (open|in_progress|blocked|done|wontfix)
  source_ref (nullable, provider-qualified — see below)
  source_url (nullable)
  requester (nullable, free-form: agent name, gh login, "human", …)
  assignee_agent (nullable)
  due_at (nullable), created_at, updated_at

task_event
  id, task_id, host, agent
  kind (work_started|work_update|blocked|done|comment_posted|reviewed|note)
  summary, refs (JSON array of refs), created_at

host              id, hostname, first_seen, last_seen
agent             id, name, host_id, first_seen, last_seen
                  (composite-unique on name+host_id)
```

### `source_ref` — the provider join key

One column carries the cross-provider linkage. Normalized so refs are
greppable and dedupable; the matching `source_url` is the human-clickable
form.

| Provider          | `source_ref` shape                  | Example                       |
| ----------------- | ----------------------------------- | ----------------------------- |
| GitHub issue / PR | `gh:<owner>/<repo>#<n>`             | `gh:ncrmro/keystone#280`      |
| GitHub PR review  | `gh:<owner>/<repo>#<n>/review/<id>` | `gh:ncrmro/keystone#280/review/882` |
| Forgejo issue/PR  | `fj:<owner>/<repo>#<n>`             | `fj:ncrmro/notes#10`          |
| Slack message     | `slack:<workspace>/<channel>/<ts>`  | `slack:T123/C456/1730000000.0001` |
| Email             | `mail:<message-id>`                 | `mail:<abc@host>`             |
| Calendar event    | `cal:<ics-uid>`                     | `cal:plant-caravan-sync@…`    |
| Agent handoff     | `agent:<from>/<kind>/<id>`          | `agent:luce/handoff/2026-05-20-keystone` |
| Local note        | `note:<repo-relative-path>`         | `note:projects/keystone/2026-05-20.md` |

Rules (extends `process.keystone-development` 16-18):

- `source_ref` is canonical and unique per task — webhooks dedupe on it.
- `source_url` is informational; agents render it for humans but never
  parse it.
- Tasks without a `source_ref` are local-only (e.g. a manual `decide`
  task an agent files for itself).

### Example payloads

A PR review request lands on drago:

```json
{
  "project_slug": "keystone",
  "milestone_id": null,
  "kind": "review",
  "status": "open",
  "title": "Review #280: claude --agent <name> CLI surface",
  "source_ref": "gh:ncrmro/keystone#280",
  "source_url": "https://github.com/ncrmro/keystone/pull/280",
  "requester": "ncrmro",
  "assignee_agent": "drago",
  "due_at": "2026-05-22T17:00:00Z"
}
```

A decision task an agent files for itself, no provider source:

```json
{
  "project_slug": "ks-systems",
  "milestone_id": 17,
  "kind": "decide",
  "status": "open",
  "title": "Pick storage class default: Rook/Ceph vs Longhorn",
  "source_ref": null,
  "requester": "luce",
  "assignee_agent": "luce"
}
```

An agent-to-agent handoff lands as a task on the new owner:

```json
{
  "project_slug": "keystone",
  "kind": "ack",
  "title": "Take over Keystone ownership from luce",
  "source_ref": "agent:luce/handoff/2026-05-20-keystone",
  "requester": "luce",
  "assignee_agent": "drago"
}
```

### MCP surface (deltas only)

The shape of the existing tools changes minimally — `mission_*` →
`project_*`, plus new task tools:

- `project_list`, `project_get`, `project_create`, `project_update`
- `milestone_set` *(was `mission_milestone_set` in the prior tools doc)*
- `task_list({project?, assignee?, kind?, status?, has_source_ref?})`
- `task_get(id)`
- `task_create(...)` — host/agent auto-injected for the originator
- `task_update(id, patch)` — status + assignee transitions
- `task_event(id, {kind, summary, refs?})` — append to the task timeline

`mission_report` becomes either `task_event` (when scoped) or
`project_event` (free-form work against a project, no task). The latter
is essentially `task_event` on an implicit `kind=note` task that the
server creates on first use per project per day to keep the timeline
clean.

### Migration sketch

Practically: rename `mission*` → `project*` in the drizzle schema, add
the new `milestone` (renamed from `mission_milestone`) and `task` +
`task_event` tables, port the seed to the new shape, and re-emit a
single migration since the spike has no real data to preserve. The
drizzle-zod re-exports (`@dash-mcp/db/zod`) cascade automatically.

### Why this lands at the right level

- A **task** is the unit a human or agent can be assigned, follow up on,
  close, or hand off — the things that already show up in PR review
  queues, email inboxes, and `agentctl <agent> tasks` today, just unified.
- A **milestone** is the planning rollup the dashboard shows on the
  detail page.
- A **project** is the long-running container with a stable slug and an
  owning narrative (the mission file).
- The Keystone brand-voice **mission** is a markdown file inside the
  project — the dashboard links to it but doesn't own it. Notebook and
  dashboard agree without either being authoritative for the other.

## Cross-cutting design notes

- **Single direction of truth**: every channel above reads from dash-mcp;
  no channel writes to dash-mcp except the agent itself and the webhook
  endpoints. This keeps the data model simple — every notification is
  derived state.
- **Marker-file pattern**: `/var/lib/keystone/dash-mcp-<kind>-<id>` is
  the universal "this notification has been seen / resolved" handle.
  Writable only by root systemd units. Banners disappear when the marker
  appears.
- **Cost discipline**: per the prior tools discussion, every MCP tool
  costs context tokens. The proposals above are deliberately written so
  the *digest* tools (`mission_list_stale`, `notification_drain`, etc.)
  do the synthesis server-side, and the agent only sees a compact
  rendered result instead of raw rows.
- **Promotion path**: each proposal can land independently. The smallest
  shippable wedge is **Proposal 1** — it exercises the digest tool, the
  marker file convention, and the `keystone.os.notifications` integration
  in one pass and gives the user immediate value at every shell login.
