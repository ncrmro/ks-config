# ks-config agent layer

This directory contains project-specific agent context for `ks-config` and its
Keystone integration. Personal, reusable skills live in
`~/repos/ncrmro/.agents` and are exposed at `~/.agents` by Home Manager.

## Layout

- `skills/` — active project-specific skills.
- `legacy/outfitter/` — compatibility catalog for Outfitter 0.10. The root
  `.outfitter` path points here.
- `archive/` — superseded agent assets retained for reference but excluded from
  active discovery.

Outfitter merges profile sources last-wins. The compatibility settings load
published defaults, the personal catalog, then this project's profiles so the
project layer has the highest precedence while working in this repository.

Do not add reusable personal skills here. Put them in
`~/repos/ncrmro/.agents/skills`; keep Keystone- and ks-config-specific guidance
in this directory.
