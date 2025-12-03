#!/bin/bash
################################################################################
# build-context-index.sh
#
# Purpose:
#   Build a searchable index of all memories with extracted keywords,
#   technologies, file patterns, and task types for fast context lookup
#
# Creates:
#   ~/.claude/logs/context-index.jsonl - Indexed memories with metadata
#
# Usage:
#   ./build-context-index.sh
#   (Run automatically on session start or after new feedback is logged)
#
################################################################################

set -euo pipefail

LOGS_DIR="$HOME/.claude/logs"
MEMORY_DIR="/Volumes/DevDrive/Cache/feedback"
WINS_FILE="$LOGS_DIR/session-wins.jsonl"
LOSSES_FILE="$LOGS_DIR/session-losses.jsonl"
INDEX_FILE="$LOGS_DIR/context-index.jsonl"

# Remove old index
rm -f "$INDEX_FILE"

# Function to extract keywords from memory content
extract_keywords() {
  local content=$1
  local keywords=""

  # Technology keywords
  for tech in auth authentication jwt oauth database sql postgres mysql mongo redis \
              api rest graphql react vue angular typescript javascript python go rust \
              docker kubernetes aws azure gcp terraform ci/cd test testing jest cypress \
              webpack vite next nuxt svelte tailwind bootstrap css html \
              node npm yarn pnpm git github gitlab; do
    if echo "$content" | grep -iq "$tech"; then
      keywords="$keywords $tech"
    fi
  done

  echo "$keywords" | xargs
}

# Function to extract task type
extract_task_type() {
  local content=$1

  if echo "$content" | grep -iqE "implement|create|add|build"; then
    echo "implementation"
  elif echo "$content" | grep -iqE "fix|bug|error|issue"; then
    echo "debugging"
  elif echo "$content" | grep -iqE "refactor|clean|improve|optimize"; then
    echo "refactoring"
  elif echo "$content" | grep -iqE "test|testing|spec"; then
    echo "testing"
  elif echo "$content" | grep -iqE "setup|config|install"; then
    echo "setup"
  else
    echo "general"
  fi
}

# Function to extract file patterns (extensions)
extract_file_patterns() {
  local content=$1
  local patterns=""

  for ext in ts js tsx jsx py go rs java md json yaml yml sh; do
    if echo "$content" | grep -q "\.$ext"; then
      patterns="$patterns $ext"
    fi
  done

  echo "$patterns" | xargs
}

# Process wins
if [ -f "$WINS_FILE" ]; then
  while IFS= read -r line; do
    cache_file=$(echo "$line" | jq -r '.cache_file // empty')

    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
      # Read memory content
      content=$(cat "$cache_file")

      # Extract metadata
      ts=$(echo "$line" | jq -r '.ts')
      project=$(echo "$line" | jq -r '.project')
      pattern=$(echo "$line" | jq -r '.matched')

      # Extract AI summary (first paragraph)
      summary=$(sed -n '/## AI Summary/,/## Quick Context/p' "$cache_file" | \
        sed '1d;$d' | \
        head -3 | \
        tr '\n' ' ' | \
        sed 's/^[[:space:]]*//' || echo "")

      # Extract keywords, task type, file patterns
      keywords=$(extract_keywords "$content")
      task_type=$(extract_task_type "$content")
      file_patterns=$(extract_file_patterns "$content")

      # Build index entry
      jq -n \
        --arg ts "$ts" \
        --arg project "$project" \
        --arg pattern "$pattern" \
        --arg type "win" \
        --arg cache_file "$cache_file" \
        --arg summary "$summary" \
        --arg keywords "$keywords" \
        --arg task_type "$task_type" \
        --arg file_patterns "$file_patterns" \
        '{
          ts: $ts,
          project: $project,
          pattern: $pattern,
          type: $type,
          cache_file: $cache_file,
          summary: $summary,
          keywords: ($keywords | split(" ") | map(select(length > 0))),
          task_type: $task_type,
          file_patterns: ($file_patterns | split(" ") | map(select(length > 0)))
        }' >> "$INDEX_FILE"
    fi
  done < "$WINS_FILE"
fi

# Process losses
if [ -f "$LOSSES_FILE" ]; then
  while IFS= read -r line; do
    cache_file=$(echo "$line" | jq -r '.cache_file // empty')

    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
      # Read memory content
      content=$(cat "$cache_file")

      # Extract metadata
      ts=$(echo "$line" | jq -r '.ts')
      project=$(echo "$line" | jq -r '.project')
      pattern=$(echo "$line" | jq -r '.matched')

      # Extract AI summary (first paragraph)
      summary=$(sed -n '/## AI Summary/,/## Quick Context/p' "$cache_file" | \
        sed '1d;$d' | \
        head -3 | \
        tr '\n' ' ' | \
        sed 's/^[[:space:]]*//' || echo "")

      # Extract keywords, task type, file patterns
      keywords=$(extract_keywords "$content")
      task_type=$(extract_task_type "$content")
      file_patterns=$(extract_file_patterns "$content")

      # Build index entry
      jq -n \
        --arg ts "$ts" \
        --arg project "$project" \
        --arg pattern "$pattern" \
        --arg type "loss" \
        --arg cache_file "$cache_file" \
        --arg summary "$summary" \
        --arg keywords "$keywords" \
        --arg task_type "$task_type" \
        --arg file_patterns "$file_patterns" \
        '{
          ts: $ts,
          project: $project,
          pattern: $pattern,
          type: $type,
          cache_file: $cache_file,
          summary: $summary,
          keywords: ($keywords | split(" ") | map(select(length > 0))),
          task_type: $task_type,
          file_patterns: ($file_patterns | split(" ") | map(select(length > 0)))
        }' >> "$INDEX_FILE"
    fi
  done < "$LOSSES_FILE"
fi

# Index complete - no need to sort, entries are appended in order
exit 0
