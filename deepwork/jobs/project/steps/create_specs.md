# Create Functional Requirement Specs

## Objective

Write spec files for one engineering scope (one spec slug) covering one or more system boundaries. Each spec contains behavioral requirements, data contracts, and edge case documentation. Spec files land in `docs/specs/NNN-<spec-slug>/`. Commit specs to a `spec/<spec-slug>` branch off `main`, open a draft PR, and assign reviewers.

## Task

Read the scope analysis and review decision from prior steps, group approved stories under one engineering scope (one spec), and write spec files using RFC 2119 keywords. The spec slug is chosen for the engineering scope — it is NOT auto-derived from the milestone slug. One milestone may depend on multiple specs, each with its own slug. Only write specs for stories that are **in scope** or **renegotiated** per the review decision — deferred stories are excluded.

### Spec slug vs milestone slug — convention reference

Per the milestone/spec convention (see `docs/conventions/milestones-and-specs.md` in the project repo when present), milestones and specs are **independent peers**, both branched off `main`:

- `milestone/<ms-slug>` — product integration, owns `docs/milestones/M<N>-<ms-slug>/`
- `spec/<spec-slug>` — engineering integration, owns `docs/specs/NNN-<spec-slug>/`

A milestone declares the specs it depends on in its `milestone.yaml` `dependsOnSpecs` array. A spec stands on its own and may be depended on by zero, one, or many milestones. Pick the spec slug to describe the engineering scope (e.g., `eval-cli-runner`, `mcp-transport-upgrade`), not the milestone.

### Process

1. **Read the prior step outputs**
   - Load `scope_analysis.md` from the `review_milestone` step
   - Load `review_decision.md` from the `document_review` step
   - Extract the approved MVP scope — only in-scope and renegotiated stories
   - Note the system boundaries and the repository slug and platform

2. **Determine the spec slug**
   - Ask the user (via `AskUserQuestion` if available) for the `<spec-slug>` describing this engineering scope. Suggest 1-2 candidate slugs based on the system boundaries in the scope analysis (e.g., `eval-cli-runner`, `recipe-search-index`).
   - The slug MUST be kebab-case
   - The slug is NOT auto-derived from the milestone slug — one milestone may have multiple specs with their own slugs
   - If the user has a clear parent milestone slug from `setup_milestone`, ask whether this spec belongs to that milestone (used in the `create_plan_issue` step to update `milestone.yaml.dependsOnSpecs`)

3. **Navigate to the project repo**
   - Work in `.repos/{owner}/{repo}`
   - Ensure the repo is up to date: `git fetch origin`

4. **Create a branch and worktree**
   - Create a branch off `origin/main` (NOT off the milestone branch — milestones and specs are peers): `git branch spec/<spec-slug> origin/main`
   - Create a worktree: `git worktree add "$HOME/.worktrees/{owner}/{repo}/spec/<spec-slug>" spec/<spec-slug>`
   - Work in the worktree for all subsequent operations

5. **Create spec files**
   - Find the next sequential spec number `NNN` by scanning existing `docs/specs/NNN-*/` directories — use the next free zero-padded integer (e.g., if `001`, `002`, `003` exist, use `004`). Numbers are stable and never reused.
   - Create directory `docs/specs/NNN-<spec-slug>/` in the repo
   - For each system boundary identified in the scope analysis (for approved stories only), create a spec file inside the directory at `docs/specs/NNN-<spec-slug>/<boundary-slug>.md`
   - `<boundary-slug>` is a short kebab-case name derived from the boundary name (e.g., `api-layer.md`, `database-schema.md`)
   - When only one boundary applies, a single `spec.md` inside the directory is also acceptable

6. **Write each spec**
   - For each spec file, include:
     - Which user stories this spec covers
     - Affected modules and files
     - Data models or API contracts (request/response schemas, database columns)
     - Behavioral requirements using RFC 2119 keywords (MUST, SHOULD, MAY)
     - Edge cases and error handling
     - ASCII art mockups for UI components (if applicable)
   - For renegotiated stories, reflect the **revised** scope from the review decision — not the original press release promise
   - Cross-reference other specs in the same directory or in peer `docs/specs/` directories when boundaries interact

7. **Commit and push**
   - Stage all spec files: `git add docs/specs/NNN-<spec-slug>/`
   - Commit: `git commit -m "docs(specs): add NNN-<spec-slug> functional requirement specs"`
   - Push: `git push -u origin spec/<spec-slug>`

8. **Open a draft PR**

   **GitHub**:

   ```bash
   gh pr create --draft \
     --title "docs(specs): NNN-<spec-slug> functional requirement specs" \
     --body "Spec for engineering scope <spec-slug>. Review before implementation begins."
   ```

   **Forgejo**:

   ```bash
   fj pr create "WIP: docs(specs): NNN-<spec-slug> functional requirement specs" \
     --head spec/<spec-slug> --base main \
     --body "Spec for engineering scope <spec-slug>. Review before implementation begins." \
     -r {owner}/{repo}
   ```

9. **Assign reviewers**
   - Read `.agents/TEAM.md` for the correct platform usernames
   - Assign Luce (CPO) and Nicholas (human) as reviewers
   - GitHub: `gh pr edit {pr_number} --add-reviewer {username1},{username2}`
   - Forgejo: use the API to add reviewers

10. **Write the specs PR report**
    - Capture the spec slug, directory path, parent milestone slug (if known) so `create_plan_issue` can update the right `milestone.yaml`

## Output Format

### specs_pr_report.md

A report documenting the created spec directory, spec files, and the draft PR.

**Structure**:

```markdown
# Specs PR Report: [Spec Slug]

## Platform

- **Platform**: [github | forgejo]
- **Repository**: [owner/repo]
- **Branch**: spec/[spec-slug]
- **Spec Directory**: docs/specs/[NNN]-[spec-slug]/
- **Spec Slug**: [spec-slug]
- **Parent Milestone Slug** (if any): [ms-slug or "(orphan spec)"]

## Draft PR

- **Number**: [PR number]
- **Title**: [PR title]
- **URL**: [PR URL]
- **Reviewers**: [assigned reviewers]

## Spec Files Created

| File                                              | Boundary        | Stories Covered        |
| ------------------------------------------------- | --------------- | ---------------------- |
| `docs/specs/004-eval-harness/api-layer.md`        | API Layer       | US-001, US-002, US-003 |
| `docs/specs/004-eval-harness/database-schema.md`  | Database Schema | US-001, US-002, US-004 |
| `docs/specs/004-eval-harness/auth-middleware.md`  | Auth Middleware | US-003, US-005         |

## Spec Summary

### docs/specs/[NNN]-[spec-slug]/[boundary].md

- **Boundary**: [boundary name]
- **Key requirements**: [1-2 sentence summary of MUST requirements]
- **Data contracts**: [list of API endpoints or models defined]

...

## Notes

[Any issues encountered, cross-spec dependencies, or items needing attention]
```

### Spec File Format

Each spec file at `docs/specs/{NNN}-{spec-slug}/{boundary}.md` should follow this structure:

````markdown
# Spec: [Boundary Name]

## Stories Covered

- US-001: [title]
- US-003: [title]

## Affected Modules

- `src/routes/api.ts`
- `src/lib/db.ts`

## Data Models

### [Model Name]

| Field | Type   | Required | Notes         |
| ----- | ------ | -------- | ------------- |
| id    | UUID   | yes      | Primary key   |
| name  | string | yes      | Max 255 chars |

## API Contracts

### POST /api/recipes

**Request**:

```json
{
  "title": "string",
  "ingredients": ["string"]
}
```

**Response** (201):

```json
{
  "id": "uuid",
  "title": "string",
  "created_at": "iso8601"
}
```

**Errors**:

- 400: Missing required fields
- 401: Not authenticated

## Behavioral Requirements

1. The system MUST validate all required fields before persisting.
2. The system MUST return a 400 error with a descriptive message when validation fails.
3. The system SHOULD sanitize HTML in user-provided text fields.
4. The system MAY cache search results for up to 60 seconds.

## Edge Cases

- Empty string fields MUST be rejected (not treated as valid input)
- Concurrent updates to the same resource MUST use optimistic locking
- File uploads exceeding 10MB MUST be rejected with a 413 error

## UI Mockups (if applicable)

```
┌─────────────────────────────────┐
│  New Recipe                     │
├─────────────────────────────────┤
│  Title: [________________]      │
│                                 │
│  Ingredients:                   │
│  [________________] [+ Add]     │
│  • Flour                        │
│  • Sugar                        │
│                                 │
│  [Save Recipe]  [Cancel]        │
└─────────────────────────────────┘
```
````

## Quality Criteria

- The spec slug was chosen for the engineering scope (not auto-derived from the milestone slug) and is kebab-case
- The `spec/<spec-slug>` branch was created off `origin/main` (not off `milestone/<ms-slug>` — milestones and specs are peers)
- Spec files live under `docs/specs/NNN-<spec-slug>/` with a fresh, never-reused `NNN`
- Every system boundary identified in the scope analysis (for approved stories) has a corresponding spec file under the spec directory
- Specs use RFC 2119 keywords (MUST, SHOULD, MAY) for behavioral requirements
- API contracts, data models, or interface definitions are specified where applicable
- A draft PR has been created with the spec files and assigned to reviewers
- Edge cases and error handling are documented in each spec
- Specs reflect renegotiated scope from the review decision, not the original press release promises
- The report records the parent milestone slug (if any) so the next step can update `milestone.yaml.dependsOnSpecs`

## Context

This step bridges analysis and implementation planning. Specs serve as the contract between product and engineering: they define what the system must do (behavioral requirements) without prescribing how (implementation details). The `spec/<spec-slug>` branch is a peer to any `milestone/<ms-slug>` — both branch off `main`. Orphan specs (no milestone parent) are valid; they ship engineering work on their own merits. The specs PR goes through review before implementation starts, ensuring alignment between Luce (product), Nicholas (human), and Drago (engineering). The next step (`create_plan_issue`) creates the `Spec: <spec-slug>` tracking issue and, if a parent milestone was identified, updates that milestone's `milestone.yaml` to append `<spec-slug>` to `dependsOnSpecs`.
