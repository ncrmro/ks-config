# Create Spec Tracking Issue

## Objective

Create a **single** `Spec: <spec-slug>` tracking issue that serves as the sole tracking issue for all implementation work on this spec. This issue includes happy paths, test expectations, design mockups, demo artifacts, a "Used by milestones" reverse-lookup section, **and a phased task checklist documenting parallelism and blocking dependencies**. PRs are opened directly against this issue — no child issues are created. After the issue succeeds, append `<spec-slug>` to the parent milestone's `milestone.yaml` `dependsOnSpecs` (if a parent milestone was identified).

## Task

Read the scope analysis, review decision, and specs PR report from prior steps, then compose and create one comprehensive `Spec:` issue on the project's platform. This issue becomes the single reference point for all implementation work tied to the spec. Multiple PRs will reference this issue via `Part of #N` or `Closes #N`.

**IMPORTANT: Do NOT create child issues.** All work is tracked in this issue's task checklist.

**ISSUE COUNT CAP**: Create exactly ONE `Spec:` issue per spec. If you identify a genuinely distinct feature that warrants its own issue (large delineating feature, not just a subtask), you MUST stop and ask the human for approval before creating it. The absolute maximum is 1-3 additional issues, and each requires explicit human sign-off. Issue bloat (10+ issues per milestone) has been a recurring problem — err on fewer issues.

### Convention reference — Spec issue title and labels

Per the milestone/spec convention (see `docs/conventions/milestones-and-specs.md` in the project repo when present):

- Title: `Spec: <spec-slug>` (e.g., `Spec: eval-cli-runner`). Do NOT use `Plan: <milestone title>` or `(M#)` suffixes.
- Label: `kind:spec`
- Body must include a **"Used by milestones"** section listing every milestone whose `milestone.yaml` `dependsOnSpecs` includes this spec, or `(none yet)` if no parent. Reviewers can derive the reverse-lookup at read time, but seeding it here gives the human-readable view on the issue itself.

### Process

1. **Read prior step outputs**
   - Load `scope_analysis.md` — for the story-to-system map and prerequisites
   - Load `review_decision.md` — for the approved MVP scope (in scope + renegotiated stories only)
   - Load `specs_pr_report.md` — for the spec slug, spec directory path, specs PR number/URL, parent milestone slug (if any), and spec file details
   - Extract the platform and repo

2. **Compose the spec issue body**
   For each **approved** user story from the review decision, include:
   - **Happy path requirements** — the expected user flow when everything works correctly
   - **Red/green test expectations** — what test should fail before implementation (red) and pass after (green). Be specific about the assertion, not just "it should work."
   - **ASCII art design mockups** — for any new UI components, page layouts, or visual elements. Show the layout, key elements, and user interaction points.
   - **Expected demo artifacts** — describe what screenshots, videos, or preview URLs should be produced when this story is complete. These are used for the press release and human review.

   Also include:
   - **Implementation order** — which stories can be parallelized and which have dependencies
   - **Feature flag requirements** — which stories need feature flags for safe deployment
   - References to the specs PR, the review decision, and the parent milestone issue (if any)
   - A **"Used by milestones"** section (see step 3)

3. **Compose the "Used by milestones" section**

   Scan every `docs/milestones/*/milestone.yaml` in the repo for entries whose `dependsOnSpecs` already contains `<spec-slug>`:

   ```bash
   # In the project repo, on main:
   for f in docs/milestones/*/milestone.yaml; do
     yq -r 'select(.dependsOnSpecs[]? == "<spec-slug>") | .slug + " (" + .forgejoIssue + ")"' "$f"
   done
   ```

   Render the result inside the issue body:

   ```markdown
   ## Used by milestones

   - eval-harness (#10)
   - cli-onboarding (#23)
   ```

   If no milestones currently depend on this spec, render `(none yet)`. Note that this step's later sub-step (step 6) will add the parent milestone declared at workflow start, so the reverse-lookup will be live as soon as that yaml is committed.

4. **Compose the phased task checklist**

   Break the work into tasks grouped by phase. Each task should map to a single small PR (2-3 files max). Use conventional commit prefixes for task names. Document parallelism and blocking:

   ```markdown
   ## Tasks

   ### Phase 1: Infrastructure (parallel — no dependencies)

   - [ ] chore: add recipes database migration
   - [ ] chore: set up image upload infrastructure

   ### Phase 2: Features (parallel — depends on Phase 1)

   - [ ] feat: add recipe creation form
   - [ ] feat: add recipe search

   ### Phase 3: Integration Tests (depends on Phase 2)

   - [ ] test: add recipe API integration tests

   ### Future Work (out of spec scope)

   - Recipe ratings and reviews
   - Recipe import from external sites
   ```

   Design for non-blocking PRs:
   - Tasks within the same phase should be independently implementable
   - Infrastructure tasks (`chore:`) come first and unblock feature work
   - Feature tasks should depend on infrastructure, not on each other
   - Use feature flags to avoid blocking on deployment order

5. **Create the spec issue**

   **GitHub**:

   ```bash
   gh issue create --repo {owner}/{repo} \
     --title "Spec: <spec-slug>" \
     --body "$BODY" \
     --label "kind:spec" --label "engineering" \
     --assignee {drago_username}
   ```

   **Forgejo**:

   ```bash
   fj issue create "Spec: <spec-slug>" \
     --body "$BODY" \
     --label "kind:spec" --label "engineering" \
     -r {owner}/{repo}
   ```

   Then assign via API.
   - Ensure `kind:spec` and `engineering` labels exist (create if missing)
   - Assign to Drago (CTO) — read username from `.agents/TEAM.md`
   - The `Spec:` issue is NOT linked to a Forgejo milestone — the milestone-spec relationship lives in `milestone.yaml.dependsOnSpecs` (the next step), and the parent milestone issue cross-references the spec issue in its own body.

6. **Update the parent milestone's `milestone.yaml`** (if a parent milestone was named at workflow start)

   On the `milestone/<ms-slug>` branch (or in its worktree), append `<spec-slug>` to `dependsOnSpecs` in `docs/milestones/M<N>-<ms-slug>/milestone.yaml`. Skip this step entirely if the spec is orphan (no parent milestone).

   ```bash
   # In the milestone worktree:
   yq -i ".dependsOnSpecs += [\"<spec-slug>\"] | .dependsOnSpecs |= unique" \
     docs/milestones/M<N>-<ms-slug>/milestone.yaml
   git add docs/milestones/M<N>-<ms-slug>/milestone.yaml
   git commit -m "docs(milestone): depend on spec <spec-slug>"
   git push origin milestone/<ms-slug>
   ```

   Use `unique` to avoid duplicate entries on re-runs.

7. **Write the plan issue report**
   - Record whether the parent milestone yaml was updated (and the resulting `dependsOnSpecs` list), or "no parent milestone — orphan spec"

## Output Format

### plan_issue_report.md

A report documenting the created spec issue.

**Structure**:

```markdown
# Spec Issue Report: [Spec Slug]

## Platform

- **Platform**: [github | forgejo]
- **Repository**: [owner/repo]

## Spec Issue

- **Number**: #[number]
- **Title**: Spec: [spec-slug]
- **URL**: [issue URL]
- **Assignee**: [Drago's username]
- **Labels**: kind:spec, engineering

## References

- **Parent Milestone Issue**: #[milestone_issue_number] (or "(orphan spec)")
- **Specs PR**: #[specs_pr_number] ([URL])
- **Review Decision**: [link or summary]

## Used by milestones (committed to milestone.yaml)

- [ms-slug] (#[issue]) — appended by this step
- [other-ms-slug] (#[issue]) — pre-existing
(or: "(none yet) — orphan spec")

## Stories Included

| Story           | Happy Path | Tests | Mockup | Demo |
| --------------- | ---------- | ----- | ------ | ---- |
| US-001: [title] | yes        | yes   | yes/no | yes  |
| US-002: [title] | yes        | yes   | yes/no | yes  |

## Implementation Order

[Summary of the phasing — what can be parallel, what must be sequential]

## Feature Flags

[List of stories requiring feature flags, or "None"]

## Notes

[Any issues or items needing attention]
```

### Spec Issue Body Format

The issue body created on the platform should follow this structure:

```markdown
# Spec: [spec-slug]

**Spec Directory**: docs/specs/[NNN]-[spec-slug]/
**Specs PR**: #[specs_pr_number]
**Parent Milestone Issue**: #[milestone_issue_number] (or omit if orphan)
**Review Decision**: [link or inline summary of scope decisions]

## Used by milestones

- [ms-slug] (#[issue])
(or: "(none yet)")

## Stories

### US-001: [Story title]

**Happy Path**:

1. User navigates to /recipes/new
2. User fills in title, ingredients, and instructions
3. User clicks "Save Recipe"
4. System creates recipe and redirects to /recipes/{id}
5. Recipe appears in the user's recipe list

**Test Expectations**:

- RED: `POST /api/recipes` with valid payload returns 404 (route doesn't exist yet)
- GREEN: `POST /api/recipes` with valid payload returns 201 with recipe ID
- RED: Recipe form component renders without crashing (component doesn't exist yet)
- GREEN: Recipe form component renders with title, ingredients, and save button

**Design Mockup**:

┌─────────────────────────────────┐
│ New Recipe                      │
├─────────────────────────────────┤
│ Title: [________________]       │
│                                 │
│ Ingredients:                    │
│ [________________] [+ Add]      │
│ • Flour                         │
│ • Sugar                         │
│                                 │
│ Instructions:                   │
│ [                             ] │
│                                 │
│ [Save Recipe] [Cancel]          │
└─────────────────────────────────┘

**Demo Artifacts**:
- Screenshot: Recipe creation form with sample data filled in
- Screenshot: Successfully created recipe detail page
- Video (optional): Full create flow from empty form to saved recipe

---

### US-002: [Story title]
...

## Tasks

### Phase 1: Infrastructure (parallel — no dependencies)
- [ ] chore: add recipes database migration
- [ ] chore: set up image upload infrastructure

### Phase 2: Features (parallel — depends on Phase 1)
- [ ] feat: add recipe creation form (US-001)
- [ ] feat: add recipe search (US-002)
- [ ] feat: add recipe sharing (US-003) — flag: `ENABLE_RECIPE_SHARING`

### Phase 3: Integration Tests (depends on Phase 2)
- [ ] test: add recipe API integration tests

### Future Work (out of spec scope)
- Recipe ratings and reviews
- Recipe import from external sites

## Feature Flags

| Story | Flag Name | Reason |
|-------|-----------|--------|
| US-003 | `ENABLE_RECIPE_SHARING` | Social features need gradual rollout |
```

> **Note to implementers**: Each task above maps to one PR. Reference this issue in your PR with `Part of #N`. Check off tasks as PRs merge.

## Quality Criteria

- The issue title is `Spec: <spec-slug>` (NOT `Plan: <milestone title>`; NO `(M#)` suffix)
- The `kind:spec` and `engineering` labels are applied
- **No child issues created** — all work tracked in this single spec issue's task checklist
- A "Used by milestones" section is present (with either parent milestone entries or `(none yet)`)
- If a parent milestone was named at workflow start, that milestone's `milestone.yaml` was updated to append `<spec-slug>` to `dependsOnSpecs` and committed/pushed on `milestone/<ms-slug>`
- Every approved user story from the review decision appears in the issue with happy path requirements
- A phased task checklist documents all work items with conventional commit prefixes
- Parallelism and blocking dependencies are clearly documented per phase
- Each story includes red/green test expectations describing what fails before and passes after implementation
- ASCII art mockups are included for new UI components or layouts
- Expected demo artifacts are described for each story (screenshots, videos, preview URLs)
- The specs PR and the spec directory path are referenced in the issue body

## After this step

Once the spec issue is created, suggest the following to the user:

> The `Spec: <spec-slug>` issue is ready. Next steps:
>
> 1. **`engineer/implement`** — use this workflow for each task in the spec issue's task checklist to drive implementation through to merged PRs. Per-task PRs target `spec/<spec-slug>`; `spec/<spec-slug>` merges to `main` when engineering is complete.
> 2. **`ks.notes` / `notes/process_inbox`** — capture the scope analysis, design decisions, and review outcome into personal notes before implementation begins. Key decisions made during the document review are worth preserving in the Zettelkasten.

## Context

This step creates the engineering tracking issue for the spec. The `Spec:` issue serves as the **single tracking issue** for all implementation work tied to this engineering scope — no child issues are created. Instead, it contains a phased task checklist where each task maps to one PR. This avoids issue sprawl (10+ granular issues per milestone) and keeps all context, parallelism notes, and blocking info in one place. PRs reference the spec issue with `Part of #N`. The test expectations follow TDD principles — defining what should fail and pass before writing code. The demo artifacts ensure that every story has a verifiable outcome visible to stakeholders. The "Used by milestones" section and the `milestone.yaml.dependsOnSpecs` update are the two halves of the milestone-spec link: one for humans reading the issue, one for tooling reading the yaml.
