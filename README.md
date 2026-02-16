# agents.md

A curated package of AGENTS.md rules, specialized subagents, and on-demand skills for AI coding agents. Built for [opencode](https://opencode.ai), with compatibility for Claude Code and other agents that support the AGENTS.md/CLAUDE.md convention.

Opinionated toward **Python + LLM pipeline development** targeting both small local models (Ollama 4B-8B) and large cloud models (GPT-5, Claude).

## What's Inside

### Global Rules (AGENTS.md)

The foundation that applies to every session:
- **Documentation-first mandate** — forces MCP doc lookup before coding (LangChain, OpenAI, context7)
- **Python standards** — 3.11+, uv, ruff, Pydantic, structlog
- **Dual-model awareness** — design for both 4B local and GPT-5 cloud models
- **GitHub workflow** — conventional commits, stacked PRs, small PR discipline
- **Skill directory** — tells agents which skills to load and when
- **Delegation table** — routes tasks to the right subagent

### 6 Subagents

| Agent | Role | Access |
|-------|------|--------|
| `@architect` | Design decisions, refactoring, dependency analysis | Read + ask-to-write |
| `@llm-engineer` | LLM pipelines, LangChain, structured output, model routing | Full write |
| `@prompt-engineer` | Prompt analysis, template design, output schemas | Read-only (advisory) |
| `@security-reviewer` | Security audits, CVEs, secrets, LLM-specific risks | Read-only (audit) |
| `@github-ops` | Issues, PRs, stacked PRs, releases, CI/CD | Full write + gh CLI |
| `@frontend-dev` | CLI (typer/rich), web UI, terminal UX | Full write |

Each agent has scoped permissions (edit/bash allow/ask/deny) and references its related skills.

### 7 On-Demand Skills

Skills are loaded only when needed, saving context tokens:

| Skill | What It Covers |
|-------|---------------|
| `python-patterns` | Project structure, typing, async, pytest, Pydantic Settings, uv |
| `langchain-patterns` | LCEL chains, structured output, LiteLLM, Ollama, LangGraph |
| `prompt-craft` | Prompt scaffolds, few-shot design, dual-model adaptation |
| `dual-model-strategy` | Schema design, fallback chains, testing, cost optimization |
| `github-workflow` | Stacked PRs (vanilla Git branches), gh CLI, issue discipline |
| `release-flow` | semantic-release, PyPI trusted publishing, Docker, GitHub Actions |
| `cli-patterns` | typer + rich: commands, progress, tables, error UX, verbosity |

## How It Fits Together

```
AGENTS.md (always loaded)
  ├── defines Python standards, doc-first mandate, core principles
  ├── skill directory → tells agents WHEN to load each skill
  └── delegation table → tells agents WHICH subagent handles what
        │
        ├── @architect ──────── loads: python-patterns
        ├── @llm-engineer ───── loads: langchain-patterns, dual-model-strategy
        ├── @prompt-engineer ── loads: prompt-craft, dual-model-strategy
        ├── @security-reviewer  (no skills — uses own checklist)
        ├── @github-ops ─────── loads: github-workflow, release-flow
        └── @frontend-dev ───── loads: cli-patterns
```

Global AGENTS.md teaches **how to work**. Project-level AGENTS.md adds **what to work on**.

## Install

```bash
git clone https://github.com/pvliesdonk/agents.md.git
cd agents.md
chmod +x install.sh
./install.sh
```

This copies everything to `~/.config/opencode/` (agents, skills, and global AGENTS.md). Restart opencode to pick up changes.

### Manual Install

Copy files to the opencode config directory:

```bash
cp AGENTS.md ~/.config/opencode/AGENTS.md
cp -r agents/ ~/.config/opencode/agents/
cp -r skills/ ~/.config/opencode/skills/
```

### Claude Code Compatibility

opencode also searches `~/.claude/` paths. To use with Claude Code:

```bash
cp AGENTS.md ~/.claude/CLAUDE.md
cp -r skills/ ~/.claude/skills/
```

Note: Claude Code doesn't support custom subagents, but the AGENTS.md rules and skills work.

## Customization

### Adding Project-Specific Rules

Create a project-level `AGENTS.md` (or `CLAUDE.md`) in your repo root to add context about your specific project — architecture, test policies, file layout, domain terminology. It complements the global rules.

### Adding Your Own Skills

```bash
mkdir -p ~/.config/opencode/skills/my-skill/
```

Create `SKILL.md` with required frontmatter:

```yaml
---
name: my-skill
description: What this skill provides (1-1024 chars)
---

Your skill content here...
```

### Adding Your Own Agents

Create a markdown file in `~/.config/opencode/agents/`:

```yaml
---
description: What this agent does
mode: subagent
temperature: 0.2
permission:
  edit: allow
  bash:
    "*": ask
---

Your agent system prompt here...
```

### MCP Server Configuration

The agents reference several MCP servers. Configure them in your `opencode.json`:

- `langchain-docs` — LangChain documentation
- `openai-docs` — OpenAI API documentation
- `context7` — General library documentation
- `github` — GitHub operations
- `playwright` — Browser automation (optional)

## Design Decisions

| Choice | Why |
|--------|-----|
| Global AGENTS.md + project AGENTS.md | Separation of concerns: global = how to work, project = what to work on |
| Skills loaded on-demand | Saves context tokens — only loaded when an agent needs the knowledge |
| Read-only agents for review roles | Structural safety: prompt-engineer and security-reviewer can't accidentally modify code |
| Documentation-first mandate | LangChain (and others) change fast. Forces lookup before implementation. |
| Dual-model by default | Real-world LLM projects use both cheap local models and expensive cloud models |

## License

MIT
