## Experimental keystone directories

This directory has two roles:
- The top-level `*.nix` files are stable consumer-side adapters for this repo.
- The mirrored `os/`, `server/`, `desktop/`, and `terminal/` directories are import shims whose `default.nix` files point at those stable adapters.
- Nested directories under `modules/keystone/` are reserved for experimental keystone copies, forks, and scratch variants.

Use experimental directories here when you need fast, unstable iteration that should not churn the canonical `../keystone` checkout. Keep `../keystone` as the primary stable checkout and as the source of the GitHub `keystone` flake input.

Rules:
- Do not retarget the root `keystone` flake input to an experimental directory here.
- Do not treat code in an experimental directory as promoted upstream code by default.
- When an experiment proves out, move the reusable result into `../keystone`, push it there, and update `flake.lock` in this repo with the normal targeted workflow.
