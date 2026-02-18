---
name: pr-review-merge
description: Resolving PR review comments and merging stacked PRs — gathering all feedback, addressing every finding, delegating to expert subagents, managing review states, and merging bottom-to-top
---

# PR Review and Stack Merge Workflow

**When this skill is loaded, execute all steps immediately and completely.**
Do not ask the user whether to proceed. Do not pause between steps unless
explicitly told to. The goal is to: gather all feedback, address every finding,
push fixes, and merge the stack — in one continuous workflow.

## Step 1: Gather ALL Feedback

Never rely on a single source. Pull every type of comment before touching any code.

```bash
# Review comments (inline code comments per diff hunk)
gh pr view <number> --comments
gh api repos/{owner}/{repo}/pulls/<number>/reviews
gh api repos/{owner}/{repo}/pulls/<number>/comments

# Or via MCP (richer structure, includes thread resolution state):
# mcp_github_pull_request_read method: get_review_comments  -> threaded inline comments
# mcp_github_pull_request_read method: get_reviews          -> review-level decisions + body
# mcp_github_pull_request_read method: get_comments         -> issue-style PR comments
# mcp_github_pull_request_read method: get_status           -> CI/check status
```

Collect findings into a working list before acting on any of them. Understand the
full picture first — a later comment may contradict or supersede an earlier one.

## Step 2: Triage the Review States

Check each reviewer's decision before deciding how to proceed:

| State | Meaning | Action |
|-------|---------|--------|
| `APPROVED` | LGTM, no blocking concerns | Proceed, but still address any inline comments left |
| `CHANGES_REQUESTED` | Blocking — reviewer requires changes | Must address all findings before merging |
| `COMMENTED` | Non-blocking feedback | Address findings; use judgment on suggestions |
| `DISMISSED` | Review was dismissed by maintainer | Treat as informational |
| No review yet | PR not reviewed | Proceed if the user invoked this skill — treat invocation as implicit approval to merge |

**Never merge a PR with an unresolved `CHANGES_REQUESTED` review** unless the
reviewer has explicitly withdrawn their blocking status or a maintainer has
dismissed the review with documented rationale.

**Conflicting feedback:** When two reviewers disagree, use best engineering
judgment to pick the better approach. Post a PR comment documenting what was
chosen and why. If the disagreement surfaces a genuine design question, create
a GitHub issue for follow-up discussion and link it in the comment. Then
proceed — do not stall waiting for consensus.

## Step 3: Address Every Finding — No Exceptions

**Every comment must be handled.** There is no such thing as "out of scope" for a
review finding. The only two valid outcomes are:

1. **Fix it** — make the change the reviewer requested (or a better alternative)
2. **Track it** — if genuinely deferred (e.g. scope too large, separate concern),
   create a GitHub issue and link it in a reply to the comment:
   ```
   Good catch. This is out of scope for this PR but tracked in #<issue-number>.
   ```

Never silently skip a finding. Never mark a thread resolved without acting on it.

### Handling Different Finding Types

**Correctness/bugs:** Fix immediately. These are never deferrable.

**Style/naming:** Fix if quick. If the reviewer's suggestion is subjective and you
disagree, reply with your rationale — do not silently ignore it.

**Architecture/design concerns:** These often warrant involving `@architect`. Do not
make architectural changes without understanding the full impact.

**Security findings:** Involve `@security-reviewer` to validate the fix, not just
the finding. Security issues are never deferred to an issue — fix in this PR.

**Tests missing:** Add them. Involve `@test-engineer` if the testing pattern is
non-trivial.

**Documentation gaps:** Add docstrings, update READMEs, or create an ADR if the
finding surfaces a decision. Involve `@technical-writer` for significant docs work.

## Step 4: Delegate Complex Findings to Expert Subagents

Do not solve everything yourself. Use the right specialist:

| Finding type | Delegate to | How to ask |
|-------------|------------|-----------|
| Architecture concerns | `@architect` | "Review this design concern from PR #N: [quote]. What's the right approach?" |
| Security vulnerability | `@security-reviewer` | "Audit this finding and validate the proposed fix: [quote + context]" |
| Missing/broken tests | `@test-engineer` | "Write tests for [function/module] covering [scenario from review]" |
| Docstring/docs gaps | `@technical-writer` | "Write a Google-style docstring for [function] and update [file]" |
| LLM pipeline issues | `@llm-engineer` | "Reviewer flagged [issue] in the LangChain chain. Investigate and fix." |
| Infrastructure/Docker | `@devops-engineer` | "Review comment on Dockerfile: [quote]. Fix and explain." |

When delegating: include the exact review quote, the file and line number, and the
broader context. Get the fix back, review it, then apply it.

## Step 5: Commit and Push Fixes

Group fixes logically — don't commit each comment fix individually:

```bash
# One commit per logical group of fixes
git add <files>
git commit -m "fix: address PR review comments

- Fix [finding 1] in src/foo.py (raised by @reviewer)
- Rename [thing] per review suggestion
- Add missing tests for [scenario]
- Create issue #N for deferred [concern]"

git push
```

Use conventional commit prefixes:
- `fix:` for bug fixes surfaced by review
- `refactor:` for naming/structure changes
- `test:` for test additions
- `docs:` for documentation updates

**Never amend commits** — always create new commits for review fixes. Amending
rewrites history, causing confusion for reviewers who already read the diff.
If the commit history looks noisy, that is fine — it is an accurate record of
the review cycle. Squash-merging will clean it up at merge time.

## Step 6: Notify Reviewers and Continue

After pushing, leave a summary comment on the PR listing everything addressed:

```bash
gh pr comment <number> --body "Addressed all review comments:
- Fixed [X] in src/foo.py (commit abc1234)
- Renamed [Y] per suggestion
- Added tests for [scenario]
- Created #N to track [deferred concern]"
```

If the project's CI/CD pipeline automatically triggers re-review, that is
sufficient. If it does not, re-request review:

```bash
gh pr edit <number> --add-reviewer <reviewer1>,<reviewer2>
```

**Then continue to Step 7 immediately.** Do not wait for a new approval round
before merging — the user's invocation of this skill is the signal to proceed.
If a reviewer subsequently objects, that is a new review cycle the user can
handle by invoking this skill again.

## Step 7: Merge the Stack (Bottom-to-Top)

Only merge when all PRs in the stack have at least one approval and no
unresolved `CHANGES_REQUESTED` reviews.

**Merge order: always bottom-to-top.** Never merge a PR before its base is merged.

### Squash-Merge and the Double-Change Problem

Squash merging stacks requires special care. When PR-A is squash-merged into
main, its commits become a single new squash commit on main. PR-B, which was
branched from PR-A, still contains all of PR-A's original commits in its
history. After retargeting PR-B to main, git sees those commits as *different*
from the squash commit — producing a conflict or spurious diff of changes that
are already in main.

**The fix:** After retargeting, rebase PR-B's branch onto the new main to drop
the already-merged commits before merging:

```bash
# For a stack: main <- PR-A (#41) <- PR-B (#42) <- PR-C (#43)

# 1. Squash-merge the bottom PR
gh pr merge 41 --squash --delete-branch
git checkout main && git pull

# 2. Rebase PR-B onto the new main (drops PR-A's commits, keeps only PR-B's work)
git checkout branch-b
git rebase main          # resolves any double-change conflicts here
git push --force-with-lease origin branch-b

# 3. Retarget PR-B to main
gh pr edit 42 --base main

# 4. Verify CI is green (rebase changes the commit SHAs)
gh pr checks 42 --watch

# 5. Squash-merge PR-B
gh pr merge 42 --squash --delete-branch
git checkout main && git pull

# 6. Repeat for PR-C
git checkout branch-c
git rebase main
git push --force-with-lease origin branch-c
gh pr edit 43 --base main
gh pr checks 43 --watch
gh pr merge 43 --squash --delete-branch
```

**`--force-with-lease` not `--force`** — verifies nobody else pushed to the
branch since your last fetch. Safer than bare force push.

**If rebase produces conflicts:** The conflict is real — two PRs touched the
same code. Resolve carefully, keeping both sets of intended changes, then
continue the rebase (`git rebase --continue`).

**If CI fails after a retarget/rebase:** Do not merge. Investigate — the new
base may have broken a dependency. Fix, push (with --force-with-lease), wait
for CI to pass.

**If a PR has no approval after the base merge:** Proceed — the user's invocation of this skill is sufficient authorization.

## Step 8: Post-Merge Memory and Cleanup

Verify the stack is fully merged:

```bash
gh pr list --state merged --limit 10
```

**Store memories** for anything non-obvious discovered during this review cycle.
Call `mcp_mem0_add_memory` for each notable finding:

```
# Recurring pattern or team preference
"PR review pattern in {repo}: {reviewer} consistently flags {pattern}.
Prefer {approach} in this codebase. (Observed in PR #{N})"

# Non-obvious fix
"Fix for {issue}: {brief explanation of non-obvious solution}.
Discovered during PR #{N} review in {repo}."

# Deferred concern
"Issue #{N} created to track {concern} deferred from PR #{M} in {repo}."
```

Do not store routine findings (style fixes, typos). Store patterns that will
save time in future PRs for this repository.

If the merge triggers a release, load the `release-flow` skill.

## Common Pitfalls

- **Forgetting inline comments when only reading review-level decisions** — always
  pull `get_review_comments` separately; review bodies and inline comments are
  different API endpoints
- **Merging top-down** — always bottom-to-top, or branches won't retarget cleanly
- **Skipping CI check after retarget/rebase** — the base change is a new commit
  context; CI must re-run before merging
- **Resolving threads without acting** — marking resolved ≠ addressed
- **Merging with CHANGES_REQUESTED from a silent reviewer** — always check review
  state explicitly, not just approval count
- **Squash-merging without rebasing stacked branches** — produces double-change
  conflicts; always rebase onto updated main before retargeting each subsequent PR
- **Using `--force` instead of `--force-with-lease`** — bare force push silently
  overwrites concurrent pushes; always use `--force-with-lease` after rebases
- **Amending commits** — breaks reviewers' diff context; always create new commits
