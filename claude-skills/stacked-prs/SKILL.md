---
name: stacked-prs
description: Stacked PR workflow with vanilla Git — creating and managing PR stacks, parallel stacks with git worktrees, propagating fixes up a stack, and safe merging bottom-to-top
---

## Why Stacked PRs

- Keeps PRs small (150-400 lines target, 800 hard limit).
- Each branch = one reviewable unit, merged bottom-up.
- Uses only vanilla Git + `gh` CLI — no external stacking tools.
- Preserves atomic commits; squash-merge cleans history at merge time.

## Single Stack: Creating and Working

```bash
# Start from fresh main
git fetch origin main
git checkout -b feat/X-models origin/main

# Work with multiple atomic commits per branch
git add -p && git commit -m "refactor(models): extract base class"
git add -p && git commit -m "feat(models): add field validation"
git push -u origin feat/X-models

# Run @architect-reviewer + paste conformance table, then:
gh pr create --base main --fill

# Stack the next PR on top
git checkout -b feat/X-api feat/X-models
git add -p && git commit -m "feat(api): add create endpoint"
git add -p && git commit -m "test(api): add endpoint tests"
git push -u origin feat/X-api
gh pr create --base feat/X-models --fill
```

## Addressing Review Comments Within a Stack

```bash
# Fix on the branch that received the comment — always NEW commits, never amend
git checkout feat/X-models
git add -p && git commit -m "fix(models): address review feedback"
git push

# Propagate up to dependent branches via merge (not rebase)
git checkout feat/X-api
git merge feat/X-models
git push
```

**Never rebase a branch that has an open PR** (except after its parent is squash-merged).
**Never `git push --force`** on branches with open PRs — use `--force-with-lease` only in the merge step.

## Merging a Stack (Bottom-Up) — CRITICAL Pattern

```bash
# Step 1: Retarget the NEXT PR before merging current (prevents auto-close)
gh pr edit <PR2-number> --base main

# Step 2: Squash-merge the bottom PR
gh pr merge <PR1-number> --squash --delete-branch

# Step 3: Rebase next PR onto updated main (removes duplicate commits)
git fetch origin main
git checkout feat/X-api
git rebase origin/main
git push --force-with-lease   # Acceptable ONLY after parent squash-merge

# Repeat: retarget PR3 → main, merge PR2, rebase PR3
```

### Danger Zone
- **NEVER** delete a base branch before retargeting dependent PRs — auto-closes them.
- **CI not triggering?** `gh pr close <n> && gh pr reopen <n>`

---

## Parallel Stacks with git worktrees

When working on multiple independent stacks simultaneously — for example when a
planner spawns parallel work streams — use one **git worktree per stack**. This
avoids stashing, branch-switching overhead, and accidental cross-stack edits.

### Setup: One Worktree per Stack

```bash
# Main worktree: feat/X stack (already checked out)
# ~/project/  →  feat/X-models, feat/X-api

# Add a second worktree for feat/Y stack
git worktree add ../project-feat-Y feat/Y-schema
# ~/project-feat-Y/  →  feat/Y-schema (separate working directory, same repo)

# Add a third for feat/Z
git worktree add ../project-feat-Z feat/Z-pipeline
```

Each worktree has its own working tree and index. You can build, test, and commit
in each independently. They share the same `.git` object store and refs.

### Naming Convention

Keep worktree directory names and branch names in sync:

```
../project-feat-X/   →   feat/X-* branches
../project-feat-Y/   →   feat/Y-* branches
../project-feat-Z/   →   feat/Z-* branches
```

This makes it unambiguous which worktree owns which stack.

### Working Across Parallel Stacks

```bash
# Work on stack X
cd ../project-feat-X
git checkout feat/X-api
# ... make changes, commit ...

# Switch to stack Y — no stash needed
cd ../project-feat-Y
git checkout feat/Y-schema
# ... make changes, commit ...

# Pull latest main into both stacks independently
cd ../project-feat-X && git fetch origin main && git merge origin/main feat/X-models
cd ../project-feat-Y && git fetch origin main && git merge origin/main feat/Y-schema
```

### Conflict Avoidance Between Parallel Stacks

Before starting parallel stacks, identify shared files. If two stacks will both
modify the same module:

1. **Prefer sequencing** — make one stack depend on the other (stack them)
2. **Partition the work** — one stack takes the interface, the other the implementation
3. **If truly independent** — proceed with parallel worktrees; resolve conflicts when
   the second stack merges to main after the first

Never let two parallel worktrees edit the same file with the intent to merge both
to main independently — this guarantees a conflict.

### Cleaning Up Worktrees After Merge

After a stack is fully merged (all PRs squash-merged to main):

```bash
# Remove the worktree
git worktree remove ../project-feat-Y

# Prune stale worktree refs
git worktree prune

# Delete the remote branches (if not auto-deleted by gh pr merge --delete-branch)
git push origin --delete feat/Y-schema feat/Y-api
```

### Worktree Status Overview

```bash
# See all active worktrees and their branches
git worktree list
```

```
/home/user/project           abc1234  [feat/X-api]
/home/user/project-feat-Y    def5678  [feat/Y-schema]
/home/user/project-feat-Z    ghi9012  [feat/Z-pipeline]
```

---

## Stack Topology Reference

```
main
├── feat/X-models      PR #10  (base: main)
│   └── feat/X-api     PR #11  (base: feat/X-models)
└── feat/Y-schema      PR #20  (base: main)        ← separate worktree
    └── feat/Y-api     PR #21  (base: feat/Y-schema)
```

Merge order: #10 → retarget #11 → merge #10 → rebase #11 → merge #11.
Stack Y proceeds independently and merges after stack X lands.
