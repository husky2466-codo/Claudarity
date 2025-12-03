#!/bin/bash
################################################################################
# populate-code-preferences.sh
#
# Purpose:
#   Analyzes feedback entries to extract technology and tool preferences
#   Populates the code_preferences table with win/loss statistics
#
# Usage:
#   ./populate-code-preferences.sh
################################################################################

set -euo pipefail

DB="$HOME/.claude/claudarity.db"

echo "🔍 Analyzing feedback for code preferences..."
echo ""

# Technology keywords to track
TECHNOLOGIES=(
  # Languages
  "Swift" "SwiftUI" "Python" "JavaScript" "TypeScript" "Bash" "Ruby" "Go" "Rust"
  # Frameworks
  "React" "Vue" "Angular" "Next.js" "Node.js" "Express" "Django" "Flask"
  # iOS/Apple
  "Xcode" "SwiftData" "CoreData" "Combine" "UIKit" "AppKit"
  # Databases
  "SQLite" "PostgreSQL" "MySQL" "MongoDB" "Redis"
  # Tools
  "Git" "GitHub" "Docker" "Kubernetes" "npm" "yarn" "pip"
  # Cloud
  "AWS" "Azure" "GCP" "Firebase" "Vercel" "Netlify"
  # APIs
  "REST" "GraphQL" "WebSocket" "gRPC"
)

# Patterns to track
PATTERNS=(
  # Architecture
  "MVVM" "MVC" "Clean Architecture" "Dependency Injection"
  # Practices
  "TDD" "BDD" "CI/CD" "Agile" "Scrum"
  # Code Quality
  "Refactoring" "Code Review" "Linting" "Testing"
)

# Tools to track
TOOLS=(
  "VSCode" "Vim" "Emacs" "Playwright" "Jest" "Mocha" "Pytest"
  "ESLint" "Prettier" "SwiftLint" "Black" "Rubocop"
)

# Clear existing preferences
sqlite3 "$DB" "DELETE FROM code_preferences;"

echo "📊 Extracting technology preferences..."

# Function to analyze and insert preference
analyze_preference() {
  local category="$1"
  local item="$2"

  # Case-insensitive search for the item in feedback entries
  local stats=$(sqlite3 "$DB" <<SQL
SELECT
  SUM(CASE WHEN type = 'win' THEN 1 ELSE 0 END) as wins,
  SUM(CASE WHEN type = 'loss' THEN 1 ELSE 0 END) as losses,
  COUNT(*) as total,
  MAX(ts) as last_seen
FROM feedback_entries
WHERE
  ai_summary LIKE '%${item}%' COLLATE NOCASE
  OR context_summary LIKE '%${item}%' COLLATE NOCASE
  OR user_message LIKE '%${item}%' COLLATE NOCASE;
SQL
)

  local wins=$(echo "$stats" | cut -d'|' -f1)
  local losses=$(echo "$stats" | cut -d'|' -f2)
  local total=$(echo "$stats" | cut -d'|' -f3)
  local last_seen=$(echo "$stats" | cut -d'|' -f4)

  # Skip if not found
  if [ "$total" -eq 0 ]; then
    return
  fi

  # Calculate win rate
  local win_rate=$(echo "scale=2; $wins / $total" | bc)

  # Determine preference
  local preference="preferred"
  if (( $(echo "$win_rate < 0.5" | bc -l) )); then
    preference="avoided"
  fi

  # Calculate confidence (higher occurrences = higher confidence)
  local confidence=$(echo "scale=2; ($total / 50) * 100" | bc)
  if (( $(echo "$confidence > 100" | bc -l) )); then
    confidence=100
  fi

  # Insert into database
  sqlite3 "$DB" <<SQL
INSERT INTO code_preferences (
  category, item, preference, win_count, loss_count,
  win_rate, confidence, total_occurrences, last_seen
) VALUES (
  '${category}',
  '${item}',
  '${preference}',
  ${wins},
  ${losses},
  ${win_rate},
  ${confidence},
  ${total},
  '${last_seen}'
);
SQL

  echo "  ✓ $item: $wins wins, $losses losses (${win_rate} win rate, ${confidence}% confidence)"
}

# Analyze technologies
echo ""
echo "Technologies:"
for tech in "${TECHNOLOGIES[@]}"; do
  analyze_preference "technology" "$tech"
done

# Analyze patterns
echo ""
echo "Patterns:"
for pattern in "${PATTERNS[@]}"; do
  analyze_preference "pattern" "$pattern"
done

# Analyze tools
echo ""
echo "Tools:"
for tool in "${TOOLS[@]}"; do
  analyze_preference "tool" "$tool"
done

# Show summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Code Preferences Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sqlite3 "$DB" <<'SQL'
.mode column
.headers on
SELECT
  category,
  COUNT(*) as total,
  SUM(CASE WHEN preference = 'preferred' THEN 1 ELSE 0 END) as preferred,
  SUM(CASE WHEN preference = 'avoided' THEN 1 ELSE 0 END) as avoided
FROM code_preferences
GROUP BY category;
SQL

echo ""
echo "Top 10 Preferred Technologies:"
sqlite3 "$DB" <<'SQL'
.mode column
.headers on
SELECT
  item,
  win_count,
  loss_count,
  ROUND(win_rate * 100, 1) || '%' as win_rate,
  ROUND(confidence, 1) || '%' as confidence
FROM code_preferences
WHERE category = 'technology' AND preference = 'preferred'
ORDER BY confidence DESC, win_rate DESC
LIMIT 10;
SQL

echo ""
echo "✅ Code preferences populated successfully!"
