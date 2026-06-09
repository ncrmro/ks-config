# Claude skills

This live Claude-facing skill surface is intentionally empty as of 2026-06-09
while the agent skills are reevaluated.

Archived Claude-facing links are in
`../../archive/skills-2026-06-09/claude/skills/`.

Claude Code reads skills from `~/.claude/skills/`. Codex and other
spec-compliant CLI coding agents read from `~/.agents/skills/`.

Keystone keeps the canonical cross-tool skill bodies in
`../../skills/`. This directory is the Claude-facing surface and should
usually contain symlinks back to those canonical skill directories.

## Rules

- Author cross-tool skills in `../../skills/<name>/SKILL.md`.
- Expose them to Claude with `skills/<name> -> ../../skills/<name>`.
- Add Claude-only skill bodies here only when Claude needs different
  naming, metadata, or loader-specific instructions.
- Do not create Claude subagents for skill work; subagents live in
  `../agents/` and are a separate Claude Task-tool persona system.

## Current skills

None.
