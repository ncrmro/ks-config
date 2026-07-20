---
name: ks-agents
description: "Agent profile/skill maintenance — quickly edit ks-config/agents and commit + push successful changes"
---

Use this skill when the user asks to create, tweak, or repair files under
`ks-config/agents/`, including Bridl profiles, shared conventions, Claude agent
assets, or skills.

## Scope

- Canonical tree: `~/repos/ncrmro/ks-config/agents/`.
- Keep changes focused on agent behavior assets. Do not mix host/module changes
  unless the user explicitly asks.
- Respect the open skill layout: every skill directory must contain `SKILL.md`,
  and the frontmatter `name:` must match the directory name exactly.

## Fast workflow

1. Inspect state first:
   ```bash
   cd ~/repos/ncrmro/ks-config
   git status --short
   git branch --show-current
   ```
2. If unrelated dirty files exist, leave them untouched and stage only the
   agent files you intentionally changed.
3. Edit the smallest useful files under `agents/`.
4. Validate cheaply:
   - Read new/edited YAML and Markdown back once.
   - If `yq` or `python` YAML tooling is available, parse changed `*.yml` files.
   - Run `git diff -- agents` and verify no unrelated prompt/skill drift.
5. Commit and push automatically when the change is coherent:
   ```bash
   git add <changed agents paths>
   git commit -m "feat(agents): <short description>"
   git push
   ```

## Commit discipline

- Successful `agents/` changes should be committed and pushed before ending the
  session so all hosts and OS-agent homes can converge through ks-config.
- Never use `git add -A` from the repo root when unrelated work is present.
- If validation fails or the user asked for a draft only, do not push; summarize
  exactly what remains.
- If push fails for auth/network reasons, leave a clean local commit and report
  the command/output needed to retry.

## Bridl profile conventions

- Keep persona profiles portable. Do not hard-code Keystone fleet paths, host
  names, or OS-environment assumptions in `drago` or `luce`.
- Put fleet facts in the single environment-parameterized `ks-fleet` profile
  and OS-environment facts in `os-ks-*` profiles.
- Put Keystone fleet/methodology knowledge in `vega` and/or `keystone-os`.
- Default model changes belong in `agents/bridl/profiles/default/profile.yml`.
