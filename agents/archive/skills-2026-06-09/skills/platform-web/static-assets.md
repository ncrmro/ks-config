# Static assets and SPA delivery

Use the simplest asset delivery model that still enforces the product's access
and cache requirements.

## Public immutable assets

Use content-addressed or build-hashed filenames for assets that can be cached
forever.

- Set long-lived immutable cache headers only when the URL changes with content.
- Keep stable-but-mutable keys on short cache windows.
- Do not put secrets in client bundles or public asset manifests.
- Generated manifests should distinguish local filesystem paths from public URLs.

## SPA fallback

For client-routed SPAs, the serving layer should return `index.html` for
non-asset application routes.

- Static hosts usually expose an SPA fallback setting.
- Custom servers should try static asset lookup first, then fall back to the
  shell for navigations.
- Cloudflare Workers static assets can use
  `not_found_handling: "single-page-application"`.

## Auth-protected assets

If static assets need auth, enforce it before the asset layer, not only inside
client code.

- Gate every request path that should be private: HTML, JS, CSS, images, blobs,
  and client routes.
- On Cloudflare Workers, `assets.run_worker_first: true` lets a Worker check
  auth before calling `env.ASSETS.fetch()`.
- Public content-addressed blobs may intentionally bypass auth; document that
  decision and validate object keys to prevent traversal or arbitrary reads.

## Build-time public env

Vite/Astro and similar bundlers inline public env at build time. Runtime vars
from a hosting platform do not automatically appear in already-built client JS.

- Export public client env during CI/build.
- Keep server-only secrets in runtime secret stores.
- Use clear naming conventions (`PUBLIC_*`, framework-specific legacy prefixes)
  and document which side consumes each variable.
