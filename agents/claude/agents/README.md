# Claude subagents

Personas Claude Code can delegate to via its Task tool. Each `.md`
file declares a persona with frontmatter:

```yaml
---
name: <persona-name>
description: When to delegate to this agent
---
<body — instructions for the persona>
```

The `description` field is load-bearing — Claude uses it to decide
when to delegate. Front-load the trigger words ("Use when…").

## Authorship

Files here (other than this README) are **user-authored**. The
`ks sync-agent-assets` script does not generate persona files; it
only manages this README.

## Subagents vs colocated roles

Keystone's skill `colocated_roles` (e.g., `software-engineer`,
`code-reviewer` colocated into `ks-engineer/`) ship the role text as
*conventions* inside a skill. To expose a role as a Claude *subagent*
(something Claude can explicitly delegate to via the Task tool),
author a persona file here. The two paths are independent: a role can
be colocated without a subagent, or have a subagent without being
colocated.
