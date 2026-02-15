---
name: langchain-patterns
description: LangChain, LangGraph, LiteLLM patterns — chain composition (LCEL), structured output across model sizes, RAG, model routing, Ollama local models, and provider-agnostic design
---

**IMPORTANT**: Always verify imports and method signatures against `langchain-docs` MCP before using. LangChain API changes frequently.

## Chain Composition (LCEL)

```python
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough, RunnableParallel
from langchain_core.output_parsers import StrOutputParser

prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a {role}."),
    ("human", "{input}")
])
chain = prompt | llm | StrOutputParser()

# Parallel execution
parallel = RunnableParallel(summary=summary_chain, keywords=keyword_chain)

# Branching
from langchain_core.runnables import RunnableBranch
branch = RunnableBranch(
    (lambda x: x["type"] == "code", code_chain),
    default_chain,
)
```

## Structured Output (Dual-Model)

```python
from pydantic import BaseModel, Field

class Entity(BaseModel):
    """Keep flat for small models. Use Field descriptions as implicit instructions."""
    name: str = Field(description="Entity name as it appears in text")
    entity_type: str = Field(description="One of: person, place, organization")
    confidence: float = Field(ge=0.0, le=1.0)

# Works across all providers (preferred)
structured = llm.with_structured_output(Entity, method="json_schema")

# For small Ollama models — force JSON mode:
from langchain_ollama import ChatOllama
small_llm = ChatOllama(model="qwen3:4b-instruct", format="json", temperature=0)
```

**Key insight**: `method="json_schema"` (JSON_MODE) works reliably across providers including Ollama. `method="function_calling"` (TOOL) can return None for complex schemas on small models.

## LiteLLM Routing

```python
# Via LiteLLM proxy (preferred for multi-model setups)
from langchain_openai import ChatOpenAI
llm = ChatOpenAI(base_url="http://litellm-proxy:4000", model="claude-sonnet-4-20250514")

# Direct with fallbacks
from litellm import completion
response = completion(
    model="claude-sonnet-4-20250514",
    messages=messages,
    fallbacks=["gpt-4o", "ollama/qwen3:8b"],
)
```

## Ollama / Local Models

```python
from langchain_ollama import ChatOllama

llm = ChatOllama(
    model="qwen3:4b-instruct",
    base_url="http://ollama:11434",
    temperature=0,
    format="json",       # Essential for structured output on small models
    # num_ctx=8192,      # Set explicitly if needed
)
```

Key insights for local models:
- 4B instruct models can outperform 8B+ on structured tasks with constrained generation.
- Disable thinking mode for structured output.
- Monitor VRAM: concurrent requests cause OOM.
- Use instruct-tuned variants, never base models.

## LangGraph (Stateful Workflows)

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict

class State(TypedDict):
    input: str
    draft: str
    iteration: int

graph = StateGraph(State)
graph.add_node("generate", generate_node)
graph.add_node("review", review_node)
graph.set_entry_point("generate")
graph.add_conditional_edges("review", should_revise, {"revise": "generate", "accept": END})
app = graph.compile()
```

## Common Pitfalls

- Don't use LangChain when a simple API call suffices.
- Always set `max_tokens` explicitly.
- Handle `OutputParserException` — structured output fails sometimes.
- Use callbacks or LangSmith for observability.
- Cache deterministic calls (temp=0, same input).
- **Never assume LangChain imports are stable** — always verify against docs.
