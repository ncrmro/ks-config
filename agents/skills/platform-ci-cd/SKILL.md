---
name: platform-ci-cd
description: "Platform CI/CD and deployment architecture — provider-agnostic pipelines, previews, secrets, releases, and hosting deploys"
---

Use this skill when planning, implementing, or reviewing build, preview, deploy,
and release automation across providers.

Keep this skill provider/implementation agnostic. Provider-specific deployment
notes belong in sibling files and are referenced from this skill.

## Supporting references

Read the relevant files before changing deployment automation:

- [Cloudflare Workers deployment notes](cloudflare-workers.md) — Wrangler,
  Workers vs Pages, local preview, bindings, Workers Builds, GitHub Actions,
  secrets, and PR checks.

## Decision areas

Use this skill for:

- CI workflow structure and required checks.
- Preview deployment strategy and branch/environment isolation.
- Production deploy promotion, approvals, and rollback shape.
- Secret management and build-time vs runtime environment variables.
- Provider-hosted builds vs GitHub Actions or other external CI.
- Deployment validation: smoke tests, migrations, asset uploads, and generated
  types.
- Monorepo deploy paths, watch paths, and working-directory discipline.

## Grouping convention

- Add provider/deploy-target files here: `cloudflare-workers.md`, `vercel.md`,
  `fly-io.md`, `railway.md`, etc.
- Add generic process files here when they span providers: `preview-envs.md`,
  `release-gates.md`, `secrets.md`, etc.
- Keep framework runtime decisions in `platform-web` and database/storage
  decisions in their own platform skills; link between skills rather than
  duplicating content.
