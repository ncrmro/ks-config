# Shared conventions

Centralized convention and role bodies referenced by skills under
`../../skills/<name>/`. Each file appears once here and is symlinked
into every skill that references it via `colocated_conventions` or
`colocated_roles` in `conventions/archetypes.yaml.skills` (keystone
repo).

## Naming

- `process.<name>.md` — process conventions (how we ship, review,
  branch, etc.)
- `code.<name>.md` — code-level conventions (shell scripts, comments,
  etc.)
- `tool.<name>.md` — tool-specific conventions (forgejo, github,
  mermaid, etc.)
- `<role>.md` — role definitions (`software-engineer`, `code-reviewer`,
  `project-lead`, etc.) — flat namespace, no `role.` prefix.

## Source of truth

These files are copies of keystone repo `conventions/*.md` and
`conventions/roles/*.md`. Edits here are clobbered by the next
`ks sync-agent-assets`. To change a convention, edit the keystone repo
(or your consumer-flake overlay) instead.
