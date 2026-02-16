---
name: testing-patterns
description: "pytest patterns, fixtures, mocking, property-based testing, async tests, coverage analysis, and LLM-specific testing strategies"
---

# Testing Patterns

## Pytest Configuration

### pyproject.toml
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks integration tests",
    "e2e: marks end-to-end tests",
    "llm: marks tests that call LLM APIs (real or mocked)",
]
filterwarnings = [
    "error",
    "ignore::DeprecationWarning:some_library.*",
]
```

### Coverage Configuration
```toml
[tool.coverage.run]
branch = true
source = ["src"]
omit = ["tests/*", "*/migrations/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.",
    "@overload",
]
```

## Fixture Patterns

### Scoped Fixtures
```python
import pytest

@pytest.fixture(scope="session")
def db_engine():
    """One engine for the entire test session."""
    engine = create_engine("sqlite:///:memory:")
    yield engine
    engine.dispose()

@pytest.fixture(scope="function")
def db_session(db_engine):
    """Fresh transaction per test, rolled back after."""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

### Factory Fixtures
```python
@pytest.fixture
def make_user(db_session):
    """Factory fixture for creating test users."""
    created = []
    def _make_user(name="test", email=None, **kwargs):
        email = email or f"{name}@test.com"
        user = User(name=name, email=email, **kwargs)
        db_session.add(user)
        db_session.flush()
        created.append(user)
        return user
    yield _make_user
    for user in created:
        db_session.delete(user)
```

### Tmp Path Fixtures
```python
@pytest.fixture
def config_dir(tmp_path):
    """Temporary config directory with default files."""
    config = tmp_path / "config"
    config.mkdir()
    (config / "settings.yaml").write_text("debug: true\n")
    return config
```

## Mocking Patterns

### LLM API Mocking
```python
@pytest.fixture
def mock_llm_response(mocker):
    """Mock LLM API with realistic response structure."""
    def _mock(content="test response", tokens=50, model="gpt-4"):
        mock = mocker.patch("litellm.completion")
        mock.return_value = MockResponse(
            choices=[MockChoice(message=MockMessage(content=content))],
            usage=MockUsage(
                prompt_tokens=tokens,
                completion_tokens=tokens * 2,
                total_tokens=tokens * 3,
            ),
            model=model,
        )
        return mock
    return _mock


def test_llm_chain_returns_parsed(mock_llm_response):
    mock_llm_response(content='{"name": "test", "score": 42}')
    result = my_chain.invoke({"query": "test"})
    assert result.name == "test"
    assert result.score == 42
```

### Structured Output Mocking
```python
@pytest.fixture
def mock_structured_output(mocker):
    """Mock with_structured_output for Pydantic models."""
    def _mock(model_class, **field_values):
        instance = model_class(**field_values)
        mock_chain = mocker.MagicMock()
        mock_chain.invoke.return_value = instance
        return mock_chain
    return _mock
```

### Environment Mocking
```python
def test_loads_api_key_from_env(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    config = load_config()
    assert config.api_key == "test-key"

def test_raises_without_api_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    with pytest.raises(ConfigError, match="OPENAI_API_KEY"):
        load_config()
```

## Async Testing

```python
import pytest
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_async_pipeline():
    """Test async LLM pipeline."""
    mock_provider = AsyncMock()
    mock_provider.acomplete.return_value = "test response"
    
    result = await pipeline.arun(provider=mock_provider, query="test")
    assert result.status == "success"
    mock_provider.acomplete.assert_awaited_once()


@pytest.mark.asyncio
async def test_timeout_handling():
    """Verify timeout raises appropriately."""
    import asyncio
    
    async def slow_response(*args, **kwargs):
        await asyncio.sleep(10)
    
    mock_provider = AsyncMock(side_effect=slow_response)
    with pytest.raises(asyncio.TimeoutError):
        await asyncio.wait_for(
            pipeline.arun(provider=mock_provider, query="test"),
            timeout=1.0,
        )
```

## Property-Based Testing

```python
from hypothesis import given, settings, strategies as st

@given(st.text(min_size=1, max_size=100))
def test_tokenizer_roundtrip(text):
    """Encoding then decoding should return original text."""
    tokens = tokenizer.encode(text)
    decoded = tokenizer.decode(tokens)
    assert decoded == text


@given(st.lists(st.integers(min_value=0, max_value=100), min_size=1))
@settings(max_examples=500)
def test_chunk_sizes_sum_to_total(sizes):
    """Chunking preserves total token count."""
    text = " ".join(["word"] * sum(sizes))
    chunks = chunk_text(text, max_tokens=50)
    total = sum(len(c.split()) for c in chunks)
    assert total == sum(sizes)
```

## Parametrize Patterns

```python
@pytest.mark.parametrize("model,expected_provider", [
    ("gpt-4", "openai"),
    ("claude-3-sonnet", "anthropic"),
    ("ollama/llama3", "ollama"),
    ("unknown-model", None),
])
def test_model_routing(model, expected_provider):
    provider = resolve_provider(model)
    assert provider == expected_provider


@pytest.mark.parametrize("input_text,expected_error", [
    ("", "Input cannot be empty"),
    ("x" * 10001, "Input exceeds maximum length"),
    ("<script>alert(1)</script>", "Input contains disallowed HTML"),
])
def test_input_validation_rejects_bad_input(input_text, expected_error):
    with pytest.raises(ValidationError, match=expected_error):
        validate_input(input_text)
```

## Test Anti-Patterns to Avoid

1. **Testing implementation details** — Test behavior, not internal state
2. **Fragile assertions** — Don't assert on exact log messages or timestamps
3. **Test interdependence** — Each test must run independently and in any order
4. **Over-mocking** — If you mock everything, you test nothing
5. **Missing edge cases** — Empty inputs, None values, boundary conditions
6. **Ignoring flaky tests** — Fix or quarantine, never ignore
7. **Testing third-party code** — Mock the boundary, don't test their library

## CI Integration

```yaml
# .github/workflows/test.yml (excerpt)
jobs:
  test:
    steps:
      - run: uv run pytest tests/unit -x --cov --cov-report=xml
      - run: uv run pytest tests/integration -x -m "not slow"
      - run: uv run pytest tests/e2e -x --timeout=120
```
