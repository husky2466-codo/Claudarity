#!/bin/bash
################################################################################
# context-search.sh (UNIFIED)
#
# Purpose:
#   Unified context search for Claudarity memory system
#   Consolidates 4 previous scripts into one robust solution
#
# Usage:
#   ./context-search.sh "search terms" [limit]
#   ./context-search.sh --query "authentication" --project "MyApp" --limit 5
#
# Search Methods (in order of preference):
#   1. SQLite FTS5 (fastest, most accurate)
#   2. Index-based with scoring (fast, good ranking)
#   3. Grep-based fallback (slowest, works without index)
#
# Arguments:
#   Simple mode: <search_terms> [limit]
#   Advanced mode: --query <terms> [--project <name>] [--files <patterns>]
#                  [--context <text>] [--task-type <type>] [--limit <n>]
#
################################################################################

set -euo pipefail

# ============ PATHS ============
DB_PATH="$HOME/.claude/claudarity.db"
INDEX_FILE="$HOME/.claude/logs/context-index.jsonl"
LOGS_DIR="$HOME/.claude/logs"
WINS_FILE="$LOGS_DIR/session-wins.jsonl"
LOSSES_FILE="$LOGS_DIR/session-losses.jsonl"

# ============ PARSE ARGUMENTS ============
QUERY=""
PROJECT=""
FILES=""
CONTEXT=""
TASK_TYPE=""
LIMIT=5

# Check if using simple syntax (positional args) or advanced (flags)
if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; then
  # Simple mode: context-search.sh "search terms" [limit]
  QUERY="${1:-}"
  LIMIT="${2:-5}"
else
  # Advanced mode with flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      --query)
        QUERY="$2"
        shift 2
        ;;
      --project)
        PROJECT="$2"
        shift 2
        ;;
      --files)
        FILES="$2"
        shift 2
        ;;
      --context)
        CONTEXT="$2"
        shift 2
        ;;
      --task-type)
        TASK_TYPE="$2"
        shift 2
        ;;
      --limit)
        LIMIT="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: $0 <search_terms> [limit]" >&2
        echo "   or: $0 --query <terms> [--project <name>] [--files <patterns>] [--limit <n>]" >&2
        exit 1
        ;;
    esac
  done
fi

# Validate we have something to search for
if [ -z "$QUERY" ] && [ -z "$FILES" ] && [ -z "$CONTEXT" ]; then
  echo "Usage: $0 <search_terms> [limit]"
  echo "   or: $0 --query <terms> [--project <name>] [--files <patterns>] [--limit <n>]"
  exit 1
fi

# ============ BUILD SEARCH TERMS ============
SEARCH_TERMS="$QUERY"
[ -n "$FILES" ] && SEARCH_TERMS="$SEARCH_TERMS $FILES"
[ -n "$CONTEXT" ] && SEARCH_TERMS="$SEARCH_TERMS $CONTEXT"
SEARCH_TERMS=$(echo "$SEARCH_TERMS" | xargs) # trim whitespace

# ============ DISPLAY HEADER ============
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 SEARCHING MEMORY FOR: $SEARCH_TERMS"
[ -n "$PROJECT" ] && echo "   Project filter: $PROJECT"
[ -n "$TASK_TYPE" ] && echo "   Task type: $TASK_TYPE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============ SEARCH METHOD 1: SQLITE FTS5 ============
# Fastest and most accurate - uses full-text search index
search_with_sqlite() {
  local found=0

  if [ ! -f "$DB_PATH" ]; then
    return 1
  fi

  # FTS5 query - searches user_message, context_summary, and ai_summary
  while IFS='|' read -r feedback_id ts project pattern type cache_file; do
    [ "$found" -ge "$LIMIT" ] && break
    [ -z "$feedback_id" ] && continue

    # Apply project filter if specified
    if [ -n "$PROJECT" ] && [ "$project" != "$PROJECT" ]; then
      continue
    fi

    found=$((found + 1))

    # Format timestamp
    formatted_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%b %d at %I:%M %p" 2>/dev/null || echo "$ts")

    # Type icon
    if [ "$type" = "win" ]; then
      icon="✅"
      label="WIN"
    else
      icon="❌"
      label="LOSS"
    fi

    echo "$icon $label - $project - $formatted_ts"
    echo "   Pattern: \"$pattern\""
    echo ""

    # Show cached summary if available
    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
      echo "   📝 What happened:"
      sed -n '/## AI Summary/,/## Quick Context/p' "$cache_file" |
        sed '1d;$d' |
        head -5 |
        sed 's/^/   /' |
        fold -s -w 70 |
        sed 's/^/   /'
      echo ""
      echo "   📄 Full memory: $cache_file"
    fi
    echo ""
    echo "---"
    echo ""
  done < <(sqlite3 "$DB_PATH" -separator '|' "
    SELECT
      fe.id,
      fe.ts,
      fe.project,
      fe.pattern,
      fe.type,
      fe.cache_file
    FROM feedback_fts
    INNER JOIN feedback_entries fe ON feedback_fts.feedback_id = fe.id
    WHERE feedback_fts MATCH '$SEARCH_TERMS'
    ORDER BY rank
    LIMIT $LIMIT
  " 2>/dev/null)

  return $([ "$found" -gt 0 ] && echo 0 || echo 1)
}

# ============ SEARCH METHOD 2: INDEX-BASED WITH SCORING ============
# Fast with good relevance ranking - uses pre-built index
search_with_index() {
  # Build index if it doesn't exist
  if [ ! -f "$INDEX_FILE" ]; then
    if [ -x "$HOME/.claude/hooks/build-context-index.sh" ]; then
      "$HOME/.claude/hooks/build-context-index.sh" 2>/dev/null || true
    fi
  fi

  if [ ! -f "$INDEX_FILE" ]; then
    return 1
  fi

  # Normalize query
  local query_lower=$(echo "$SEARCH_TERMS" | tr '[:upper:]' '[:lower:]')
  local query_terms=$(echo "$query_lower" | tr ' ' '\n')

  # Search index and score results
  local temp_results=$(mktemp)

  while IFS= read -r entry; do
    local score=0

    # Extract fields
    local keywords=$(echo "$entry" | jq -r '.keywords[]' 2>/dev/null | tr '\n' ' ')
    local task_type=$(echo "$entry" | jq -r '.task_type')
    local project_name=$(echo "$entry" | jq -r '.project')
    local summary=$(echo "$entry" | jq -r '.summary')
    local file_patterns=$(echo "$entry" | jq -r '.file_patterns[]' 2>/dev/null | tr '\n' ' ')

    # Apply project filter
    if [ -n "$PROJECT" ] && [ "$project_name" != "$PROJECT" ]; then
      continue
    fi

    # Score based on keyword matches
    for term in $query_terms; do
      # Keyword match (highest weight)
      if echo "$keywords" | grep -qw "$term"; then
        score=$((score + 20))
      fi

      # Summary match
      if echo "$summary" | tr '[:upper:]' '[:lower:]' | grep -qw "$term"; then
        score=$((score + 10))
      fi

      # File pattern match
      if echo "$file_patterns" | grep -qw "$term"; then
        score=$((score + 5))
      fi
    done

    # Task type match bonus
    if [ -n "$TASK_TYPE" ] && [ "$task_type" = "$TASK_TYPE" ]; then
      score=$((score + 10))
    fi

    # Only include if score > 0
    if [ "$score" -gt 0 ]; then
      echo "$score|$entry" >> "$temp_results"
    fi
  done < "$INDEX_FILE"

  # Display results
  if [ -f "$temp_results" ] && [ -s "$temp_results" ]; then
    local count=0
    sort -t'|' -k1 -rn "$temp_results" | head -n "$LIMIT" | while IFS='|' read -r score entry; do
      count=$((count + 1))

      local type=$(echo "$entry" | jq -r '.type')
      local ts=$(echo "$entry" | jq -r '.ts')
      local project_name=$(echo "$entry" | jq -r '.project')
      local pattern=$(echo "$entry" | jq -r '.pattern')
      local summary=$(echo "$entry" | jq -r '.summary')
      local task_type=$(echo "$entry" | jq -r '.task_type')
      local cache_file=$(echo "$entry" | jq -r '.cache_file')
      local keywords=$(echo "$entry" | jq -r '.keywords | join(", ")')

      # Format timestamp
      local formatted_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%b %d at %I:%M %p" 2>/dev/null || echo "$ts")

      # Type icon
      if [ "$type" = "win" ]; then
        icon="✅"
        label="WIN"
      else
        icon="❌"
        label="LOSS"
      fi

      echo "$icon $label - $project_name - $formatted_ts"
      echo "   Pattern: \"$pattern\" | Task: $task_type | Relevance: $score"
      echo ""
      echo "   📝 Summary:"
      echo "   $summary" | fold -s -w 70 | sed 's/^/   /'
      echo ""
      echo "   🏷️  Keywords: $keywords"
      echo "   📄 Full memory: $cache_file"
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

# ============ SEARCH METHOD 3: GREP-BASED FALLBACK ============
# Slowest but works without any index
search_with_grep() {
  local search_lower=$(echo "$SEARCH_TERMS" | tr '[:upper:]' '[:lower:]')

  # Function to calculate relevance score
  calculate_relevance() {
    local memory_file=$1
    local score=0

    if [ ! -f "$memory_file" ]; then
      echo "0"
      return
    fi

    local content=$(cat "$memory_file" | tr '[:upper:]' '[:lower:]')

    # Score based on search term matches
    for term in $search_lower; do
      local count=$(echo "$content" | grep -o "$term" | wc -l | xargs)
      score=$((score + count * 10))
    done

    # Bonus points for project match
    if [ -n "$PROJECT" ]; then
      if echo "$content" | grep -q "project.*$PROJECT"; then
        score=$((score + 20))
      fi
    fi

    echo "$score"
  }

  # Collect all memories with relevance scores
  local temp_results=$(mktemp)

  # Search wins
  if [ -f "$WINS_FILE" ]; then
    while IFS= read -r line; do
      local cache_file=$(echo "$line" | jq -r '.cache_file // empty')

      if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        local score=$(calculate_relevance "$cache_file")

        if [ "$score" -gt 0 ]; then
          local ts=$(echo "$line" | jq -r '.ts')
          local project=$(echo "$line" | jq -r '.project')
          local pattern=$(echo "$line" | jq -r '.matched')

          # Apply project filter
          if [ -n "$PROJECT" ] && [ "$project" != "$PROJECT" ]; then
            continue
          fi

          echo "$score|win|$ts|$project|$pattern|$cache_file" >> "$temp_results"
        fi
      fi
    done < "$WINS_FILE"
  fi

  # Search losses
  if [ -f "$LOSSES_FILE" ]; then
    while IFS= read -r line; do
      local cache_file=$(echo "$line" | jq -r '.cache_file // empty')

      if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        local score=$(calculate_relevance "$cache_file")

        if [ "$score" -gt 0 ]; then
          local ts=$(echo "$line" | jq -r '.ts')
          local project=$(echo "$line" | jq -r '.project')
          local pattern=$(echo "$line" | jq -r '.matched')

          # Apply project filter
          if [ -n "$PROJECT" ] && [ "$project" != "$PROJECT" ]; then
            continue
          fi

          echo "$score|loss|$ts|$project|$pattern|$cache_file" >> "$temp_results"
        fi
      fi
    done < "$LOSSES_FILE"
  fi

  # Display results
  if [ -f "$temp_results" ] && [ -s "$temp_results" ]; then
    sort -t'|' -k1 -rn "$temp_results" | head -n "$LIMIT" | while IFS='|' read -r score type ts project pattern cache_file; do
      # Format timestamp
      local formatted_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%b %d at %I:%M %p" 2>/dev/null || echo "$ts")

      # Type icon
      if [ "$type" = "win" ]; then
        icon="✅"
        label="WIN"
      else
        icon="❌"
        label="LOSS"
      fi

      echo "$icon $label - $project - $formatted_ts"
      echo "   Pattern: \"$pattern\" | Relevance: $score"
      echo ""

      if [ -f "$cache_file" ]; then
        echo "   📝 What happened:"
        sed -n '/## AI Summary/,/## Quick Context/p' "$cache_file" |
          sed '1d;$d' |
          head -5 |
          sed 's/^/   /' |
          fold -s -w 70 |
          sed 's/^/   /'
        echo ""
        echo "   📄 Full memory: $cache_file"
      fi
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

# ============ EXECUTE SEARCH WITH FALLBACK CHAIN ============
FOUND=false

# Try SQLite FTS5 first (fastest)
if search_with_sqlite 2>/dev/null; then
  FOUND=true
# Fallback to index-based search
elif search_with_index 2>/dev/null; then
  FOUND=true
# Final fallback to grep
elif search_with_grep 2>/dev/null; then
  FOUND=true
fi

# No results found
if [ "$FOUND" = false ]; then
  echo "No relevant past experiences found for: $SEARCH_TERMS"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
