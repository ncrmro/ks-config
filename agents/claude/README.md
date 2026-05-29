# Claude-specific assets

Files that only Claude Code reads. Other CLI coding agents read from
`../skills/` and `../_shared/` — those are cross-tool. This directory
holds the Claude-only surface.

## Layout

- **`agents/`** — Claude subagent personas (`name` + `description`
  frontmatter, full persona body). Claude's Task tool discovers
  subagents from this path and uses the `description` to decide when to
  delegate.

The `~/.claude/skills/` symlink resolves to `../skills/` (the
cross-tool canonical), so Claude shares the skill catalog with every
other spec-compliant agent. Only subagents are vendor-specific.

Gemini and Codex have their own subagent/persona surfaces upstream,
but keystone does not currently emit content for them — only Claude.
The directory layout is keystone-managed; the upstream tools may
have richer support that keystone simply hasn't wired in yet.
