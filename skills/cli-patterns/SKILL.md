---
name: cli-patterns
description: Python CLI design with typer and rich — command structure, output formatting, progress indicators, error UX, verbosity levels, and machine-readable output patterns
---

**Note**: Verify typer/rich API details via `context7` MCP before implementation.

## Command Structure (typer)

```python
import typer
from rich.console import Console

app = typer.Typer(help="My CLI Tool", no_args_is_help=True)
console = Console(stderr=True)  # UI on stderr, data on stdout

@app.command()
def generate(
    input_file: str = typer.Argument(help="Input file path"),
    prompt: str = typer.Argument(help="Generation prompt"),
    provider: str = typer.Option(None, "--provider", "-p",
        help="LLM provider (e.g., ollama/qwen3:4b-instruct)"),
    verbose: int = typer.Option(0, "--verbose", "-v", count=True,
        help="Increase verbosity (-v, -vv, -vvv)"),
    json_output: bool = typer.Option(False, "--json",
        help="Output as JSON (for scripting)"),
):
    """Generate output using the configured LLM pipeline."""
```

## Output Principles

- **stdout = data** (pipeable). **stderr = UI** (progress, status, errors).
- `Console(stderr=True)` for all rich output.
- Support `--json` for machine-readable output.
- Exit codes: 0=success, 1=user error, 2=system error.

## Verbosity Levels

```python
import structlog
log = structlog.get_logger()

# Map -v flags to log levels
LOG_LEVELS = {0: "WARNING", 1: "INFO", 2: "DEBUG", 3: "DEBUG"}  # -vvv = trace via structlog

def configure_logging(verbose: int):
    level = LOG_LEVELS.get(min(verbose, 3), "DEBUG")
    structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(level))
```

| Flag | Shows | Use Case |
|------|-------|----------|
| (none) | Result summary | Normal usage |
| `-v` | Stage transitions, key decisions | Understanding flow |
| `-vv` | API calls, timing, tokens | Performance debugging |
| `-vvv` | Full prompts, responses, validation | LLM debugging |

## Progress Indicators (rich)

```python
from rich.progress import Progress, SpinnerColumn, TextColumn

# For LLM calls (unknown duration)
with Progress(SpinnerColumn(), TextColumn("{task.description}")) as progress:
    task = progress.add_task("Generating output...", total=None)
    result = await llm.ainvoke(prompt)

# For multi-step pipelines (known steps)
from rich.progress import BarColumn, TaskProgressColumn
with Progress(BarColumn(), TaskProgressColumn()) as progress:
    task = progress.add_task("Pipeline", total=6)
    for stage in stages:
        await run_stage(stage)
        progress.advance(task)
```

## Tables and Panels

```python
from rich.table import Table
from rich.panel import Panel

# Tabular data
table = Table(title="Pipeline Status")
table.add_column("Stage", style="cyan")
table.add_column("Status", style="green")
table.add_column("Tokens", justify="right")
table.add_row("Generate", "Complete", "1,234")
console.print(table)

# Summary panels
console.print(Panel(
    f"[green]Generation complete[/green]\n"
    f"Model: {result.model}\n"
    f"Tokens: {result.total_tokens}",
    title="Result",
))
```

## Error UX

```python
# User-facing: rich panel with guidance
console.print(Panel(
    f"[red]Provider '{name}' not found.[/red]\n\n"
    f"Available: {', '.join(available)}\n"
    f"Set via: --provider, APP_PROVIDER env, or config file",
    title="Configuration Error",
    border_style="red",
))
raise typer.Exit(1)

# Never show raw tracebacks. Catch, format, guide.
# Show tracebacks only at -vvv verbosity.
```

## Interactive vs Pipeline Mode

```python
import sys
from rich.prompt import Confirm

def maybe_confirm(message: str) -> bool:
    """Prompt interactively, auto-yes in pipeline mode."""
    if not sys.stdin.isatty():
        return True  # Non-interactive: proceed
    return Confirm.ask(message)
```

Always provide non-interactive alternatives (flags, env vars) for every interactive prompt.

## Subcommand Groups

```python
# Nested commands for complex CLIs
pipeline_app = typer.Typer(help="Pipeline operations")
app.add_typer(pipeline_app, name="pipeline")

@pipeline_app.command("run")
def pipeline_run(to: str = typer.Option("ship", help="Run up to stage")):
    """Execute pipeline stages."""

# Usage: mytool pipeline run --to seed
```
