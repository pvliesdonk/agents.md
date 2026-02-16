#!/usr/bin/env bash
#
# capture-code-style.sh - PostToolUse hook
# Automatically captures code style preferences from Edit/Write operations
#
# Event: PostToolUse
# Matcher: "Edit|Write"
# Purpose: Extract and store code style patterns as they emerge

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool information
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only process Edit/Write operations with meaningful content
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

if [[ -z "$CONTENT" ]]; then
    exit 0
fi

### CUSTOMIZATION POINT: Adjust file type filters
# Skip binary files and generated code
if [[ "$FILE_PATH" =~ \.(json|lock|min\.js|bundle\.js|map)$ ]]; then
    exit 0
fi

# Detect programming language from file extension
LANG=""
if [[ "$FILE_PATH" =~ \.py$ ]]; then
    LANG="Python"
elif [[ "$FILE_PATH" =~ \.(js|jsx|ts|tsx)$ ]]; then
    LANG="JavaScript/TypeScript"
elif [[ "$FILE_PATH" =~ \.md$ ]]; then
    LANG="Markdown"
else
    # Skip unknown file types
    exit 0
fi

# Analyze code style patterns
PATTERNS=()

### CUSTOMIZATION POINT: Add/remove pattern detection logic

# Detect indentation (spaces vs tabs, size)
if echo "$CONTENT" | grep -q $'^\t'; then
    PATTERNS+=("Uses tabs for indentation in $LANG")
elif echo "$CONTENT" | grep -q '^    '; then
    PATTERNS+=("Uses 4-space indentation in $LANG")
elif echo "$CONTENT" | grep -q '^  '; then
    PATTERNS+=("Uses 2-space indentation in $LANG")
fi

# Python-specific patterns
if [[ "$LANG" == "Python" ]]; then
    # Import style
    if echo "$CONTENT" | grep -q '^from .* import '; then
        if echo "$CONTENT" | grep -q 'from typing import'; then
            PATTERNS+=("Python: Uses type hints (imports from typing)")
        fi
    fi
    
    # Docstring style
    if echo "$CONTENT" | grep -q '"""'; then
        PATTERNS+=("Python: Uses triple-quote docstrings")
    fi
    
    # Dataclass vs Pydantic
    if echo "$CONTENT" | grep -q 'from dataclasses import'; then
        PATTERNS+=("Python: Prefers dataclasses for models")
    elif echo "$CONTENT" | grep -q 'from pydantic import'; then
        PATTERNS+=("Python: Uses Pydantic for models")
    fi
fi

# JavaScript/TypeScript patterns
if [[ "$LANG" == "JavaScript/TypeScript" ]]; then
    # Quotes preference
    if echo "$CONTENT" | grep -q "^import.*'"; then
        PATTERNS+=("JS/TS: Prefers single quotes for imports")
    elif echo "$CONTENT" | grep -q '^import.*"'; then
        PATTERNS+=("JS/TS: Prefers double quotes for imports")
    fi
    
    # Semicolons
    if echo "$CONTENT" | grep -Eq '^[^/]*;$'; then
        PATTERNS+=("JS/TS: Uses semicolons")
    fi
    
    # Arrow functions vs function keyword
    if echo "$CONTENT" | grep -q '=>'; then
        PATTERNS+=("JS/TS: Prefers arrow functions")
    fi
fi

# Only store if we detected meaningful patterns
if [[ ${#PATTERNS[@]} -eq 0 ]]; then
    exit 0
fi

### CUSTOMIZATION POINT: Adjust memory storage threshold
# Store at most one memory per session per file type to avoid noise
MEMORY_KEY="code_style_${LANG// /_}_${SESSION_ID}"

# Create memory text
MEMORY_TEXT="Code style preferences observed in $LANG ($(basename "$FILE_PATH")):\n"
for pattern in "${PATTERNS[@]}"; do
    MEMORY_TEXT="$MEMORY_TEXT- $pattern\n"
done

# Call mem0 MCP to store memory
# Note: This uses a hypothetical MCP CLI interface - adjust based on actual mem0 MCP implementation
# In practice, this would call the MCP server via the agent's MCP client

# For Claude Code, we output JSON that suggests the memory to add
# The agent can then decide whether to act on it
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Observed code style: ${PATTERNS[0]}"
  }
}
EOF

# Alternative: If mem0 MCP provides a CLI tool, call it directly:
# echo "$MEMORY_TEXT" | mem0-cli add --user-id default --metadata "language=$LANG,session=$SESSION_ID"

exit 0
