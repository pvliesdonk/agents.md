---
description: Start a new multi-agent deliberation on an architectural problem
---

# Start Multi-Agent Deliberation

You are creating a new architectural deliberation for this problem:

**Problem:** $ARGUMENTS

## Steps

### 1. Detect Repository Context

Get the current repository owner and name from the git remote:
```bash
REPO_URL=$(git config --get remote.origin.url)
# Extract owner/repo from URL
```

### 2. Search Memory for Related Decisions

Before creating the discussion, search mem0 for relevant prior architectural decisions:

```
Search query: [extract key topic from problem statement]
```

Look for:
- Prior deliberations on similar topics
- Architectural decisions that might be relevant
- Related design patterns or constraints

### 3. Get Discussion Category

Query the repository's discussion categories and select "Ideas" (or fallback to "General"):

```bash
gh api graphql -f query='
  query {
    repository(owner: "OWNER", name: "REPO") {
      discussionCategories(first: 10) {
        nodes {
          id
          name
        }
      }
    }
  }
' --jq '.data.repository.discussionCategories.nodes[] | select(.name=="Ideas" or .name=="General") | .id' | head -1
```

### 4. Create the Discussion

Use the GraphQL API to create the discussion:

```bash
CATEGORY_ID="..." # from step 3
TITLE="..." # derive from problem statement, keep concise

gh api graphql -f query='
  mutation {
    createDiscussion(input: {
      repositoryId: "REPO_ID"
      categoryId: "'"$CATEGORY_ID"'"
      title: "'"$TITLE"'"
      body: "DISCUSSION_BODY"
    }) {
      discussion {
        number
        url
      }
    }
  }
'
```

**Getting the repository ID:**
```bash
gh api graphql -f query='
  query {
    repository(owner: "OWNER", name: "REPO") {
      id
    }
  }
' --jq '.data.repository.id'
```

### 5. Compose the Discussion Body

The discussion body should include:

```markdown
# Problem Statement

[The problem description from user]

## Context

[Relevant codebase context — summarize the area of code this affects]

## Prior Related Decisions

[If mem0 search found relevant prior decisions, list them here with links]

Example:
- Discussion #42: [Topic] — decided X because Y ([link])
- Discussion #67: [Related topic] — considered Z but chose W ([link])

[If no prior decisions found, state: "No related prior architectural decisions found in memory."]

## Goal

[What question needs answering or what decision needs making]

---

**Multi-agent deliberation:** This discussion will be evaluated by Claude Opus 4.6, Gemini 3 Pro, and GPT-5.2 agents. Each will investigate independently and provide their analysis.
```

### 6. Report the Result

After creating the discussion, report:
- Discussion number
- Discussion URL
- Summary of any related prior decisions included in the context
- Next step: `/deliberate-round N` to begin the first round

## Example Output

```
Created Discussion #123: "Rethinking Shared Passages"
URL: https://github.com/owner/repo/discussions/123

Related prior decisions included:
- Discussion #42: Graph-theoretic vs narrative convergence

Ready for deliberation. Run: /deliberate-round 123
```
