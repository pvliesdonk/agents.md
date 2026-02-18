---
name: pr-review-merge
description: Resolving PR review comments and merging stacked PRs — gathering all feedback, addressing every finding, delegating to expert subagents, managing review states, and merging bottom-to-top
---

# PR Review and Stack Merge Workflow

**Execute this workflow immediately and completely.** Do not ask the user whether
to proceed — loading this skill is authorization to act. The goal is: gather all
feedback, address every finding, push fixes, hand off the merge to `@github-ops`.

## Step 1: Gather ALL Feedback

Pull every feedback source before touching any code:

```
mcp_github_pull_request_read method: get_review_comments  # threaded inline comments
mcp_github_pull_request_read method: get_reviews           # review decisions + body
mcp_github_pull_request_read method: get_comments          # issue-style PR comments
mcp_github_pull_request_read method: get_status            # CI/check status
```

Build a full finding list before acting on any of them. A later comment may
contradict or supersede an earlier one.

## Step 2: Triage Review States

| State | Action |
|-------|--------|
| `APPROVED` | Proceed — still address any inline comments left |
| `CHANGES_REQUESTED` | Must address all findings before merging |
| `COMMENTED` | Non-blocking — use judgment on suggestions |
| `DISMISSED` | Treat as informational |
| No review | User invocation of this skill is sufficient authorization to proceed |

**Never merge with unresolved `CHANGES_REQUESTED`** unless a maintainer has
dismissed the review with documented rationale.

## Step 3: Address Every Finding — No Exceptions

Every comment has exactly two valid outcomes:

1. **Fix it** — make the change (or a better alternative)
2. **Track it** — create a GitHub issue, reply to the comment with the issue link:
   `"Good catch. Out of scope here — tracked in #N."`

Never silently skip a finding. Never mark a thread resolved without acting on it.

**Conflicting feedback:** Pick the better approach, post a PR comment explaining
the choice. If it surfaces a genuine design question, create an issue and link it.
Then proceed — do not stall.

## Step 4: Delegate to Expert Subagents

Do not solve everything yourself. Spawn the right specialist:

| Finding type | Delegate to | What to pass |
|-------------|------------|--------------|
| Architecture concerns | `@architect` | Exact quote + file/line + context |
| Security vulnerability | `@security-reviewer` | Quote + proposed fix to validate |
| Missing/broken tests | `@test-engineer` | Function/module + scenario from review |
| Docstring/docs gaps | `@technical-writer` | Function signature + what's missing |
| LLM pipeline issues | `@llm-engineer` | Quote + chain context |
| Infrastructure/Docker | `@devops-engineer` | Quote + Dockerfile/compose context |

Security findings are never deferred — fix in this PR.

## Step 5: Commit and Push

Group fixes logically — not one commit per comment:

```bash
git add <files>
git commit -m "fix: address PR #N review comments

- Fix [finding] in src/foo.py
- Add missing tests for [scenario]
- Create issue #M for deferred [concern]"

git push
```

**Never amend** — always new commits. Squash-merging will clean history at
merge time. Amending rewrites history reviewers already read.

## Step 6: Leave Summary Comment

```bash
gh pr comment <number> --body "Addressed all review comments:
- Fixed [X] (commit abc1234)
- Added tests for [scenario]
- Created #N to track [deferred concern]"
```

If the project's CI/CD automatically triggers re-review, that is sufficient.
Do not wait for a new approval round — proceed immediately to `@github-ops`.

## Step 7: Hand Off to @github-ops

Invoke `@github-ops` to handle all git mechanics:

```
@github-ops Merge the PR stack: #<bottom>, #<middle>, #<top> (bottom-to-top,
squash-merge). Retarget and rebase each PR before merging. Use --force-with-lease
after rebases. Wait for CI to pass between merges.
```

`@github-ops` owns: retargeting, rebasing, force-with-lease pushes, CI checks,
squash-merges, branch deletion, post-merge memory storage.

## Step 8: Store Memories

Call `mcp_mem0_add_memory` for non-obvious findings from this review cycle:

```
"PR review pattern in {repo}: {reviewer} flags {pattern}. Prefer {approach}. (PR #{N})"
"Fix for {issue}: {non-obvious solution}. Discovered in PR #{N} review, {repo}."
"Issue #{N} created: {concern} deferred from PR #{M} in {repo}."
```

Do not store routine style fixes. Store patterns that will save time in future PRs.

## Common Pitfalls

- **Reading only review bodies, not inline comments** — always call `get_review_comments`
  separately; they are a different API endpoint from review decisions
- **Marking threads resolved without acting** — resolved ≠ addressed
- **Merging with CHANGES_REQUESTED outstanding** — always check review state explicitly
- **Amending commits** — breaks reviewers' diff context; always new commits
