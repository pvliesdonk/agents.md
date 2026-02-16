---
name: github-workflow
description: GitHub development workflow — stacked PRs with vanilla Git branches, gh CLI recipes, issue tracking discipline, PR review handling, and CI/CD patterns
---

## Stacked PR Workflow (Vanilla Git)

### Why Stacked PRs
- Keeps PRs small (150-400 lines target, 800 hard limit).
- Each branch = one reviewable PR, merged bottom-up.
- Uses only vanilla Git + `gh` CLI. No external stacking tools.

### Why Vanilla Git (Not stack-pr / git-branchless)
- Preserves atomic commits (multiple commits per PR, not one fat commit).
- No external tool dependencies or version breakage.
- CI triggers work reliably (no force-push hash mismatches).
- Full control over merge strategy.

### Creating a Stack
```bash
# Start from fresh main
git fetch origin main
git checkout -b feat/X-models origin/main

# Work with multiple atomic commits per branch
git add -p && git commit -m "refactor(models): extract base class"
git add -p && git commit -m "feat(models): add field validation"
git push -u origin feat/X-models
gh pr create --base main --fill

# Stack the next PR on top
git checkout -b feat/X-mutations feat/X-models
git add -p && git commit -m "feat(mutations): add create mutation"
git add -p && git commit -m "test(mutations): add mutation tests"
git push -u origin feat/X-mutations
gh pr create --base feat/X-models --fill
```

### Addressing Review Comments
```bash
# Add NEW commits — never amend or rebase branches with open PRs
git checkout feat/X-models
git add -p && git commit -m "fix(models): address review feedback"
git push

# Propagate to dependent branches via merge (not rebase)
git checkout feat/X-mutations
git merge feat/X-models
git push
```

### Merging (Bottom-Up) — CRITICAL Pattern
```bash
# Step 1: Retarget NEXT PR before merging current (prevents auto-close)
gh pr edit <PR2-number> --base main

# Step 2: Merge the bottom PR
gh pr merge <PR1-number> --squash --delete-branch

# Step 3: Rebase next PR onto updated main (removes duplicate commits)
git checkout feat/X-mutations
git fetch origin main
git rebase origin/main
git push --force-with-lease   # Acceptable ONLY after parent squash-merge

# Repeat: retarget PR3 → main, merge PR2, rebase PR3
```

### Danger Zone
- **NEVER** `git commit --amend` or `git rebase` on branches with open PRs (except after parent squash-merge).
- **NEVER** `git push --force` on branches with open PRs. Use `--force-with-lease` only in the merge step above.
- **NEVER** delete a base branch before retargeting dependent PRs — closes them.
- **CI not triggering?** Close and reopen the PR: `gh pr close <n> && gh pr reopen <n>`

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
