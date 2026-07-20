# Skills

This live skill surface is intentionally empty as of 2026-06-09 while the
agent skills are reevaluated.

Archived skill bodies are in `../archive/skills-2026-06-09/skills/`.

This directory remains in place because CLI coding agents read it as the
canonical [`.agents/skills/` open standard][spec] path:

- **Codex, Gemini CLI, GitHub Copilot CLI, Cursor, Rovo Dev, Kiro,
  OpenCode, Augment** read it via `~/.agents/skills/` (the user-tier
  spec path).
- **Claude Code** reads it via `~/.claude/skills/` (Claude vendor
  path). Same target — home-manager activation symlinks both at the
  same canonical directory.

## Restoring skills

Move only reevaluated skill directories back from the archive. Each restored
skill must be a subdirectory named lowercase-with-hyphens per the spec. Inside:

- `SKILL.md` — frontmatter (`name` + `description`) + body. The
  `name:` field MUST match the directory name; mismatch causes silent
  load failure in spec-compliant agents.
- `<convention>.md` — symlinks into `../../_shared/conventions/`, one
  per colocated convention or role.

## Naming

- `ks-*` — keystone-curated skills tied to a slash-command id
  published by this host (e.g., `/ks-engineer`, `/ks-dev`). Only
  emitted if the host capability set includes the matching command.
- Bare names (`deepwork`, `wrap-up`, `review`) — always-on workflow
  skills that don't gate on capability.

Add user-authored skills via `<consumer-flake>/agents/_shared/skills.yaml`.

[spec]: https://github.com/ncrmro/keystone/blob/main/docs/research/agent-skills.md
