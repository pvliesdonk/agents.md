---
name: issue-writing
description: Writing well-structured GitHub issues — standard templates, removal issue discipline, design doc references, test update requirements, epic sizing, and dependency declaration
---

# Issue Writing

A well-written issue is the contract between the person filing it and the person
implementing it. Vague issues produce vague PRs. Concrete acceptance criteria
produce verifiable implementations.

## Standard Issue Template

Every issue, regardless of type, uses this structure:

```markdown
## Problem

One sentence: what is wrong or missing, and why it matters.

## Background

Context the implementer needs. Link to related issues, PRs, ADRs, or discussions.
Keep it short — if it needs more than 3-4 sentences, link to a document instead.

## Design Documentation

<!-- REQUIRED — choose one: -->
- Relevant: [ADR-0003](docs/decisions/0003-...), [Design Doc](docs/design/...)
- None available — implementation is the spec.
- Conflict: [ADR-0002](docs/decisions/0002-...) specifies X but this issue proposes Y.
  See Background for rationale.

## Acceptance Criteria

- [ ] 1. Concrete, verifiable statement of what must be true when done
- [ ] 2. Each item independently checkable — no "and also" items
- [ ] 3. ...

## Test Updates

<!-- REQUIRED — choose one: -->
- Tests added/updated: describe what scenarios are covered
- No test changes needed: [reason]
- Coverage: patch coverage must not regress below [N]%

## Out of Scope

Explicitly list related things this issue does NOT cover. This prevents
scope creep and "while I'm in there" additions.

- Not in scope: [thing that seems related but isn't]

## Dependencies

- Blocked by: #N (must be merged before this starts)
- Blocks: #N (this must merge before that can start)
- None

## Definition of Done

- [ ] All acceptance criteria checked off
- [ ] Tests pass, coverage not regressed
- [ ] architect-reviewer conformance table in PR body (all CONFORMANT)
- [ ] Design docs updated if needed (or separate issue filed: #N)
- [ ] Verification commands pass (removal issues only — see below)
```

---

## Removal Issues — Special Rules

**Removal must always be a standalone issue.** Never bundle "remove X" with "add Y"
in the same issue. Bundling guarantees the removal gets deferred — the new feature
ships, the old code stays.

> If removal is trivially small (< 10 lines, < 5 minutes), it may accompany an
> addition. Everything else: separate issue.

### Mandatory: Verification Section

Every removal issue must include a **Verification** section with shell commands
that mechanically confirm the removal happened. These commands must return zero
matches when the issue is complete. They are acceptance criteria — run them before
closing the issue.

```markdown
## Verification

Run these commands after implementation. All must return 0 matches:

```bash
# Old class is gone
grep -r "OldClassName" src/ tests/

# Old API endpoint removed
grep -r "/api/v1/legacy" src/

# Old dependency removed
grep "old-package" pyproject.toml
```
```

If any command returns matches, the issue is not done.

### Mandatory: Test Updates as a Deliverable

Tests that exercised the removed code must be **rewritten** to assert the new
expected state — not deleted, not left passing via a compatibility shim.

State this explicitly in the issue:

```markdown
## Test Updates

- `tests/test_pipeline.py::test_legacy_stage` — rewrite to assert stage is absent
  from the pipeline output, not just that the pipeline doesn't crash.
- `tests/test_api.py::test_v1_endpoint` — assert 404, not 200.
```

The goal: tests become positive evidence that the removal happened, not just
evidence that nothing broke.

### Removal Issue Template

```markdown
## Problem

[OldThing] is no longer needed because [reason]. It adds maintenance burden /
dead code / confusion without providing value.

## Background

[OldThing] was introduced in #N to [original purpose]. That purpose is now served
by [NewThing / changed requirements].

## Design Documentation

- [ADR-0007](docs/decisions/0007-...): specifies that [OldThing] is superseded

## What to Remove

- `src/module/old_thing.py` — delete entirely
- `src/pipeline.py:142-156` — remove the call site
- `tests/test_old_thing.py` — rewrite (see Test Updates)

## Acceptance Criteria

- [ ] 1. [OldThing] class/function/module no longer exists in the codebase
- [ ] 2. All call sites removed or migrated to [NewThing]
- [ ] 3. Tests rewritten to assert new expected state (not just deleted)

## Test Updates

- `tests/test_old_thing.py::test_X` — rewrite to assert [new expected state]

## Verification

```bash
grep -r "OldThing" src/ tests/       # must return 0 matches
grep -r "old_thing" src/ tests/      # must return 0 matches
```

## Out of Scope

- Implementing [NewThing] — tracked in #N
- Migrating external consumers — tracked in #N

## Dependencies

- Blocked by: #N ([NewThing] must exist before [OldThing] can be removed)

## Definition of Done

- [ ] All acceptance criteria checked off
- [ ] Verification commands return 0 matches
- [ ] Tests rewritten (not deleted) to assert new expected state
- [ ] architect-reviewer conformance table in PR body
```

---

## Design Documentation References

Every issue must address design documentation. There are exactly three valid states:

### 1. Design docs exist and are relevant
List them. Link to the specific section, not just the file.

```markdown
## Design Documentation

- [ADR-0003](docs/decisions/0003-use-langgraph.md), §3 — specifies the agent
  loop structure this issue implements
- [Design: Pipeline Stages](docs/design/pipeline.md), "Stage Interface" — defines
  the interface this issue must conform to
```

### 2. No design docs exist
State it explicitly. This is not a gap to paper over — it means the implementation
is the spec, and future decisions should reference the PR/issue.

```markdown
## Design Documentation

No design documents cover this area. Implementation decisions in this issue
become the de facto specification.
```

### 3. Conflict with existing design docs
Flag the conflict explicitly. Do not silently diverge from a design doc.

```markdown
## Design Documentation

⚠️ Conflict: [ADR-0002](docs/decisions/0002-...) specifies approach X, but this
issue proposes approach Y because [reason]. This issue supersedes ADR-0002.
A new ADR should be filed to document the updated decision (see Dependencies).
```

### When Design Docs Need Updating

If implementing this issue will make existing design docs stale or incorrect,
**file a separate issue** for the documentation update and link it:

```markdown
## Dependencies

- Blocks: #N (update ADR-0003 to reflect new pipeline interface)
```

The documentation update issue can be merged in parallel or immediately after,
but must not be forgotten. Documentation that contradicts the code is worse than
no documentation.

---

## Test Update Requirements

State test expectations explicitly in every issue. Never leave it to the
implementer's judgment.

| Situation | Required statement |
|-----------|-------------------|
| New feature | "Add tests for [scenarios X, Y, Z]" |
| Bug fix | "Add regression test that would have caught this bug" |
| Removal | "Rewrite [test names] to assert new expected state" |
| Refactor | "Existing tests must continue to pass; patch coverage must not regress" |
| No test changes | "No test changes needed because [specific reason]" |

### Coverage Floor

If the project tracks coverage, state the floor explicitly:

```markdown
## Test Updates

Patch coverage must remain above 85%. New code must be covered by the added tests.
```

---

## Epic and Milestone Discipline

### Size Limit

**Epics must not exceed 10 issues.** Larger efforts split into sequential
milestones of ≤ 10 issues, each independently valuable and deployable.

Between milestones: stop and audit. Did the previous milestone achieve its goals?
Are the design assumptions still valid? **Never execute more than one milestone
per session without explicit user approval.**

### Issue Size Check

Before filing an issue, estimate the PR size. If implementation would clearly
exceed 400 lines of diff:

1. Identify the natural split points
2. File 2–3 smaller issues instead
3. Set dependencies between them

A 600-line PR that touches 8 files is a sign the issue was too large, not that
the implementation was done right.

### Milestone Template

```markdown
## Milestone N: [Name]

Goal: [one sentence — what this milestone delivers]

Issues:
1. #N — [title]
2. #N — [title]
...

Audit gate: before starting milestone N+1, verify:
- [ ] All milestone N issues closed
- [ ] [specific behavior] confirmed working end-to-end
- [ ] No regressions in [area]
```

---

## Dependency Declaration

Never leave issue ordering implicit. If issue B cannot start until issue A is
merged, say so in the issue body and in GitHub:

```markdown
## Dependencies

- Blocked by: #42 (the new interface must exist before the old one can be removed)
- Blocks: #44 (downstream consumer cannot be updated until this API is stable)
```

Set this in GitHub as well:
```bash
# GitHub doesn't have native blocking, use labels or project board ordering
gh issue edit <N> --add-label "blocked"
gh issue comment <N> --body "Blocked by #42 — will start after that merges."
```

**Removal before addition** is the preferred ordering when a milestone includes
both. Delete the old code first — tests break — then add the new code — tests
pass. This makes it impossible to close the removal issue by adding a shim.

---

## Structural Acceptance Criteria

For issues that require two implementations to be structurally aligned (e.g., "make function A consistent with function B"), behavioral criteria are not sufficient. The issue must specify:

1. **Which files and functions** to compare — exact paths and function names
2. **Which structural property** must match — not "same behavior" but "same DAG construction approach", "same loop order", "same edge interleaving"
3. **How to verify** — a diff command or explicit comparison the implementer must perform before declaring done

**Why this matters:** The primary agent passes the issue verbatim to an implementation subagent. If the structural property is described vaguely, the subagent implements their interpretation of it. Their interpretation may pass all tests while missing the one structural difference that caused the bug.

```markdown
## Acceptance Criteria

- [ ] `verify_hints_acyclic` builds the base DAG using a pre-built full graph
  (all pairs) before iterating — identical to `_simulate_hints_sequential`
  lines 42–67. Verify by reading both functions and confirming the DAG
  construction block precedes the pair iteration loop in both.
- [ ] Diff of `verify_hints_acyclic` vs `_simulate_hints_sequential` shows
  no structural difference in DAG construction (only variable names may differ)
```

**Behavioral criteria alone (insufficient):**
> "make `verify_hints_acyclic` consistent with `_simulate_hints_sequential`"

**Structural criteria (sufficient):**
> "`verify_hints_acyclic` must pre-build the full commit-ordering base DAG from all pairs before testing any hints — same as `_simulate_hints_sequential` lines 42–67. Verify: the pair loop in `verify_hints_acyclic` must receive a pre-built DAG, not build it incrementally per pair."

### The Issue IS the Delegation Prompt

The implementer will receive this issue verbatim — body and all comments — and implement it directly. The primary agent will not re-explain or rephrase it. Write acceptance criteria as if you are writing the implementation prompt, because you are. Every structural detail that matters must be in the issue body or a pinned comment, not in a verbal explanation added at delegation time.

**When delegating, always include comments:**
```bash
gh issue view <N>         # body
gh issue view <N> --comments   # full discussion thread
```

Design decisions made in the comment thread — including clarifications, option selections, and "use Option 1 not Option 2" choices — are part of the spec. An implementer who only reads the body misses half the issue.

---

## Anti-Patterns

- **"Add X and remove Y"** in one issue — removal gets deferred, guaranteed
- **Vague acceptance criteria** — "improve performance" is not verifiable; "p95 latency < 200ms under load test" is
- **Behavioral criteria for structural alignment** — "make A consistent with B" requires specifying which structural property must match and how to verify it
- **Missing out-of-scope** — without it, scope creep is invisible until review
- **No verification commands on removal issues** — the issue can be "closed" with the old code still present
- **"Tests as needed"** — always specify; "as needed" means never
- **Silent design doc conflicts** — diverging from a spec without noting it creates hidden technical debt
- **Mega-issues** — if you can't implement it in one focused PR, it's two issues
