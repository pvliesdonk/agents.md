---
description: Synthesize deliberation findings and store the decision in memory
---

# Synthesize Deliberation

Conclude the deliberation on GitHub Discussion #$1.

## Steps

### 1. Read the Full Discussion

Use GitHub MCP tools to read:
- The original discussion post
- All comments from all agents
- Any human comments if present

Analyze the deliberation for:
- Points of consensus
- Open disagreements
- Key insights discovered
- Recommended direction

### 2. Synthesize the Decision

Create a synthesis covering:

```markdown
# Deliberation Summary

## Points of Consensus

[Where all agents agree, or where 2+ agents converge on the same position]

## Open Disagreements

[Where agents fundamentally differ, with each position summarized]

## Key Insights

[Non-obvious findings that emerged — things nobody knew at the start]

## Recommended Direction

[Your synthesis: what should we do and why]

## Remaining Questions

[Anything unresolved that needs human decision or more information]

## Agent Contributions

- **Claude Opus 4.6:** [brief summary of this agent's main contribution]
- **Gemini 3 Pro:** [brief summary of this agent's main contribution]
- **GPT-5.2:** [brief summary of this agent's main contribution]
```

### 3. Post the Synthesis to the Discussion

Use the GitHub GraphQL API to post your synthesis as a final comment:

```bash
# Get discussion node ID
DISCUSSION_ID=$(gh api graphql -f query='
  query {
    repository(owner: "OWNER", name: "REPO") {
      discussion(number: '$1') {
        id
      }
    }
  }
' --jq '.data.repository.discussion.id')

# Post synthesis comment
gh api graphql -f query='
  mutation {
    addDiscussionComment(input: {
      discussionId: "'"$DISCUSSION_ID"'"
      body: "'"$SYNTHESIS_MARKDOWN"'"
    }) {
      comment { id }
    }
  }
'
```

### 4. Store Decision in Memory (if mem0 configured)

If mem0 is configured, store this architectural decision for future reference:

```
Text: "Architectural decision: [topic from discussion title]. 
Decided: [one sentence summary of the decision]. 
Discussed in Discussion #$1 ([full URL]). 
Key factors: [brief rationale]. 
Agents: Claude Opus 4.6, Gemini 3 Pro, GPT-5.2."

Metadata: {
  "type": "architectural_decision",
  "discussion": $1,
  "repo": "owner/repo",
  "agents": ["claude-opus-4.6", "gemini-3-pro", "gpt-5.2"],
  "date": "YYYY-MM-DD"
}
```

This memory will be discovered by future `/deliberate-start` commands when searching for related decisions.

**If mem0 is not configured**, skip this step and note: "Memory storage skipped (mem0 not configured)."

### 5. Propose an ADR

If the deliberation reached a clear architectural decision, propose creating an ADR:

"This decision could be captured as an ADR. Shall I create `docs/decisions/NNNN-{topic}.md`?"

If the user agrees, use the `/adr-create` command or scaffold the ADR manually following the MADR template from the `documentation-patterns` skill. Link the GitHub Discussion in the ADR's Links section.

### 6. Present the Synthesis

Display the synthesis to the user and confirm:
- Posted to Discussion #$1
- Stored in memory (if mem0 configured)
- Discussion URL for reference
- Whether an ADR should be created

## Example Output

```
Deliberation concluded on Discussion #123

Synthesis posted: https://github.com/owner/repo/discussions/123#comment-xyz

Decision stored in memory:
"Architectural decision: Shared passages pattern. Decided: Use graph-theoretic 
approach with explicit outcome nodes. Discussed in Discussion #123. Key factors: 
Separates logical structure from presentation, enables better validation."

Key recommendation: [one sentence summary]
```

## Notes

- This command should be run **after** agents have had sufficient rounds to converge or clarify disagreements
- If agents are still generating new insights, consider running another `/deliberate-round` instead
- The memory storage ensures future deliberations can build on this decision
