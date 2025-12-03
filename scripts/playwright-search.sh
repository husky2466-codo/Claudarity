#!/bin/bash
################################################################################
# playwright-search.sh
#
# Purpose:
#   Search playwright scraper project data, documentation, logs, and reports
#   in the COOLFORK project directory
#
# Usage:
#   ./playwright-search.sh "search terms" [limit]
#
# Searches through:
#   - Documentation files (.md)
#   - Log files (.log)
#   - Scraped data (.json)
#   - Test output
#   - Implementation notes
#
################################################################################

set -euo pipefail

# ============ PATHS ============
COOLFORK_PATH="/Volumes/DevDrive/Projects/COOLFORK"
WEB_SCRAPER_PATH="$COOLFORK_PATH/Video Excel Database/web-scraper"

# ============ PARSE ARGUMENTS ============
QUERY="${1:-}"
LIMIT="${2:-10}"

if [ -z "$QUERY" ]; then
  echo "Usage: $0 <search_terms> [limit]"
  exit 1
fi

# ============ CHECK IF PATH EXISTS ============
if [ ! -d "$COOLFORK_PATH" ]; then
  echo "❌ ERROR: COOLFORK directory not found at $COOLFORK_PATH"
  exit 1
fi

# ============ DISPLAY HEADER ============
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎭 SEARCHING PLAYWRIGHT SCRAPER DATA FOR: $QUERY"
echo "📁 Location: $COOLFORK_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============ SEARCH FUNCTION ============
search_playwright_data() {
  local search_lower=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
  local temp_results=$(mktemp)
  local found=0

  # Function to calculate relevance score
  calculate_relevance() {
    local file_path=$1
    local score=0

    if [ ! -f "$file_path" ]; then
      echo "0"
      return
    fi

    local content=$(cat "$file_path" 2>/dev/null | tr '[:upper:]' '[:lower:]')

    # Count matches for each search term
    for term in $search_lower; do
      local count=$(echo "$content" | grep -o "$term" | wc -l | xargs)
      score=$((score + count))
    done

    # Bonus points for file type
    case "$file_path" in
      *IMPLEMENTATION*.md) score=$((score + 20)) ;;
      *README.md) score=$((score + 15)) ;;
      *COMPONENTS.md) score=$((score + 15)) ;;
      *.log) score=$((score + 10)) ;;
      *report*.md) score=$((score + 10)) ;;
    esac

    echo "$score"
  }

  # Get file type icon
  get_file_icon() {
    local file_path=$1
    case "$file_path" in
      *.md) echo "📄" ;;
      *.log) echo "📋" ;;
      *.json) echo "📦" ;;
      *.js|*.ts) echo "⚙️" ;;
      *) echo "📁" ;;
    esac
  }

  # Get file type label
  get_file_type() {
    local file_path=$1
    case "$file_path" in
      *IMPLEMENTATION*.md) echo "Implementation Doc" ;;
      *COMPONENTS*.md) echo "Components Doc" ;;
      *README.md) echo "README" ;;
      *QUICK_START.md) echo "Quick Start Guide" ;;
      *report*.md) echo "Scraper Report" ;;
      *backup*.md) echo "Data Backup" ;;
      *combined.log) echo "Combined Logs" ;;
      *errors.log) echo "Error Logs" ;;
      *test*.log) echo "Test Output" ;;
      *.json) echo "Scraped Data" ;;
      *.js) echo "Test Script" ;;
      *) echo "File" ;;
    esac
  }

  # Search markdown files (documentation)
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local score=$(calculate_relevance "$file")

    if [ "$score" -gt 0 ]; then
      echo "$score|$file" >> "$temp_results"
    fi
  done < <(find "$COOLFORK_PATH" -type f -name "*.md" -not -path "*/node_modules/*" 2>/dev/null)

  # Search log files
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local score=$(calculate_relevance "$file")

    if [ "$score" -gt 0 ]; then
      echo "$score|$file" >> "$temp_results"
    fi
  done < <(find "$COOLFORK_PATH" -type f -name "*.log" -not -path "*/node_modules/*" 2>/dev/null)

  # Search JSON data files (if they exist in data directories)
  if [ -d "$WEB_SCRAPER_PATH/data" ]; then
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      local score=$(calculate_relevance "$file")

      if [ "$score" -gt 0 ]; then
        echo "$score|$file" >> "$temp_results"
      fi
    done < <(find "$WEB_SCRAPER_PATH/data" -type f -name "*.json" 2>/dev/null | head -20)
  fi

  # Search test scripts
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local score=$(calculate_relevance "$file")

    if [ "$score" -gt 0 ]; then
      echo "$score|$file" >> "$temp_results"
    fi
  done < <(find "$WEB_SCRAPER_PATH" -maxdepth 1 -type f -name "test-*.js" 2>/dev/null)

  # Display results sorted by relevance
  if [ -f "$temp_results" ] && [ -s "$temp_results" ]; then
    sort -t'|' -k1 -rn "$temp_results" | head -n "$LIMIT" | while IFS='|' read -r score file_path; do
      found=$((found + 1))

      local icon=$(get_file_icon "$file_path")
      local file_type=$(get_file_type "$file_path")
      local file_name=$(basename "$file_path")
      local rel_path=$(echo "$file_path" | sed "s|$COOLFORK_PATH/||")

      # Get file modified time
      local modified=$(stat -f "%Sm" -t "%b %d at %I:%M %p" "$file_path" 2>/dev/null || echo "Unknown")

      echo "$icon $file_type - $file_name"
      echo "   📍 Path: $rel_path"
      echo "   🕐 Modified: $modified"
      echo "   📊 Relevance Score: $score"
      echo ""

      # Show preview of matches
      echo "   🔍 Matching content:"
      grep -i -C 2 "$QUERY" "$file_path" 2>/dev/null | head -10 | sed 's/^/      /' || echo "      (Binary or unreadable content)"
      echo ""
      echo "   📄 Full file: $file_path"
      echo ""
      echo "---"
      echo ""
    done
    rm -f "$temp_results"
    return 0
  else
    rm -f "$temp_results"
    return 1
  fi
}

# ============ EXECUTE SEARCH ============
if ! search_playwright_data; then
  echo "❌ No matches found for: $QUERY"
  echo ""
  echo "💡 Try searching for:"
  echo "   - scraper, playwright, fullcompass, christie"
  echo "   - video, broadcast, lenses, projector"
  echo "   - implementation, components, test"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
