---
name: pr-review-merge
description: Resolving PR review comments and merging stacked PRs — gathering all feedback, addressing every finding, delegating to expert subagents, managing review states, and merging bottom-to-top
---

# PR Review and Stack Merge Workflow

**Execute this workflow immediately and completely.** Do not ask the user whether
to proceed — loading this skill is authorization to act. The goal is: gather all
feedback, address every finding, push fixes, hand off the merge to `@github-ops`.

## Step 1: Gather ALL Feedback

Pull every feedback source before touching any code. **All four calls are
mandatory** — skipping any of them is incomplete feedback gathering:

```
mcp__github__pull_request_read (get_comments)          # issue-style PR comments ← START HERE
mcp__github__pull_request_read (get_reviews)           # review decisions + body
mcp__github__pull_request_read (get_review_comments)   # threaded inline comments
mcp__github__pull_request_read (get_status)            # CI/check status
```

**`get_comments` (issue-style PR comments) is listed first because it is the
most commonly skipped and often contains the most important feedback.**
Architectural concerns, conceptual objections, and design questions are
typically left as PR comments, not inline review comments. Inline comments
address local code issues. PR comments address the PR as a whole.

These are separate API endpoints. Calling one does not return the other.
A PR with zero inline review comments may still have critical PR comments.

### Mandatory: Produce a Full Finding List

Before acting on anything, write out every piece of feedback found across all
four sources. Format:

```
PR comments (get_comments):
- [author, timestamp]: "[quote or summary]"
- ...

Review decisions (get_reviews):
- [author]: APPROVED / CHANGES_REQUESTED / COMMENTED
  "[review body if present]"

Inline comments (get_review_comments):
- [author, file:line]: "[quote or summary]"
- ...

CI status: passing / failing / pending
```

A later comment may contradict or supersede an earlier one — read everything
before acting on anything.

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

## Step 6: Reply to Every Comment — No Exceptions

After pushing, reply individually to every piece of feedback from the finding
list. Every comment gets exactly one of these replies:

| Outcome | Reply format |
|---------|-------------|
| Fixed | `"Fixed in <commit sha>. [One sentence explaining what changed and why.]"` |
| Deferred | `"Good catch — out of scope here. Tracked in #N."` |
| Intentionally not changed | `"Intentionally kept as-is: [reason]. Happy to discuss if you disagree."` |

**PR comments** (issue-style) — reply with `gh pr comment`:
```bash
gh pr comment <pr-number> --body "Fixed in abc1234. Extracted the validation
logic into a separate validator class as suggested."
```

**Inline review comments** — reply to the specific thread, then resolve it:
```bash
# Reply to a specific review comment thread
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  --method POST --field body="Fixed in abc1234. Renamed for clarity."

# Resolve the thread after replying
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id} \
  --method PATCH --field "in_reply_to_id={comment_id}"
```

**Never resolve a thread without replying first.** Resolution without a reply
is invisible — it looks like the comment was acknowledged but leaves no record
of what was done or why.

Work through the finding list item by item. When every comment has a reply,
proceed to the summary.

## Step 6b: Leave Summary Comment

```bash
gh pr comment <number> --body "Addressed all review comments:
- Fixed [X] (commit abc1234)
- Added tests for [scenario]
- Created #N to track [deferred concern]"
```

The summary is a high-level roll-up. Individual replies (Step 6) handle the
per-comment accountability. Both are required.

## Step 6c: Pre-Merge Conformance Gate (Mandatory)

Before handing off to `@github-ops`, run `@architect-reviewer` on the **final state** of the branch:

Invoke `@architect-reviewer` with:
- The **design document sections** relevant to the changed code
- The **full PR diff** (`gh pr diff <number>`)
- The **original issue** being fixed, if one exists (`gh issue view <N>`)

**This is a fresh run on the final diff — not a repeat of the pre-PR check.** Review cycles can negotiate away spec requirements ("just track it in a follow-up") or fixup commits can inadvertently break a previously CONFORMANT item.

| Finding | Action |
|---------|--------|
| All CONFORMANT | Proceed to Step 6d |
| Any PARTIAL | Fix, push, return to Step 5 |
| Any MISSING / DEAD | Fix, push, return to Step 5 — no exceptions |

## Step 6d: Bot Review Loop

This project uses automated reviewers. Trigger both before merging:

**Claude bot** reviews automatically on every push — no action needed.

**Gemini bot** must be triggered manually:
```bash
gh pr comment <number> --body "/gemini review"
```

Then wait for both bots to complete their reviews. Evaluate:

| Outcome | Action |
|---------|--------|
| Both LGTM or COMMENTED only | Proceed to Step 7 |
| Either has CHANGES_REQUESTED | Address all findings (Step 3–5), reply to each comment (Step 6), push, Claude re-reviews automatically, post `/gemini review` again, repeat from Step 6d |

**LGTM from both bots is the merge gate.** Do not hand off to `@github-ops` until this is satisfied.

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

Use mem0 (if configured) for non-obvious findings from this review cycle:

```
"PR review pattern in {repo}: {reviewer} flags {pattern}. Prefer {approach}. (PR #{N})"
"Fix for {issue}: {non-obvious solution}. Discovered in PR #{N} review, {repo}."
"Issue #{N} created: {concern} deferred from PR #{M} in {repo}."
```

Do not store routine style fixes. Store patterns that will save time in future PRs.

## Common Pitfalls

- **Skipping `get_comments`** — the most common failure. PR comments contain
  architectural and conceptual feedback that inline comments never capture.
  A PR can have zero inline comments and still have blocking concerns in `get_comments`.
- **Treating `get_reviews` as sufficient** — review decisions (APPROVED etc.) are
  separate from review body text, which is separate from inline comments, which is
  separate from PR comments. Four calls, not one.
- **Producing no finding list before acting** — without writing out all feedback first,
  early findings get acted on before later ones are read, causing contradictions to be missed.
- **Marking threads resolved without acting** — resolved ≠ addressed
- **Merging with CHANGES_REQUESTED outstanding** — always check review state explicitly
- **Amending commits** — breaks reviewers' diff context; always new commits
- **Merging top-to-bottom** — always merge bottom-to-top for stacked PRs
