---
name: github-workflow
description: GitHub development workflow — issue discipline, commit format, pre-PR conformance gate, gh CLI recipes, and PR review handling
---

## Before Creating a PR (Mandatory Gate)

Run this checklist **before every `gh pr create`**, without exception.

### Step 1: Run @architect-reviewer

Invoke `@architect-reviewer` with:
- The **design document sections** relevant to the changed code (search `docs/` for specs, ADRs, design docs — if none exist, note that in the PR body)
- The **changed files** (`git diff origin/main --name-only`)
- The **issue being fixed**, if one exists (`gh issue view <N>` — pass the full body)

`@architect-reviewer` will produce a conformance table with CONFORMANT / PARTIAL / MISSING / DEAD per requirement.

### Step 2: Act on the Findings

| Finding | Action |
|---------|--------|
| All CONFORMANT | Proceed to Step 3 |
| Any PARTIAL | Fix the gap, re-run `@architect-reviewer` |
| Any MISSING | Fix before opening the PR — no exceptions |
| Any DEAD | Fix the broken producer→consumer chain before opening the PR |

Do not open the PR with unresolved MISSING or DEAD findings. There is no "I'll fix it in a follow-up" for items the design requires.

### Step 3: Paste the Conformance Table into the PR Body

The PR body **must** contain the `@architect-reviewer` conformance table. A PR body without it signals the gate was skipped.

```markdown
## Design Conformance

| # | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| 1 | ... | ADR-0003, §2 | CONFORMANT | src/pipeline.py:142 |
...

Reviewed by @architect-reviewer — all requirements CONFORMANT.
```

If the repo has no design documents, write: `No design documents found — conformance review not applicable.`

### Step 4: Open the PR

```bash
gh pr create --fill
```

For stacked PRs and parallel work across multiple stacks, load the `stacked-prs` skill.

---

## gh CLI Recipes

```bash
# Issues
gh issue create -t "Title" -b "Body" -l bug
gh issue list --state open --label "priority:high"
gh issue close 42 -c "Fixed in #45"
gh issue edit 42 --add-label "in-progress"

# PRs
gh pr create --fill                     # From current branch, auto-fill
gh pr list --state open --author @me
gh pr checks 45                         # CI status
gh pr review 45 --approve
gh pr merge 45 --squash --delete-branch # For non-stacked PRs only

# CI/CD
gh run list --workflow=ci.yml
gh run view <id> --log-failed
gh run rerun <id> --failed
gh workflow run release.yml -f force=minor

# Searching
gh search code "pattern" --repo owner/repo
gh search issues "label:bug is:open" --repo owner/repo
```

## Issue Discipline

For full issue writing guidance — templates, removal discipline, design doc references,
test requirements, epic sizing — load the `issue-writing` skill.

### NEVER defer work without an issue
If a reviewer says "you could also..." or "consider adding..." and it's out of scope:
1. Create an issue immediately: `gh issue create -t "Follow-up: ..." -b "From PR #N"`
2. Link it in the PR comment
3. Move on

### Issue Triage Labels
- `bug`, `enhancement`, `documentation`
- `priority:high`, `priority:low`
- `good-first-issue` for onboarding

## PR Review Handling

- Address every comment before re-requesting review.
- If you disagree, explain reasoning — don't ignore.
- Fix issues in the same PR, don't defer to follow-ups (unless truly out of scope).
- Self-review with `git diff origin/main` before every push.

## Commit Message Format

```
type(scope): description

[optional body]

[optional footer: BREAKING CHANGE, Refs #issue]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`
