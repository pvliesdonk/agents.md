---
name: python-patterns
description: Python 3.11+ best practices — typing, project structure, error handling, async patterns, testing with pytest, Pydantic configuration, and packaging with uv
---

## Project Structure (src layout)

```
project/
├── src/project_name/
│   ├── __init__.py        # Public API exports
│   ├── domain/            # Core logic (no IO)
│   │   ├── models.py      # Dataclasses/Pydantic
│   │   └── services.py    # Pure business rules
│   ├── infra/             # IO, external services
│   ├── config.py          # Pydantic Settings
│   └── cli.py             # typer entry points
├── tests/
│   ├── conftest.py
│   ├── unit/
│   └── integration/
├── pyproject.toml         # Single source of truth (uv)
└── Dockerfile
```

## Typing (3.11+)

```python
def process(items: list[str], config: dict[str, int] | None = None) -> bool: ...

from typing import Protocol, runtime_checkable

@runtime_checkable
class Serializable(Protocol):
    def to_dict(self) -> dict[str, Any]: ...

type JsonDict = dict[str, Any]
type Result[T] = tuple[T, None] | tuple[None, str]
```

## Error Handling

```python
class PipelineError(Exception):
    def __init__(self, stage: str, message: str, cause: Exception | None = None):
        super().__init__(f"[{stage}] {message}")
        self.stage = stage
        self.__cause__ = cause

# Structured logging for errors (structlog)
log.exception("pipeline_failed", stage=stage, input_id=item.id)
```

## Async Patterns (3.11+)

```python
# Semaphore for rate limiting
sem = asyncio.Semaphore(10)
async def rate_limited(item):
    async with sem:
        return await process(item)

# TaskGroup for structured concurrency
async with asyncio.TaskGroup() as tg:
    task1 = tg.create_task(fetch_data())
    task2 = tg.create_task(process_data())

# Gather with error isolation
results = await asyncio.gather(*tasks, return_exceptions=True)
successes = [r for r in results if not isinstance(r, Exception)]
```

## Configuration (Pydantic Settings)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

class AppConfig(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="APP_", env_file=".env")
    db_url: str = Field(description="Database connection string")
    debug: bool = False
    workers: int = Field(default=4, ge=1, le=32)
```

## Testing

- `pytest` with fixtures. Parametrize for edge cases.
- `pytest-asyncio` (auto mode) for async tests.
- Separate unit (fast, no IO) from integration (slow, real services).
- Prefer fakes over mocks. Mock at the boundary, not deep inside.
- `time-machine` for time-dependent tests.
- **Never run full suite locally without permission** — CI's job.

## Packaging (uv)

```bash
uv init --lib           # New library project
uv add pydantic         # Add dependency
uv run pytest           # Run in project venv
uv build                # Build wheel + sdist
uv tool install ruff    # Install CLI tool globally
```
