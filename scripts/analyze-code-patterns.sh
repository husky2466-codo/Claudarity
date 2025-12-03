#!/bin/bash
# Code Pattern Analyzer for Claudarity Memory System
# Analyzes win/loss memory files to extract code patterns and preferences

MEMORY_DIR="/Volumes/DevDrive/Cache/feedback"
LOGS_DIR="$HOME/.claude/logs"
PREFS_FILE="$LOGS_DIR/code-preferences.json"
TEMP_ANALYSIS="$LOGS_DIR/.pattern-analysis-temp.json"

# Initialize preferences file if it doesn't exist
init_preferences() {
  if [ ! -f "$PREFS_FILE" ]; then
    cat > "$PREFS_FILE" <<'EOF'
{
  "version": "1.0",
  "last_updated": "",
  "libraries": {
    "preferred": [],
    "avoided": []
  },
  "frameworks": {
    "preferred": [],
    "avoided": []
  },
  "technologies": {
    "preferred": [],
    "avoided": []
  },
  "patterns": {
    "liked": [],
    "disliked": []
  },
  "tools": {
    "preferred": [],
    "avoided": []
  },
  "naming": {
    "style": "inferred",
    "examples": []
  },
  "confidence_scores": {}
}
EOF
    echo "Initialized code preferences database at $PREFS_FILE"
  fi
}

# Extract technologies/libraries from AI summaries and Quick Context
extract_tech_patterns() {
  local memory_file="$1"
  local win_or_loss="$2"

  # Common tech keywords to look for
  local tech_keywords=(
    "SwiftUI" "SwiftData" "CoreData" "UIKit" "Combine" "async/await"
    "Anthropic API" "Claude" "Haiku" "Sonnet" "Opus"
    "bash" "shell script" "jq" "curl" "git" "rsync"
    "hook" "webhook" "API" "REST" "JSON" "JSONL"
    "React" "Vue" "Angular" "Node.js" "Express"
    "Python" "Ruby" "JavaScript" "TypeScript" "Swift"
    "Docker" "Kubernetes" "AWS" "Firebase"
    "MCP" "Claude Code" "terminal" "iTerm2"
  )

  # Extract AI Summary section
  local summary=$(sed -n '/## AI Summary/,/## Quick Context/p' "$memory_file" | grep -v "^##")

  # Extract Quick Context section
  local context=$(sed -n '/## Quick Context/,/## User Message/p' "$memory_file" | grep -v "^##")

  # Search for tech keywords in both sections
  local found_tech=()
  for tech in "${tech_keywords[@]}"; do
    if echo "$summary $context" | grep -qi "$tech"; then
      found_tech+=("$tech")
    fi
  done

  # Output as JSON
  if [ ${#found_tech[@]} -gt 0 ]; then
    printf '%s\n' "${found_tech[@]}" | jq -R . | jq -s -c "{file: \"$memory_file\", type: \"$win_or_loss\", technologies: .}"
  fi
}

# Extract tool usage patterns from Quick Context
extract_tool_patterns() {
  local memory_file="$1"
  local win_or_loss="$2"

  # Tool emojis and their names
  local context=$(sed -n '/## Quick Context/,/## User Message/p' "$memory_file")

  # Count tool usage
  local edit_count=$(echo "$context" | grep -o "✏️ Edit" | wc -l | tr -d ' ')
  local bash_count=$(echo "$context" | grep -o "🔧 Bash" | wc -l | tr -d ' ')
  local read_count=$(echo "$context" | grep -o "📖" | wc -l | tr -d ' ')
  local write_count=$(echo "$context" | grep -o "✍️ Write" | wc -l | tr -d ' ')
  local task_count=$(echo "$context" | grep -o "🔧 Task" | wc -l | tr -d ' ')
  local grep_count=$(echo "$context" | grep -o "🔍 Grep" | wc -l | tr -d ' ')
  local glob_count=$(echo "$context" | grep -o "🌐 Glob" | wc -l | tr -d ' ')

  # Output as JSON
  jq -n -c \
    --arg file "$memory_file" \
    --arg type "$win_or_loss" \
    --argjson edit "$edit_count" \
    --argjson bash "$bash_count" \
    --argjson read "$read_count" \
    --argjson write "$write_count" \
    --argjson task "$task_count" \
    --argjson grep "$grep_count" \
    --argjson glob "$glob_count" \
    '{
      file: $file,
      type: $type,
      tools: {
        Edit: $edit,
        Bash: $bash,
        Read: $read,
        Write: $write,
        Task: $task,
        Grep: $grep,
        Glob: $glob
      }
    }'
}

# Extract implementation patterns from AI summaries
extract_implementation_patterns() {
  local memory_file="$1"
  local win_or_loss="$2"

  # Pattern keywords
  local pattern_keywords=(
    "hook" "automation" "background process" "async" "parallel"
    "cache" "memory" "database" "JSONL" "markdown"
    "API integration" "debugging" "error handling" "validation"
    "clean architecture" "separation of concerns" "modular"
    "refactoring" "optimization" "performance"
    "user feedback" "logging" "monitoring"
  )

  local summary=$(sed -n '/## AI Summary/,/## Quick Context/p' "$memory_file" | grep -v "^##")

  local found_patterns=()
  for pattern in "${pattern_keywords[@]}"; do
    if echo "$summary" | grep -qi "$pattern"; then
      found_patterns+=("$pattern")
    fi
  done

  if [ ${#found_patterns[@]} -gt 0 ]; then
    printf '%s\n' "${found_patterns[@]}" | jq -R . | jq -s -c "{file: \"$memory_file\", type: \"$win_or_loss\", patterns: .}"
  fi
}

# Analyze all memory files
analyze_all_memories() {
  echo "Analyzing memory files in $MEMORY_DIR..."

  local tech_data=()
  local tool_data=()
  local pattern_data=()

  # Process win files
  for file in "$MEMORY_DIR"/win-*.md; do
    [ -f "$file" ] || continue

    # Extract patterns
    local tech=$(extract_tech_patterns "$file" "win")
    [ -n "$tech" ] && tech_data+=("$tech")

    local tools=$(extract_tool_patterns "$file" "win")
    [ -n "$tools" ] && tool_data+=("$tools")

    local patterns=$(extract_implementation_patterns "$file" "win")
    [ -n "$patterns" ] && pattern_data+=("$patterns")
  done

  # Process loss files
  for file in "$MEMORY_DIR"/loss-*.md; do
    [ -f "$file" ] || continue

    local tech=$(extract_tech_patterns "$file" "loss")
    [ -n "$tech" ] && tech_data+=("$tech")

    local tools=$(extract_tool_patterns "$file" "loss")
    [ -n "$tools" ] && tool_data+=("$tools")

    local patterns=$(extract_implementation_patterns "$file" "loss")
    [ -n "$patterns" ] && pattern_data+=("$patterns")
  done

  # Combine all data using proper JSON formatting
  local tech_json="[]"
  if [ ${#tech_data[@]} -gt 0 ]; then
    tech_json=$(printf '%s\n' "${tech_data[@]}" | jq -s '.')
  fi

  local tools_json="[]"
  if [ ${#tool_data[@]} -gt 0 ]; then
    tools_json=$(printf '%s\n' "${tool_data[@]}" | jq -s '.')
  fi

  local patterns_json="[]"
  if [ ${#pattern_data[@]} -gt 0 ]; then
    patterns_json=$(printf '%s\n' "${pattern_data[@]}" | jq -s '.')
  fi

  jq -n \
    --argjson tech "$tech_json" \
    --argjson tools "$tools_json" \
    --argjson patterns "$patterns_json" \
    '{tech: $tech, tools: $tools, patterns: $patterns}' > "$TEMP_ANALYSIS"

  echo "Analysis complete. Results saved to $TEMP_ANALYSIS"
}

# Update preferences based on analysis
update_preferences() {
  echo "Updating code preferences..."

  if [ ! -f "$TEMP_ANALYSIS" ]; then
    echo "No analysis data found. Run analysis first."
    return 1
  fi

  # Use Python to aggregate and update preferences
  python3 - "$TEMP_ANALYSIS" "$PREFS_FILE" <<'PYTHON_EOF'
import json
import sys
from collections import defaultdict
from datetime import datetime

# Load analysis data
with open(sys.argv[1], 'r') as f:
    analysis = json.load(f)

# Load current preferences
with open(sys.argv[2], 'r') as f:
    prefs = json.load(f)

# Aggregate technology mentions
tech_wins = defaultdict(int)
tech_losses = defaultdict(int)

for item in analysis.get('tech', []):
    for tech in item.get('technologies', []):
        if item['type'] == 'win':
            tech_wins[tech] += 1
        else:
            tech_losses[tech] += 1

# Aggregate pattern mentions
pattern_wins = defaultdict(int)
pattern_losses = defaultdict(int)

for item in analysis.get('patterns', []):
    for pattern in item.get('patterns', []):
        if item['type'] == 'win':
            pattern_wins[pattern] += 1
        else:
            pattern_losses[pattern] += 1

# Aggregate tool usage
tool_wins = defaultdict(int)
tool_losses = defaultdict(int)

for item in analysis.get('tools', []):
    for tool, count in item.get('tools', {}).items():
        if count > 0:
            if item['type'] == 'win':
                tool_wins[tool] += count
            else:
                tool_losses[tool] += count

# Update preferences with confidence scores
def update_category(category, wins_dict, losses_dict):
    preferred = []
    avoided = []
    confidence = {}

    for item in set(list(wins_dict.keys()) + list(losses_dict.keys())):
        win_count = wins_dict.get(item, 0)
        loss_count = losses_dict.get(item, 0)
        total = win_count + loss_count

        if total >= 2:  # Minimum occurrences for confidence
            win_rate = win_count / total if total > 0 else 0
            conf_score = min(total / 10.0, 1.0)  # Confidence increases with occurrences

            confidence[item] = {
                "win_count": win_count,
                "loss_count": loss_count,
                "win_rate": round(win_rate, 4),
                "confidence": round(conf_score, 2),
                "total_occurrences": total
            }

            if win_rate >= 0.7:  # 70% win rate = preferred
                preferred.append(item)
            elif win_rate <= 0.3:  # 30% win rate = avoided
                avoided.append(item)

    return {
        "preferred": sorted(preferred),
        "avoided": sorted(avoided),
        "confidence": confidence
    }

# Update each category
tech_result = update_category("technologies", tech_wins, tech_losses)
prefs['technologies']['preferred'] = tech_result['preferred']
prefs['technologies']['avoided'] = tech_result['avoided']
prefs['confidence_scores']['technologies'] = tech_result['confidence']

pattern_result = update_category("patterns", pattern_wins, pattern_losses)
prefs['patterns']['liked'] = pattern_result['preferred']
prefs['patterns']['disliked'] = pattern_result['avoided']
prefs['confidence_scores']['patterns'] = pattern_result['confidence']

tool_result = update_category("tools", tool_wins, tool_losses)
prefs['tools']['preferred'] = tool_result['preferred']
prefs['tools']['avoided'] = tool_result['avoided']
prefs['confidence_scores']['tools'] = tool_result['confidence']

# Update timestamp
prefs['last_updated'] = datetime.utcnow().isoformat() + 'Z'

# Save updated preferences
with open(sys.argv[2], 'w') as f:
    json.dump(prefs, f, indent=2)

print("Preferences updated successfully")
print(f"Preferred technologies: {', '.join(tech_result['preferred'])}")
print(f"Preferred patterns: {', '.join(pattern_result['preferred'])}")
print(f"Preferred tools: {', '.join(tool_result['preferred'])}")
PYTHON_EOF

  echo "Code preferences updated at $PREFS_FILE"
}

# Main execution
main() {
  init_preferences
  analyze_all_memories
  update_preferences

  # Keep temp file for debugging
  # rm -f "$TEMP_ANALYSIS"

  echo ""
  echo "Code style learning complete!"
  echo "View preferences: cat $PREFS_FILE"
  echo "Debug data: cat $TEMP_ANALYSIS"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  main "$@"
fi
