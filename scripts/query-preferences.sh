#!/bin/bash
# Query Code Preferences - Check learned preferences before making decisions

PREFS_FILE="$HOME/.claude/logs/code-preferences.json"

# Check if preferences exist
if [ ! -f "$PREFS_FILE" ]; then
  echo "No code preferences found. Run analyze-code-patterns.sh first."
  exit 1
fi

# Function to query a specific category
query_category() {
  local category="$1"
  local item="$2"

  case "$category" in
    "tech"|"technology"|"technologies")
      jq -r --arg item "$item" '
        if (.technologies.preferred | index($item)) then
          "PREFERRED: \($item) has positive history"
        elif (.technologies.avoided | index($item)) then
          "AVOIDED: \($item) has negative history"
        else
          "NEUTRAL: No strong preference for \($item)"
        end
      ' "$PREFS_FILE"

      # Show confidence if available
      jq -r --arg item "$item" '
        if .confidence_scores.technologies[$item] then
          .confidence_scores.technologies[$item] |
          "  Win rate: \(.win_rate * 100)% | Confidence: \(.confidence * 100)% | Total uses: \(.total_occurrences)"
        else
          ""
        end
      ' "$PREFS_FILE"
      ;;

    "pattern"|"patterns")
      jq -r --arg item "$item" '
        if (.patterns.liked | index($item)) then
          "LIKED: \($item) pattern has worked well"
        elif (.patterns.disliked | index($item)) then
          "DISLIKED: \($item) pattern has caused issues"
        else
          "NEUTRAL: No strong preference for \($item)"
        end
      ' "$PREFS_FILE"

      jq -r --arg item "$item" '
        if .confidence_scores.patterns[$item] then
          .confidence_scores.patterns[$item] |
          "  Win rate: \(.win_rate * 100)% | Confidence: \(.confidence * 100)% | Total uses: \(.total_occurrences)"
        else
          ""
        end
      ' "$PREFS_FILE"
      ;;

    "tool"|"tools")
      jq -r --arg item "$item" '
        if (.tools.preferred | index($item)) then
          "PREFERRED: \($item) tool has been effective"
        elif (.tools.avoided | index($item)) then
          "AVOIDED: \($item) tool has had issues"
        else
          "NEUTRAL: No strong preference for \($item)"
        end
      ' "$PREFS_FILE"

      jq -r --arg item "$item" '
        if .confidence_scores.tools[$item] then
          .confidence_scores.tools[$item] |
          "  Win rate: \(.win_rate * 100)% | Confidence: \(.confidence * 100)% | Total uses: \(.total_occurrences)"
        else
          ""
        end
      ' "$PREFS_FILE"
      ;;

    *)
      echo "Unknown category: $category"
      echo "Valid categories: tech, pattern, tool"
      exit 1
      ;;
  esac
}

# Show all preferences
show_all() {
  echo "=== Code Preferences Summary ==="
  echo ""

  local last_updated=$(jq -r '.last_updated' "$PREFS_FILE")
  echo "Last updated: $last_updated"
  echo ""

  echo "--- Preferred Technologies ---"
  jq -r '.technologies.preferred[]' "$PREFS_FILE" 2>/dev/null | while read -r tech; do
    local conf=$(jq -r --arg t "$tech" '.confidence_scores.technologies[$t].confidence // 0' "$PREFS_FILE")
    local wins=$(jq -r --arg t "$tech" '.confidence_scores.technologies[$t].win_count // 0' "$PREFS_FILE")
    printf "  ✓ %-20s (confidence: %.0f%%, wins: %d)\n" "$tech" "$(echo "$conf * 100" | bc)" "$wins"
  done
  echo ""

  echo "--- Avoided Technologies ---"
  jq -r '.technologies.avoided[]' "$PREFS_FILE" 2>/dev/null | while read -r tech; do
    local conf=$(jq -r --arg t "$tech" '.confidence_scores.technologies[$t].confidence // 0' "$PREFS_FILE")
    local losses=$(jq -r --arg t "$tech" '.confidence_scores.technologies[$t].loss_count // 0' "$PREFS_FILE")
    printf "  ✗ %-20s (confidence: %.0f%%, losses: %d)\n" "$tech" "$(echo "$conf * 100" | bc)" "$losses"
  done
  echo ""

  echo "--- Liked Patterns ---"
  jq -r '.patterns.liked[]' "$PREFS_FILE" 2>/dev/null | while read -r pattern; do
    local conf=$(jq -r --arg p "$pattern" '.confidence_scores.patterns[$p].confidence // 0' "$PREFS_FILE")
    local wins=$(jq -r --arg p "$pattern" '.confidence_scores.patterns[$p].win_count // 0' "$PREFS_FILE")
    printf "  ✓ %-30s (confidence: %.0f%%, wins: %d)\n" "$pattern" "$(echo "$conf * 100" | bc)" "$wins"
  done
  echo ""

  echo "--- Disliked Patterns ---"
  jq -r '.patterns.disliked[]' "$PREFS_FILE" 2>/dev/null | while read -r pattern; do
    local conf=$(jq -r --arg p "$pattern" '.confidence_scores.patterns[$p].confidence // 0' "$PREFS_FILE")
    local losses=$(jq -r --arg p "$pattern" '.confidence_scores.patterns[$p].loss_count // 0' "$PREFS_FILE")
    printf "  ✗ %-30s (confidence: %.0f%%, losses: %d)\n" "$pattern" "$(echo "$conf * 100" | bc)" "$losses"
  done
  echo ""

  echo "--- Preferred Tools ---"
  jq -r '.tools.preferred[]' "$PREFS_FILE" 2>/dev/null | while read -r tool; do
    local conf=$(jq -r --arg t "$tool" '.confidence_scores.tools[$t].confidence // 0' "$PREFS_FILE")
    local wins=$(jq -r --arg t "$tool" '.confidence_scores.tools[$t].win_count // 0' "$PREFS_FILE")
    printf "  ✓ %-15s (confidence: %.0f%%, uses in wins: %d)\n" "$tool" "$(echo "$conf * 100" | bc)" "$wins"
  done
  echo ""
}

# Show raw JSON
show_raw() {
  cat "$PREFS_FILE" | jq '.'
}

# Main CLI
case "${1:-}" in
  "")
    show_all
    ;;
  "query")
    if [ $# -lt 3 ]; then
      echo "Usage: $0 query <category> <item>"
      echo "Example: $0 query tech 'SwiftUI'"
      exit 1
    fi
    query_category "$2" "$3"
    ;;
  "raw")
    show_raw
    ;;
  "help"|"-h"|"--help")
    cat <<EOF
Code Preferences Query Tool

Usage:
  $0              Show all preferences summary
  $0 query <category> <item>   Query specific preference
  $0 raw          Show raw JSON data
  $0 help         Show this help

Categories:
  tech, technology, technologies
  pattern, patterns
  tool, tools

Examples:
  $0 query tech "SwiftUI"
  $0 query pattern "hook"
  $0 query tool "Edit"
EOF
    ;;
  *)
    echo "Unknown command: $1"
    echo "Try: $0 help"
    exit 1
    ;;
esac
