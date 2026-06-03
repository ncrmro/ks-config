# keystone-spike

Staging area for modules, packages, and lib helpers that are destined to
live in [`ncrmro/keystone`](https://github.com/ncrmro/keystone) but are
iterated here in `ncrmro/ks-config` until they are stable enough to
promote.

## Why this directory exists

Promoting code into `keystone` is expensive — every change loops through:
the keystone PR, a `flake.lock` bump in this repo, a `ks build`, and a
deploy. That cadence is wrong for early/exploratory work. So this
directory holds anything that is going to *eventually* live in keystone
but isn't there yet.

The layout under `keystone-spike/` mirrors `keystone/`'s own structure so
that promotion is a `git mv` rather than a port:

| Spike path here                                          | Future keystone path                       |
| -------------------------------------------------------- | ------------------------------------------ |
| `modules/keystone-spike/lib/<helper>.nix`                | `keystone/lib/templates.nix` (merged in)   |
| `modules/keystone-spike/packages/<name>/`                | `keystone/packages/<name>/`                |
| `modules/keystone-spike/modules/os/<name>.nix`           | `keystone/modules/os/<name>.nix`           |
| `modules/keystone-spike/modules/terminal/<name>.nix`     | `keystone/modules/terminal/<name>.nix`     |

`lib/` helpers are the harder case because they end up *inside*
`templates.nix` rather than as their own file — those entries live here
as standalone files for clean isolation, and the promotion step inlines
them into `templates.nix` (the README of each helper notes where it
lands).

## What's currently inside

### `packages/devbox-image/`

`dockerTools.buildLayeredImage` factory that wraps a home-manager
`activationPackage` into a portable OCI image. Pair with the per-repo
`devbox` launcher (already shipped at `packages/devbox/` in this repo)
to run a published image instead of the host-`/nix/store` bind-mount
substrate the spike uses today.

Promotion target: `keystone/packages/devbox-image/`.

### `lib/portable-terminal.nix`

Standalone `home-manager.lib.homeManagerConfiguration` builder that
imports `inputs.keystone.homeModules.terminal` for use inside the
devbox-image. Mirrors the shape of `keystone/lib/templates.nix`'s
`mkMacosTerminal` but targets Linux + uid-0-root inside the container.

Promotion target: a `mkPortableTerminal` function in
`keystone/lib/templates.nix`, alongside `mkMacosTerminal` (~line 720
post-#548). Once keystone PR #548 lands and `terminalMinimal` becomes
threadable via specialArgs, the call here gains
`extraSpecialArgs.terminalMinimal = true;` and the image stops carrying
the heavy submodule closure (mail/calendar/deepwork/agents/etc).

## Relationship to `modules/dev-sandbox/`

`modules/dev-sandbox/` (sibling, already in PR #30) holds the
*host-side* spike: the `devbox` launcher, Quadlet-templated containers,
PAT cascade, etc. It also has its own `README.md` with a promotion
checklist pointing at `keystone/modules/{os,terminal}/devbox.nix` and
`keystone/packages/devbox/`.

`keystone-spike/` and `dev-sandbox/` are *both* staging areas for
keystone-bound code. They could be merged into one directory once both
are mature; for now they stay separate because each has its own PR
lifecycle:

- `dev-sandbox/` — open in PR #30 of this repo
- `keystone-spike/` — added in the follow-up PR that extends #30 with
  the portable image

A future cleanup may rename `dev-sandbox/` to live under
`keystone-spike/modules/{os,terminal}/` so there is one unambiguous
staging tree.

## Hard rule

**Nothing in this directory may be referenced as a stable API.**
Anything here can be renamed, moved, or rewritten without a deprecation
cycle. Once a piece graduates to keystone proper, the spike copy here is
deleted in the same PR that lands the keystone-side change + the
`flake.lock` bump in this repo.
