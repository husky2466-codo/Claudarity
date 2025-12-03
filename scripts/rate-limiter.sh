#!/bin/bash
################################################################################
# rate-limiter.sh
#
# Purpose: Throttle auto-context injection to prevent spam
#
# Usage:
#   ./rate-limiter.sh
#
# Configuration:
#   RATE_LIMIT_MESSAGES=10  (max 1 auto-context per N messages)
#
# Returns:
#   Exit code 0: ALLOW (output "ALLOW")
#   Exit code 1: DENY (output "DENY")
################################################################################

set -euo pipefail

# ============ CONFIGURATION ============
RATE_LIMIT_MESSAGES=10
STATE_FILE="$HOME/.claude/logs/auto-context-state.json"

# Create state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  echo '{"last_injection_ts": 0, "message_count": 0, "total_injections": 0}' > "$STATE_FILE"
fi

# ============ READ STATE ============
LAST_INJECTION_TS=$(jq -r '.last_injection_ts // 0' "$STATE_FILE" 2>/dev/null || echo 0)
MESSAGE_COUNT=$(jq -r '.message_count // 0' "$STATE_FILE" 2>/dev/null || echo 0)
TOTAL_INJECTIONS=$(jq -r '.total_injections // 0' "$STATE_FILE" 2>/dev/null || echo 0)

# Increment message count
MESSAGE_COUNT=$((MESSAGE_COUNT + 1))

# ============ CHECK RATE LIMIT ============
ALLOW=false

# Allow if we've passed the message threshold
if [ "$MESSAGE_COUNT" -ge "$RATE_LIMIT_MESSAGES" ]; then
  ALLOW=true
  MESSAGE_COUNT=0
  TOTAL_INJECTIONS=$((TOTAL_INJECTIONS + 1))
  LAST_INJECTION_TS=$(date +%s)
fi

# ============ SAVE STATE ============
jq -n \
  --arg last_ts "$LAST_INJECTION_TS" \
  --arg msg_count "$MESSAGE_COUNT" \
  --arg total "$TOTAL_INJECTIONS" \
  '{
    last_injection_ts: ($last_ts | tonumber),
    message_count: ($msg_count | tonumber),
    total_injections: ($total | tonumber)
  }' > "$STATE_FILE"

# ============ OUTPUT RESULT ============
if [ "$ALLOW" = true ]; then
  echo "ALLOW"
  exit 0
else
  echo "DENY"
  exit 1
fi
