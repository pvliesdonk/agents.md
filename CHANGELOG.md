# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-02-16

### Added

**Claude Code Support:**
- Added `claude-agents/` directory with 6 agents in Claude Code format
- Added `claude-skills/` directory with 8 skills in Claude Code format
- Multi-target install script supporting OpenCode, Claude Code, and both
- `SYNC.md` maintenance guide for dual-format workflow

**mem0 Integration:**
- New `memory-patterns` skill with comprehensive mem0 integration guide
- Hook examples in `.claude/hooks/examples/`:
  - `capture-code-style.sh` - Auto-capture code preferences
  - `preserve-context.sh` - Save context before compaction
  - `session-summary.sh` - Create session summaries
  - `conversation-insights.sh` - Extract conversation insights
- Memory guidance sections added to all 6 agents
- mem0 MCP tool reference added to `AGENTS.md`
- Memory Usage column added to Delegation table

### Changed

**Documentation-First Mandate:**
- Refined from prescriptive "ANY library" to architecture-focused guidance
- Added symptom recognition for stale knowledge (rebuilding features)
- Clarified when to trust training knowledge vs lookup documentation
- Emphasized fast-changing frameworks and post-training-cutoff libraries

**Installation:**
- `install.sh` now supports `opencode`, `claude`, and `both` targets
- Default behavior unchanged (OpenCode installation)

### Migration Guide

**For existing users:**

1. **No action required** for OpenCode users - existing installation continues to work
2. **Claude Code users** can now install with: `./install.sh claude`
3. **Dual-platform users** can install both with: `./install.sh both`

**To enable memory features:**

1. Review `skills/memory-patterns/SKILL.md`
2. (Optional) Copy and customize hooks from `.claude/hooks/examples/`
3. Configure hooks in your agent configuration

**Format compatibility:**
- `AGENTS.md` remains compatible with both platforms
- OpenCode: `agents/` and `skills/` (unchanged)
- Claude Code: `claude-agents/` and `claude-skills/` (new)

## [1.0.0] - 2026-02-15

### Initial Release

- Global `AGENTS.md` with opinionated Python + LLM development rules
- 6 specialized subagents (architect, llm-engineer, prompt-engineer, security-reviewer, github-ops, frontend-dev)
- 7 on-demand skills (python-patterns, langchain-patterns, prompt-craft, dual-model-strategy, github-workflow, release-flow, cli-patterns)
- OpenCode format support
- Installation script for `~/.config/opencode/`
