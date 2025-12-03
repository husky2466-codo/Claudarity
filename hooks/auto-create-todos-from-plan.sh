#!/bin/bash
################################################################################
# auto-create-todos-from-plan.sh
#
# Purpose:
#   After user accepts a plan, automatically create a todo list if one doesn't exist
#   Extracts implementation steps from the plan file and converts to todos
#
# Trigger: user-prompt-submit (after user responds to plan acceptance prompt)
#
################################################################################

set -euo pipefail

# Read input from stdin
INPUT=$(cat)

# Extract transcript path and user message
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
USER_MESSAGE=$(echo "$INPUT" | jq -r '.user_message // empty')

# Exit if we don't have required data
if [ -z "$TRANSCRIPT_PATH" ] || [ -z "$USER_MESSAGE" ]; then
  exit 0
fi

# Get session ID from transcript path
SESSION_ID=$(basename "$TRANSCRIPT_PATH" .jsonl)
PROJECT_DIR=$(dirname "$TRANSCRIPT_PATH")

# Check if we just exited plan mode in the last few messages
PLAN_EXIT_RECENT=$(tail -n 50 "$TRANSCRIPT_PATH" 2>/dev/null | grep -c "ExitPlanMode" || echo "0")

# If no recent plan exit, nothing to do
if [ "$PLAN_EXIT_RECENT" -eq 0 ]; then
  exit 0
fi

# Check if user is accepting the plan (common acceptance patterns)
USER_ACCEPTING=$(echo "$USER_MESSAGE" | grep -iE "(yes|proceed|go ahead|do it|looks good|approved|accept|implement|let's do|start)" || echo "")

# If user isn't accepting, nothing to do
if [ -z "$USER_ACCEPTING" ]; then
  exit 0
fi

# Check if todos already exist for this session
TODOS_DIR="$HOME/.claude/todos"
TODO_FILE=$(ls "$TODOS_DIR"/*"$SESSION_ID"*.json 2>/dev/null | head -1 || echo "")

# If todos already exist, nothing to do
if [ -n "$TODO_FILE" ] && [ -f "$TODO_FILE" ]; then
  exit 0
fi

# Find the most recent plan file
PLANS_DIR="$HOME/.claude/plans"
LATEST_PLAN=$(ls -t "$PLANS_DIR"/*.md 2>/dev/null | head -1 || echo "")

# If no plan file found, nothing to do
if [ -z "$LATEST_PLAN" ] || [ ! -f "$LATEST_PLAN" ]; then
  exit 0
fi

# Extract implementation steps from plan file
# Look for numbered lists, bullet points, or markdown headers indicating steps
STEPS=$(grep -E "^(#{1,4} |[0-9]+\. |- \*\*|Step [0-9]+)" "$LATEST_PLAN" | head -20)

# If no steps found, nothing to do
if [ -z "$STEPS" ]; then
  exit 0
fi

# Log the auto-creation
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
echo "$(date '+%Y-%m-%d %H:%M:%S') | Auto-creating todos from plan: $LATEST_PLAN" >> "$LOG_DIR/auto-todos.log"

# Create a message for Claude to generate todos from the plan
# Include the plan file path so Claude can read it
cat <<EOF
{
  "decision": "allow_with_message",
  "reason": "🎯 AUTO-TODO TRIGGER

You just accepted a plan and there's no todo list yet. You MUST now:

1. Read the plan file: $LATEST_PLAN
2. Extract all implementation steps from the plan
3. Use TodoWrite to create a structured todo list
4. Mark the first todo as 'in_progress'

Do this IMMEDIATELY before proceeding with implementation. This ensures we track progress properly.

The plan file contains the steps you need to convert to todos."
}
EOF

exit 2  # Exit code 2 adds the message to context
