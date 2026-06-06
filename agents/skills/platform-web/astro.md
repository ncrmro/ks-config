# Astro implementation notes

Use this skill when planning, implementing, or reviewing Astro projects.
It captures local repo patterns observed across NCRMRO/partner projects and
turns them into deployment/runtime choices.

## First decision: what is Astro doing?

Pick the smallest runtime that satisfies the product surface.

### 1. Full static site / content app

Use when every route can be built ahead of time and there are no runtime API
endpoints.

- Astro default output is static; `output: "static"` may be explicit for clarity.
- No adapter is required unless the host/deploy platform needs one.
- Local scripts are usually `astro dev`, `astro build`, `astro preview`.
- Examples:
  - `ncrmro/catalyst/code/web`: plain static Astro, no adapter.
  - `scifireality/placeholder/code/web`: static Astro with React/MDX and Vite
    filesystem allowances for symlinked/generated assets.
  - `ncrmro/plouton/code/web`: explicit `output: "static"` with React islands.

Use this for marketing/content sites until server endpoints are clearly needed.

### 2. Static SPA with Astro as bundler only

Use when React/client routing owns the app and SSR would only emit an empty
island shell.

- Set `output: "static"`.
- Use `client:only` islands for the SPA shell.
- Serve `index.html` as fallback from the runtime shell.
- If hosting on Cloudflare, a hand-written Worker can add auth, R2, and SPA
  fallback without running Astro SSR.
- Example: `unsupervised/deepwork-frontend/code/web`:
  - Astro builds one static shell.
  - Local target is a Bun server with `/api/*`, `/debug/*`, `/ws`.
  - Hosted target is a thin Cloudflare Worker with `/auth/*`, `/r2/*`, and
    `env.ASSETS.fetch()`.

Prefer this for CLI/local apps and hosted demo viewers where SSR is pure cost.

### 3. Mostly static site with a few runtime endpoints

Use when pages are mostly static but forms, contact handlers, webhooks, or small
APIs need runtime execution.

Options:

- Cloudflare adapter with default/static-prerendered pages and individual
  `export const prerender = false` endpoints.
- `output: "hybrid"` when the project wants static by default but a server
  entrypoint available for dynamic routes.

Examples:

- `jtco/marketing-site/code/web`: Cloudflare adapter, contact page/API opt out
  with `prerender = false`, email binding in Wrangler.
- `ncrmro/media-production-assistant/code/web`: `output: "hybrid"`; current
  pages static, Worker entrypoint ready for future endpoints.

Prefer this over full SSR when dynamic behavior is isolated.

### 4. Full SSR on Cloudflare Workers

Use when authenticated dashboards, per-user data, server-rendered pages, or
runtime APIs are core to the product.

- Set `output: "server"`.
- Use `@astrojs/cloudflare` adapter.
- Prerender public/content pages explicitly with `export const prerender = true`.
- Keep API/auth routes dynamic with `export const prerender = false` where
  useful for clarity.
- Use `platformProxy` for local dev when code reads Cloudflare bindings.

Examples:

- `EONMUN/EONMUN/code`: `output: 'server'`; public pages opt into prerender;
  admin/API/auth routes are dynamic; Auth.js Google admin gate.
- `ncrmro/plant-caravan/code/web`: `output: 'server'`; docs/blog/team pages
  prerender; app/API/auth surfaces run on Workers; R2/Turso/Stripe/web-push
  bindings live in Wrangler.

### 5. Node/Bun SSR or middleware

Use when the app needs local system access, subprocesses, websockets, CAD/tools,
or to embed Astro inside a larger Node/Bun server.

- Set `output: "server"`.
- Use `@astrojs/node`.
- Choose `mode: "standalone"` for a self-contained Node server.
- Choose `mode: "middleware"` when another server owns routing/lifecycle.

Examples:

- `ncrmro/3dPCB-paper/code/web`: Node standalone; prerendered gallery pages,
  dynamic local endpoints for open/rebuild/printer actions.
- `ncrmro/cadeng/code/web-client`: Node middleware embedded by Cadeng's Bun
  server; stable manifest integration for compiled imports.
- `ncrmro/vega/code/web`: Node middleware for Keystone/Vega web UI.

## Auth patterns

### Auth.js on Astro/Cloudflare

- Use `@auth/core` directly in Astro API routes or a custom Worker.
- Mount a catch-all endpoint such as `/api/auth/[...auth].ts` or Worker
  `/auth/*`.
- Keep OAuth secrets in Wrangler secrets or CI secrets:
  - `AUTH_SECRET`
  - `AUTH_GOOGLE_ID`
  - `AUTH_GOOGLE_SECRET`
  - optional `AUTH_REDIRECT_PROXY_URL` for preview URLs/stable callback routing.
- Use `trustHost: true` on Workers.
- Prefer JWT sessions unless a DB/session adapter is explicitly required.
- For admin surfaces, enforce email/domain allowlists in Auth.js callbacks.

Observed repo variants:

- EONMUN: Google OAuth admin allowlist via `ADMIN_EMAILS`; JWT session;
  `/api/auth`; dynamic admin route.
- Plant Caravan: Google OAuth in SaaS; credentials provider for local/non-SaaS;
  local HTTP can use a dev secret and local DB; session callback attaches user id.
- Unsupervised: hosted Worker has optional Google OAuth, restricted to
  `@unsupervised.com`; auth is not currently an app-wide gate.

### Static assets behind auth

If the whole SPA/assets must be protected on Cloudflare, do not rely only on
client-side checks. Put a Worker in front of assets and set Wrangler assets
`run_worker_first: true`, then call `env.ASSETS.fetch()` after the gate.

## Local dev notes

- `astro dev` is enough for pure Astro and most adapter projects.
- Use `server.host: "0.0.0.0"` / `allowedHosts: true` when testing across LAN,
  tailnet, or reverse proxies.
- Use Cloudflare adapter `platformProxy: { enabled: true }` if local code needs
  Worker bindings.
- Use `wrangler dev` for custom Workers or when verifying actual Workers asset
  routing/bindings.
- Use `wrangler pages dev ./dist` only for Cloudflare Pages-style projects.

## Review checklist

- Is the selected output mode the smallest viable runtime?
- Are public pages prerendered when the app is otherwise SSR?
- Are dynamic endpoints explicitly marked `prerender = false` where ambiguity
  would hurt future maintainers?
- Are build-time public env vars supplied during the build, not only in
  Wrangler runtime `vars`?
- Does local dev have a safe auth mode, and does production require real
  secrets?
- If using `nodejs_compat` with Astro Cloudflare SSR, smoke-test dynamic pages
  under workerd/preview, not just `astro preview`.
