# ApplePi profiles

Profiles are composable layers for agent behavior. Keep each profile focused on
one dimension so personas can combine reusable building blocks without copying
skills or prompt text.

Profile layers:

- `default`: neutral provider, model, and thinking defaults. This currently
  defaults every ApplePi profile to `gpt-5.5`.
- OS environment base: where the agent is being started, exactly one of
  `os-ks-admin-user`, `os-ks-agent-user`, or `os-ks-container`.
- Fleet base: Keystone fleet context from the single `ks-fleet` profile,
  parameterized by Keystone-provided environment variables/assets such as
  `$KEYSTONE_CURRENT_HOST` and generated host/agent/team/service metadata.
- Domain base: shared repo or operating context, such as `keystone-os`.
- Role base: reusable job shape, such as `platform-engineer`, `product-lead`,
  or `project-lead`.
- Persona: portable named identity, such as `drago` or `luce`. Persona profiles
  must not hard-code Keystone fleet paths, host assumptions, or container
  assumptions; compose a fleet, OS-environment, and domain profile when that
  context is true.
- Launch composite: `outfitter run --profile` takes a single profile, so
  recurring launch contexts get a thin composite profile whose only job is
  `inherits` — e.g. `drago-os-agent` = `drago` + `ks-fleet` +
  `os-ks-agent-user`. Keystone's pi-task-runner and vega's pi-rpc bridge
  launch agents with these composites.

Examples:

- OS-agent Drago home: `outfitter run -p drago-os-agent`
- OS-agent Luce home: `outfitter run -p luce-os-agent`
- Admin-user Keystone work: compose a `vega-os-admin`-style profile inheriting
  `vega` + `ks-fleet` + `os-ks-admin-user`, then `outfitter run -p <id>`
- Portable Luce in a container: a composite inheriting `luce` + `os-ks-container`

A good building-block profile is narrow, stable, and non-personal. In the
current ApplePi merger, `skills` compose across inherited profiles, while
`append_system_prompt` is a scalar where the higher-precedence profile wins.
Role bases may own reusable delivery guidance as `append_system_prompt` when
persona profiles use `system_prompt` for identity text; avoid duplicating shared
workflow rules in persona profiles.
