#!/bin/bash
# Trigger Detection Script for Auto-Context Injection
# Analyzes user messages and tool results to detect when context injection is relevant
# Exit code: 0 if score >= 25, 1 if below threshold

# ============ CONFIGURATION ============
# Keyword weights
KEYWORD_SCORE=20
FILE_PATTERN_SCORE=15
ERROR_SCORE=30
LOSS_PATTERN_SCORE=25
THRESHOLD=25

# Keywords to detect
KEYWORDS=(
  "authentication" "database" "API" "form" "validation"
  "SwiftUI" "React" "bug" "error" "broken" "failing"
  "JWT" "auth" "login" "session" "state" "hook" "component"
)

# Loss patterns to detect
LOSS_PATTERNS=(
  "broken" "failing" "not working" "issue" "problem"
  "doesn't work" "not found" "error" "failed"
)

# ============ FIND TRANSCRIPT ============
# Use environment variable or find latest transcript
TRANSCRIPT_FILE="${CLAUDE_TRANSCRIPT_PATH:-}"

if [ -z "$TRANSCRIPT_FILE" ] || [ ! -f "$TRANSCRIPT_FILE" ]; then
  # Find most recent transcript
  TRANSCRIPT_FILE=$(find "$HOME/.claude/projects" -name "*.jsonl" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [ -z "$TRANSCRIPT_FILE" ] || [ ! -f "$TRANSCRIPT_FILE" ]; then
  # No transcript available - output minimal JSON and exit
  echo '{"score": 0, "keywords": [], "files": [], "has_errors": false, "trigger_type": "none"}'
  exit 1
fi

# ============ EXTRACT RECENT MESSAGES ============
# Get last 3 messages from transcript
RECENT_MESSAGES=$(tail -n 3 "$TRANSCRIPT_FILE" 2>/dev/null)

if [ -z "$RECENT_MESSAGES" ]; then
  echo '{"score": 0, "keywords": [], "files": [], "has_errors": false, "trigger_type": "none"}'
  exit 1
fi

# Extract user messages and tool results
USER_TEXT=$(echo "$RECENT_MESSAGES" | jq -r 'select(.type == "user") | .message.content' 2>/dev/null | tr '\n' ' ')
TOOL_RESULTS=$(echo "$RECENT_MESSAGES" | jq -r 'select(.type == "assistant") | .message.content[] | select(.type == "tool_use" or .type == "tool_result")' 2>/dev/null)

# Combine for analysis
COMBINED_TEXT="$USER_TEXT $TOOL_RESULTS"
COMBINED_LOWER=$(echo "$COMBINED_TEXT" | tr '[:upper:]' '[:lower:]')

# ============ SCORING ============
SCORE=0
MATCHED_KEYWORDS=()
MATCHED_FILES=()
HAS_ERRORS=false
TRIGGER_TYPES=()

# 1. Check for keywords
for keyword in "${KEYWORDS[@]}"; do
  if echo "$COMBINED_LOWER" | grep -qi "\b${keyword}\b"; then
    SCORE=$((SCORE + KEYWORD_SCORE))
    MATCHED_KEYWORDS+=("$keyword")
  fi
done

if [ ${#MATCHED_KEYWORDS[@]} -gt 0 ]; then
  TRIGGER_TYPES+=("keywords")
fi

# 2. Check for file patterns (Read, Edit, Write operations)
FILES=$(echo "$RECENT_MESSAGES" | jq -r '
  select(.type == "assistant") |
  .message.content[] |
  select(.type == "tool_use") |
  select(.name == "Read" or .name == "Edit" or .name == "Write") |
  .input.file_path // empty
' 2>/dev/null)

if [ -n "$FILES" ]; then
  while IFS= read -r file; do
    if [ -n "$file" ]; then
      SCORE=$((SCORE + FILE_PATTERN_SCORE))
      filename=$(basename "$file")
      MATCHED_FILES+=("$filename")
    fi
  done <<< "$FILES"

  if [ ${#MATCHED_FILES[@]} -gt 0 ]; then
    TRIGGER_TYPES+=("files")
  fi
fi

# 3. Check for errors in tool results
if echo "$COMBINED_LOWER" | grep -qiE '\b(error|failed|exception|not found)\b'; then
  SCORE=$((SCORE + ERROR_SCORE))
  HAS_ERRORS=true
  TRIGGER_TYPES+=("errors")
fi

# 4. Check for loss patterns in user messages
for pattern in "${LOSS_PATTERNS[@]}"; do
  if echo "$COMBINED_LOWER" | grep -qi "$pattern"; then
    SCORE=$((SCORE + LOSS_PATTERN_SCORE))
    TRIGGER_TYPES+=("loss")
    break
  fi
done

# ============ BUILD OUTPUT ============
# Remove duplicates from arrays
MATCHED_KEYWORDS=($(echo "${MATCHED_KEYWORDS[@]}" | tr ' ' '\n' | sort -u))
MATCHED_FILES=($(echo "${MATCHED_FILES[@]}" | tr ' ' '\n' | sort -u))
TRIGGER_TYPES=($(echo "${TRIGGER_TYPES[@]}" | tr ' ' '\n' | sort -u))

# Join trigger types with +
TRIGGER_TYPE=$(IFS=+; echo "${TRIGGER_TYPES[*]}")
[ -z "$TRIGGER_TYPE" ] && TRIGGER_TYPE="none"

# Build JSON output using jq
OUTPUT=$(jq -n \
  --arg score "$SCORE" \
  --argjson keywords "$(printf '%s\n' "${MATCHED_KEYWORDS[@]}" | jq -R . | jq -s .)" \
  --argjson files "$(printf '%s\n' "${MATCHED_FILES[@]}" | jq -R . | jq -s .)" \
  --argjson has_errors "$HAS_ERRORS" \
  --arg trigger_type "$TRIGGER_TYPE" \
  '{
    score: ($score | tonumber),
    keywords: $keywords,
    files: $files,
    has_errors: $has_errors,
    trigger_type: $trigger_type
  }')

echo "$OUTPUT"

# Exit with appropriate code
if [ "$SCORE" -ge "$THRESHOLD" ]; then
  exit 0
else
  exit 1
fi
