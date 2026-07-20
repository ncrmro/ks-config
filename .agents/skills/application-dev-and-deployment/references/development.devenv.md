# Local development with devenv (v2 layout)

The inner loop never touches a cluster: `devenv up` runs the app and every
supporting process locally via devenv's built-in process-compose.

## Layout

- `devenv.nix` + `devenv.yaml` + `.envrc` containing `use devenv`
  (run `direnv allow` on first use).
- Pin `inputs.nixpkgs.url` in `devenv.yaml` to a specific rev
  (e.g. `github:cachix/devenv-nixpkgs/<rev>`) — an unpinned bump forces
  from-source rebuilds of anything not in the binary cache.
- Tools go in `packages = with pkgs; [ ... ]`.

## Processes

Declare processes in `devenv.nix`; devenv generates the process-compose
config — never write a standalone `process-compose.yaml`:

```nix
processes.<app>.exec = "…";        # devenv up (foreground) / devenv up -d
# stop with: devenv processes down
```

Settings live under `process.managers.process-compose.settings`. Dynamic
ports use `env_cmds` there (e.g. `env_cmds.DB_PORT = "shuf -i 10000-60000
-n 1"`); do NOT also list the var in the process's `environment` block —
that triggers parse-time `${VAR}` substitution and yields an empty value.
Child processes inherit env_cmds vars automatically.

## Inspecting state

`process-compose` is not on the host PATH — use it inside the shell
against the generated socket:

```sh
SOCK=$(find /run/user/$UID -maxdepth 2 -name pc.sock | head -1)
devenv shell -- process-compose process list -u "$SOCK" --use-uds -o json
devenv shell -- process-compose process logs <name> -u "$SOCK" --use-uds --tail 50 --log-no-color
```

Never `-f`/follow in automation. For dynamic-port processes avoid
`readiness_probe.http_get.port` (not Go-templated — `{{.VAR}}` is taken
literally); use an `exec` probe or skip the probe.

## Boundaries

- Local dev state (DBs, uploads) lives under the project dir or
  `$DEVENV_STATE`, never in cluster volumes.
- Migrations run the same way locally and in the container entrypoint, so
  the dev loop exercises the prod startup path.
