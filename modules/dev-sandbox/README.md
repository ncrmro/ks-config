# dev-sandbox (devbox) — spike

Per-repo dev sandbox container. Long-lived sibling of keystone's `podman-agent`
(which is `--rm`/one-shot). Reuses the same rootless-podman substrate, `/nix`
named volume, and language-cache volume strategy.

This directory is laid out to mirror keystone's destination so promotion is
`git mv`, not a rewrite:

| Spike path (here)                          | Future keystone path                            |
| ------------------------------------------ | ----------------------------------------------- |
| `modules/dev-sandbox/os.nix`               | `keystone/modules/os/dev-sandbox.nix`           |
| `modules/dev-sandbox/home.nix`             | `keystone/modules/terminal/devbox.nix`          |
| `packages/devbox/`                         | `keystone/packages/devbox/`                     |
| `hosts/common/optional/dev-sandbox.nix`    | (deleted — `keystone.devSandbox.enable = true`) |
| `home-manager/common/optional/dev-sandbox.nix` | (deleted — `keystone.terminal.devbox.enable = true`) |

See `/home/ncrmro/.claude/plans/what-libraries-exist-for-nifty-frost.md` for
the full plan, library survey, and decision log.

## What it does

- Renders a Quadlet `~/.config/containers/systemd/devbox-<owner>-<repo>.container`
  per repo
- `systemctl --user start devbox-<owner>-<repo>.service` brings up a long-lived
  container from the portable `devbox-<user>` image, seeds the shared
  `devbox-nix-shared` volume from that image on first start, then mounts it at
  `/nix` alongside language caches, the repo bind mount, and a per-owner
  GitHub PAT loaded as a podman secret
- Entrypoint starts `ttyd` (web) and `sshd` (Remote-SSH) fronting a zellij
  session named after the repo; survives reboot via the Quadlet unit + named
  volumes

## Promotion checklist (to keystone)

1. `git mv modules/dev-sandbox/os.nix ../keystone/modules/os/dev-sandbox.nix`
2. `git mv modules/dev-sandbox/home.nix ../keystone/modules/terminal/devbox.nix`
3. `git mv packages/devbox ../keystone/packages/devbox`
4. Add `./dev-sandbox.nix` to `keystone/modules/os/default.nix` imports list
5. Add `./devbox.nix` to `keystone/modules/terminal/default.nix` imports list
6. Add `devbox = callPackage ./packages/devbox { };` to `keystone/overlays/default.nix`
7. Remove this spike's `hosts/common/optional/dev-sandbox.nix`,
   `home-manager/common/optional/dev-sandbox.nix`, and entries in
   `packages/default.nix` + `flake.nix:packages.x86_64-linux`
8. In nixos-config, enable via `keystone.devSandbox.enable = true` (host) and
   `keystone.terminal.devbox.enable = true` (home-manager)

## Explicit non-goals (spike)

- CRIU checkpoint/restore (zellij sessions survive reboot; in-flight processes do not)
- Custom OCI image build in this staging area (the launcher expects the sibling
  portable `modules/keystone-spike/` image to be built and loaded locally)
- Per-repo isolated `/nix` volume (shared by default; option exists)
- Docker rootful path (option exists, implementation is a TODO stub)
- Library-based podman SDK (launcher uses `subprocess.run(["podman", ...])`)
- `ks devbox` subcommand in the Rust ks binary (separate workstream)

## Sibling staging area

`modules/keystone-spike/` (sibling) houses the **portable container
image** half of the spike — a `dockerTools.buildLayeredImage` factory
that bakes a keystone home-manager profile into an OCI image runnable
on any rootless-podman host. See `modules/keystone-spike/README.md`.
The two directories may be merged once both pieces are mature.
