#!/bin/bash
################################################################################
# auto-context-recall.sh
#
# Purpose:
#   Automatically generate session context by analyzing current project state
#   and querying Claudarity database for relevant past experiences
#
# Usage:
#   ./auto-context-recall.sh [project_dir]
#
################################################################################

PROJECT_DIR="${1:-$PWD}"
cd "$PROJECT_DIR" || exit 1

PROJECT_NAME=$(basename "$PROJECT_DIR")
SESSION_CONTEXT_FILE="$HOME/.claude/session-context.md"
CONTEXT_SEARCH_SCRIPT="$HOME/.claude/hooks/context-search.sh"

# Clear or create session context file
> "$SESSION_CONTEXT_FILE"

echo "# Session Context - $PROJECT_NAME" >> "$SESSION_CONTEXT_FILE"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$SESSION_CONTEXT_FILE"
echo "" >> "$SESSION_CONTEXT_FILE"

# ============ ANALYZE CURRENT PROJECT STATE ============
echo "## Current Project State" >> "$SESSION_CONTEXT_FILE"
echo "" >> "$SESSION_CONTEXT_FILE"

# Get current branch
if [ -d ".git" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  echo "- **Branch:** \`$BRANCH\`" >> "$SESSION_CONTEXT_FILE"

  # Get recently modified files (last 24 hours)
  RECENT_FILES=$(git diff --name-only HEAD@{1.day.ago}..HEAD 2>/dev/null | head -10)
  if [ -n "$RECENT_FILES" ]; then
    echo "- **Recently Modified:**" >> "$SESSION_CONTEXT_FILE"
    echo "$RECENT_FILES" | while read -r file; do
      echo "  - \`$file\`" >> "$SESSION_CONTEXT_FILE"
    done
  fi

  # Get recent commit messages (last 5)
  RECENT_COMMITS=$(git log -5 --pretty=format:"  - %s" 2>/dev/null)
  if [ -n "$RECENT_COMMITS" ]; then
    echo "- **Recent Commits:**" >> "$SESSION_CONTEXT_FILE"
    echo "$RECENT_COMMITS" >> "$SESSION_CONTEXT_FILE"
  fi
else
  echo "- **Branch:** Not a git repository" >> "$SESSION_CONTEXT_FILE"
fi

echo "" >> "$SESSION_CONTEXT_FILE"
echo "---" >> "$SESSION_CONTEXT_FILE"
echo "" >> "$SESSION_CONTEXT_FILE"

# ============ BUILD SEARCH TERMS ============
SEARCH_TERMS=""

# Add project name
SEARCH_TERMS="$SEARCH_TERMS $PROJECT_NAME"

# Add branch name keywords
if [ -d ".git" ]; then
  BRANCH_KEYWORDS=$(echo "$BRANCH" | sed 's/[-_/]/ /g')
  SEARCH_TERMS="$SEARCH_TERMS $BRANCH_KEYWORDS"

  # Add file extension patterns
  FILE_EXTENSIONS=$(git diff --name-only HEAD@{1.day.ago}..HEAD 2>/dev/null | \
    sed 's/.*\.//' | sort -u | tr '\n' ' ')
  SEARCH_TERMS="$SEARCH_TERMS $FILE_EXTENSIONS"

  # Add keywords from recent commit messages
  COMMIT_KEYWORDS=$(git log -5 --pretty=format:"%s" 2>/dev/null | \
    tr '[:upper:]' '[:lower:]' | \
    grep -oE '\w{4,}' | \
    sort | uniq -c | sort -rn | head -10 | awk '{print $2}' | tr '\n' ' ')
  SEARCH_TERMS="$SEARCH_TERMS $COMMIT_KEYWORDS"
fi

# Clean up search terms
SEARCH_TERMS=$(echo "$SEARCH_TERMS" | tr -s ' ' | sed 's/^ //;s/ $//')

# Now write the header with search terms
echo "## Relevant Past Experiences" >> "$SESSION_CONTEXT_FILE"
echo "" >> "$SESSION_CONTEXT_FILE"
echo "_Searching for: ${SEARCH_TERMS}_" >> "$SESSION_CONTEXT_FILE"
echo "" >> "$SESSION_CONTEXT_FILE"

# ============ QUERY CLAUDARITY DATABASE ============
if [ -x "$CONTEXT_SEARCH_SCRIPT" ] && [ -n "$SEARCH_TERMS" ]; then
  # Run context search and capture output
  RECALL_OUTPUT=$("$CONTEXT_SEARCH_SCRIPT" "$SEARCH_TERMS" 5 2>&1)

  # Check if any results found
  if echo "$RECALL_OUTPUT" | grep -q "No relevant past experiences found"; then
    echo "No relevant past experiences found in Claudarity database." >> "$SESSION_CONTEXT_FILE"
    echo "" >> "$SESSION_CONTEXT_FILE"
    echo "_Try working on your current task - this session will create new memories!_" >> "$SESSION_CONTEXT_FILE"
  else
    # Parse and format the output
    echo "$RECALL_OUTPUT" | sed '1,/━━━━━/d' | sed '/━━━━━/,$d' >> "$SESSION_CONTEXT_FILE"
  fi
else
  echo "⚠️  Context search script not found or search terms empty." >> "$SESSION_CONTEXT_FILE"
fi

echo "" >> "$SESSION_CONTEXT_FILE"
echo "---" >> "$SESSION_CONTEXT_FILE"
echo "" >> "$SESSION_CONTEXT_FILE"

# ============ OUTPUT SUMMARY ============
echo "📝 Session context generated: $SESSION_CONTEXT_FILE"
echo ""
echo "Search terms used: $SEARCH_TERMS"
echo ""
echo "Context file is now available for this session."

exit 0
