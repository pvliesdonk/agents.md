---
name: pr-review-merge
description: Resolving PR review comments and merging stacked PRs — gathering all feedback, addressing every finding, delegating to expert subagents, managing review states, and merging bottom-to-top
---

# PR Review and Stack Merge Workflow

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
| No review yet | PR not reviewed | Do not merge without at least one approval |

**Never merge a PR with an unresolved `CHANGES_REQUESTED` review** unless the
reviewer has explicitly withdrawn their blocking status or a maintainer has
dismissed the review with documented rationale.

**Conflicting feedback:** When two reviewers disagree, use best engineering judgment,
document the decision in a PR comment explaining what was chosen and why, then
re-request review from the conflicting parties.

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

## Step 6: Re-Request Review

After pushing, notify reviewers:

```bash
# Re-request review from everyone who reviewed
gh pr edit <number> --add-reviewer <reviewer1>,<reviewer2>

# Or leave a comment summarising what was addressed
gh pr comment <number> --body "Addressed all review comments:
- Fixed [X] (commit abc1234)
- Renamed [Y] per suggestion
- Created #N to track [deferred concern]

Ready for re-review."
```

Do not merge immediately after pushing fixes — give reviewers a chance to
re-review unless they explicitly said "just make this one change then LGTM".

## Step 7: Merge the Stack (Bottom-to-Top)

Only merge when all PRs in the stack have at least one approval and no
unresolved `CHANGES_REQUESTED` reviews.

**Merge order: always bottom-to-top.** Never merge a PR before its base is merged.

```bash
# For a stack: main <- PR-A (#41) <- PR-B (#42) <- PR-C (#43)

# 1. Merge the bottom PR (already targets main)
gh pr merge 41 --squash --delete-branch   # or --merge, per project convention

# 2. Retarget the next PR to main (its base just merged)
gh pr edit 42 --base main

# 3. Verify CI is green on #42 after retarget (base change can affect checks)
gh pr checks 42 --watch

# 4. Merge #42
gh pr merge 42 --squash --delete-branch

# 5. Retarget #43 to main, verify, merge
gh pr edit 43 --base main
gh pr checks 43 --watch
gh pr merge 43 --squash --delete-branch
```

**If CI fails after a retarget:** Do not merge. Investigate the failure — the
new base may have introduced a conflict or broken a dependency. Fix it, push,
wait for CI to pass.

**If a PR has no approval after the base merge:** Do not merge. Request review.

## Step 8: Post-Merge

```bash
# Verify the stack is fully merged
gh pr list --state merged --limit 10

# Store memory of any notable patterns discovered
# (non-obvious review findings, team preferences, recurring issues)
```

If the merge triggers a release, load the `release-flow` skill.

## Common Pitfalls

- **Forgetting inline comments when only reading review-level decisions** — always
  pull `get_review_comments` separately; review bodies and inline comments are
  different API endpoints
- **Merging top-down** — always bottom-to-top, or branches won't retarget cleanly
- **Skipping CI check after retarget** — the base change is a new commit context;
  CI must re-run
- **Resolving threads without acting** — marking resolved ≠ addressed
- **Merging with CHANGES_REQUESTED from a silent reviewer** — always check review
  state explicitly, not just approval count
