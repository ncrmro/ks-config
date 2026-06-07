# devenv (2.x)

Some repos use [devenv](https://devenv.sh/) for the dev shell instead of a flake `devShells.default`. Layout:

- `devenv.yaml` — inputs (`nixpkgs.url`, follows). Set `allowUnfree: true` if any package needs it.
- `devenv.nix` — packages, `languages.*`, `env`, `enterShell`, `processes.*`, `tasks.*`.
- `devenv.lock` — committed alongside `devenv.yaml`.
- `.envrc` — `use devenv` (replaces `use flake`); run `direnv allow` once.
- `.gitignore` — must include `.devenv/` and `.devenv.flake.nix`.

External consumers (e.g. ks-config's `inputs.vega.nixosModules`) keep working only because `flake.nix` is preserved with its `nixosModules`/`packages` outputs — devenv replaces only the dev shell, not the production build flake.

## Process model gotchas (2.0.3)

The defaults in devenv 2 are different from the 1.x docs you'll find first on Google. Verified against `cachix/devenv` source at tag `v2.0.3`:

- **Default `process.manager.implementation` is `native`**, not `process-compose` (`src/modules/processes.nix:346`). The native runtime uses its own socket (`native.sock`), not process-compose's `pc.sock`.
- **`devenv up --detach` is unimplemented on the native manager** in 2.0.3 (`devenv/src/devenv.rs:140-146`, comment: "This should be changed closer to 2.0 release"). The CLI returns success but the processes die with it — no listener, no pid file. To get a real background stack, opt in:
  ```nix
  process.manager.implementation = "process-compose";
  ```
- **Long-running processes**: `processes.<name>.exec`. Use `processes.<name>.cwd = "subdir"` instead of `cd subdir` in `exec`.
- **One-shot commands** (migrations, seeds, build steps): use `tasks.<name>` with `type = "oneshot"`, NOT `processes.<name>`. The devenv-tasks wrapper for `type = "process"` stays alive until the underlying process exits — so a one-shot declared as a process shows `Running` forever in `process-compose process list` even after its inner command exits 0.
- **`process.managers.process-compose.settings.processes.<name>`** is *YAML overrides* on the per-process entries devenv generates from `processes.<name>` (e.g. `availability`, `depends_on`, `readiness_probe`). It is NOT a parallel declaration channel — declaring there alone raises `× No processes defined`.
- **Browsers / Playwright**: same as flake — `pkgs.playwright-driver.browsers` in `packages`, then `env.PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}"`. Never run `playwright install`.

## Minimal correct shape for a single long-running web process

```nix
{ pkgs, config, ... }: {
  packages = [ pkgs.sqlite pkgs.jq ];
  languages.javascript = { enable = true; package = pkgs.nodejs_22; bun.enable = true; };
  env.KS_VEGA_ROOT = config.devenv.root;

  process.manager.implementation = "process-compose";
  processes.web = {
    cwd = "code";
    exec = ''exec bun run --filter @ks-vega/web dev -- --port "''${WEB_PORT:-4321}" --host 0.0.0.0'';
  };
}
```

Lifecycle: `devenv up --detach`, `tail -f .devenv/processes.log`, `devenv processes stop`. Override env from the parent shell: `WEB_PORT=5000 devenv up --detach`.

## When to reach for which

- Project uses `flake.nix` with `devShells.default` — see [tool.nix-devshell.md](tool.nix-devshell.md).
- Project uses `devenv.nix` + `devenv.yaml` — this doc.
- Mixed repo (production package via flake, dev shell via devenv) — both apply; keep `nixosModules`/`packages` flake outputs intact for downstream consumers.
