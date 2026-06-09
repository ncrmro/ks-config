---
name: repo-release-operator
description: "Promote milestone branches through demo readiness, release squash, and post-release cleanup"
---

Use this skill when a milestone or release candidate needs final validation,
demo gating, promotion to the default branch, release notes, or cleanup.

This skill owns the release event. It does not manage day-to-day feature or spec
branching unless needed to unblock the release; use
`repo-development-pipeline-operator` for ongoing milestone/spec pipeline work.

## Release model

Treat release as a distinct promotion step:

- Milestone branches are integration and preview surfaces.
- The default branch should receive one release-shaped commit unless the repo
  has a stricter release convention.
- The milestone branch should retain spec-sized history for archaeology.
- The default branch should stay easy to audit, revert, and operate.
- The release commit should be one reverter and one blame target for the shipped
  milestone.

Default promotion shape:

```text
feat/*  --squash--> spec/*
spec/*  --squash--> milestone/*
milestone/* --squash/cherry-pick release event--> main
```

The milestone branch preserves the internal authoring trail. The default branch
preserves the ship log.

## Preconditions

Before release promotion:

1. Fetch remotes and inspect the default branch, milestone branch, open PRs, and
   worktrees.
2. Confirm the milestone branch is up to date with the default branch or record
   why it intentionally is not.
3. Confirm every included spec has an approved promotion decision.
4. Confirm release-blocking CI is green or explicitly waived.
5. Confirm the demo has been run or schedule the exact demo command/path.
6. Confirm release notes or commit-message bullets summarize each included spec.
7. Confirm no dirty worktree state will be accidentally included.
8. Confirm milestone docs are included unless the release is intentionally
   silent.
9. Confirm feature flag flips are included or explicitly deferred.
10. Confirm included spec `tasks.md` files have no unfinished release-blocking
    tasks.
11. Confirm included spec `checklists/` have no unfinished release-blocking
    gates.
12. Confirm each included spec's `quickstart.md` or equivalent validation path
    has been run, waived, or declared not applicable.

## Demo gate

A milestone should not release without a demo decision.

Classify demo state as:

- `required-pass`: demo must pass before release.
- `required-waived`: demo was intentionally waived with reason and owner.
- `not-required`: release is infrastructure-only or explicitly silent.

For demo-required releases, capture:

- What was demonstrated.
- Exact command or environment used.
- Screenshots, logs, or recordings when useful.
- Known gaps that remain after release.
- Spec quickstart or manual-verification path used, when the repo provides one.

## Spec readiness

Before promoting a spec into a release:

- Infer active specs from milestone metadata, PR targets, branch names, and
  `specs/NNN-*` directories.
- Read each included spec's `tasks.md`, `spec.md`, `plan.md`, `checklists/`,
  and `quickstart.md` when present.
- Treat unchecked task items as blockers unless explicitly marked follow-up or
  waived by the release owner.
- Treat unchecked checklist items as blockers when they describe requirement,
  safety, migration, manual-verification, or demo gates.
- Verify PR titles and commit messages carry spec or task identifiers when the
  repo requires numbered spec/task traceability.
- Do not promote a spike branch. Promote only its captured findings or the
  later spec work that absorbed those findings.

## Promotion mechanics

Use repo-local conventions when present. Otherwise prefer:

1. Start from a clean default branch worktree.
2. Bring the default branch up to date.
3. Create a release branch if the repo requires PR review before default-branch
   landing.
4. Squash-merge or cherry-pick-squash the milestone range.
5. Write a release commit message that names the milestone and lists included
   specs.
6. Run release validation.
7. Open or update the release PR, or merge when the user explicitly asks and the
   repo policy allows it.

Do not destructively reset shared branches. Do not force-push release branches
without explicit approval.

## Release commit contract

When no repo-specific contract overrides this, the release commit should:

- Be produced with `git merge --squash milestone/<slug>` or an equivalent
  cherry-pick-and-squash flow.
- Name the milestone in the subject.
- List included specs in the body.
- Include milestone docs by default.
- Include the production feature flag flip in the same commit or an explicit
  follow-up commit, whichever keeps the default branch green.
- Avoid carrying the feature/spec branch authoring graph onto the default
  branch.

The milestone docs land on the default branch once the product is real. Skip
them only for intentionally silent releases, and say that explicitly in the
release notes.

Example body shape:

```text
Release milestone: hardware enrollment

Included specs:
- full-disk-encryption-unlock-methods
- hardware-keys

Demo:
- sudo ks hardware setup on fresh hardware
- reboot validation for hardware key, recovery key, and TPM unlock
```

## Post-release cleanup

After release:

- Mark milestone and spec issues with final status.
- Link the release commit or PR.
- Close or archive merged PRs.
- Identify stale `feat/*`, `spec/*`, `spike/*`, and `milestone/*` branches.
- Recommend branch deletion only when merged state is verified.
- Record follow-up work separately from release-complete work.

## Output

When reporting release status, include:

- Release candidate branch and target branch.
- Included milestones/specs.
- Demo status.
- CI status.
- Task and checklist readiness.
- Promotion method.
- Exact release commands or PR actions.
- Cleanup actions taken or recommended.
