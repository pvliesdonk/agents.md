#!/usr/bin/env bash
#
# preserve-context.sh - PreCompact hook
# Saves critical context before context compaction to prevent losing important decisions
#
# Event: PreCompact
# Purpose: Extract and preserve key decisions, unresolved issues, and insights before compaction

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
    # No transcript available, nothing to preserve
    exit 0
fi

### CUSTOMIZATION POINT: Adjust what patterns to extract from conversation

# Extract recent conversation turns (last 50 lines)
RECENT_CONTEXT=$(tail -n 50 "$TRANSCRIPT_PATH" | jq -r 'select(.type == "text") | .text' 2>/dev/null || echo "")

if [[ -z "$RECENT_CONTEXT" ]]; then
    exit 0
fi

# Look for architectural decision markers
DECISIONS=()
while IFS= read -r line; do
    # Look for decision language
    if echo "$line" | grep -Eqi "(we decided|decision:|chose|selected|opted for|will use|prefer to)"; then
        DECISIONS+=("$line")
    fi
done <<< "$RECENT_CONTEXT"

# Look for unresolved issues
ISSUES=()
while IFS= read -r line; do
    if echo "$line" | grep -Eqi "(TODO|FIXME|unresolved|need to|should investigate|pending)"; then
        ISSUES+=("$line")
    fi
done <<< "$RECENT_CONTEXT"

# Look for performance insights
INSIGHTS=()
while IFS= read -r line; do
    if echo "$line" | grep -Eqi "(performs better|faster than|slower than|more efficient|optimization)"; then
        INSIGHTS+=("$line")
    fi
done <<< "$RECENT_CONTEXT"

### CUSTOMIZATION POINT: Adjust memory storage threshold
# Only store if we found meaningful content
FOUND_COUNT=$((${#DECISIONS[@]} + ${#ISSUES[@]} + ${#INSIGHTS[@]}))
if [[ $FOUND_COUNT -eq 0 ]]; then
    exit 0
fi

# Build memory text
MEMORY_TEXT="Context preserved before compaction (session $SESSION_ID):\n"

if [[ ${#DECISIONS[@]} -gt 0 ]]; then
    MEMORY_TEXT="$MEMORY_TEXT\nArchitectural Decisions:\n"
    for decision in "${DECISIONS[@]:0:3}"; do  # Limit to 3 most recent
        MEMORY_TEXT="$MEMORY_TEXT- ${decision:0:200}\n"  # Truncate long lines
    done
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    MEMORY_TEXT="$MEMORY_TEXT\nUnresolved Issues:\n"
    for issue in "${ISSUES[@]:0:3}"; do
        MEMORY_TEXT="$MEMORY_TEXT- ${issue:0:200}\n"
    done
fi

if [[ ${#INSIGHTS[@]} -gt 0 ]]; then
    MEMORY_TEXT="$MEMORY_TEXT\nPerformance Insights:\n"
    for insight in "${INSIGHTS[@]:0:3}"; do
        MEMORY_TEXT="$MEMORY_TEXT- ${insight:0:200}\n"
    done
fi

# Add context metadata
PROJECT_NAME=$(basename "$CWD")
MEMORY_TEXT="$MEMORY_TEXT\nProject: $PROJECT_NAME"

# Output context for Claude to see
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "Preserved context: Found ${FOUND_COUNT} items to remember (${#DECISIONS[@]} decisions, ${#ISSUES[@]} issues, ${#INSIGHTS[@]} insights)"
  }
}
EOF

# Alternative: If mem0 MCP provides a CLI tool, store directly:
# echo -e "$MEMORY_TEXT" | mem0-cli add --user-id default --metadata "event=precompact,project=$PROJECT_NAME"

exit 0
