#!/bin/bash
################################################################################
# detect-compaction.sh
#
# Purpose:
#   Monitors transcript files for conversation compaction events
#   Extracts AI-generated summaries when Claude compacts a conversation
#   Detects when conversation continues after a summary
#
# Usage:
#   ./detect-compaction.sh [transcript_file] [session_id]
#
# How it works:
#   1. Scans transcript for compaction markers
#   2. Extracts the AI summary from compaction event
#   3. Returns summary text for logging
#
# Compaction Detection Strategy:
#   - Look for large text blocks with summary markers
#   - Detect phrases like "In our conversation so far", "Summary:", etc.
#   - Identify when message count drops significantly (context window reset)
#   - Track when new messages appear after summary
################################################################################

set -euo pipefail

TRANSCRIPT_FILE="${1:-}"
SESSION_ID="${2:-}"

if [ -z "$TRANSCRIPT_FILE" ]; then
  echo "ERROR: No transcript file provided" >&2
  echo "Usage: $0 <transcript_file> [session_id]" >&2
  exit 1
fi

if [ ! -f "$TRANSCRIPT_FILE" ]; then
  echo "ERROR: Transcript file not found: $TRANSCRIPT_FILE" >&2
  exit 1
fi

# Debug logging
DEBUG_LOG="$HOME/.claude/logs/compaction-debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")"

log_debug() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" >> "$DEBUG_LOG"
}

log_debug "=========================================="
log_debug "Checking for compaction in: $TRANSCRIPT_FILE"
log_debug "Session ID: ${SESSION_ID:-unknown}"

################################################################################
# COMPACTION DETECTION LOGIC
################################################################################

# Strategy 1: Look for explicit summary markers in assistant messages
# Claude often uses phrases like these when compacting:
SUMMARY_MARKERS=(
  "In our conversation so far"
  "To summarize our conversation"
  "Here's a summary of what we've discussed"
  "Let me recap our session"
  "Summary of our work"
  "Here's what we've accomplished"
  "Conversation summary"
  "Session recap"
)

# Extract all assistant text messages (skip tool_use blocks)
# Look for long messages (>500 chars) that might be summaries
TEMP_SUMMARIES=$(mktemp)

jq -r '
  select(.type == "assistant") |
  .message.content[] |
  select(.type == "text") |
  .text
' "$TRANSCRIPT_FILE" 2>/dev/null > "$TEMP_SUMMARIES" || true

# Check if any messages contain summary markers
FOUND_SUMMARY=""
SUMMARY_TEXT=""

while IFS= read -r msg_text; do
  # Skip short messages (summaries are usually substantial)
  msg_length=${#msg_text}
  [ "$msg_length" -lt 500 ] && continue

  # Check for summary markers
  for marker in "${SUMMARY_MARKERS[@]}"; do
    if echo "$msg_text" | grep -qi "$marker"; then
      log_debug "Found summary marker: '$marker'"
      log_debug "Message length: $msg_length chars"

      FOUND_SUMMARY="true"
      SUMMARY_TEXT="$msg_text"
      break 2  # Exit both loops
    fi
  done
done < "$TEMP_SUMMARIES"

rm -f "$TEMP_SUMMARIES"

################################################################################
# Strategy 2: Detect message count drops (context window reset)
################################################################################

# Count messages before and after potential compaction
# If there's a significant drop, it might indicate compaction
TOTAL_MESSAGES=$(jq -s 'length' "$TRANSCRIPT_FILE" 2>/dev/null || echo "0")
log_debug "Total messages in transcript: $TOTAL_MESSAGES"

# Check for sudden drops in message sequence
# This is harder to detect without historical data, so we'll focus on Strategy 1

################################################################################
# OUTPUT RESULTS
################################################################################

if [ -n "$FOUND_SUMMARY" ]; then
  log_debug "✅ COMPACTION DETECTED"
  log_debug "Summary length: ${#SUMMARY_TEXT} chars"

  # Output summary in JSON format for easy parsing
  jq -n \
    --arg summary "$SUMMARY_TEXT" \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg transcript "$TRANSCRIPT_FILE" \
    '{
      compaction_detected: true,
      summary: $summary,
      session_id: $session_id,
      timestamp: $timestamp,
      transcript_file: $transcript,
      summary_length: ($summary | length)
    }'

  log_debug "Summary output successfully"
  exit 0
else
  log_debug "❌ No compaction detected"

  # Output negative result
  jq -n \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    '{
      compaction_detected: false,
      session_id: $session_id,
      timestamp: $timestamp
    }'

  exit 0
fi
