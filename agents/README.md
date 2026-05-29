# Agents

This directory holds the agent assets installed on this host. Every CLI
coding agent — Claude Code, Codex, Gemini CLI, GitHub Copilot CLI,
Cursor, Rovo Dev, Kiro, OpenCode, Augment — reads from this tree via
home-dir symlinks that home-manager activation creates.

## Layout

| Path | Purpose |
|---|---|
| `_shared/AGENTS.md` | Single canonical instruction file. The per-tool symlinks (`~/.claude/CLAUDE.md`, `~/.gemini/GEMINI.md`, `~/.codex/AGENTS.md`) all resolve here. |
| `_shared/conventions/` | Centralized conventions and roles, referenced by skills via per-skill symlinks. |
| `_shared/TEAM.md` | Generated roster for humans and OS agents. OS agents receive this as `~/TEAM.md`. |
| `_shared/SERVICES.md` | Generated service index. OS agents receive this as `~/SERVICES.md`. |
| `<agent>/AGENTS.md` | User-authored OS-agent instruction file. OS agents receive this as `~/AGENTS.md` and `~/.pi/agent/AGENTS.md`. |
| `<agent>/SYSTEM.md` | User-authored OS-agent system file. OS agents receive this as `~/SYSTEM.md`, `~/.pi/agent/SYSTEM.md`, and `~/.pi/agents/SYSTEM.md`. |
| `<agent>/SOUL.md` | Generated OS-agent identity file. OS agents receive this as `~/SOUL.md`. |
| `skills/` | Canonical skill tree per the [`.agents/skills/` open standard][spec]. Read by every spec-compliant agent. |
| `claude/agents/` | Claude-specific subagent personas. Read via `~/.claude/agents/`. |

## Maintenance

- `ks sync-agent-assets` regenerates keystone-curated content. Per-host
  state (capabilities, archetype) determines which skills land. The
  command is manual — `ks switch` / `ks update --dev` never write here
  implicitly.
- User-authored content in `claude/agents/<persona>.md`,
  `_shared/skills.yaml`, `<agent>/AGENTS.md`, and `<agent>/SYSTEM.md`
  survives sync.
- OS-agent identity docs are rooted here, not in `~/notes`: activation links
  `~/SOUL.md`, `~/TEAM.md`, and `~/SERVICES.md` into each agent home.
- README files in this tree (including this one) are regenerated;
  edits there will be overwritten.

[spec]: https://github.com/ncrmro/keystone/blob/main/docs/research/agent-skills.md
