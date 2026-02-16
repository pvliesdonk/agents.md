# Maintaining Dual Formats

This guide explains how to maintain parallel OpenCode and Claude Code agent/skill formats.

## Philosophy

**OpenCode format is the source of truth.** Always edit OpenCode versions first, then sync changes to Claude Code versions. This ensures consistency and prevents divergence.

## Workflow

### 1. Edit OpenCode Version (Source of Truth)

Make changes to:
- `agents/*.md`
- `skills/*/SKILL.md`

### 2. Sync to Claude Code Version

Use an LLM assistant to apply changes to:
- `claude-agents/*.md`
- `claude-skills/*/SKILL.md`

**Prompt template:**
```
Sync changes from agents/X.md to claude-agents/X.md
Apply the conversion rules from SYNC.md
```

### 3. Update Tracking

- Update `CHANGELOG.md` with changes
- Update "Last Synced" dates below

### 4. Test Both Installations

```bash
./install.sh opencode  # Test OpenCode
./install.sh claude    # Test Claude Code
```

---

## Conversion Rules

### Agent Format Conversion

| OpenCode Field | Claude Code Field | Conversion Logic |
|----------------|-------------------|------------------|
| `description` | `description` | Direct copy |
| `mode: subagent` | — | Omit (implied by directory location) |
| `temperature: 0.1` | `model: haiku` | temp < 0.3 → haiku |
| `temperature: 0.3` | `model: sonnet` | 0.3 ≤ temp < 0.5 → sonnet |
| `temperature: 0.7` | `model: opus` | temp ≥ 0.5 → opus |
| `permission.edit: ask` | `permissionMode: default` | Conservative mapping |
| `permission.edit: allow` | `permissionMode: acceptEdits` | Liberal mapping |
| `permission.edit: deny` | `permissionMode: plan` | Read-only mapping |
| `permission.bash."grep *": allow` | `tools: [..., Bash]` | Include Bash, document restrictions in body |
| `permission.bash."git push": ask` | Document in body | "Note: git push requires approval" |

### Permission Mapping Strategy

**Liberal approach with consideration:**
- Default to least restrictive that maintains safety
- Document restrictions in agent body text when bash patterns can't be expressed
- Test agent behavior after conversion

### Tool Allowlist Creation

Extract from OpenCode permission patterns:

**Example:**
```yaml
# OpenCode
permission:
  edit: false
  bash:
    "grep *": allow
    "rg *": allow
    "find *": allow
```

**Converts to Claude Code:**
```yaml
tools: Read, Glob, Grep, Bash
permissionMode: plan  # edit: false → plan mode
```

**Body note:** "Bash limited to read-only operations (grep, rg, find)"

### Skills Format Conversion

Most skills are **directly compatible** - just copy:

```bash
cp skills/skill-name/SKILL.md claude-skills/skill-name/SKILL.md
```

**Only adjust if:**
- Frontmatter contains OpenCode-specific fields
- Body references OpenCode-specific features

---

## Agent-Specific Mappings

### @architect (Read + Ask-to-Write)

**OpenCode:**
```yaml
description: Software architect for Python systems...
mode: subagent
temperature: 0.2
permission:
  edit: ask
  bash:
    "grep *": allow
    "rg *": allow
    "find *": allow
    "*": ask
```

**Claude Code:**
```yaml
name: architect
description: Software architect for Python systems...
model: haiku
permissionMode: default
tools: Read, Glob, Grep, Bash
```

**Body note:** "Bash: analysis commands allowed, modifications require approval"

---

### @llm-engineer (Full Write)

**OpenCode:**
```yaml
description: LLM pipeline engineer...
mode: subagent
temperature: 0.3
permission:
  edit: allow
  bash:
    "curl *": ask
    "*": allow
```

**Claude Code:**
```yaml
name: llm-engineer
description: LLM pipeline engineer...
model: sonnet
permissionMode: acceptEdits
tools: Read, Write, Edit, Glob, Grep, Bash
```

**Body note:** "Most operations auto-approved; curl requires confirmation"

---

### @prompt-engineer (Read-Only Advisory)

**OpenCode:**
```yaml
description: Prompt engineering specialist...
mode: subagent
temperature: 0.2
permission:
  edit: deny
  bash:
    "grep *": allow
    "rg *": allow
```

**Claude Code:**
```yaml
name: prompt-engineer
description: Prompt engineering specialist...
model: haiku
permissionMode: plan
tools: Read, Grep, Glob
```

**Body note:** "Read-only agent - proposes changes but doesn't execute"

---

### @security-reviewer (Read-Only Audit)

**OpenCode:**
```yaml
description: Security reviewer...
mode: subagent
temperature: 0.1
permission:
  edit: deny
  bash:
    "grep *": allow
    "rg *": allow
    "git *": allow
```

**Claude Code:**
```yaml
name: security-reviewer
description: Security reviewer...
model: haiku
permissionMode: plan
tools: Read, Grep, Glob, Bash
```

**Body note:** "Audit-only mode - no modifications. Bash limited to git/grep operations."

---

### @github-ops (Full Write + gh CLI)

**OpenCode:**
```yaml
description: GitHub operations specialist...
mode: subagent
temperature: 0.3
permission:
  edit: ask
  bash:
    "gh *": allow
    "git log*": allow
    "git status*": allow
    "git diff*": allow
    "git push*": ask
    "git merge*": ask
```

**Claude Code:**
```yaml
name: github-ops
description: GitHub operations specialist...
model: sonnet
permissionMode: default
tools: Read, Write, Edit, Bash, Glob, Grep
```

**Body note:** "Uses gh CLI extensively. Approvals requested for destructive git operations (push, merge)."

---

### @frontend-dev (Full Write + Dev Tools)

**OpenCode:**
```yaml
description: Frontend and CLI developer...
mode: subagent
temperature: 0.3
permission:
  edit: allow
  bash:
    "npm *": allow
    "node *": allow
    "python *": allow
```

**Claude Code:**
```yaml
name: frontend-dev
description: Frontend and CLI developer...
model: sonnet
permissionMode: acceptEdits
tools: Read, Write, Edit, Bash, Glob, Grep
```

**Body note:** "Development operations auto-approved"

---

## Last Synced

- **agents/**: 2026-02-16
- **skills/**: 2026-02-16

## Testing Checklist

After syncing, verify:

- [ ] Both installations complete without errors
- [ ] Agent behavior remains similar across platforms
- [ ] Permission models work as expected
- [ ] Skills load correctly in both formats
- [ ] AGENTS.md remains compatible with both

```bash
# Test OpenCode
./install.sh opencode
# Verify: ~/.config/opencode/agents/ and ~/.config/opencode/skills/

# Test Claude Code  
./install.sh claude
# Verify: ~/.claude/agents/ and ~/.claude/skills/

# Test both
./install.sh both
```

---

## Common Issues

**Issue:** Agent behavior differs between platforms

**Solution:** Check permission mapping - may need to adjust `permissionMode` or add body notes

---

**Issue:** Skill not loading in Claude Code

**Solution:** Check frontmatter for OpenCode-specific fields, verify `name` matches directory

---

**Issue:** Bash commands blocked unexpectedly

**Solution:** Review tool allowlist, ensure `Bash` is included if needed

---

## Tips

1. **Use git branches** when syncing - makes it easy to review diffs
2. **Test behavior** with a simple task after syncing each agent
3. **Document divergences** if intentional optimization requires different approaches
4. **Batch syncs** - sync all agents together, then all skills
5. **Keep body text identical** where possible - diverge only frontmatter
