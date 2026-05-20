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
| `skills/` | Canonical skill tree per the [`.agents/skills/` open standard][spec]. Read by every spec-compliant agent. |
| `claude/agents/` | Claude-specific subagent personas. Read via `~/.claude/agents/`. |

## Maintenance

- `ks sync-agent-assets` regenerates keystone-curated content. Per-host
  state (capabilities, archetype) determines which skills land. The
  command is manual — `ks switch` / `ks update --dev` never write here
  implicitly.
- User-authored content in `claude/agents/<persona>.md` and
  `_shared/skills.yaml` survives sync.
- README files in this tree (including this one) are regenerated;
  edits there will be overwritten.

[spec]: https://github.com/ncrmro/keystone/blob/main/docs/research/agent-skills.md
