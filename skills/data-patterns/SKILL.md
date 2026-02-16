---
name: data-patterns
description: RAG data pipeline patterns — chunking strategies, vector store selection, embedding optimization, data validation, schema evolution, and evaluation metrics
---

# Data Patterns

Reference patterns for building production RAG pipelines and data-intensive LLM applications.

## RAG Chunking Strategies

### Fixed-Size Chunking
```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,        # tokens, not chars — measure with tiktoken
    chunk_overlap=64,      # 10-15% overlap prevents broken context
    separators=["\n\n", "\n", ". ", " ", ""],
    length_function=len,   # replace with token counter for accuracy
)
```
**When:** Uniform documents, simple retrieval. Fast, predictable.

### Semantic Chunking
```python
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings

chunker = SemanticChunker(
    OpenAIEmbeddings(),
    breakpoint_threshold_type="percentile",  # or "standard_deviation", "interquartile"
    breakpoint_threshold_amount=95,
)
```
**When:** Mixed-format documents where topic boundaries matter more than size.

### Document-Aware Chunking
```python
# For structured documents (markdown, HTML, code)
from langchain.text_splitter import MarkdownHeaderTextSplitter

headers_to_split_on = [
    ("#", "h1"), ("##", "h2"), ("###", "h3"),
]
splitter = MarkdownHeaderTextSplitter(headers_to_split_on=headers_to_split_on)
# Preserves header hierarchy as metadata on each chunk
```
**When:** Documentation, technical manuals, code files with clear structure.

### Chunking Decision Matrix

| Document Type | Strategy | Chunk Size | Overlap |
|--------------|----------|-----------|---------|
| Prose / articles | Recursive | 512-1024 tokens | 10% |
| Technical docs | Markdown-aware | Natural sections | Headers as metadata |
| Code files | Language-aware (tree-sitter) | Function/class level | Imports as context |
| Chat logs | Fixed by message/turn | 1 turn or 3-5 turns | 1 turn overlap |
| Legal / contracts | Semantic | Variable | 15% (precision matters) |

## Vector Store Selection

### When to Use Each

| Store | Best For | Hosted? | Filtering | Scale |
|-------|---------|---------|-----------|-------|
| **Chroma** | Prototyping, small datasets (<100K docs) | Local | Basic metadata | Single node |
| **pgvector** | Already using PostgreSQL, need ACID | Self-hosted | Full SQL | Medium (1M) |
| **Qdrant** | Production, rich filtering, hybrid search | Both | Advanced payload filters | Large (100M+) |
| **Pinecone** | Managed, zero-ops, enterprise | Cloud only | Metadata filters | Large |
| **Weaviate** | Multimodal, graph-like queries | Both | GraphQL | Large |
| **FAISS** | Offline/batch, maximum speed | Local only | None (add yourself) | Very large |

### Embedding Model Selection

```python
# Small + fast (local, good for prototyping)
# ~384 dimensions, ~50M params
from sentence_transformers import SentenceTransformer
model = SentenceTransformer("all-MiniLM-L6-v2")

# Medium (cloud, balanced cost/quality)
# ~1536 dimensions
from langchain_openai import OpenAIEmbeddings
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")

# Large (cloud, maximum quality)
# ~3072 dimensions, configurable
embeddings = OpenAIEmbeddings(
    model="text-embedding-3-large",
    dimensions=1024,  # reduce dimensions for cost/speed trade-off
)
```

**Cost optimization:** Use `text-embedding-3-small` for development, `text-embedding-3-large` with reduced dimensions for production. Benchmark YOUR data — generic benchmarks don't reflect domain-specific performance.

## Data Validation

### Document Validation with Pydantic

```python
from pydantic import BaseModel, field_validator
from typing import Literal

class ChunkedDocument(BaseModel):
    content: str
    source: str
    chunk_index: int
    total_chunks: int
    metadata: dict

    @field_validator("content")
    @classmethod
    def content_not_empty(cls, v: str) -> str:
        if len(v.strip()) < 10:
            raise ValueError(f"Chunk content too short: {len(v)} chars")
        return v

    @field_validator("chunk_index")
    @classmethod
    def valid_index(cls, v: int, info) -> int:
        if "total_chunks" in info.data and v >= info.data["total_chunks"]:
            raise ValueError(f"chunk_index {v} >= total_chunks {info.data['total_chunks']}")
        return v
```

### DataFrame Validation with Pandera

```python
import pandera as pa
from pandera.typing import DataFrame, Series

class EmbeddingSchema(pa.DataFrameModel):
    document_id: Series[str] = pa.Field(nullable=False, unique=True)
    content: Series[str] = pa.Field(str_length={"min_value": 10})
    embedding: Series[object]  # numpy array
    source: Series[str] = pa.Field(isin=["web", "pdf", "api", "manual"])
    created_at: Series[pa.DateTime]

    class Config:
        strict = True
        coerce = True

@pa.check_types
def process_embeddings(df: DataFrame[EmbeddingSchema]) -> DataFrame[EmbeddingSchema]:
    # Pandera validates input and output automatically
    ...
```

## Schema Evolution

### Versioned Embedding Schemas

```python
from pydantic import BaseModel
from typing import Any
from datetime import datetime

class DocumentSchemaV1(BaseModel):
    """Original schema."""
    content: str
    source: str
    embedding: list[float]

class DocumentSchemaV2(BaseModel):
    """Added metadata and chunk info."""
    content: str
    source: str
    embedding: list[float]
    metadata: dict[str, Any] = {}
    chunk_index: int = 0
    schema_version: int = 2

def migrate_v1_to_v2(doc: DocumentSchemaV1) -> DocumentSchemaV2:
    """Migration function — run as batch job, not on-read."""
    return DocumentSchemaV2(
        content=doc.content,
        source=doc.source,
        embedding=doc.embedding,
        metadata={"migrated_from": "v1", "migrated_at": datetime.now().isoformat()},
        chunk_index=0,
        schema_version=2,
    )
```

**Rules:**
1. Always add a `schema_version` field
2. New fields must have defaults (backward compatible)
3. Never remove fields — deprecate with migration
4. Re-embed when changing embedding model (don't mix dimensions)
5. Migration is a batch job, not a read-time operation

## RAG Evaluation

### Retrieval Metrics

```python
def recall_at_k(retrieved_ids: list[str], relevant_ids: set[str], k: int) -> float:
    """What fraction of relevant docs appear in top-k results?"""
    top_k = set(retrieved_ids[:k])
    return len(top_k & relevant_ids) / len(relevant_ids) if relevant_ids else 0.0

def mrr(retrieved_ids: list[str], relevant_ids: set[str]) -> float:
    """Mean Reciprocal Rank — how high is the first relevant result?"""
    for i, doc_id in enumerate(retrieved_ids, 1):
        if doc_id in relevant_ids:
            return 1.0 / i
    return 0.0

def ndcg_at_k(retrieved_ids: list[str], relevance_scores: dict[str, float], k: int) -> float:
    """Normalized Discounted Cumulative Gain — accounts for graded relevance."""
    import math
    dcg = sum(
        relevance_scores.get(doc_id, 0.0) / math.log2(i + 2)
        for i, doc_id in enumerate(retrieved_ids[:k])
    )
    ideal = sorted(relevance_scores.values(), reverse=True)[:k]
    idcg = sum(score / math.log2(i + 2) for i, score in enumerate(ideal))
    return dcg / idcg if idcg > 0 else 0.0
```

### End-to-End RAG Evaluation

```python
# Using ragas or similar framework
eval_dataset = [
    {
        "question": "What is the refund policy?",
        "ground_truth": "Full refund within 30 days of purchase.",
        "contexts": [...],  # retrieved chunks
        "answer": "...",     # LLM-generated answer
    },
]

# Key metrics:
# - Faithfulness: Does the answer stay faithful to retrieved context?
# - Answer relevance: Does the answer actually address the question?
# - Context precision: Are retrieved chunks relevant to the question?
# - Context recall: Did retrieval find all necessary information?
```

## Anti-Patterns

1. **Chunking without measuring** — Always evaluate retrieval quality after changing chunking strategy
2. **One embedding model for all** — Code, prose, and structured data need different embedding approaches
3. **Skipping validation** — Garbage in, garbage out. Validate documents before embedding
4. **Mixing embedding dimensions** — Never store vectors from different models in the same index
5. **Read-time migration** — Schema changes should be batch operations, not on-the-fly
6. **Ignoring metadata** — Rich metadata enables filtering, reducing the search space dramatically
7. **Over-chunking** — More chunks != better retrieval. Measure recall@k, not just chunk count
