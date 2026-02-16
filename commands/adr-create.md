---
description: "Create a new Architecture Decision Record with MADR template"
agent: technical-writer
subtask: true
---

Create a new Architecture Decision Record (ADR) for: $ARGUMENTS

## Steps

### 1. Find the Next ADR Number

Check the `docs/decisions/` directory for existing ADRs:
```bash
ls docs/decisions/*.md 2>/dev/null | sort | tail -1
```

If the directory doesn't exist, create it and start at 0001.
Otherwise, increment the highest existing number.

### 2. Derive the Filename

Convert the topic to a short kebab-case slug:
- "Use LangGraph for agent orchestration" → `0001-use-langgraph-for-agent-orchestration.md`
- Keep it under 60 characters

### 3. Scaffold the ADR

Create `docs/decisions/NNNN-slug.md` using the MADR template:

```markdown
# NNNN. Title Derived from Arguments

## Status

Proposed

## Context and Problem Statement

[Fill in based on $ARGUMENTS and any relevant codebase context]

## Decision Drivers

- [driver 1]
- [driver 2]

## Considered Options

1. [option 1]
2. [option 2]
3. [option 3]

## Decision Outcome

Chosen: **[pending]**, because [to be decided].

### Consequences

- Good: [pending]
- Bad: [pending]

## Links

- [Add relevant links to issues, PRs, discussions]
```

### 4. Search Memory for Context

Search mem0 for related architectural decisions that might inform this ADR:
```
Search: "architectural decision {topic keywords}"
```

If related decisions are found, reference them in the Context section or Links.

If mem0 is not available, skip this step.

### 5. Report

Tell the user:
- The ADR file path created
- The ADR number assigned
- Any related prior decisions found
- Remind them to fill in the Considered Options and Decision Outcome sections
