#!/bin/bash
################################################################################
# context-aware-start.sh
#
# Purpose:
#   Enhanced session start that shows project-specific context
#   from past wins/losses in the current project
#
# Triggers: Session start
#
################################################################################

set -euo pipefail

# Get current project
CWD="${1:-$(pwd)}"
PROJECT=$(basename "$CWD" 2>/dev/null || echo "unknown")

DB_PATH="$HOME/.claude/claudarity.db"

# Configure retention period (default 7 days, configurable via env)
RETENTION_DAYS=${CLAUDARITY_RETENTION_DAYS:-7}

# ============ PROJECT-SPECIFIC CONTEXT ============
# Find recent wins/losses for THIS project from SQLite database
PROJECT_WINS=0
PROJECT_LOSSES=0
RECENT_PROJECT_WINS_DATA=""
RECENT_PROJECT_LOSSES_DATA=""

# Calculate timestamp for retention period
TWO_DAYS_AGO=$(date -u -v-${RETENTION_DAYS}d "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "$RETENTION_DAYS days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)

if [ -f "$DB_PATH" ]; then
  # Count wins for this project
  PROJECT_WINS=$(sqlite3 "$DB_PATH" "
    SELECT COUNT(*)
    FROM feedback_entries
    WHERE project = '$PROJECT' AND type = 'win'
  " 2>/dev/null || echo "0")

  # Count losses for this project
  PROJECT_LOSSES=$(sqlite3 "$DB_PATH" "
    SELECT COUNT(*)
    FROM feedback_entries
    WHERE project = '$PROJECT' AND type = 'loss'
  " 2>/dev/null || echo "0")

  # Get last 5 wins for this project from retention period with cache files
  RECENT_PROJECT_WINS_DATA=$(sqlite3 "$DB_PATH" -separator '|' "
    SELECT cache_file, pattern, ts
    FROM feedback_entries
    WHERE project = '$PROJECT'
      AND type = 'win'
      AND cache_file IS NOT NULL
      AND ts >= '$TWO_DAYS_AGO'
    ORDER BY ts DESC
    LIMIT 5
  " 2>/dev/null)

  # Get last 5 losses for this project from retention period with cache files
  RECENT_PROJECT_LOSSES_DATA=$(sqlite3 "$DB_PATH" -separator '|' "
    SELECT cache_file, pattern, ts
    FROM feedback_entries
    WHERE project = '$PROJECT'
      AND type = 'loss'
      AND cache_file IS NOT NULL
      AND ts >= '$TWO_DAYS_AGO'
    ORDER BY ts DESC
    LIMIT 5
  " 2>/dev/null)
fi

# Only show if there's project history
if [ "$PROJECT_WINS" -gt 0 ] || [ "$PROJECT_LOSSES" -gt 0 ]; then
  cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 PROJECT MEMORY: $PROJECT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 Wins: $PROJECT_WINS | 💥 Losses: $PROJECT_LOSSES

EOF

  # Show recent wins
  if [ -n "$RECENT_PROJECT_WINS_DATA" ]; then
    echo "✅ RECENT WINS (Last $RETENTION_DAYS Days):"
    echo ""

    echo "$RECENT_PROJECT_WINS_DATA" | while IFS='|' read -r cache_file pattern ts; do
      # Format timestamp
      time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%b %d at %I:%M %p" 2>/dev/null || echo "$ts")

      echo "  • $pattern - $time"

      # Extract AI summary (first line only) from cache file if it exists
      if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        summary=$(sed -n '/## AI Summary/,/## Quick Context/p' "$cache_file" | \
          sed '1d;$d' | \
          head -1 | \
          sed 's/^[[:space:]]*//')

        if [ -n "$summary" ]; then
          echo "    ↳ $summary"
        fi
      fi
      echo ""
    done
  fi

  # Show recent losses
  if [ -n "$RECENT_PROJECT_LOSSES_DATA" ]; then
    echo "❌ RECENT LOSSES (Last $RETENTION_DAYS Days - learn from these):"
    echo ""

    echo "$RECENT_PROJECT_LOSSES_DATA" | while IFS='|' read -r cache_file pattern ts; do
      # Format timestamp
      time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%b %d at %I:%M %p" 2>/dev/null || echo "$ts")

      echo "  • $pattern - $time"

      # Extract AI summary (first line only) from cache file if it exists
      if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        summary=$(sed -n '/## AI Summary/,/## Quick Context/p' "$cache_file" | \
          sed '1d;$d' | \
          head -1 | \
          sed 's/^[[:space:]]*//')

        if [ -n "$summary" ]; then
          echo "    ↳ $summary"
        fi
      fi
      echo ""
    done
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "💡 TIP: Use /gomemory <query> to search for specific past experiences"
  echo ""
fi

exit 0
