#!/bin/bash

# Stop hook to intercept plan mode exit and offer /sab execution option
# This hook fires when Claude finishes responding in Plan Mode

# Read the input JSON from stdin
INPUT=$(cat)

# Extract the transcript path from the input
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# If we don't have a transcript path, exit normally
if [ -z "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# State file to track if we've already prompted for this exit
STATE_FILE="${TRANSCRIPT_PATH}.sab_prompted"

# If we've already prompted for this plan mode exit, don't prompt again
if [ -f "$STATE_FILE" ]; then
  exit 0
fi

# Check if the LAST FEW messages contain an actual ExitPlanMode tool call
# This indicates Claude is trying to exit plan mode RIGHT NOW (not from earlier in conversation)
# We need to look for the actual tool_use structure, not just the word "ExitPlanMode"
if tail -n 50 "$TRANSCRIPT_PATH" | jq -s 'any(.[]; select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "ExitPlanMode"))' 2>/dev/null | grep -q "true"; then

  # Mark that we've prompted for this exit
  touch "$STATE_FILE"

  # Block the normal flow and ask Claude to offer /sab option
  # The reason field will be fed back to Claude as context
  cat <<'EOF'
{
  "decision": "block",
  "reason": "Plan mode exit detected. Please ask the user if they would like to: A) Proceed with implementation as planned, or B) Execute /sab to structure the approved query before implementation. Wait for their response before proceeding."
}
EOF

  exit 2  # Exit code 2 indicates blocking with message
fi

# For all other cases, allow normal continuation
exit 0
