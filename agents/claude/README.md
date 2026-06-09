# Claude-specific assets

Files that only Claude Code reads. Other CLI coding agents read from
`../skills/` and `../_shared/` — those are cross-tool. This directory
holds the Claude-only surface.

## Layout

- **`agents/`** — Claude subagent personas (`name` + `description`
  frontmatter, full persona body). Claude's Task tool discovers
  subagents from this path and uses the `description` to decide when to
  delegate.
- **`skills/`** — Claude Code skill surface. Currently empty while skills
  are reevaluated; archived links are under
  `../archive/skills-2026-06-09/claude/skills/`.

When skills are restored, most should be authored once in `../skills/`,
then exposed to Claude through `skills/`. This keeps Codex, Gemini, and
other spec-compliant agents aligned with Claude while still acknowledging
that Claude and Codex use different skill lookup paths:

- Codex/spec-compliant path: `~/.agents/skills/`
- Claude path: `~/.claude/skills/`

When adding a new cross-tool skill, create the canonical directory in
`../skills/<name>/` and add a matching symlink in `skills/<name>/`.
Do not duplicate the skill body unless Claude genuinely needs a
different version.

Gemini and Codex have their own subagent/persona surfaces upstream,
but keystone does not currently emit content for them — only Claude.
The directory layout is keystone-managed; the upstream tools may
have richer support that keystone simply hasn't wired in yet.
