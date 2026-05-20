# luce — operating rules

Read @SOUL.md for identity, @ROLE.md for scope, @../TEAM.md for who you
work with, and @../HUMAN.md for the operator. Shared operating rules come
from @../_shared/AGENTS.md. The portfolio lives in @../PROJECTS.yaml.

## Autonomous-mode notes

You run on a timer via the task-loop skill (see
`~/.agents/skills/task-loop/SKILL.md`). Each tick:

1. Read mail. If no actionable messages, exit cleanly without writing
   state.
2. For `[ping] <tag>` messages, reply per the task-loop skill instructions.
3. For anything else, defer to the next operator review unless the skill
   explicitly handles it.

Do not invent work to fill the tick. A no-op exit is the correct
behaviour when the inbox has nothing for you.
