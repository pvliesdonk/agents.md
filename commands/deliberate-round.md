---
description: Run one deliberation round (all 3 models comment on discussion)
---

# Run Deliberation Round

Execute one round of multi-agent deliberation on GitHub Discussion #$1.

## Process

Spawn all three deliberator agents **in parallel** as subtasks:

1. **@claude-deliberator**
2. **@gemini-deliberator**  
3. **@gpt-deliberator**

Pass each agent this prompt:

```
Read GitHub Discussion #$1 in this repository. 

Steps:
1. Read the full discussion including all existing comments
2. Investigate the codebase independently — read relevant files, trace implementations
3. Research externally if needed (docs, web search)
4. Post a comment to the discussion following the deliberation protocol
5. Return a summary (3-5 sentences) of your key findings and position

Remember:
- Identify yourself as [Model Name agent] in your comment
- Cite specific files and line numbers
- Challenge assumptions, propose alternatives
- Do not implement anything
```

## After All Three Complete

Collect the summaries from each agent and present them:

```
Round completed on Discussion #$1

**Claude Opus 4.6 summary:**
[agent's summary]

**Gemini 3 Pro summary:**
[agent's summary]

**GPT-5.2 summary:**
[agent's summary]

---

Review the comments at: [discussion URL]

Next steps:
- Run another round: /deliberate-round $1
- Conclude deliberation: /deliberate-summarize $1
```

## Notes

- Agents run **in parallel** — each responds to the same discussion state
- Agents do **not** share context — each investigates independently
- The GitHub Discussion is the shared state between rounds
- Each round, agents re-read the full discussion history
