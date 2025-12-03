#!/bin/bash
################################################################################
# context-detector.sh
#
# Purpose:
#   Detects when Claude is working on something similar to past work
#   and proactively surfaces relevant memories
#
# Triggers:
#   - When conversation mentions specific keywords (auth, database, API, etc.)
#   - When similar file paths are being modified
#   - When task patterns match past experiences
#
# Usage:
#   Reads from stdin (Claude Code hook input)
#   Outputs context-aware suggestions when relevant
#
################################################################################

set -euo pipefail

# Read JSON input
input=$(cat)

# Extract conversation context
user_message=$(echo "$input" | jq -r '.prompt // ""')
working_dir=$(echo "$input" | jq -r '.cwd // ""')
project=$(basename "$working_dir" 2>/dev/null || echo "unknown")

# Skip empty messages
[ -z "$user_message" ] && exit 0

# Convert to lowercase for matching
lower_message=$(echo "$user_message" | tr '[:upper:]' '[:lower:]')

# ============ KEYWORD DETECTION ============
# Define high-value keywords that indicate specific technical work
KEYWORDS=(
  # Auth/Security
  "auth" "authentication" "login" "jwt" "oauth" "password" "token"
  "session" "security" "permission" "authorization"

  # Data/Database
  "database" "db" "sql" "query" "schema" "migration" "postgres"
  "mysql" "mongo" "redis" "prisma" "orm"

  # API/Networking
  "api" "endpoint" "rest" "graphql" "fetch" "request" "response"
  "http" "websocket" "grpc"

  # Frontend
  "react" "component" "hook" "state" "props" "redux" "context"
  "ui" "form" "validation" "styling" "css"

  # Testing
  "test" "testing" "jest" "cypress" "playwright" "mock" "unit test"

  # DevOps/Infrastructure
  "docker" "kubernetes" "deploy" "ci/cd" "pipeline" "build"
  "terraform" "aws" "cloud"

  # Architecture
  "refactor" "architecture" "design pattern" "microservice" "monorepo"
  "performance" "optimization" "caching"
)

# Check if message contains any keywords
DETECTED_KEYWORDS=""
for keyword in "${KEYWORDS[@]}"; do
  if echo "$lower_message" | grep -qw "$keyword"; then
    DETECTED_KEYWORDS="$DETECTED_KEYWORDS $keyword"
  fi
done

# ============ FILE PATH DETECTION ============
# Extract file paths from message (common patterns)
DETECTED_FILES=$(echo "$user_message" | grep -oE '([a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+\.(ts|js|py|go|rs|java|tsx|jsx|md|json|yaml|yml|sh)' || echo "")

# ============ TASK PATTERN DETECTION ============
# Detect common task patterns
TASK_PATTERNS=""

if echo "$lower_message" | grep -qE "implement|create|add|build"; then
  TASK_PATTERNS="$TASK_PATTERNS implementation"
fi

if echo "$lower_message" | grep -qE "fix|bug|error|issue|problem"; then
  TASK_PATTERNS="$TASK_PATTERNS debugging"
fi

if echo "$lower_message" | grep -qE "refactor|clean|improve|optimize"; then
  TASK_PATTERNS="$TASK_PATTERNS refactoring"
fi

if echo "$lower_message" | grep -qE "test|testing|spec"; then
  TASK_PATTERNS="$TASK_PATTERNS testing"
fi

# ============ RELEVANCE THRESHOLD ============
# Only show suggestions if we have enough context
HAS_KEYWORDS=$([ -n "$DETECTED_KEYWORDS" ] && echo "1" || echo "0")
HAS_FILES=$([ -n "$DETECTED_FILES" ] && echo "1" || echo "0")
HAS_PATTERNS=$([ -n "$TASK_PATTERNS" ] && echo "1" || echo "0")

RELEVANCE_SCORE=$((HAS_KEYWORDS + HAS_FILES + HAS_PATTERNS))

# Only proceed if relevance score >= 1 (at least one signal)
if [ "$RELEVANCE_SCORE" -eq 0 ]; then
  exit 0
fi

# ============ BUILD SEARCH QUERY ============
SEARCH_QUERY="$DETECTED_KEYWORDS $TASK_PATTERNS"

# Add file extensions as context (e.g., "typescript" if .ts files mentioned)
if [ -n "$DETECTED_FILES" ]; then
  EXTENSIONS=$(echo "$DETECTED_FILES" | grep -oE '\.[a-z]+$' | sort -u | tr -d '.')
  SEARCH_QUERY="$SEARCH_QUERY $EXTENSIONS"
fi

# ============ SEARCH MEMORY ============
# Run context search (fork to background to avoid blocking)
(
  $HOME/.claude/hooks/context-search.sh \
    --query "$SEARCH_QUERY" \
    --project "$project" \
    --files "$DETECTED_FILES" \
    --limit 3 \
    2>/dev/null
) &

exit 0
