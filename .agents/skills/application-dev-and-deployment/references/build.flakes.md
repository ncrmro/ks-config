# Building with flakes: binaries and OCI images

The flake is the only build entry point. Two outputs per app:

- `packages.<app>` — the server binary/closure (also consumable by a
  NixOS module for host-native deployment).
- `packages.<app>-container` — the OCI image.

## Image conventions (dockerTools)

```nix
packages.<app>-container = pkgs.dockerTools.buildLayeredImage {
  name = "<registry>/<owner>/<app>";
  # NO fixed tag: the tag defaults to the nix output hash, so every
  # content change produces a new tag and `kubectl set image` is a
  # guaranteed rollout trigger; unchanged content produces the same tag
  # and a no-op.
  config = {
    Entrypoint = [ "${startScript}" ];   # run migrations, then exec server
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
  };
  contents = [ pkgs.cacert pkgs.tzdata pkgs.iana-etc ];
};
```

Read the tag with `nix eval --raw .#<app>-container.imageTag`.

## Rules

- Entrypoint = migrate then `exec` the server — one startup path for dev,
  container, and any future host-native module.
- `buildLayeredImage` over `buildImage`: layer reuse keeps repeated
  imports/pushes cheap.
- Refuse to build from a dirty worktree in deploy scripts unless
  `--allow-dirty` — the image tag must correspond to a commit.
- Cross-check what a rollout will run: compare `imageTag` against the
  image on the running pod before assuming "deploy didn't work".

## Nix-native alternative

Apps that belong on a host rather than in the cluster reuse
`packages.<app>` from a NixOS module (`services.<app>`) — same flake, no
image. Choose per app; the build interface doesn't change.
