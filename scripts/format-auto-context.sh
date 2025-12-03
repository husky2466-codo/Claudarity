#!/bin/bash
################################################################################
# format-auto-context.sh
#
# Purpose: Format auto-context search results for user display
#
# Usage:
#   cat search-results.txt | ./format-auto-context.sh [max_results]
#
# Input: Raw output from context-search.sh
# Output: Formatted, concise context for auto-injection
################################################################################

set -euo pipefail

# ============ CONFIGURATION ============
MAX_RESULTS="${1:-3}"
TEMP_INPUT=$(mktemp)

# Read all input into temp file
cat > "$TEMP_INPUT"

# Check if input is empty
if [ ! -s "$TEMP_INPUT" ]; then
  rm -f "$TEMP_INPUT"
  exit 0
fi

# ============ PARSE AND FORMAT ============

echo ""
echo "╭─────────────────────────────────────────────────────────────────╮"
echo "│  💭 Relevant Past Experience (Auto-Context)                    │"
echo "╰─────────────────────────────────────────────────────────────────╯"
echo ""

# Count total results
TOTAL_RESULTS=$(grep -c "^━━━━━━━━━━" "$TEMP_INPUT" 2>/dev/null || echo 0)

if [ "$TOTAL_RESULTS" -eq 0 ]; then
  echo "   No relevant context found."
  echo ""
  rm -f "$TEMP_INPUT"
  exit 0
fi

# Extract and display results (limit to MAX_RESULTS)
COUNT=0
IN_RESULT=false
CURRENT_RESULT=""

while IFS= read -r line; do
  # Detect result boundaries
  if echo "$line" | grep -q "^━━━━━━━━━━"; then
    IN_RESULT=true
    continue
  fi

  if [ "$IN_RESULT" = true ]; then
    if echo "$line" | grep -q "^---$"; then
      # End of current result
      if [ "$COUNT" -lt "$MAX_RESULTS" ]; then
        echo "$CURRENT_RESULT"
        echo ""
        COUNT=$((COUNT + 1))
      fi
      CURRENT_RESULT=""
      IN_RESULT=false
    else
      # Accumulate result lines
      CURRENT_RESULT="$CURRENT_RESULT$line"$'\n'
    fi
  fi
done < "$TEMP_INPUT"

# Show if more results available
if [ "$TOTAL_RESULTS" -gt "$MAX_RESULTS" ]; then
  REMAINING=$((TOTAL_RESULTS - MAX_RESULTS))
  echo "   ℹ️  $REMAINING more result(s) available. Use /gomemory for full search."
  echo ""
fi

echo "─────────────────────────────────────────────────────────────────"
echo ""

# Cleanup
rm -f "$TEMP_INPUT"

exit 0
