# DeepWork jobs (ks-config-local)

User-editable DeepWork jobs that take precedence over the upstream copies
shipped with `keystone/.deepwork/jobs/`. Edit freely here without carrying
upstream merge conflicts; the `deepwork learn` workflow consumes the same
files.

## How discovery works

The DeepWork MCP server reads colon-delimited paths from the
`DEEPWORK_ADDITIONAL_JOBS_FOLDERS` env var (first match wins per job name).
ks-config's `home-manager/ncrmro/base.nix` prepends this directory to the
list set by `keystone.terminal.deepwork`, so a job defined here overrides
the upstream copy of the same slug.

Current resolution order (highest precedence first):

1. `~/repos/ncrmro/ks-config/deepwork/jobs/` (this directory)
2. Whatever `keystone.terminal.deepwork` resolves to:
   - dev mode: the local keystone checkout under `~/repos/ncrmro/keystone/.deepwork/jobs/`
     plus `.deepwork/jobs-internal/`
   - locked mode: the `keystone-deepwork-jobs` Nix store path
3. The deepwork flake's `library/jobs/` (also from `keystone.terminal.deepwork`)

## Adding or editing a job

1. Copy or create the job directory under `jobs/<slug>/` — slug is
   `lowercase_snake_case`.
2. Validate against `job.schema.json` (kept in sync with upstream).
3. Restart the DeepWork MCP server (or reopen the agent session) so the
   discovery pass re-scans. No `ks-dev` rebuild needed — the env var
   already points at this path, and the files are read at server start.

## Authoring conventions

See `keystone/CONTRIBUTOR.md` (§ "DeepWork") and the upstream spec
`keystone/specs/REQ-015-deepwork-consolidation.md` for the canonical
job layout, naming rules, and schema requirements.
