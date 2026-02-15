---
name: github-workflow
description: GitHub development workflow — stacked PRs with stack-pr and git-branchless, gh CLI recipes, issue tracking discipline, PR review handling, and CI/CD patterns
---

## Stacked PR Workflow (stack-pr + git-branchless)

### Why Stacked PRs
- Keeps PRs small (150-400 lines target, 800 hard limit).
- Each commit = one reviewable PR, merged bottom-up.
- `stack-pr` handles branch creation, PR dependencies, and post-merge rebasing.
- `git-branchless` handles local commit management (amend, reorder, rebase).

### Setup
```bash
uv tool install stack-pr      # Requires gh CLI
cargo install --locked git-branchless  # Or: brew install git-branchless
git branchless init            # Per-repo, one-time
```

### Daily Workflow
```bash
git fetch origin main && git checkout origin/main

# Work in commits (not branches)
git add -p && git commit -m "refactor(models): extract base class"
git add -p && git commit -m "feat(models): add new entity type"

git branchless smartlog        # View stack graph
stack-pr view                  # Preview (read-only)
stack-pr submit                # Create/update PRs
```

### Amending Mid-Stack
```bash
git prev / git next            # Navigate stack
# Make changes
git add -p && git amend        # Auto-rebases descendants
stack-pr submit                # Update all PRs
```

### Merging
```bash
stack-pr land                  # Merge bottom PR, rebase rest

# If merged via GitHub UI:
git sync                       # Rebase onto updated main
stack-pr submit                # Update remaining PRs
```

### Danger Zone
- **NEVER** merge stacked PRs manually with squash — causes orphans.
- **NEVER** use `git submit --forge github` (git-branchless) — it's broken.
- **NEVER** delete a base branch manually — closes all dependent PRs.
- If stuck: `stack-pr abandon` cleans up, then `stack-pr submit` recreates.

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
