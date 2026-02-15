---
name: dual-model-strategy
description: Design patterns for LLM systems targeting both small local models (Ollama 4B-8B) and large cloud models (GPT-5, Claude Sonnet/Opus) — schema design, prompt adaptation, provider abstraction, testing strategy, and cost optimization
---

## The Core Challenge

The same pipeline must produce acceptable results on a 4B Ollama model AND GPT-5. Design for the constraint (small model), then let large models excel naturally.

## Model Capability Matrix

| Capability | 4B-8B (Ollama) | GPT-4o / Sonnet | GPT-5 / Opus |
|-----------|----------------|-----------------|--------------|
| Structured output | Needs `format="json"` | `with_structured_output()` | Reliable |
| Schema complexity | Flat, <10 fields | Moderate nesting | Deep nesting OK |
| Tool use | 1-3 tools max | 5-10 tools | 10+ tools |
| Context window | 4K-8K practical | 128K | 200K+ |
| Chain-of-thought | Often hurts | Helps | Helps significantly |
| Temperature sweet spot | 0 | 0-0.3 | 0-0.5 |
| Prompt budget | <1000 tokens | <4000 tokens | <8000 tokens |

## Schema Design for Dual-Model

```python
from pydantic import BaseModel, Field

# GOOD: Flat schema, descriptive fields, inline enum values
class ExtractedEntity(BaseModel):
    name: str = Field(description="Entity name as it appears in text")
    entity_type: str = Field(description="e.g., person, organization, location, event")
    confidence: float = Field(ge=0.0, le=1.0, description="Extraction confidence score")
    tags: list[str] = Field(description="1-4 relevant tags", min_length=1, max_length=4)

# BAD: Deeply nested, complex types, ambiguous fields
class ExtractedEntity(BaseModel):
    metadata: MetadataBlock           # Nesting = failure on small models
    attributes: dict[str, list[Any]]  # dict[str, list] confuses small models
```

### Rules
- Keep schemas flat (max 1 level of nesting).
- Use `str` with description + examples over `Literal`/`Enum` for fields LLMs generate.
- Set `min_length=1` on required strings to catch empty values.
- Use `list[str]` with min/max length, not unbounded lists.
- Provide field descriptions that double as prompt instructions.

## Prompt Adaptation Pattern

```python
def build_prompt(task: str, model_size: str) -> str:
    """Adapt prompt complexity to model capability."""
    core = TASK_TEMPLATES[task]  # Shared task definition

    if model_size == "small":
        # Strip reasoning instructions, add rigid format spec
        return f"{FORMAT_SPEC}\n\n{core}\n\n{WORKED_EXAMPLE}\n\n{FORMAT_SPEC}"
    else:
        # Add nuance, allow exploration
        return f"{SYSTEM_CONTEXT}\n\n{core}\n\n{CONSTRAINTS}\n\n{FORMAT_SPEC}"
```

## Provider Abstraction

```python
# Phase-specific provider selection
providers:
  default: ollama/qwen3:4b-instruct      # Cheap default
  discuss: ollama/qwen3:4b-instruct      # Tool-enabled exploration
  summarize: openai/gpt-4o              # Narrative quality
  serialize: openai/o1-mini             # Structured output accuracy
```

Precedence: CLI flag → env var → project config → default

## Testing Strategy

### Unit Tests (model-agnostic)
- Test schema validation with hand-crafted fixtures.
- Test prompt template rendering.
- Test tool result parsing.
- No LLM calls. Fast. Free.

### Smoke Tests (per model class)
- Run each stage with 1 representative input per model size.
- Assert: output parses, required fields present, no validation errors.
- Expensive. Run selectively.

### Benchmarking
- Test set of 10-20 inputs per stage.
- Metrics: parse success rate, field accuracy, token cost, latency.
- Compare across models. Track regressions.
- **Key finding**: Smaller models can outperform larger ones on structured tasks when using constrained generation.

## Cost Optimization

- Use small models for exploration/iteration during development.
- Use large models only for final quality and hard tasks (summarization, complex reasoning).
- Cache deterministic calls (temp=0, same prompt hash).
- Batch related calls where possible.
- Monitor token usage per stage via structlog.

## Fallback Chains

```python
# Progressive fallback: try cheap → expensive
fallback_order = [
    "ollama/qwen3:4b-instruct",   # Free, fast
    "ollama/llama3.3:8b",         # Free, better quality
    "openai/gpt-4o-mini",         # Cheap cloud
    "openai/gpt-4o",              # Full cloud
    "anthropic/claude-sonnet",     # Alternative cloud
]
```

Design validation to detect when a small model's output is unusable, then escalate to the next tier automatically.
