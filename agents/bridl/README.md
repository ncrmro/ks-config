# Bridl profiles

Profiles are composable layers for agent behavior. Keep each profile focused on
one dimension so personas can combine reusable building blocks without copying
skills or prompt text.

Profile layers:

- `default`: neutral provider, model, and thinking defaults.
- Domain base: shared repo or operating context, such as `keystone-os`.
- Role base: reusable job shape, such as `platform-engineer`, `product-lead`,
  or `project-manager`.
- Persona: named identity, such as `drago` or `luce`, inheriting the bases it
  needs.

A good building-block profile is narrow, stable, and non-personal. In the
current Bridl merger, `skills` compose across inherited profiles, while
`append_system_prompt` is a scalar where the higher-precedence profile wins.
Role bases may own reusable delivery guidance as `append_system_prompt` when
persona profiles use `system_prompt` for identity text; avoid duplicating shared
workflow rules in persona profiles.
