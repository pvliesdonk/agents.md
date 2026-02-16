# Hook Examples for mem0 Integration

This directory contains reference implementations of hooks that automatically capture memories during Claude Code sessions.

## Available Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `capture-code-style.sh` | PostToolUse | Extracts code style preferences from Edit/Write operations |
| `preserve-context.sh` | PreCompact | Saves critical context before compaction |
| `session-summary.sh` | SessionEnd | Creates searchable summary of session |
| `conversation-insights.sh` | Stop | Extracts explicit user preferences (use sparingly) |

## Installation

1. **Copy scripts to your project**:
   ```bash
   mkdir -p .claude/hooks
   cp .claude/hooks/examples/*.sh .claude/hooks/
   chmod +x .claude/hooks/*.sh
   ```

2. **Configure hooks** in `.claude/settings.json` or `.claude/settings.local.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Edit|Write",
           "hooks": [
             {
               "type": "command",
               "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/capture-code-style.sh"
             }
           ]
         }
       ],
       "PreCompact": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/preserve-context.sh"
             }
           ]
         }
       ],
       "SessionEnd": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-summary.sh"
             }
           ]
         }
       ]
     }
   }
   ```

3. **Restart Claude Code** to load hooks

## Customization

Each script has clearly marked customization points:

- **Thresholds**: Adjust when memories are created
- **Filters**: Customize what patterns to capture
- **Memory text**: Modify how information is formatted

Look for `### CUSTOMIZATION POINT` comments in each script.

## Testing Hooks

Test hooks locally without running Claude Code:

```bash
# Test PostToolUse hook
echo '{"tool_name": "Edit", "tool_input": {"file_path": "test.py", "old_string": "x = 1", "new_string": "x = 2"}, "session_id": "test"}' | .claude/hooks/capture-code-style.sh

# Test PreCompact hook
echo '{"transcript_path": "/path/to/transcript.jsonl", "session_id": "test"}' | .claude/hooks/preserve-context.sh

# Test SessionEnd hook
echo '{"session_id": "test", "cwd": "/path/to/project"}' | .claude/hooks/session-summary.sh
```

## Environment Variables

Hooks receive these variables automatically:

- `$CLAUDE_PROJECT_DIR`: Project root directory
- `$CLAUDE_ENV_FILE`: Path to environment file (SessionStart only)
- `$CLAUDE_CODE_REMOTE`: Set to "true" in remote web environments

## Hook Input/Output

### Input (stdin)
Hooks receive JSON on stdin with event-specific fields. Common fields:
- `session_id`: Current session identifier
- `transcript_path`: Path to conversation JSON
- `cwd`: Current working directory
- `hook_event_name`: Event name that fired

### Output (stdout/stderr)
- **Exit 0**: Success, optionally print JSON to control behavior
- **Exit 2**: Blocking error, stderr shown to Claude
- **Other**: Non-blocking error, shown in verbose mode

## Memory Best Practices

1. **Be selective**: Don't capture every operation, only significant ones
2. **Use descriptive text**: Make memories searchable
3. **Include context**: Store *why*, not just *what*
4. **Review periodically**: Delete outdated memories
5. **Search before storing**: Avoid duplicates

## Troubleshooting

### Hook not running
- Check file permissions: `chmod +x .claude/hooks/*.sh`
- Verify hook configuration in settings
- Restart Claude Code after configuration changes

### JSON parsing errors
- Ensure your shell profile doesn't print startup text
- Use `jq` for JSON parsing (install if missing)
- Test hooks manually with sample JSON

### mem0 MCP not available
- Verify mem0 MCP server is configured in opencode.json
- Check MCP server is running: `opencode mcp list`
- Test mem0 tools: use `/tools` in Claude Code

## Learn More

Load the `memory-patterns` skill in Claude Code:
```
Load the memory-patterns skill
```

This provides detailed guidance on when to use memory, scoping strategies, and agent-specific patterns.
