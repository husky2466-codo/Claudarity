#!/bin/bash
################################################################################
# auto-context-inject.sh (MAIN ORCHESTRATOR)
#
# Purpose: Main hook for automatic context injection
#          Coordinates all sub-scripts to provide seamless memory recall
#
# Triggered by: UserPromptSubmit event (via user-prompt-submit.sh)
#
# Flow:
#   1. Check if disabled
#   2. Run trigger detection (analyze relevance)
#   3. Check rate limiter (throttle)
#   4. Search context (find relevant memories)
#   5. Format and display results
#
# Performance: Non-blocking, runs in background, < 1 second
################################################################################

# Read JSON input from stdin BEFORE forking
input=$(cat)

# Fork to background immediately to avoid blocking user input
(
  set -euo pipefail

  # ============ CONFIGURATION ============
  MIN_RELEVANCE_SCORE=25
  RATE_LIMIT_MESSAGES=10
  MAX_RESULTS_SHOWN=3

  # ============ PATHS ============
  SCRIPTS_DIR="$HOME/.claude/scripts"
  HOOKS_DIR="$HOME/.claude/hooks"
  DISABLE_FLAG="$HOME/.claude/.no-auto-context"

  # ============ STEP 1: CHECK IF DISABLED ============
  [ -f "$DISABLE_FLAG" ] && exit 0

  # ============ STEP 2: EXTRACT USER MESSAGE ============
  user_message=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null)

  # Exit if no message
  [ -z "$user_message" ] && exit 0

  # ============ STEP 3: RUN TRIGGER DETECTION ============
  # Analyze message relevance and extract keywords
  trigger_output=$(echo "$user_message" | "$SCRIPTS_DIR/detect-context-triggers.sh" 2>/dev/null)
  trigger_exit=$?

  # Exit if score below threshold (exit code 1)
  if [ $trigger_exit -ne 0 ]; then
    exit 0
  fi

  # Parse trigger detection output
  SCORE=$(echo "$trigger_output" | jq -r '.score // 0' 2>/dev/null)
  KEYWORDS=$(echo "$trigger_output" | jq -r '.keywords[]' 2>/dev/null | tr '\n' ' ' | xargs)

  # Validate score meets minimum
  if [ "$SCORE" -lt "$MIN_RELEVANCE_SCORE" ]; then
    exit 0
  fi

  # ============ STEP 4: CHECK RATE LIMITER ============
  rate_result=$("$SCRIPTS_DIR/rate-limiter.sh" 2>/dev/null)

  # Exit if rate limit denies (DENY)
  if [ "$rate_result" = "DENY" ]; then
    exit 0
  fi

  # ============ STEP 5: SEARCH FOR CONTEXT ============
  # Use keywords from trigger detection
  if [ -z "$KEYWORDS" ]; then
    # Fallback to message words if no keywords extracted
    KEYWORDS=$(echo "$user_message" | tr -s ' ' | head -c 100)
  fi

  # Run context search (limit to MAX_RESULTS_SHOWN)
  search_results=$("$HOOKS_DIR/context-search.sh" "$KEYWORDS" "$MAX_RESULTS_SHOWN" 2>/dev/null)

  # Check if search returned results
  if [ -z "$search_results" ]; then
    exit 0
  fi

  # Check if "No relevant" message (no results)
  if echo "$search_results" | grep -q "No relevant past experiences"; then
    exit 0
  fi

  # ============ STEP 6: FORMAT AND DISPLAY ============
  # Format results for user display
  formatted_output=$(echo "$search_results" | "$SCRIPTS_DIR/format-auto-context.sh" "$MAX_RESULTS_SHOWN" 2>/dev/null)

  # Display to user and Claude
  if [ -n "$formatted_output" ]; then
    echo "$formatted_output"
  fi

) &

# Return immediately - don't block
exit 0
