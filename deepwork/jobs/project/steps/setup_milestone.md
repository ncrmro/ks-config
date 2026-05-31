# Set Up Milestone and Link Issue

## Objective

Check if a milestone already exists for this scope, create one if needed, scaffold the in-repo milestone directory (`docs/milestones/M<N>-<ms-slug>/`) and long-lived `milestone/<ms-slug>` branch, update the issue body with refined user stories, and link the issue to the milestone.

## Task

Using the refined stories and milestone title from the previous step, set up the milestone and issue on the project's platform (GitHub or Forgejo) and scaffold the per-milestone docs/branch artifacts per the milestone/spec convention (see `docs/conventions/milestones-and-specs.md` in the project repo when present).

### Branch types — convention reference

Per the milestone/spec convention, the repo has three long-lived branch types, all peers off `main`:

- `milestone/<ms-slug>` — product integration branch carrying `docs/milestones/M<N>-<ms-slug>/`
- `spec/<spec-slug>` — engineering integration branch carrying `docs/specs/NNN-<spec-slug>/`
- `spike/<spike-slug>` — short-lived investigation branch whose findings flow into a spec's `research.md` (or as a note on a parent `Spec:` issue) and is then typically discarded

This step creates the milestone branch. Spec branches are created in `create_specs`. Spikes are created ad hoc by the engineer (e.g., via `engineer/implement` or manually) when an investigation is needed; this workflow does not create them automatically.

### Process

1. **Determine the platform and repo**
   - Use the `project_repo` input to identify the platform and repo slug
   - Read `.agents/TEAM.md` to get the correct agent username for the platform

2. **Check for existing milestone**
   - GitHub: `gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title == "TITLE") | .number'`
   - Forgejo: `tea api /repos/{owner}/{repo}/milestones` or equivalent curl
   - The milestone title MUST be `Milestone: <ms-slug>` (e.g., `Milestone: eval-harness`). Do NOT use the `(M#) — consolidated user stories` suffix — the `kind:milestone` label and unique slug carry kind and identity.
   - If a matching milestone exists, use it (record its number and URL)
   - If no match, create a new milestone

3. **Create milestone (if needed)**
   - GitHub: `gh api repos/{owner}/{repo}/milestones -f title="Milestone: <ms-slug>" -f description="DESCRIPTION"`
   - Forgejo: `tea api -X POST /repos/{owner}/{repo}/milestones` with title and description
   - The milestone description MUST be a short summary (2-3 sentences max). GitHub/Forgejo milestone descriptions are collapsed by default — long content is hidden behind a click.
   - The description MUST include both **why** (the problem or motivation) and **what** (the deliverable). Lead with the why — it gives reviewers instant context on the business reason for the milestone.
   - Example: "Developers lose minutes every day switching between projects across scattered terminals and workspaces. This milestone delivers a unified context system for launching, naming, and switching between scoped work environments. User stories: #174"
   - Record the Forgejo/GitHub milestone id `<N>` — it becomes the `M<N>` prefix in `docs/milestones/M<N>-<ms-slug>/`.

4. **Ensure required labels exist**
   - Check that `kind:milestone`, `kind:spec`, `kind:spike`, `product`, and `engineering` labels exist on the repo
   - Create any missing labels:
     - GitHub: `gh label create "kind:milestone" --repo owner/repo --description "Milestone tracking issue" --color "5319E7"`
     - Forgejo: equivalent API call
   - Use sensible default colors if creating

5. **Create the long-lived milestone branch**
   - Derive `<ms-slug>` (kebab-case) from the milestone title (e.g., "Eval Harness" -> `eval-harness`)
   - Ensure local main is current: `git fetch origin && git checkout main && git pull --ff-only`
   - Create branch `milestone/<ms-slug>` off `origin/main` if it does not already exist:
     - `git rev-parse --verify --quiet "refs/heads/milestone/<ms-slug>" || git branch "milestone/<ms-slug>" origin/main`
   - Optionally create a worktree at `$HOME/.worktrees/{owner}/{repo}/milestone/<ms-slug>` and work there for the scaffold step
   - Skip silently if the branch already exists

6. **Scaffold `docs/milestones/M<N>-<ms-slug>/`**
   - On the `milestone/<ms-slug>` branch, create the directory if missing and add four files (stubs are fine):
     - `press-release.md` — stub (will be filled in by `write_press_release`)
     - `internal-faq.md` — stub (will be filled in by `write_internal_faq`)
     - `designs.md` — stub
     - `milestone.yaml` — written now with this schema:
       ```yaml
       slug: <ms-slug>
       forgejoMilestone: <N>
       forgejoIssue: <issue-#>
       flag: VEGA_FLAG_MILESTONE_<SLUG_UPPER>
       dependsOnSpecs: []
       status: planned
       ```
   - `<SLUG_UPPER>` converts hyphens in `<ms-slug>` to underscores and uppercases (e.g., `eval-harness` -> `EVAL_HARNESS`)
   - Commit: `git add docs/milestones/M<N>-<ms-slug>/ && git commit -m "docs(milestone): scaffold M<N>-<ms-slug> directory"`
   - Push: `git push -u origin milestone/<ms-slug>`

7. **Update or create the stories issue**
   - The issue title MUST be `Milestone: <ms-slug>` (drop any `(M#)` or `— consolidated user stories` suffix)
   - Build the issue body with two sections:
     1. If a press release preceded this milestone, embed its full text under a `## Press Release` heading at the top of the issue body. This is the working-backwards doc that scoped the milestone — reviewers must be able to read it directly on the issue. Do NOT link to vault file paths (private, invisible to reviewers).
     2. Below the press release (or at the top if no press release), include all refined stories from `refined_stories.md` under a `## User Stories` heading.
   - If `issue_number` is provided:
     - GitHub: `gh issue edit <number> --repo owner/repo --title "Milestone: <ms-slug>" --body "BODY"`
     - Add the `kind:milestone` and `product` labels to the issue
     - Set the milestone on the issue
     - Assign to the business agent's account
   - If `issue_number` is blank:
     - GitHub: `gh issue create --repo owner/repo --title "Milestone: <ms-slug>" --body "BODY" --label "kind:milestone" --label "product" --milestone "Milestone: <ms-slug>"`
     - Assign to the business agent's account
   - Record the resulting issue number — it goes into `forgejoIssue` in `milestone.yaml` (re-edit and commit the yaml if the issue was newly created in this step)

8. **Verify the setup**
   - Confirm the milestone exists and the issue is linked to it
   - Confirm `kind:milestone` and `product` labels are applied
   - Confirm the `milestone/<ms-slug>` branch exists on origin and `docs/milestones/M<N>-<ms-slug>/milestone.yaml` is committed
   - Record all URLs and numbers

## Output Format

### setup_report.md

A summary of everything that was created or updated.

**Structure**:

```markdown
# Milestone Setup Report

## Milestone

- **Slug**: [ms-slug]
- **Title**: Milestone: [ms-slug]
- **Number**: [milestone number — this is the M<N> in the docs dir]
- **URL**: [milestone URL]
- **Status**: [created | already existed]

## Repo Scaffold

- **Branch**: milestone/[ms-slug] — [created | already existed]
- **Docs directory**: docs/milestones/M[N]-[ms-slug]/
- **Files**: press-release.md (stub), internal-faq.md (stub), designs.md (stub), milestone.yaml
- **Feature flag**: VEGA_FLAG_MILESTONE_[SLUG_UPPER]

## Issue

- **Number**: [issue number]
- **Title**: Milestone: [ms-slug]
- **URL**: [issue URL]
- **Status**: [updated | created]
- **Labels**: kind:milestone, product, [others]
- **Assigned To**: [agent username]

## Actions Taken

1. [Description of each action, e.g., "Created milestone 'Milestone: eval-harness'"]
2. [e.g., "Created branch milestone/eval-harness off origin/main"]
3. [e.g., "Scaffolded docs/milestones/M5-eval-harness/ with milestone.yaml"]
4. [e.g., "Retitled issue #42 to 'Milestone: eval-harness'"]
5. [e.g., "Added kind:milestone label to issue #42"]
6. [e.g., "Linked issue #42 to milestone"]

## Platform

- **Platform**: [github | forgejo]
- **Repository**: [owner/repo]
```

**Concrete example**:

```markdown
# Milestone Setup Report

## Milestone

- **Slug**: homelab-monitoring-stack
- **Title**: Milestone: homelab-monitoring-stack
- **Number**: 3
- **URL**: https://github.com/ncrmro/homelab/milestone/3
- **Status**: created

## Repo Scaffold

- **Branch**: milestone/homelab-monitoring-stack — created
- **Docs directory**: docs/milestones/M3-homelab-monitoring-stack/
- **Files**: press-release.md (stub), internal-faq.md (stub), designs.md (stub), milestone.yaml
- **Feature flag**: VEGA_FLAG_MILESTONE_HOMELAB_MONITORING_STACK

## Issue

- **Number**: 42
- **Title**: Milestone: homelab-monitoring-stack
- **URL**: https://github.com/ncrmro/homelab/issues/42
- **Status**: updated
- **Labels**: kind:milestone, product
- **Assigned To**: luce-ncrmro

## Actions Taken

1. Created milestone "Milestone: homelab-monitoring-stack" (#3)
2. Created labels: kind:milestone, kind:spec, kind:spike, product, engineering
3. Created branch milestone/homelab-monitoring-stack off origin/main
4. Scaffolded docs/milestones/M3-homelab-monitoring-stack/ with milestone.yaml (deps: [])
5. Updated issue #42 body with 4 refined user stories
6. Retitled issue #42 to "Milestone: homelab-monitoring-stack"
7. Added kind:milestone and product labels to issue #42
8. Set milestone on issue #42 to "Milestone: homelab-monitoring-stack"
9. Assigned issue #42 to luce-ncrmro

## Platform

- **Platform**: github
- **Repository**: ncrmro/homelab
```

## Quality Criteria

- A milestone was found or created with title `Milestone: <ms-slug>` and its URL is recorded
- The `milestone/<ms-slug>` branch exists on origin (created off main, or skipped because it already existed)
- `docs/milestones/M<N>-<ms-slug>/` exists with `press-release.md`, `internal-faq.md`, `designs.md`, and a populated `milestone.yaml` (schema fields: slug, forgejoMilestone, forgejoIssue, flag, dependsOnSpecs, status)
- The stories issue is titled `Milestone: <ms-slug>` (no `(M#) — consolidated user stories` suffix)
- The issue body contains the refined user stories
- The `kind:milestone` and `product` labels are on the issue
- The report includes milestone title, issue number, branch name, docs directory, and URLs
- The `kind:milestone`, `kind:spec`, `kind:spike`, `product`, and `engineering` labels exist on the repo for future use

## Next Steps

After this workflow completes, suggest the following to the user:

> The milestone, branch, and docs scaffold are ready. The natural next step is to run **`project/milestone_engineering_handoff`** to produce an internal FAQ, conduct the document review, create one or more `spec/<spec-slug>` branches with functional requirement specs, and create a single plan issue tracking all implementation work.

## Context

This is the step that makes the milestone concrete on the platform AND in the repo. After this step, a human can review the consolidated `Milestone:` issue, comment on individual stories, and approve them before agents begin spec work. The milestone provides the tracking container; the issue is the parent scope document; the `milestone/<ms-slug>` branch and `docs/milestones/M<N>-<ms-slug>/` directory are where the long-lived product docs (press release, internal FAQ, designs) and the `milestone.yaml` dependency declaration live. Specs are peer artifacts created downstream in `create_specs`.
