#!/usr/bin/env bash
#
# conversation-insights.sh - Stop hook
# Extracts explicit user preferences from conversation (use sparingly - fires frequently)
#
# Event: Stop
# Purpose: Capture explicit preference statements as they occur
# WARNING: This hook fires after every agent response - use conservative filters

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

### CUSTOMIZATION POINT: Adjust preference detection patterns
# Only capture very explicit preference statements to avoid noise

# Get the most recent user message (last 5 lines of transcript)
RECENT_USER_MESSAGE=$(tail -n 5 "$TRANSCRIPT_PATH" | jq -r 'select(.role == "user") | .content' 2>/dev/null | tail -n 1)

if [[ -z "$RECENT_USER_MESSAGE" ]]; then
    exit 0
fi

# Look for EXPLICIT preference language
PREFERENCE=""

if echo "$RECENT_USER_MESSAGE" | grep -Eqi "I (prefer|like|want|always use|never use|don't use)"; then
    PREFERENCE=$(echo "$RECENT_USER_MESSAGE" | grep -Eio "I (prefer|like|want|always use|never use|don't use).*" | head -n 1)
fi

if echo "$RECENT_USER_MESSAGE" | grep -Eqi "please (always|never|don't)"; then
    PREFERENCE=$(echo "$RECENT_USER_MESSAGE" | grep -Eio "please (always|never|don't).*" | head -n 1)
fi

if echo "$RECENT_USER_MESSAGE" | grep -Eqi "(use|choose|select) .* (instead of|rather than|over)"; then
    PREFERENCE=$(echo "$RECENT_USER_MESSAGE" | grep -Eio ".*(use|choose|select) .* (instead of|rather than|over).*" | head -n 1)
fi

### CUSTOMIZATION POINT: Add more preference patterns or adjust existing ones

# Only store if we found a clear preference
if [[ -z "$PREFERENCE" ]]; then
    exit 0
fi

# Truncate very long preferences
PREFERENCE=${PREFERENCE:0:250}

# Output preference for potential storage
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "User preference detected: $PREFERENCE"
  }
}
EOF

# Alternative: If mem0 MCP provides a CLI, store directly:
# echo "User preference: $PREFERENCE" | mem0-cli add --user-id default --metadata "event=preference,session=$SESSION_ID"

exit 0
