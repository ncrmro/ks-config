# Claude skills

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

- `ks-host-sync` -> `../../skills/ks-host-sync`
- `repo-development-pipeline-operator` -> `../../skills/repo-development-pipeline-operator`
- `repo-release-operator` -> `../../skills/repo-release-operator`
