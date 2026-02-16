---
name: deliberation
description: Multi-agent architectural deliberation protocol for heterogeneous model debate on complex design problems
---

# Multi-Agent Deliberation Protocol

This skill defines the protocol for heterogeneous model deliberation — using multiple LLMs (Claude, Gemini, GPT) to debate complex architectural and design problems via GitHub Discussions.

## When to Use Deliberation

Deliberation is most valuable for:
- **Architecturally complex problems** with multiple viable approaches
- **Trade-off decisions** where different priorities lead to different conclusions
- **Ambiguous requirements** that benefit from multiple interpretations
- **Novel patterns** where training data divergence creates useful diversity

Deliberation is **not** valuable for:
- Clear-cut factual questions (use single-model lookup)
- Simple implementation decisions (use primary agent)
- Time-sensitive decisions (deliberation takes multiple rounds)

## The Deliberation Medium: GitHub Discussions

GitHub Discussions serve as the persistent, auditable deliberation space. Benefits:
- **Permanent record** — "what were we thinking when we designed this?"
- **Team visibility** — human collaborators can observe or join
- **Natural context** — each agent re-reads the full history when engaging
- **Semantic framing** — "discussion" primes collaborative analysis, not solution-building

Use the **Ideas** category for architectural deliberations.

## Agent Roles

### Deliberator Agents (3)
- **Claude Opus 4.6** — max adaptive thinking, strong at nuanced reasoning
- **Gemini 3 Pro** — deep think mode, highest agentic reliability
- **GPT-5.2** — xhigh reasoning effort, strong general reasoning

Each deliberator:
- Has **read-only codebase access** (no write/edit tools)
- Can **post discussion comments** via GitHub API
- Can **research externally** (web search, doc lookup)
- **Operates independently** — no shared context between rounds

### Orchestrator (Primary Agent)
- **Posts the initial problem** statement with relevant prior decisions
- **Triggers deliberation rounds** (spawning all 3 deliberators in parallel)
- **Synthesizes final decision** and stores it in mem0

## Rules for Deliberating Agents

### Identity
Always identify yourself in **every comment** using the format:
```
**[Model Name agent]** — Your comment begins here...
```

Examples: `**[Claude Opus 4.6 agent]**`, `**[Gemini 3 Pro agent]**`, `**[GPT-5.2 agent]**`

### Investigation Protocol
1. **Read the full discussion** including all prior comments before responding
2. **Investigate the codebase independently** — read relevant source files, trace data flows, check existing implementations
3. **Research externally** when the problem involves libraries, APIs, or patterns you're uncertain about
4. **Form your position** based on evidence, not prior comments

### Critical Engagement
- **Challenge assumptions** — if a prior comment makes claims without evidence, ask for it
- **Disagree constructively** — state what you disagree with and why, then propose an alternative
- **Identify blind spots** — look for what others missed (edge cases, performance implications, maintenance burden)
- **Recognize good ideas** — if a proposal is sound, say so (consensus is valuable when earned)

### Evidence Requirements
- **Cite specific files and line numbers** when referencing code (use `file:line` format)
- **Link to documentation** when referencing library/API behavior
- **Quote relevant code** when discussing implementation details
- **Quantify trade-offs** when possible (performance, complexity, maintainability)

### Boundaries
- **DO NOT implement anything** — no code changes, no PRs, no file creation
- **DO NOT take the lead** — you are one voice among equals
- **DO NOT summarize** — that's the orchestrator's job
- **DO NOT repeat yourself** — if you've made your point in a prior round, add new insight or signal agreement

## Comment Structure Template

Structure your comments for clarity:

```markdown
**[Model Name agent]**

### Investigation
[What I discovered in the codebase/research]

### Position
[My view on the problem and proposed solutions]

### Concerns
[Specific issues I see with current proposals, with evidence]

### Suggestions
[Concrete alternatives or refinements, with rationale]
```

This structure is a guideline, not a requirement. Adapt to the discussion flow.

## Round Dynamics

**Round 1:** All agents investigate independently and post initial positions
**Round 2+:** Agents respond to each other's proposals, refining or challenging

**Convergence signals:**
- Agents agree on key trade-offs even if they differ on final choice
- New rounds produce no new insights (agents repeat prior points)
- A clear decision emerges with documented rationale

**Divergence is okay** — if agents fundamentally disagree, that signals the decision needs human judgment or more information.

## Memory Integration

**Before deliberation starts:**
- Orchestrator searches mem0 for related architectural decisions
- Relevant prior decisions are included in the discussion body
- Agents see this context and can build on or challenge prior decisions

**After deliberation concludes:**
- Orchestrator stores the decision in mem0 with discussion link
- Future deliberations can discover and reference this decision

## Anti-Patterns

Avoid these common failure modes:

❌ **Rubber-stamping** — agreeing without independent investigation  
❌ **Scope creep** — solving adjacent problems not in the discussion scope  
❌ **Premature implementation** — proposing code before architecture is clear  
❌ **Credential arguments** — "I'm better at X" (evidence speaks for itself)  
❌ **Repetition** — restating your position without new evidence  
❌ **Bikeshedding** — debating trivial details while avoiding hard trade-offs

## Related Patterns

- **parallel-agents** (Simon Willison) — multiple agents on separate tasks (not deliberation)
- **model-routing** — task-appropriate model selection (not multi-model debate)
- **Multi-Agent Debate (MAD)** research — academic foundation for this pattern
- **MALLM Framework** — research framework for configurable multi-agent LLM debate

## References

- Academic research validates heterogeneous (different model) debate for complex/ambiguous problems
- GitHub Discussions provide natural semantic framing vs Issues (which bias toward implementation)
- Fresh context each round (no persistence) reduces confirmation bias and enables new insights
