---
name: prompt-craft
description: Prompt engineering techniques for dual-model systems — template structure, few-shot design, structured output prompting, model-adaptive strategies for both small (4B-8B) and large (GPT-5, Claude) models
---

## Prompt Scaffold

```
[ROLE]        Who the model is / expertise
[CONTEXT]     Background, domain constraints
[TASK]        One clear instruction
[FORMAT]      Output structure with example
[CONSTRAINTS] Boundaries, edge cases, what to avoid
[EXAMPLES]    Few-shot demonstrations (if needed)
```

Claude: use XML tags. GPT: markdown headers. Small models: minimal structure, maximum explicitness.

## Dual-Model Adaptation

### For Small Models (4B-8B Ollama)
- **Max 1000 tokens** prompt length. Cut ruthlessly.
- **One task per prompt**. No compound instructions.
- **Complete worked example** is mandatory — the model mimics format.
- Every enum value listed explicitly: `quality: one of "excellent", "good", "fair", "poor"`
- **No chain-of-thought** unless tested (often hurts structured output).
- Positive instructions: "Write X" not "Don't do Y."
- **Sandwich**: format spec at start AND end.

### For Large Models (GPT-5, Claude)
- Multi-section prompts with nuanced instructions.
- `<thinking>` tags for chain-of-thought (Claude).
- Few-shot optional — large models generalize from descriptions.
- Can handle "Don't X unless Y" conditional constraints.
- System prompt for persona, user prompt for task.

## Few-Shot Design

- **3-5 examples**. More than 7 has diminishing returns.
- Include at least one **edge case** example.
- Show **reasoning**, not just input→output.
- Order: easy → medium → edge case.
- For small models: examples are the prompt. They define the contract.

## Structured Output

1. Provide the **exact schema** with field descriptions.
2. Include a **complete worked example** (JSON, ready to copy).
3. Specify handling for missing/ambiguous fields.
4. For enums, list ALL valid values in the prompt.
5. Show good AND bad examples for critical fields:

```
## Dilemma ID Naming (CRITICAL)
GOOD: `host_benevolent_or_self_serving`
BAD: `host_motivation`
```

## Defensive Patterns

- **Sandwich**: Repeat critical instructions at start and end.
- **Validate → Feedback → Repair**: Validate output, format structured errors, ask model to fix.
- **Discuss → Freeze → Serialize**: Separate exploration from structured output generation.
- **Anti-pleasantry**: "Do NOT end with 'Good luck!' or similar."

## Systematic Testing

1. Define success criteria before iterating.
2. Test set of 10-20 diverse inputs including edge cases.
3. Change one thing at a time.
4. Track: prompt version, model, temperature, pass rate, failure modes.
5. Failure taxonomy: wrong format, hallucination, refusal, partial output, off-topic.
