---
name: infrastructure-patterns
description: "Docker, Kubernetes, secrets management, IaC, CI/CD pipelines, and deployment strategies for Python + LLM applications"
---

# Infrastructure Patterns

Reference patterns for deploying and operating Python + LLM applications.

## Docker Multi-Stage Builds

### Python + uv (Production)

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install dependencies (cached layer)
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# Copy source and install project
COPY src/ ./src/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# Runtime stage
FROM python:3.12-slim AS runtime
WORKDIR /app

# Non-root user
RUN groupadd -r app && useradd -r -g app -d /app app
COPY --from=builder --chown=app:app /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
USER app

EXPOSE 8000
CMD ["python", "-m", "myapp"]
```

### Key Optimization Points
- `--mount=type=cache` for uv cache persistence across builds
- Copy `pyproject.toml` + `uv.lock` before source (dependency caching)
- `UV_COMPILE_BYTECODE=1` for faster startup in production
- Pin base image to digest: `python:3.12-slim@sha256:abc...`

## Docker Compose Patterns

### Development Stack

```yaml
services:
  app:
    build:
      context: .
      target: builder        # Use builder stage for dev
    command: uv run uvicorn myapp:app --reload --host 0.0.0.0
    env_file: .env
    volumes:
      - .:/app:cached
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
  
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: localdev
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp"]
      interval: 5s
      timeout: 5s
      retries: 5
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

### Testing Stack
```yaml
# docker-compose.test.yml
services:
  test:
    build: .
    command: uv run pytest --cov --cov-report=xml
    env_file: .env.test
    depends_on:
      postgres:
        condition: service_healthy
```

## Secrets Management Patterns

### Pydantic BaseSettings (Runtime Config)

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )
    
    # Required secrets (no defaults)
    openai_api_key: SecretStr
    database_url: SecretStr
    
    # Optional with defaults
    debug: bool = False
    log_level: str = "INFO"
    
    # Model config
    default_model: str = "gpt-4o"
    fallback_model: str = "ollama/llama3.2"
```

### SOPS for Encrypted Secrets in Git

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/.*\.yaml
    age: age1ql3z7hjy54pw3hyww5ayf0...  # Team key
```

```bash
# Encrypt
sops --encrypt secrets/prod.yaml > secrets/prod.enc.yaml

# Decrypt at deploy time
sops --decrypt secrets/prod.enc.yaml | kubectl apply -f -
```

### GitHub Actions Secrets

```yaml
# Access in workflows
env:
  OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

## CI/CD Pipeline Patterns

### Complete GitHub Actions Pipeline

```yaml
name: CI/CD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv sync --frozen
      - run: uv run ruff check .
      - run: uv run ruff format --check .
      - run: uv run mypy src/

  test:
    needs: lint
    runs-on: ubuntu-latest
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_DB: test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv sync --frozen
      - run: uv run pytest --cov --cov-report=xml
      - uses: codecov/codecov-action@v4

  build-push:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Caching Strategy

```yaml
# uv cache
- uses: astral-sh/setup-uv@v4
  with:
    enable-cache: true                    # Auto-caches based on uv.lock

# Docker layer cache
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

## Kubernetes Patterns

### LLM Service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-service
  labels:
    app: llm-service
spec:
  replicas: 2
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0     # Zero-downtime deploys
  selector:
    matchLabels:
      app: llm-service
  template:
    metadata:
      labels:
        app: llm-service
    spec:
      terminationGracePeriodSeconds: 60
      containers:
        - name: app
          image: ghcr.io/org/llm-service:latest
          ports:
            - containerPort: 8000
          envFrom:
            - secretRef:
                name: llm-service-secrets
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "2000m"
          startupProbe:
            httpGet:
              path: /health
              port: 8000
            failureThreshold: 30
            periodSeconds: 10     # Allow up to 5 min for model loading
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
            periodSeconds: 5
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Pods
      pods:
        metric:
          name: http_request_duration_seconds_p95
        target:
          type: AverageValue
          averageValue: "2s"    # Scale on latency, not CPU
```

### External Secrets (Vault → k8s)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: llm-service-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: llm-service-secrets
  data:
    - secretKey: OPENAI_API_KEY
      remoteRef:
        key: secret/data/llm-service
        property: openai_api_key
```

## Health Check Patterns

### FastAPI Health Endpoints

```python
from fastapi import FastAPI, status
from fastapi.responses import JSONResponse

app = FastAPI()

@app.get("/health")
async def health():
    """Liveness: is the process running?"""
    return {"status": "ok"}

@app.get("/ready")
async def ready():
    """Readiness: is the service ready to accept traffic?"""
    checks = {
        "database": await check_db(),
        "model_loaded": model_manager.is_loaded,
        "cache": await check_redis(),
    }
    all_ok = all(checks.values())
    return JSONResponse(
        status_code=status.HTTP_200_OK if all_ok else status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"ready": all_ok, "checks": checks},
    )
```

## Environment Management

### Config Hierarchy
```
.env.example     → Template (committed to git, no real values)
.env             → Local dev (gitignored)
.env.test        → CI testing (gitignored or encrypted)
secrets/*.enc.yaml → Encrypted secrets (committed, decrypted at deploy)
```

### Feature Flags Pattern
```python
class FeatureFlags(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="FF_")
    
    enable_new_rag_pipeline: bool = False
    enable_streaming_responses: bool = True
    max_parallel_model_calls: int = 3
```

## Anti-Patterns

1. **Storing secrets in Docker images** — Use runtime injection (env vars, mounted secrets)
2. **Using `latest` tag in production** — Pin to SHA digest or semantic version
3. **No health checks** — Every service must have liveness + readiness probes
4. **Shared databases between services** — Each service owns its data
5. **No resource limits** — LLM workloads will consume all available memory without limits
6. **Manual deployments** — Everything through CI/CD, no `kubectl apply` from laptops
7. **Monolithic CI pipelines** — Split lint/test/build/deploy into separate jobs for parallelism
