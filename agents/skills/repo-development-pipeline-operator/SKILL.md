---
name: repo-development-pipeline-operator
description: "Operate milestone, spec, spike, feature, worktree, issue, and stacked PR pipelines"
---

Use this skill when work spans milestone/spec planning, branch topology,
stacked PRs, rebases, issue linkage, or repo worktree state.

This skill sits between product management and platform engineering. It keeps
the product scope, engineering specs, git branch graph, PR targets, and local
worktrees aligned so milestone work remains reviewable and releasable.

## Operating model

Treat milestones and specs as separate peers:

- A milestone is a product deliverable with scope, demo expectations, and
  release readiness.
- A spec is an engineering artifact that can be reviewed, approved, and
  promoted independently.
- A spike is time-boxed research that produces findings and does not promote as
  a long-lived integration branch.

Use this branch shape unless the repo has a stricter local convention:

```text
main
├── milestone/<milestone-slug>
├── spec/<spec-slug>
│   ├── feat/<spec-slug>-<task-slug>
│   └── feat/<spec-slug>-<task-slug>
└── spike/<spike-slug>
```

Some repos use Spec Kit-style branches instead of explicit `spec/*` branches:

```text
NNN-<spec-slug>
copilot/<NNN>-<spec-slug>-<task-id>
```

When that convention is present, extract the active spec from the numeric
prefix and locate `specs/NNN-*/`. Do not rename the repo's branch model to the
generic one just to fit this skill.

Promotion boundaries:

- `feat/*` PRs target `spec/<spec-slug>` and squash-merge into the spec branch.
- `spec/*` PRs target `milestone/<milestone-slug>` and squash-merge as one
  spec-sized commit.
- Orphan specs may target the default branch directly when no milestone owns
  them.
- Cross-cutting feature branches that do not belong to one milestone may
  squash-merge directly into the default branch as release-shaped commits.
- `spike/*` branches do not promote by default; capture findings in spec docs or
  issues, then discard or archive the branch.

Milestones may depend on specs; specs do not point back to milestones. Compute
"used by milestones" by scanning milestone metadata, not by adding milestone
frontmatter to specs.

## Documentation layout

Use the repo-local docs layout when present. If no stronger convention exists,
use this shape:

```text
docs/
├── milestones/
│   └── M<N>-<milestone-slug>/
│       ├── press-release.md
│       ├── internal-faq.md
│       ├── designs.md
│       └── milestone.yaml
└── specs/
    └── NNN-<spec-slug>/
        ├── plan.md
        ├── spec.md
        ├── data-model.md
        ├── api-spec.json
        ├── research.md
        └── tasks.md
```

`M<N>` matches the provider milestone id when the repo uses Forgejo or GitHub
milestones. `NNN` is a repo-local, zero-padded spec number that should not be
reused.

Milestone docs carry product context:

- `press-release.md`: customer-facing value and announcement shape.
- `internal-faq.md`: stakeholder questions, scope decisions, and trade-offs.
- `designs.md`: screenshots, sketches, or an explicit stub.
- `milestone.yaml`: machine-readable milestone metadata.

Spec docs carry engineering context:

- `plan.md`: architecture and phased implementation narrative.
- `spec.md`: behavioral requirements, preferably with stable requirement IDs.
- `data-model.md`: storage/schema changes when applicable.
- `api-spec.json`: request/response contracts when applicable.
- `research.md`: findings from spikes, libraries, and discarded approaches.
- `tasks.md`: sequenced PR plan.
- `contracts/`: API or CLI contracts when the repo uses directory-based
  contracts.
- `checklists/`: quality gates, requirement checks, and manual verification
  steps.
- `quickstart.md`: demo or local validation path when the repo uses Spec Kit.

When working inside a spec directory, read in this order unless the repo says
otherwise:

1. `tasks.md`
2. `spec.md`
3. `plan.md`
4. `data-model.md`, if present
5. `contracts/`, if present
6. `research.md`, if present
7. `checklists/`, if present

## Metadata schema

When a milestone has `milestone.yaml`, keep this schema:

```yaml
slug: hardware-enrollment
forgejoMilestone: 5
forgejoIssue: 10
flag: KEYSTONE_FLAG_MILESTONE_HARDWARE_ENROLLMENT
dependsOnSpecs:
  - full-disk-encryption-unlock-methods
status: in_progress
```

Required fields:

- `slug`: kebab-case; matches the milestone directory suffix and branch slug.
- `forgejoMilestone`: provider milestone id when available.
- `forgejoIssue`: tracking issue id for `Milestone: <slug>`.
- `flag`: per-milestone feature flag when the repo uses flags.
- `dependsOnSpecs`: kebab-case spec slugs; zero or more.
- `status`: `planned`, `in_progress`, `shipped`, or `cancelled`.

Do not add milestone backrefs to spec files. A spec can serve multiple
milestones, and milestone consumers should be discovered from
`dependsOnSpecs`.

## Issue convention

Use repo-local issue labels when present. If no stronger convention exists, use:

```text
Milestone: <slug>  label: kind:milestone
Spec: <slug>       label: kind:spec
Spike: <slug>      label: kind:spike
```

Milestone issues should link:

- The milestone docs directory.
- Press release excerpt.
- Designs or demo screenshots when available.
- Feature flag name when applicable.
- Every spec named in `dependsOnSpecs`.

Spec issues should link:

- The spec docs directory.
- Phased task checklist.
- Current "used by milestones" reverse lookup.

Spike issues should record:

- The open question.
- The time box.
- The finding destination, usually spec `research.md` or a parent issue.

Do not add redundant suffixes like `(M#)` or explanatory title tails when the
label and slug already identify the issue.

## Feature flags

If the repo gates milestone work with flags, use:

```text
<PROJECT>_FLAG_MILESTONE_<SLUG_UPPER>
```

Hyphens become underscores. For example, `hardware-enrollment` becomes
`KEYSTONE_FLAG_MILESTONE_HARDWARE_ENROLLMENT`.

Default to disabled in production. Enable locally or on milestone branches only
when the preview path needs the code live. The production flip belongs to the
release event or a follow-up release-safe commit.

## Worktree requirements

Before making decisions, inspect local and remote state. Prefer local
worktrees so agents can compare branches without repeatedly switching the main
checkout.

Use this layout:

```text
~/repos/OWNER/REPO_NAME/                  default branch checkout
~/repos/OWNER/REPO_NAME/worktrees/BRANCH_NAME/
```

If the repo defines its own worktree tool, use that instead. Common repo-local
commands:

```text
bin/worktree add <branch-name> [base-ref]
bin/worktree list
bin/worktree remove <branch-name>
```

`BRANCH_NAME` preserves branch slashes as subdirectories. Do not flatten branch
names into hyphenated slugs unless the repo-local worktree tool explicitly does
that. For example:

```text
~/repos/ncrmro/keystone/worktrees/spec/REQ-032-full-disk-encryption-unlock-methods/
~/repos/ncrmro/keystone/worktrees/milestone/M1-V1-KS-OS-FDE-deployment/
~/repos/ncrmro/keystone/worktrees/feat/hardware-fde-namespace/
```

At skill start:

1. Find the repo root and default branch.
2. Fetch remotes.
3. List local branches, remote branches, open PRs, and existing worktrees.
4. Detect repo-local worktree policy from docs, scripts, `.gitignore`, and
   existing worktree paths.
5. Create missing worktrees for relevant `milestone/*`, `spec/*`, `feat/*`,
   `copilot/*`, and `spike/*` branches when safe.
6. Update clean worktrees to their remote tracking branch.
7. Do not overwrite dirty worktrees; report them as blockers or coordination
   points.

## Rebase and update order

Update from the trunk outward:

1. Update the default branch checkout.
2. Rebase `milestone/*` branches on the default branch when the milestone is
   intended to preview current trunk.
3. Rebase `spec/*` branches on the default branch, unless the repo convention
   explicitly bases specs on milestone branches.
4. Rebase `feat/*` branches on their target `spec/*` branch.
5. Re-run tests or validation after conflict resolution at the smallest useful
   scope.

Do not rebase or force-push a shared branch unless the repo convention permits
it and the branch owner is known.

## Issue and PR alignment

Keep the public record aligned:

- Milestone issues track product scope, demo requirements, included specs, and
  release readiness.
- Spec issues track engineering acceptance criteria, phased tasks, and
  promotion status.
- Feature PRs target spec branches.
- Spec PRs target milestone branches.
- Spike issues record open questions, time boxes, and findings.
- Spike findings must be copied into spec `research.md` or the relevant issue
  before the spike branch is deleted.

When a repo uses numbered spec/task conventions:

- Branch names should include the active spec prefix, for example
  `copilot/001-smart-doc-upload-T012`.
- PR titles should include the spec scope, for example
  `feat(001-smart-doc-upload): implement drag-and-drop UI`.
- Commit messages should include task IDs when the repo requires them, for
  example `[T001] implement drag-and-drop UI`.
- Mark tasks complete in `tasks.md` immediately after finishing and validating
  them.

When issue-backed work starts or materially changes, post the repo-required
`Work Started` or `Work Update` comment.

## Task execution

For spec-driven task work:

- Check `checklists/` first; warn if quality gates are incomplete.
- Complete all tasks in phase N before starting phase N+1.
- Only parallelize tasks marked as parallel by the spec, such as `[P]`.
- Check user-story or task dependencies before starting implementation.
- Prefer test-first execution when tests are requested.
- Before marking a task complete, verify implementation, run the relevant tests,
  confirm repo patterns from `plan.md`, and commit or record the completed
  state according to the repo convention.
- If blocked, document the blocker in the issue, PR, task file, or work report
  and identify the missing dependency.

## Scope control

For new work, classify it before implementation:

- `milestone`: changes product scope, demo promise, or release readiness.
- `spec`: needed to make an engineering behavior coherent and reviewable.
- `feat`: an implementation slice under an existing spec.
- `spike`: resolves uncertainty before committing to a spec.
- `follow-up`: valuable but not required for the current milestone.

If the work threatens milestone scope, say so directly and propose the smallest
branch or issue shape that preserves the release path.

## Output

When reporting status, include:

- Current default branch and relevant branch graph.
- Worktrees present, missing, clean, dirty, or stale.
- PR target mismatches.
- Active spec inferred from branch or working directory.
- Task IDs, incomplete checklist gates, and phase/dependency blockers.
- Required rebases in execution order.
- Scope risks and which milestone/spec/feature/spike bucket each belongs to.
- Next command-level actions.
