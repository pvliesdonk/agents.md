#!/usr/bin/env bash
#
# session-summary.sh - SessionEnd hook
# Creates a searchable summary of the session when it ends
#
# Event: SessionEnd
# Purpose: Summarize tasks completed, decisions made, and patterns observed

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
    # No transcript, can't summarize
    exit 0
fi

### CUSTOMIZATION POINT: Adjust session length threshold
# Only create summary for sessions with meaningful activity (>10 turns)
TURN_COUNT=$(wc -l < "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
if [[ $TURN_COUNT -lt 10 ]]; then
    exit 0
fi

PROJECT_NAME=$(basename "$CWD")
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

# Extract session content
FULL_CONTEXT=$(jq -r 'select(.type == "text") | .text' "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

if [[ -z "$FULL_CONTEXT" ]]; then
    exit 0
fi

### CUSTOMIZATION POINT: Customize what to extract from session

# Count files modified
FILES_MODIFIED=$(echo "$FULL_CONTEXT" | grep -Eo "file_path.*\.(py|js|ts|md|json)" | sort -u | wc -l)

# Extract task completions
TASKS_COMPLETED=$(echo "$FULL_CONTEXT" | grep -Eic "(completed|finished|done|fixed|implemented|added)" || echo "0")

# Look for error fixes
ERRORS_FIXED=$(echo "$FULL_CONTEXT" | grep -Eic "(error.*fixed|bug.*resolved|issue.*solved)" || echo "0")

# Extract key technologies mentioned
TECHNOLOGIES=$(echo "$FULL_CONTEXT" | grep -Eio "(langchain|langgraph|fastapi|pydantic|pytest|docker|react|typescript)" | sort -u | tr '\n' ', ' | sed 's/,$//')

# Look for test runs
TESTS_RUN=$(echo "$FULL_CONTEXT" | grep -ic "test.*pass\|all tests" || echo "0")

# Build summary
SUMMARY="Session summary for $PROJECT_NAME ($TIMESTAMP):\n"
SUMMARY="$SUMMARY- Duration: $TURN_COUNT conversation turns\n"
SUMMARY="$SUMMARY- Files modified: $FILES_MODIFIED\n"
SUMMARY="$SUMMARY- Tasks completed: $TASKS_COMPLETED\n"

if [[ $ERRORS_FIXED -gt 0 ]]; then
    SUMMARY="$SUMMARY- Errors fixed: $ERRORS_FIXED\n"
fi

if [[ $TESTS_RUN -gt 0 ]]; then
    SUMMARY="$SUMMARY- Test runs: $TESTS_RUN\n"
fi

if [[ -n "$TECHNOLOGIES" ]]; then
    SUMMARY="$SUMMARY- Technologies: $TECHNOLOGIES\n"
fi

# Extract first user prompt as session topic
FIRST_PROMPT=$(head -n 20 "$TRANSCRIPT_PATH" | jq -r 'select(.role == "user") | .content' 2>/dev/null | head -n 1 | cut -c 1-150)
if [[ -n "$FIRST_PROMPT" ]]; then
    SUMMARY="$SUMMARY- Initial request: $FIRST_PROMPT\n"
fi

# Output summary
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionEnd",
    "additionalContext": "Session completed: $TASKS_COMPLETED tasks, $FILES_MODIFIED files modified"
  }
}
EOF

# Alternative: If mem0 MCP provides a CLI, store the full summary:
# echo -e "$SUMMARY" | mem0-cli add --user-id default --metadata "event=session_end,project=$PROJECT_NAME,date=$TIMESTAMP"

exit 0
