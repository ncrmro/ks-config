---
name: task-loop
description: "Process the agent's inbox once: reply to [ping] messages with [pong], then exit. Designed to be invoked on a recurring systemd timer."
---

# Task-loop

A single non-interactive pass over the agent's inbox. Invoked by a
systemd user timer (see keystone `taskLoop` module). Each tick is a
fresh process — no internal looping, no long-running state.

Initial scope is ping/pong only. Future revisions will add calendar,
forgejo, and project-status ingest. Do not invent work outside this
scope; exit cleanly when there is nothing to do.

## Context to load before acting

Read these from the agent's home directory:

- @~/SOUL.md, @~/ROLE.md, @~/AGENTS.md — identity and operating rules.
- @~/TEAM.md, @~/HUMAN.md — addressing and operator profile.
- @~/PROJECTS.yaml — portfolio for disambiguating thread context.

## Procedure

1. List unread envelopes as JSON:

   ```sh
   himalaya envelope list --output json
   ```

2. Filter the result in-memory to envelopes whose `subject` starts with
   `[ping] ` and whose `flags` array does NOT include `Answered` (or the
   server-specific spelling — IMAP exposes the flag as `\Answered`,
   himalaya's JSON output usually normalises to `Answered`).

3. For each matching envelope:
   - Fetch the full message body for context:
     ```sh
     himalaya message read <id>
     ```
   - Reply with body `pong`:
     ```sh
     himalaya message reply <id> pong
     ```
     `himalaya message reply` prefills the standard `Re: <subject>` and
     marks the source envelope `\Answered` on send. Verify both before
     moving on — if either is missing, fall back to:
     ```sh
     himalaya flag add <id> answered
     ```

4. After processing all matches, exit 0. Do not poll, do not retry, do
   not write to TASKS.yaml — the next tick of the systemd timer will
   pick up new mail.

## Hard limits

- Do not reply to a message that is not a `[ping] <tag>`.
- Do not initiate new threads from this skill.
- Do not invoke other skills (no deepwork, no /ks, no /ks.ea) inside
  this tick.
- If the inbox lookup fails (network, auth), log the error to stderr
  and exit non-zero. The timer will retry on the next tick.
