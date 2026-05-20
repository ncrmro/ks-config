# Skills

Canonical skill tree per the [`.agents/skills/` open standard][spec].
Every CLI coding agent reads this directory:

- **Codex, Gemini CLI, GitHub Copilot CLI, Cursor, Rovo Dev, Kiro,
  OpenCode, Augment** read it via `~/.agents/skills/` (the user-tier
  spec path).
- **Claude Code** reads it via `~/.claude/skills/` (Claude vendor
  path). Same target — home-manager activation symlinks both at the
  same canonical directory.

## Layout

Each skill is a subdirectory named lowercase-with-hyphens per the
spec. Inside:

- `SKILL.md` — frontmatter (`name` + `description`) + body. The
  `name:` field MUST match the directory name; mismatch causes silent
  load failure in spec-compliant agents.
- `<convention>.md` — symlinks into `../../_shared/conventions/`, one
  per colocated convention or role.

## Naming

- `ks-*` — keystone-curated skills tied to a slash-command id
  published by this host (e.g., `/ks-engineer`, `/ks-notes`). Only
  emitted if the host capability set includes the matching command.
- Bare names (`deepwork`, `wrap-up`, `review`) — always-on workflow
  skills that don't gate on capability.

Add user-authored skills via `<consumer-flake>/agents/_shared/skills.yaml`.

[spec]: https://github.com/ncrmro/keystone/blob/main/docs/research/agent-skills.md
