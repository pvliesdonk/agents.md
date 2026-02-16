---
name: documentation-patterns
description: "ADR templates, API documentation standards, technical writing voice, changelog patterns, and code comment guidelines"
---

# Documentation Patterns

## Architecture Decision Records (ADRs)

### Purpose

ADRs capture significant architectural decisions with their context, rationale, and consequences. They answer "what were we thinking when we designed this?"

### Location and Naming

- **Path:** `docs/decisions/NNNN-short-title.md`
- **Numbering:** Sequential, zero-padded to 4 digits (0001, 0002, ...)
- **Title:** Short noun phrase describing the decision
- **Examples:**
  - `docs/decisions/0001-use-langgraph-for-agent-orchestration.md`
  - `docs/decisions/0002-adopt-dual-model-strategy.md`
  - `docs/decisions/0003-github-discussions-for-deliberation.md`

### Status Lifecycle

```
Proposed → Accepted → [Deprecated | Superseded by NNNN]
```

- **Proposed:** Under discussion, not yet decided
- **Accepted:** Decision made and active
- **Deprecated:** No longer relevant (technology removed, feature deleted)
- **Superseded:** Replaced by a newer decision (link to the new ADR)

### Immutability Rule

Never edit an accepted ADR. If a decision changes:
1. Create a new ADR with the updated decision
2. Set the old ADR's status to "Superseded by [NNNN](link)"
3. Reference the old ADR in the new one's context section

### When to Create ADRs

| Situation | Create ADR? |
|-----------|-------------|
| New library/framework adoption | Yes |
| Architectural pattern change | Yes |
| Deliberation outcome (`/deliberate-summarize`) | Yes — link the Discussion |
| Bug fix | No |
| Minor refactoring | No |
| New feature (standard pattern) | No |
| New feature (novel approach) | Yes |
| Changing an existing ADR | Yes — supersede |

### MADR Template

```markdown
# NNNN. Short Decision Title

## Status

Proposed | Accepted | Deprecated | Superseded by [NNNN](NNNN-short-title.md)

## Context and Problem Statement

What is the issue that we're seeing that motivates this decision?

## Decision Drivers

- [driver 1]
- [driver 2]

## Considered Options

1. Option A
2. Option B
3. Option C

## Decision Outcome

Chosen: **Option B**, because [justification].

### Consequences

- Good: [positive]
- Bad: [negative]
- Neutral: [trade-off]

## Links

- Discussion: [#N](url) — if from deliberation
- PR: [#N](url) — implementing PR
- Related: [NNNN](path) — related ADRs
```

## API Documentation Standards

### Google-Style Docstrings

Every public function, method, and class must have a docstring:

```python
def function_name(param1: Type, param2: Type = default) -> ReturnType:
    """One-line summary (imperative mood).

    Extended description if needed. Explain non-obvious behavior,
    algorithms, or side effects.

    Args:
        param1: Description of param1.
        param2: Description of param2. Defaults to X.

    Returns:
        Description of return value.

    Raises:
        SpecificError: When this specific condition occurs.

    Example:
        >>> result = function_name("input", param2=42)
        >>> assert result.status == "ok"
    """
```

### Documentation Hierarchy

1. **Module docstring:** One sentence explaining what this module does
2. **Class docstring:** Purpose, key attributes, usage example
3. **Method docstrings:** What it does, args, returns, raises
4. **Inline comments:** Only for WHY, never for WHAT

### Type Hints as Documentation

Type hints ARE documentation. Prefer:
```python
def process(items: list[Document], config: ProcessConfig) -> list[Chunk]:
```
Over vague types that require reading the docstring to understand.

## Technical Writing Voice

### Principles

1. **Precision:** Use exact terms. "Returns a list" not "gives back some items"
2. **Conciseness:** Cut filler. "The function processes X" not "This function is responsible for the processing of X"
3. **Active voice:** "The agent reads the discussion" not "The discussion is read by the agent"
4. **Present tense:** "This module handles..." not "This module will handle..."
5. **Imperative for instructions:** "Run the command" not "You should run the command"

### Audience Awareness

| Audience | Style |
|----------|-------|
| API users | Formal, complete, examples-first |
| Team developers | Concise, assume project context |
| Future self | Explain WHY, link to discussions/issues |
| New contributors | Explicit prerequisites, step-by-step |

## Code Comment Standards

### DO Comment

- **Complex algorithms:** Explain the approach and why it was chosen
- **Non-obvious constraints:** Business rules, performance trade-offs, API limitations
- **Workarounds:** Link to the issue/bug that necessitated the workaround
- **Decision rationale:** Link to ADR or Discussion when pattern is non-obvious

### DON'T Comment

- **Obvious code:** `# Increment counter` above `counter += 1`
- **What the code does:** The code already says that
- **Commented-out code:** Use version control
- **TODO without context:** `# TODO: fix this` — link an issue instead

### Linking Pattern

```python
# Workaround for LangChain issue #12345
# See: https://github.com/langchain-ai/langchain/issues/12345
# ADR: docs/decisions/0005-custom-retry-logic.md
```

## Changelog and Release Notes

### Conventional Commits → Changelog

Commits following conventional format are auto-processed by semantic-release:

| Prefix | Changelog Section | Version Bump |
|--------|-------------------|-------------|
| `feat:` | Features | Minor |
| `fix:` | Bug Fixes | Patch |
| `docs:` | (usually excluded) | None |
| `refactor:` | (usually excluded) | None |
| `BREAKING CHANGE:` | Breaking Changes | Major |

### Writing Good Commit Messages

```
feat: add multi-agent deliberation with heterogeneous models

Support architectural deliberation using Claude Opus 4.6, Gemini 3 Pro,
and GPT-5.2 in parallel rounds. Each agent independently investigates
the codebase and posts analysis to a GitHub Discussion.

Closes #42
```

- **Subject:** Imperative, lowercase, no period, under 72 chars
- **Body:** Explain WHY, not WHAT. The diff shows what changed.
- **Footer:** Reference issues, breaking changes
