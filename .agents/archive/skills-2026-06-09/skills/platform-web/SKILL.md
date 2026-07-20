---
name: platform-web
description: "Platform web architecture — framework/runtime selection, rendering modes, static assets, and web auth boundaries"
---

Use this skill when planning, implementing, or reviewing web application
architecture across frameworks and hosting providers.

Keep this skill provider/implementation agnostic. Put framework- or provider-
specific notes in sibling files and reference them here rather than creating a
new top-level skill for every tool.

## Supporting references

Read the relevant files before making design or implementation decisions:

- [Astro implementation notes](astro.md) — Astro static, SPA, hybrid, SSR,
  local Node/Bun, Cloudflare adapter, and Auth.js patterns observed across
  local repos.
- [Static assets and SPA delivery](static-assets.md) — immutable assets,
  SPA fallback, cache boundaries, build-time env, and asset auth gates.

## Decision areas

Use this skill for:

- Web framework/runtime selection.
- Static vs SPA vs hybrid vs SSR rendering decisions.
- Adapter/runtime selection: Node/Bun, edge workers, static hosts, or custom
  serving shells.
- Client-side build environment and public variable handling.
- Static asset delivery, cache policy, SPA fallback, and protected assets.
- Web auth boundary placement: client-only hints vs server/edge enforcement.
- Porting web apps across frameworks or hosting runtimes.

## Grouping convention

- Add framework-specific files here: `astro.md`, `nextjs.md`, `remix.md`, etc.
- Add web delivery topic files here: `static-assets.md`, `forms.md`,
  `web-auth-boundaries.md`, etc.
- Do not create a top-level `platform-<framework>` skill unless the framework
  becomes broad enough to own multiple subdocuments.
- Put deployment pipeline/provider mechanics in `platform-ci-cd`; link back here
  when a web runtime depends on those mechanics.
