# Bridl profiles

Profiles are composable layers for agent behavior. Keep each profile focused on
one dimension so personas can combine reusable building blocks without copying
skills or prompt text.

Profile layers:

- `default`: neutral provider, model, and thinking defaults. This currently
  defaults every Bridl profile to `gpt-5.5`.
- Runtime base: where the agent is being started, such as `runtime-user-direct`,
  `runtime-os-agent-home`, or `runtime-container`.
- Host base: host-local context, such as `host-ncrmro-workstation`,
  `host-ncrmro-laptop`, `host-ocean`, or `host-mercury`.
- Domain base: shared repo or operating context, such as `keystone-os`.
- Role base: reusable job shape, such as `platform-engineer`, `product-lead`,
  or `project-manager`.
- Persona: portable named identity, such as `drago` or `luce`. Persona profiles
  must not hard-code Keystone fleet paths, host assumptions, or container
  assumptions; compose a host/runtime/domain profile when that context is true.

Examples:

- Direct user workstation Keystone work: `bridl run -p vega -p host-ncrmro-workstation -p runtime-user-direct`
- OS-agent Drago home: `bridl run -p drago -p runtime-os-agent-home`
- Portable Luce in a container: `bridl run -p luce -p runtime-container`
- Fast prototyping: `bridl run -p vibe-code -p runtime-user-direct`

If your launcher supports an environment-variable profile selector, set it to
these same profile ids (for example `BRIDL_PROFILE=vega,host-ncrmro-workstation,runtime-user-direct`).
Prefer explicit `-p` arguments when possible so the active context is visible in
logs and shell history.

A good building-block profile is narrow, stable, and non-personal. In the
current Bridl merger, `skills` compose across inherited profiles, while
`append_system_prompt` is a scalar where the higher-precedence profile wins.
Role bases may own reusable delivery guidance as `append_system_prompt` when
persona profiles use `system_prompt` for identity text; avoid duplicating shared
workflow rules in persona profiles.
