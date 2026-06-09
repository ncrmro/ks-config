# Cloudflare Workers deployment notes

Use this skill when planning, implementing, or reviewing Cloudflare Workers
hosting for Astro or custom frontend/server runtimes.

## Choose the Worker shape

### Astro Cloudflare adapter Worker

Use when Astro owns server rendering or runtime endpoints.

Typical config:

```jsonc
{
  "name": "app-name",
  "main": "@astrojs/cloudflare/entrypoints/server",
  "compatibility_date": "2026-05-13",
  "compatibility_flags": ["global_fetch_strictly_public"],
  "assets": { "directory": "./dist", "binding": "ASSETS" },
  "observability": { "enabled": true }
}
```

Add `nodejs_compat` only when dependencies require Node compatibility
(Auth.js, some DB clients, Stripe, Astro runtime edges). If enabled, test dynamic
SSR routes under workerd/Cloudflare preview; some Astro/workerd combinations can
mis-handle Node-like `process` detection.

### Astro hybrid/static build plus generated Worker

Use when current pages are static but a Worker entrypoint is desired for future
endpoints. Astro may emit `dist/_worker.js/index.js` depending on adapter
version/config. Keep Wrangler `main` aligned with the actual build output.

### Hand-written Worker in front of static assets

Use when Astro is only a static bundler and the Worker owns auth, R2, routing,
or SPA fallback.

```jsonc
{
  "main": "src/worker.ts",
  "assets": {
    "binding": "ASSETS",
    "directory": "./dist",
    "not_found_handling": "single-page-application",
    "run_worker_first": true
  }
}
```

- `run_worker_first: true` is required if auth or logging must cover every
  asset request, not just navigations.
- The Worker should call `env.ASSETS.fetch(request)` after any gates/special
  routes.
- Keep public immutable blobs on content-addressed URLs and set long cache
  headers.

### Cloudflare Pages style

Use only for projects intentionally deploying with Pages commands:

- `wrangler pages dev ./dist`
- `wrangler pages deploy ./dist`
- `pages_build_output_dir = "./dist"` in `wrangler.toml`

Do not mix Pages assumptions into Workers deployments without a deliberate
migration plan.

## Wrangler config checklist

Core fields:

- `name`: stable Worker name.
- `main`: adapter entrypoint or custom Worker source.
- `compatibility_date`: pin and update deliberately.
- `compatibility_flags`: start minimal; add `nodejs_compat` only when needed.
- `assets`: `directory`, `binding`, optional SPA fallback/run-worker-first.
- `observability.enabled`: enable unless there is a reason not to.
- `routes` / `custom_domain` / `workers_dev` / `preview_urls`: choose per
  production and preview needs.

Bindings:

- `vars`: non-secret runtime values only.
- Secrets: set with `wrangler secret put NAME` or CI secret injection; never
  commit tokens/private keys.
- `kv_namespaces`: bind `SESSION` when Astro sessions or adapter provisioning
  need a stable namespace.
- `r2_buckets`: uploads, static blobs, firmware, demo bundles.
- `send_email`: contact forms/transactional email where Cloudflare Email
  Routing send bindings are used.
- DB/API services: Turso/libSQL URLs may be non-secret, but auth tokens are
  secrets.

Build-time vs runtime env:

- Vite/Astro inlines public client vars at build time (`PUBLIC_*`, legacy
  `NEXT_PUBLIC_*`). Setting them only in Wrangler `vars` gives server runtime
  access but does not populate client bundles.
- CI/deploy systems must export public build vars before `astro build`.

## Local development and preview

- `astro dev`: fastest feedback for Astro pages; use adapter
  `platformProxy: { enabled: true }` if code accesses Cloudflare bindings.
- `astro preview`: validates Astro build output, but may not exactly reproduce
  workerd/binding behavior.
- `wrangler dev`: use for custom Workers and binding/asset routing validation.
- `wrangler dev --ip 0.0.0.0`: expose preview to LAN/tailnet devices when
  needed.
- `wrangler pages dev ./dist`: Pages-only local preview.

Always test the path that matters:

- Auth callback/session routes.
- API endpoints with bindings.
- Asset fallback/client-side routes.
- R2 blob streaming and cache headers.
- Dynamic SSR pages under Cloudflare/workerd, especially with `nodejs_compat`.

## Deployment options

### Manual/local deploy

Use for first deploys, smoke tests, or emergency pushes:

```bash
bun install
bun run build
bunx wrangler deploy
```

For monorepos, run from the app directory or pass the appropriate Wrangler
config/working directory. Generate binding types when available:

```bash
bunx wrangler types
# or project-specific env interface output
bunx wrangler types --env-interface CloudflareEnv ./cloudflare-env.d.ts
```

### Cloudflare Workers Builds

Use when Cloudflare owns branch/PR preview builds.

- Configure root directory / build command / deploy command in Cloudflare.
- In monorepos, set watch paths carefully. If only `code/web/**` is watched,
  docs/content outside that path may not trigger previews.
- Know whether previews share production bindings/databases. If they do, note
  the risk in PRs and avoid destructive preview actions.
- If a branch adds DB migrations, run compatible migrations before validating
  preview pages that select new columns.

### GitHub Actions deploy

Use when GitHub should own CI, tests, migrations, and production deploy order.

Minimum shape:

```yaml
name: deploy-web
on:
  push:
    branches: [main]
    paths:
      - code/web/**
      - .github/workflows/deploy-web.yml

jobs:
  deploy:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: code/web
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install --frozen-lockfile
      - run: bun run build
        env:
          PUBLIC_SITE_URL: https://example.com
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: code/web
          command: deploy
```

Recommended additions:

- Typecheck/test before deploy.
- Run migrations before deploy when new code expects new schema.
- Upload R2/static blobs before deploy if manifest points at them.
- Use GitHub Environments for production approval/secrets.
- Separate preview deploy workflows from production deploy workflows.

## Auth and secrets on Workers

Auth.js/Google common secrets:

- `AUTH_SECRET`
- `AUTH_GOOGLE_ID`
- `AUTH_GOOGLE_SECRET`
- optional `AUTH_REDIRECT_PROXY_URL` for stable callbacks from preview URLs
- optional `AUTH_URL` depending on routing/library assumptions

Operational rules:

- Production must fail closed if required auth secrets are missing.
- Local dev may disable auth or use a clearly marked dev-only credentials
  provider, but never let dev credentials leak into SaaS mode.
- Restrict sign-in by email/domain in callbacks for admin/private products.
- If protecting static assets, enforce it in the Worker before `ASSETS.fetch`,
  not only inside the client app.

## PR/review checklist

- Does Wrangler `main` match the chosen Worker shape and generated output?
- Are secrets absent from `wrangler.jsonc`/`wrangler.toml`?
- Are build-time public vars supplied by CI/Workers Builds?
- Are preview deployments documented, including shared DB/binding tradeoffs?
- Are local preview commands documented for `astro dev`, `wrangler dev`, or
  Pages as appropriate?
- Are R2/KV/email bindings named consistently with code and generated types?
- Is `nodejs_compat` justified and smoke-tested on dynamic routes?
