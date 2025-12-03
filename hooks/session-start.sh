#!/bin/bash
# Session Start Hook - Load recent wins/losses from memory
# Reads memory files referenced in logs to show Claude detailed context

# ============ CLEANUP OLD CACHE FILES (once per day) ============
LAST_CLEANUP_FILE="$HOME/.claude/logs/.last-cleanup-date"
TODAY=$(date '+%Y-%m-%d')

if [ -f "$LAST_CLEANUP_FILE" ]; then
  LAST_CLEANUP=$(cat "$LAST_CLEANUP_FILE")
else
  LAST_CLEANUP=""
fi

# Run cleanup if we haven't run it today
if [ "$LAST_CLEANUP" != "$TODAY" ]; then
  "$HOME/.claude/scripts/cleanup-feedback-cache.sh" &>/dev/null &
  echo "$TODAY" > "$LAST_CLEANUP_FILE"
fi

# ============ CHECK FOR PREVIOUS SESSION COMPACTION ============
# Before showing current context, check if the previous session ended with compaction
LAST_SESSION_TRANSCRIPT="$HOME/.claude/logs/last-session-transcript"

if [ -f "$LAST_SESSION_TRANSCRIPT" ]; then
  PREV_TRANSCRIPT=$(cat "$LAST_SESSION_TRANSCRIPT")
  PREV_SESSION_ID=$(basename "$PREV_TRANSCRIPT" .jsonl)

  # Check if we already logged this session's compaction
  SUMMARY_FILE="/Volumes/DevDrive/Cache/feedback/session-summary-$PREV_SESSION_ID.md"

  if [ ! -f "$SUMMARY_FILE" ] && [ -f "$PREV_TRANSCRIPT" ]; then
    # Run compaction detection
    COMPACTION_RESULT=$("$HOME/.claude/scripts/detect-compaction.sh" "$PREV_TRANSCRIPT" "$PREV_SESSION_ID" 2>/dev/null)

    COMPACTION_DETECTED=$(echo "$COMPACTION_RESULT" | jq -r '.compaction_detected // false' 2>/dev/null || echo "false")

    if [ "$COMPACTION_DETECTED" = "true" ]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "📝 PREVIOUS SESSION COMPACTION DETECTED"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "Logging session summary..."

      # Log the session summary
      echo "$COMPACTION_RESULT" | "$HOME/.claude/scripts/log-session-summary.sh"

      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
  fi
fi

# First, show project-specific context
$HOME/.claude/hooks/context-aware-start.sh 2>/dev/null

log_dir="$HOME/.claude/logs"
wins_file="$log_dir/session-wins.jsonl"
losses_file="$log_dir/session-losses.jsonl"

# Get timestamp for configurable retention period (default 7 days)
retention_days=${CLAUDARITY_RETENTION_DAYS:-7}  # Default 7 days, configurable
cutoff_date=$(date -u -v-${retention_days}d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "$retention_days days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)

# Count wins and losses from last 2 days
wins_count=0
losses_count=0

if [ -f "$wins_file" ]; then
  wins_count=$(jq -r --arg cutoff "$cutoff_date" 'select(.ts >= $cutoff)' "$wins_file" 2>/dev/null | wc -l | xargs)
fi

if [ -f "$losses_file" ]; then
  losses_count=$(jq -r --arg cutoff "$cutoff_date" 'select(.ts >= $cutoff)' "$losses_file" 2>/dev/null | wc -l | xargs)
fi

# Output summary header
cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 MEMORY (Last $retention_days Days)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 WINS: $wins_count
EOF

# Read and display recent win memory files (last 5)
if [ -f "$wins_file" ] && [ "$wins_count" -gt 0 ]; then
  echo ""
  jq -r --arg cutoff "$cutoff_date" '
    select(.ts >= $cutoff) | .cache_file
  ' "$wins_file" 2>/dev/null | tail -5 | while read -r cache_file; do
    if [ -f "$cache_file" ]; then
      cat "$cache_file"
      echo ""
      echo "---"
      echo ""
    fi
  done
fi

echo ""
echo "💥 LOSSES: $losses_count"

# Read and display recent loss memory files (last 5)
if [ -f "$losses_file" ] && [ "$losses_count" -gt 0 ]; then
  echo ""
  jq -r --arg cutoff "$cutoff_date" '
    select(.ts >= $cutoff) | .cache_file
  ' "$losses_file" 2>/dev/null | tail -5 | while read -r cache_file; do
    if [ -f "$cache_file" ]; then
      cat "$cache_file"
      echo ""
      echo "---"
      echo ""
    fi
  done
fi

cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# ============ CODE PREFERENCES ============
# Show learned code style preferences
prefs_file="$HOME/.claude/logs/code-preferences.json"

if [ -f "$prefs_file" ]; then
  last_updated=$(jq -r '.last_updated' "$prefs_file")

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🧠 CODE PREFERENCES (Updated: ${last_updated:0:10})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Show top preferred technologies
  pref_tech_count=$(jq -r '.technologies.preferred | length' "$prefs_file")
  if [ "$pref_tech_count" -gt 0 ]; then
    echo "✅ PREFERRED TECHNOLOGIES:"
    jq -r '.technologies.preferred[] | "  • " + .' "$prefs_file" | head -5
    echo ""
  fi

  # Show liked patterns
  liked_pattern_count=$(jq -r '.patterns.liked | length' "$prefs_file")
  if [ "$liked_pattern_count" -gt 0 ]; then
    echo "✅ LIKED PATTERNS:"
    jq -r '.patterns.liked[] | "  • " + .' "$prefs_file" | head -5
    echo ""
  fi

  # Show preferred tools
  pref_tools_count=$(jq -r '.tools.preferred | length' "$prefs_file")
  if [ "$pref_tools_count" -gt 0 ]; then
    echo "✅ PREFERRED TOOLS:"
    jq -r '.tools.preferred[] | "  • " + .' "$prefs_file" | head -5
    echo ""
  fi

  # Show avoided items if any
  avoided_tech_count=$(jq -r '.technologies.avoided | length' "$prefs_file")
  disliked_pattern_count=$(jq -r '.patterns.disliked | length' "$prefs_file")
  avoided_tools_count=$(jq -r '.tools.avoided | length' "$prefs_file")

  if [ "$avoided_tech_count" -gt 0 ] || [ "$disliked_pattern_count" -gt 0 ] || [ "$avoided_tools_count" -gt 0 ]; then
    echo "⚠️  AVOID:"
    [ "$avoided_tech_count" -gt 0 ] && jq -r '.technologies.avoided[] | "  • Tech: " + .' "$prefs_file"
    [ "$disliked_pattern_count" -gt 0 ] && jq -r '.patterns.disliked[] | "  • Pattern: " + .' "$prefs_file"
    [ "$avoided_tools_count" -gt 0 ] && jq -r '.tools.avoided[] | "  • Tool: " + .' "$prefs_file"
    echo ""
  fi

  echo "Query: ~/.claude/scripts/query-preferences.sh query <category> <item>"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Run pattern analysis if needed (every 10 new feedback entries)
WIN_COUNT=$(wc -l < "$wins_file" 2>/dev/null || echo "0")
LOSS_COUNT=$(wc -l < "$losses_file" 2>/dev/null || echo "0")
TOTAL_FEEDBACK=$((WIN_COUNT + LOSS_COUNT))

LAST_ANALYSIS_COUNT=0
if [ -f "$HOME/.claude/logs/.last-analysis-count" ]; then
  LAST_ANALYSIS_COUNT=$(cat "$HOME/.claude/logs/.last-analysis-count")
fi

if [ $((TOTAL_FEEDBACK - LAST_ANALYSIS_COUNT)) -ge 10 ]; then
  echo ""
  echo "📊 Running code pattern analysis (new feedback detected)..."
  "$HOME/.claude/scripts/analyze-code-patterns.sh" &>/dev/null &
  echo "$TOTAL_FEEDBACK" > "$HOME/.claude/logs/.last-analysis-count"
fi

# ============ CROSS-PROJECT PATTERNS ============
# Generate fresh aggregation
$HOME/.claude/hooks/aggregate-patterns.sh 2>/dev/null

# Display cross-project insights
patterns_file="$HOME/.claude/logs/cross-project-patterns.jsonl"

if [ -f "$patterns_file" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🌐 CROSS-PROJECT PATTERNS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Global patterns (2+ projects or high confidence)
  global_count=$(jq -r 'select(.global_scope == true)' "$patterns_file" | wc -l | xargs)

  if [ "$global_count" -gt 0 ]; then
    echo "✅ GLOBAL PATTERNS ($global_count)"
    jq -r 'select(.global_scope == true) |
      "  • \(.pattern) (\(.type)) - \(.win_rate * 100 | floor)% win rate across \(.projects | length) project(s) [confidence: \(.confidence * 100 | floor)%]"' \
      "$patterns_file"
  fi

  echo ""

  # Project-specific patterns
  project_count=$(jq -r 'select(.global_scope == false)' "$patterns_file" | wc -l | xargs)

  if [ "$project_count" -gt 0 ]; then
    echo "📍 PROJECT-SPECIFIC PATTERNS ($project_count)"
    jq -r 'select(.global_scope == false) |
      "  • \(.pattern) (\(.type)) - only in \(.projects[0]) [\(.win_count + .loss_count) occurrences]"' \
      "$patterns_file"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
