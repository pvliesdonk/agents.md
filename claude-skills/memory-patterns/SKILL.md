---
name: memory-patterns
description: mem0 integration patterns — when to use memory, hook-based auto-capture, scoping strategy, and practical examples per agent type
---

**Load this skill when working with persistent memory or setting up memory automation.**

## Overview

mem0 provides persistent memory across sessions through an MCP server. Memories are shared across all agents (user_id scope by default) and survive context compaction, session restarts, and even project switches.

## When to Use Memory

### Proactive Memory Usage (Recommended)

Store information that should persist across sessions:
- **Architectural decisions** with rationale (prevents re-explaining choices)
- **User preferences** discovered during conversation (code style, naming conventions)
- **Project-specific patterns** (test structure, deployment process)
- **Effective solutions** to recurring problems
- **Performance observations** (which models work best for what tasks)

### Reactive Memory Usage

Search memories when:
- User asks "what did we decide about X?"
- Starting work on a familiar project
- You notice recurring questions/patterns
- Before proposing architectural changes (check for prior decisions)

## Hook-Based Auto-Capture

Use hooks to automatically capture memories at key points. Reference implementations available in `.claude/hooks/examples/` (copy and customize).

### PostToolUse Pattern - Capture Code Style

After Edit/Write operations, extract code style preferences:

```yaml
PostToolUse:
  - matcher: "Edit|Write"
    hooks:
      - type: command
        command: "$CLAUDE_PROJECT_DIR/.claude/hooks/examples/capture-code-style.sh"
```

**What it captures**:
- Indentation preferences (tabs vs spaces)
- Import organization patterns
- Naming conventions observed
- Testing patterns

### PreCompact Pattern - Preserve Critical Context

Before context compaction, save important information that would be lost:

```yaml
PreCompact:
  - hooks:
      - type: command
        command: "$CLAUDE_PROJECT_DIR/.claude/hooks/examples/preserve-context.sh"
```

**What it captures**:
- Key architectural decisions from current session
- Unresolved issues flagged for follow-up
- Performance insights discovered
- User preferences expressed

### SessionEnd Pattern - Session Summary

At session end, create searchable summary:

```yaml
SessionEnd:
  - hooks:
      - type: command
        command: "$CLAUDE_PROJECT_DIR/.claude/hooks/examples/session-summary.sh"
```

**What it captures**:
- Tasks completed
- Decisions made
- Problems solved
- Patterns observed

### Stop Pattern - Conversational Insights

After each agent response, optionally extract insights:

```yaml
Stop:
  - hooks:
      - type: command
        command: "$CLAUDE_PROJECT_DIR/.claude/hooks/examples/conversation-insights.sh"
```

**Use sparingly** - fires frequently. Best for:
- High-value architectural discussions
- User feedback on agent performance
- Explicit preference statements

## Memory Scoping Strategy

**Default scope**: `user_id` (shared across all agents)

```python
# Add memory (visible to all agents)
mem0_add_memory(
    text="User prefers functional components over class components in React",
    user_id="default"  # Shared across agents
)

# Search memories (all agents can find this)
mem0_search_memories(
    query="React component preferences"
)
```

**When to use agent_id scope**:
- Agent-specific performance data
- Agent-specific learned behaviors
- When explicitly isolating agent memories

```python
# Agent-specific memory
mem0_add_memory(
    text="@llm-engineer: qwen3:4b performs better than llama3.3:8b for structured output on this project",
    agent_id="llm-engineer"
)
```

## Memory Hygiene

**When to delete**:
- Outdated architectural decisions (mark old, store new)
- Obsolete preferences (user changed their mind)
- Project-specific memories when project ends

```python
# Clean up outdated memories
mem0_delete_all_memories(user_id="default")  # Nuclear option
mem0_delete_memory(memory_id="specific_id")  # Surgical removal
```

**When to update**:
- Refining existing preferences
- Correcting misunderstood patterns

```python
mem0_update_memory(
    memory_id="abc123",
    text="Updated: User prefers 88-char line length (not 80)"
)
```

## Agent-Specific Patterns

### @architect
**Store**: Architectural decisions, design trade-offs, refactoring strategies
**Search**: Before proposing major structural changes
**Example**: "We chose SQLAlchemy over raw SQL for maintainability despite performance cost"

### @llm-engineer
**Store**: Model performance observations, effective prompt patterns, provider quirks
**Search**: Before choosing models or designing prompts
**Example**: "Small models (4B) outperform 8B on structured output with constrained generation"

### @prompt-engineer
**Store**: Successful prompt templates, few-shot examples that worked
**Search**: When designing new prompts for similar tasks
**Example**: "Chain-of-thought prompting reduces hallucination for small models on this task"

### @security-reviewer
**Store**: Security patterns found in codebase, vulnerabilities discovered, fixes applied
**Search**: Before auditing similar code
**Example**: "This project uses cryptography library for password hashing, not bcrypt"

### @github-ops
**Store**: PR merge patterns, team reviewer preferences, CI/CD quirks
**Search**: Before creating PRs or releases
**Example**: "Team prefers squash merges, always tag @reviewer-name for API changes"

### @frontend-dev
**Store**: UI/UX decisions, user feedback, component patterns
**Search**: Before implementing similar UI features
**Example**: "User prefers spinner over progress bar for indeterminate operations"

## Anti-Patterns

❌ **Don't store ephemeral state** (current file contents, temporary variables)
❌ **Don't duplicate information** already in AGENTS.md or project docs
❌ **Don't store too frequently** (creates noise, use PreCompact instead)
❌ **Don't forget to search** before storing similar information
✅ **Do store decisions with context** (why, not just what)
✅ **Do use descriptive memory text** (searchable, specific)
✅ **Do review memories periodically** (delete outdated information)
