---
name: observability-patterns
description: "structlog setup, LLM monitoring, OpenTelemetry, Prometheus metrics, PII redaction, cost tracking, and dual-model observability"
---

# Observability Patterns

## Structured Logging with structlog

### Setup
```python
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
        structlog.processors.TimeStamper(fmt="iso"),
        # PII redaction MUST be before JSON rendering
        pii_redactor,
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)
```

### Bound Loggers with Context
```python
log = structlog.get_logger()

# Bind context that persists across log calls
log = log.bind(
    request_id=request_id,
    user_id=user_id,
    model=model_name,
)

log.info("chain.started", chain_name="qa_retrieval", query_length=len(query))
# ... chain executes ...
log.info("chain.completed", duration_ms=elapsed, tokens_used=usage.total_tokens)
```

### Context Variables (async-safe)
```python
import structlog
from contextvars import ContextVar

request_id_var: ContextVar[str] = ContextVar("request_id", default="unknown")

# Set at request boundary
structlog.contextvars.bind_contextvars(
    request_id=str(uuid4()),
    session_id=session_id,
)

# All log calls in this async context automatically include these fields
```

## PII Redaction

### structlog Processor
```python
import re

PATTERNS = {
    "email": re.compile(r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+"),
    "api_key": re.compile(r"(sk-|key-|token-)[a-zA-Z0-9]{20,}"),
    "ssn": re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
}

def pii_redactor(logger, method_name, event_dict):
    """Redact PII from all string values in log events."""
    for key, value in event_dict.items():
        if isinstance(value, str):
            for pii_type, pattern in PATTERNS.items():
                value = pattern.sub(f"[REDACTED_{pii_type.upper()}]", value)
            event_dict[key] = value
    return event_dict
```

### Prompt Logging with Redaction
```python
def log_prompt(log, prompt: str, response: str, model: str):
    """Log LLM interaction with PII-safe content."""
    log.info(
        "llm.interaction",
        model=model,
        prompt_length=len(prompt),
        prompt_preview=prompt[:100] + "..." if len(prompt) > 100 else prompt,
        response_length=len(response),
        # Never log full prompts in production — they may contain user PII
        # Use prompt_preview for debugging, full prompt only at DEBUG level
    )
    log.debug("llm.interaction.full", prompt=prompt, response=response)
```

## LLM-Specific Monitoring

### Token Tracking
```python
from dataclasses import dataclass, field
from collections import defaultdict

@dataclass
class TokenTracker:
    """Track token usage per model, per chain, per request."""
    usage: dict = field(default_factory=lambda: defaultdict(lambda: {
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "total_tokens": 0,
        "requests": 0,
    }))

    def record(self, model: str, prompt_tokens: int, completion_tokens: int):
        entry = self.usage[model]
        entry["prompt_tokens"] += prompt_tokens
        entry["completion_tokens"] += completion_tokens
        entry["total_tokens"] += prompt_tokens + completion_tokens
        entry["requests"] += 1

    def cost_estimate(self, model: str) -> float:
        """Estimate cost based on known pricing."""
        pricing = {
            "gpt-5.2": {"input": 1.75, "output": 14.00},  # per 1M tokens
            "claude-opus-4-6": {"input": 15.00, "output": 75.00},
            "gemini-3-pro": {"input": 1.25, "output": 10.00},
        }
        if model not in pricing:
            return 0.0
        entry = self.usage[model]
        rates = pricing[model]
        return (
            entry["prompt_tokens"] * rates["input"] / 1_000_000
            + entry["completion_tokens"] * rates["output"] / 1_000_000
        )
```

### Fallback Chain Monitoring
```python
def log_fallback_event(log, primary_model: str, fallback_model: str, reason: str):
    """Log when a model fallback occurs."""
    log.warning(
        "llm.fallback",
        primary_model=primary_model,
        fallback_model=fallback_model,
        reason=reason,
        # Track fallback frequency for alerting
    )

# In your chain:
try:
    result = await primary_model.ainvoke(prompt)
except (RateLimitError, TimeoutError) as e:
    log_fallback_event(log, "gpt-5.2", "claude-sonnet-4", str(e))
    result = await fallback_model.ainvoke(prompt)
```

### Dual-Model Observability
```python
def log_model_selection(log, task: str, selected_model: str, reason: str):
    """Log which model was selected for a task and why."""
    log.info(
        "model.selected",
        task=task,
        model=selected_model,
        reason=reason,
        # Enables analysis: which tasks route to which models?
    )

def log_model_comparison(log, task: str, results: dict[str, any]):
    """Log when multiple models are compared (e.g., deliberation)."""
    log.info(
        "model.comparison",
        task=task,
        models=list(results.keys()),
        agreement=_calculate_agreement(results),
    )
```

## OpenTelemetry Integration

### Setup for LLM Chains
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Initialize tracer
provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://localhost:4317"))
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("llm-pipeline")

# Instrument chain steps
async def run_chain(query: str):
    with tracer.start_as_current_span("chain.qa_retrieval") as span:
        span.set_attribute("query.length", len(query))

        with tracer.start_as_current_span("chain.retrieve"):
            docs = await retriever.ainvoke(query)
            span.set_attribute("docs.count", len(docs))

        with tracer.start_as_current_span("chain.generate") as gen_span:
            result = await llm.ainvoke(prompt)
            gen_span.set_attribute("model", result.model)
            gen_span.set_attribute("tokens.total", result.usage.total_tokens)

        return result
```

## Prometheus Metrics

### Key Metrics for LLM Systems
```python
from prometheus_client import Counter, Histogram, Gauge

# Request metrics
llm_requests_total = Counter(
    "llm_requests_total",
    "Total LLM API requests",
    ["model", "chain", "status"],
)

llm_request_duration = Histogram(
    "llm_request_duration_seconds",
    "LLM request latency",
    ["model", "chain"],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0],
)

# Token metrics
llm_tokens_used = Counter(
    "llm_tokens_used_total",
    "Total tokens consumed",
    ["model", "token_type"],  # token_type: prompt, completion
)

# Cost metrics
llm_cost_dollars = Counter(
    "llm_cost_dollars_total",
    "Estimated cost in USD",
    ["model", "chain"],
)

# Model health
llm_fallback_total = Counter(
    "llm_fallback_total",
    "Number of model fallbacks",
    ["primary_model", "fallback_model", "reason"],
)

llm_active_requests = Gauge(
    "llm_active_requests",
    "Currently in-flight LLM requests",
    ["model"],
)
```

## Error Tracking

### Sentry Integration for LLM Errors
```python
import sentry_sdk

sentry_sdk.init(
    dsn="https://...",
    traces_sample_rate=0.1,
    before_send=redact_pii_from_event,  # Reuse PII patterns
)

def handle_llm_error(error: Exception, context: dict):
    """Capture LLM errors with useful context."""
    sentry_sdk.set_context("llm", {
        "model": context.get("model"),
        "chain": context.get("chain"),
        "prompt_length": context.get("prompt_length"),
        # Never send actual prompt content to error tracking
    })
    sentry_sdk.capture_exception(error)
```

## Dashboard Patterns

### Key Grafana Panels for LLM Monitoring
1. **Request rate** — `rate(llm_requests_total[5m])` by model and status
2. **Latency P50/P95/P99** — `histogram_quantile(0.95, llm_request_duration)`
3. **Token burn rate** — `rate(llm_tokens_used_total[1h])` by model
4. **Cost accumulation** — `increase(llm_cost_dollars_total[24h])`
5. **Fallback frequency** — `rate(llm_fallback_total[1h])` — alert if > threshold
6. **Error rate** — `rate(llm_requests_total{status="error"}[5m])` / total
7. **Model selection distribution** — Pie chart of model usage across tasks
