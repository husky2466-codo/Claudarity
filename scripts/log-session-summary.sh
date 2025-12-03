#!/bin/bash
################################################################################
# log-session-summary.sh
#
# Purpose:
#   Creates session-summary memory files from compaction events
#   Links to wins/losses from that session
#   Updates context index for searchability
#
# Usage:
#   ./log-session-summary.sh <compaction_json>
#   OR
#   ./log-session-summary.sh --summary "..." --session-id "..." [--transcript "..."]
#
# Input:
#   - JSON from detect-compaction.sh (via stdin or file)
#   - OR command-line arguments
#
# Output:
#   - Creates /Volumes/DevDrive/Cache/feedback/session-summary-{session_id}.md
#   - Updates context index
#   - Links to related wins/losses
################################################################################

set -euo pipefail

################################################################################
# PARSE INPUT
################################################################################

SUMMARY_TEXT=""
SESSION_ID=""
TRANSCRIPT_FILE=""
TIMESTAMP=""

# Check if input is coming from stdin or args
if [ $# -eq 0 ]; then
  # Read JSON from stdin
  INPUT_JSON=$(cat)

  SUMMARY_TEXT=$(echo "$INPUT_JSON" | jq -r '.summary // empty')
  SESSION_ID=$(echo "$INPUT_JSON" | jq -r '.session_id // empty')
  TRANSCRIPT_FILE=$(echo "$INPUT_JSON" | jq -r '.transcript_file // empty')
  TIMESTAMP=$(echo "$INPUT_JSON" | jq -r '.timestamp // empty')
elif [ "$1" = "--summary" ]; then
  # Parse command-line arguments
  SUMMARY_TEXT="${2:-}"
  SESSION_ID="${4:-}"
  TRANSCRIPT_FILE="${6:-}"
  TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
else
  echo "ERROR: Invalid usage" >&2
  echo "Usage: $0 <compaction_json>" >&2
  echo "   OR: $0 --summary \"...\" --session-id \"...\" [--transcript \"...\"]" >&2
  exit 1
fi

# Validate required fields
if [ -z "$SUMMARY_TEXT" ]; then
  echo "ERROR: No summary text provided" >&2
  exit 1
fi

if [ -z "$SESSION_ID" ]; then
  # Generate session ID from timestamp if not provided
  SESSION_ID="session-$(date '+%Y%m%d-%H%M%S')"
fi

if [ -z "$TIMESTAMP" ]; then
  TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
fi

################################################################################
# FIND RELATED WINS/LOSSES
################################################################################

LOGS_DIR="$HOME/.claude/logs"
WINS_FILE="$LOGS_DIR/session-wins.jsonl"
LOSSES_FILE="$LOGS_DIR/session-losses.jsonl"

# Get timestamp range for this session (last 24 hours as a safe window)
SESSION_START=$(date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)

# Collect related wins
RELATED_WINS=()
if [ -f "$WINS_FILE" ]; then
  while IFS= read -r line; do
    win_ts=$(echo "$line" | jq -r '.ts')
    win_cache=$(echo "$line" | jq -r '.cache_file')

    # Check if win is within session timeframe
    if [[ "$win_ts" > "$SESSION_START" ]]; then
      RELATED_WINS+=("$win_cache")
    fi
  done < "$WINS_FILE"
fi

# Collect related losses
RELATED_LOSSES=()
if [ -f "$LOSSES_FILE" ]; then
  while IFS= read -r line; do
    loss_ts=$(echo "$line" | jq -r '.ts')
    loss_cache=$(echo "$line" | jq -r '.cache_file')

    # Check if loss is within session timeframe
    if [[ "$loss_ts" > "$SESSION_START" ]]; then
      RELATED_LOSSES+=("$loss_cache")
    fi
  done < "$LOSSES_FILE"
fi

################################################################################
# EXTRACT KEY LEARNINGS FROM SUMMARY
################################################################################

# Parse summary for key learnings, technologies used, patterns, etc.
# This uses simple keyword extraction - could be enhanced with AI later

KEY_TECHNOLOGIES=()
KEY_PATTERNS=()

# Technology keywords
TECH_KEYWORDS=(
  "SwiftUI" "Swift" "Xcode" "iOS" "iPadOS" "SwiftData"
  "React" "TypeScript" "JavaScript" "Node" "npm"
  "Python" "bash" "shell" "git" "github"
  "API" "REST" "GraphQL" "SQL" "SQLite" "Postgres"
  "Docker" "Kubernetes" "AWS" "Azure" "GCP"
)

for tech in "${TECH_KEYWORDS[@]}"; do
  if echo "$SUMMARY_TEXT" | grep -qi "\b$tech\b"; then
    KEY_TECHNOLOGIES+=("$tech")
  fi
done

# Pattern keywords
PATTERN_KEYWORDS=(
  "refactor" "optimize" "debug" "fix" "implement" "design"
  "architecture" "testing" "deployment" "security" "authentication"
  "database" "migration" "integration" "automation"
)

for pattern in "${PATTERN_KEYWORDS[@]}"; do
  if echo "$SUMMARY_TEXT" | grep -qi "\b$pattern\b"; then
    KEY_PATTERNS+=("$pattern")
  fi
done

################################################################################
# CREATE SESSION SUMMARY FILE
################################################################################

CACHE_DIR="/Volumes/DevDrive/Cache/feedback"
mkdir -p "$CACHE_DIR"

SUMMARY_FILE="$CACHE_DIR/session-summary-$SESSION_ID.md"

# Get human-readable timestamp
HUMAN_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TIMESTAMP" "+%B %d, %Y at %I:%M %p" 2>/dev/null || echo "$TIMESTAMP")

# Get project name from transcript path if available
PROJECT_NAME="unknown"
if [ -n "$TRANSCRIPT_FILE" ]; then
  PROJECT_NAME=$(basename "$(dirname "$TRANSCRIPT_FILE")" | sed 's/^-Users-USERNAME-//' | sed 's/-/ /g')
fi

# Build wins section
WINS_SECTION=""
if [ ${#RELATED_WINS[@]} -gt 0 ]; then
  WINS_SECTION="## Related Wins (${#RELATED_WINS[@]})

"
  for win_file in "${RELATED_WINS[@]}"; do
    if [ -f "$win_file" ]; then
      win_pattern=$(grep -m1 "^**Pattern:**" "$win_file" 2>/dev/null | sed 's/\*\*Pattern:\*\* //' || echo "win")
      WINS_SECTION+="- [$win_pattern]($win_file)
"
    fi
  done
  WINS_SECTION+="
"
fi

# Build losses section
LOSSES_SECTION=""
if [ ${#RELATED_LOSSES[@]} -gt 0 ]; then
  LOSSES_SECTION="## Related Losses (${#RELATED_LOSSES[@]})

"
  for loss_file in "${RELATED_LOSSES[@]}"; do
    if [ -f "$loss_file" ]; then
      loss_pattern=$(grep -m1 "^**Pattern:**" "$loss_file" 2>/dev/null | sed 's/\*\*Pattern:\*\* //' || echo "loss")
      LOSSES_SECTION+="- [$loss_pattern]($loss_file)
"
    fi
  done
  LOSSES_SECTION+="
"
fi

# Build technologies section
TECH_SECTION=""
if [ ${#KEY_TECHNOLOGIES[@]} -gt 0 ]; then
  TECH_SECTION="## Technologies

"
  for tech in "${KEY_TECHNOLOGIES[@]}"; do
    TECH_SECTION+="- $tech
"
  done
  TECH_SECTION+="
"
fi

# Build patterns section
PATTERNS_SECTION=""
if [ ${#KEY_PATTERNS[@]} -gt 0 ]; then
  PATTERNS_SECTION="## Key Activities

"
  for pattern in "${KEY_PATTERNS[@]}"; do
    PATTERNS_SECTION+="- $pattern
"
  done
  PATTERNS_SECTION+="
"
fi

# Write the summary file
cat > "$SUMMARY_FILE" << EOF
# Session Summary

**Session ID:** $SESSION_ID
**Time:** $HUMAN_TS
**Project:** $PROJECT_NAME

---

## AI-Generated Summary

$SUMMARY_TEXT

---

$WINS_SECTION$LOSSES_SECTION$TECH_SECTION$PATTERNS_SECTION
## Session Metadata

- **Wins:** ${#RELATED_WINS[@]}
- **Losses:** ${#RELATED_LOSSES[@]}
- **Technologies:** ${#KEY_TECHNOLOGIES[@]}
- **Summary Length:** ${#SUMMARY_TEXT} characters
- **Transcript:** $TRANSCRIPT_FILE

---

*This session summary was automatically captured by Claudarity's compaction detection system.*
EOF

################################################################################
# UPDATE CONTEXT INDEX
################################################################################

CONTEXT_INDEX="$HOME/.claude/logs/context-index.jsonl"
mkdir -p "$(dirname "$CONTEXT_INDEX")"

# Add entry to context index (compact JSON - one line per entry)
jq -nc \
  --arg type "session-summary" \
  --arg session_id "$SESSION_ID" \
  --arg timestamp "$TIMESTAMP" \
  --arg file "$SUMMARY_FILE" \
  --arg project "$PROJECT_NAME" \
  --argjson wins "${#RELATED_WINS[@]}" \
  --argjson losses "${#RELATED_LOSSES[@]}" \
  --arg summary "${SUMMARY_TEXT:0:500}" \
  '{
    type: $type,
    session_id: $session_id,
    timestamp: $timestamp,
    file: $file,
    project: $project,
    wins: $wins,
    losses: $losses,
    summary_preview: $summary,
    searchable: true
  }' >> "$CONTEXT_INDEX"

################################################################################
# OUTPUT SUCCESS
################################################################################

echo ""
echo "✅ Session summary created: $SUMMARY_FILE"
echo ""
echo "📊 Session Stats:"
echo "   - Wins: ${#RELATED_WINS[@]}"
echo "   - Losses: ${#RELATED_LOSSES[@]}"
echo "   - Technologies: ${#KEY_TECHNOLOGIES[@]}"
echo "   - Patterns: ${#KEY_PATTERNS[@]}"
echo ""

# Output JSON for programmatic use
jq -n \
  --arg file "$SUMMARY_FILE" \
  --arg session_id "$SESSION_ID" \
  --argjson wins "${#RELATED_WINS[@]}" \
  --argjson losses "${#RELATED_LOSSES[@]}" \
  '{
    success: true,
    summary_file: $file,
    session_id: $session_id,
    stats: {
      wins: $wins,
      losses: $losses
    }
  }'

exit 0
