#!/bin/bash
# Claudarity Baseline Summary - Show all-time wins/losses statistics

DB_FILE="$HOME/.claude/claudarity.db"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
  echo "Claudarity database not found at: $DB_FILE"
  exit 1
fi

# Function to calculate percentage
calc_percent() {
  local wins=$1
  local total=$2
  if [ "$total" -eq 0 ]; then
    echo "0"
  else
    echo "scale=0; ($wins * 100) / $total" | bc
  fi
}

# Function to create progress bar
progress_bar() {
  local wins=$1
  local losses=$2
  local total=$((wins + losses))
  local width=10

  if [ "$total" -eq 0 ]; then
    echo "░░░░░░░░░░"
    return
  fi

  local filled=$(echo "scale=0; ($wins * $width) / $total" | bc)
  local empty=$((width - filled))

  local bar=""
  for ((i=0; i<filled; i++)); do
    bar+="█"
  done
  for ((i=0; i<empty; i++)); do
    bar+="░"
  done

  echo "$bar"
}

# Get overall stats
stats=$(sqlite3 "$DB_FILE" "
SELECT
  COUNT(*) as total,
  COUNT(CASE WHEN type = 'win' THEN 1 END) as wins,
  COUNT(CASE WHEN type = 'loss' THEN 1 END) as losses,
  COUNT(DISTINCT project) as projects,
  MIN(date(ts)) as first_entry,
  MAX(date(ts)) as last_entry
FROM feedback_entries;
")

total=$(echo "$stats" | cut -d'|' -f1)
wins=$(echo "$stats" | cut -d'|' -f2)
losses=$(echo "$stats" | cut -d'|' -f3)
projects=$(echo "$stats" | cut -d'|' -f4)
first_entry=$(echo "$stats" | cut -d'|' -f5)
last_entry=$(echo "$stats" | cut -d'|' -f6)

# Calculate win rate
win_rate=$(calc_percent "$wins" "$total")

# Header
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}📊 CLAUDARITY BASELINE (All-Time Summary)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Overall Performance
echo -e "${BOLD}${BLUE}🎯 OVERALL PERFORMANCE${NC}"
echo -e "   ${GREEN}Wins: $wins${NC} | ${RED}Losses: $losses${NC} | ${YELLOW}Win Rate: ${win_rate}%${NC}"
echo -e "   Projects: $projects | Total Feedback: $total entries"
echo -e "   First Entry: $first_entry | Last Entry: $last_entry"
echo ""

# Recent Timeline (Last 30 Days by Week)
echo -e "${BOLD}${BLUE}📈 RECENT TIMELINE (Last 30 Days)${NC}"
sqlite3 "$DB_FILE" "
SELECT
  strftime('%Y-%m-%d', ts, 'weekday 0', '-6 days') as week_start,
  strftime('%Y-%m-%d', ts, 'weekday 0') as week_end,
  COUNT(CASE WHEN type = 'win' THEN 1 END) as wins,
  COUNT(CASE WHEN type = 'loss' THEN 1 END) as losses
FROM feedback_entries
WHERE ts >= date('now', '-30 days')
GROUP BY strftime('%Y-%W', ts)
ORDER BY week_start;
" | while IFS='|' read -r week_start week_end wins losses; do
  bar=$(progress_bar "$wins" "$losses")
  echo -e "   ${week_start} to ${week_end}: ${bar} ${GREEN}${wins} wins${NC}, ${RED}${losses} losses${NC}"
done

# If no recent data
if [ $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM feedback_entries WHERE ts >= date('now', '-30 days');") -eq 0 ]; then
  echo "   No data in the last 30 days"
fi
echo ""

# Top Win Patterns
echo -e "${BOLD}${BLUE}🏆 TOP WIN PATTERNS (All-Time)${NC}"
sqlite3 "$DB_FILE" "
SELECT pattern, COUNT(*) as count
FROM feedback_entries
WHERE type = 'win'
GROUP BY pattern
ORDER BY count DESC
LIMIT 5;
" | nl -w2 -s'. ' | while read -r line; do
  num=$(echo "$line" | cut -d'.' -f1)
  pattern=$(echo "$line" | cut -d'|' -f1 | cut -d'.' -f2- | xargs)
  count=$(echo "$line" | cut -d'|' -f2)
  echo -e "   ${GREEN}${num}.${NC} ${BOLD}${pattern}${NC} (${count} occurrences)"
done

# If no wins
if [ "$wins" -eq 0 ]; then
  echo "   No win patterns yet"
fi
echo ""

# Top Loss Patterns
echo -e "${BOLD}${BLUE}💥 TOP LOSS PATTERNS (All-Time)${NC}"
sqlite3 "$DB_FILE" "
SELECT pattern, COUNT(*) as count
FROM feedback_entries
WHERE type = 'loss'
GROUP BY pattern
ORDER BY count DESC
LIMIT 5;
" | nl -w2 -s'. ' | while read -r line; do
  num=$(echo "$line" | cut -d'.' -f1)
  pattern=$(echo "$line" | cut -d'|' -f1 | cut -d'.' -f2- | xargs)
  count=$(echo "$line" | cut -d'|' -f2)
  echo -e "   ${RED}${num}.${NC} ${BOLD}${pattern}${NC} (${count} occurrences)"
done

# If no losses
if [ "$losses" -eq 0 ]; then
  echo "   No loss patterns yet - perfect record!"
fi
echo ""

# Project Breakdown
echo -e "${BOLD}${BLUE}📁 PROJECT BREAKDOWN${NC}"
sqlite3 "$DB_FILE" "
SELECT
  project,
  COUNT(CASE WHEN type = 'win' THEN 1 END) as wins,
  COUNT(CASE WHEN type = 'loss' THEN 1 END) as losses,
  COUNT(*) as total
FROM feedback_entries
WHERE project != ''
GROUP BY project
ORDER BY wins DESC;
" | while IFS='|' read -r project proj_wins proj_losses proj_total; do
  proj_rate=$(calc_percent "$proj_wins" "$proj_total")
  printf "   ${BOLD}%-20s${NC} ${GREEN}%2d wins${NC}, ${RED}%2d losses${NC} (${YELLOW}%d%% win rate${NC})\n" \
    "$project:" "$proj_wins" "$proj_losses" "$proj_rate"
done

# Check for entries with no project
no_project=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM feedback_entries WHERE project = '';")
if [ "$no_project" -gt 0 ]; then
  echo -e "   ${BOLD}[No Project]:${NC}       $no_project entries"
fi
echo ""

# Quick Insights
echo -e "${BOLD}${BLUE}💡 QUICK INSIGHTS${NC}"

# Best performing project
best_project=$(sqlite3 "$DB_FILE" "
SELECT project,
  CAST(COUNT(CASE WHEN type = 'win' THEN 1 END) * 100.0 / COUNT(*) AS INTEGER) as win_rate
FROM feedback_entries
WHERE project != ''
GROUP BY project
ORDER BY win_rate DESC, COUNT(*) DESC
LIMIT 1;
" | head -1)

if [ -n "$best_project" ]; then
  best_name=$(echo "$best_project" | cut -d'|' -f1)
  best_rate=$(echo "$best_project" | cut -d'|' -f2)
  echo -e "   • Best performing project: ${GREEN}${best_name}${NC} (${best_rate}% win rate)"
fi

# Most active project
most_active=$(sqlite3 "$DB_FILE" "
SELECT project, COUNT(*) as total
FROM feedback_entries
WHERE project != ''
GROUP BY project
ORDER BY total DESC
LIMIT 1;
")

if [ -n "$most_active" ]; then
  active_name=$(echo "$most_active" | cut -d'|' -f1)
  active_count=$(echo "$most_active" | cut -d'|' -f2)
  echo -e "   • Most active project: ${CYAN}${active_name}${NC} (${active_count} total entries)"
fi

# Recent trend (last 7 days)
recent_wins=$(sqlite3 "$DB_FILE" "
SELECT COUNT(CASE WHEN type = 'win' THEN 1 END)
FROM feedback_entries
WHERE ts >= date('now', '-7 days');
")
recent_total=$(sqlite3 "$DB_FILE" "
SELECT COUNT(*)
FROM feedback_entries
WHERE ts >= date('now', '-7 days');
")

# Handle empty values
[ -z "$recent_wins" ] && recent_wins=0
[ -z "$recent_total" ] && recent_total=0

if [ "$recent_total" -gt 0 ]; then
  recent_rate=$(calc_percent "$recent_wins" "$recent_total")
  echo -e "   • Recent trend: ${YELLOW}${recent_rate}% wins${NC} in last 7 days (${recent_total} entries)"
fi

# Average entries per day
if [ -n "$first_entry" ] && [ -n "$last_entry" ]; then
  days_active=$(sqlite3 "$DB_FILE" "SELECT julianday('$last_entry') - julianday('$first_entry') + 1;")
  avg_per_day=$(echo "scale=1; $total / $days_active" | bc)
  echo -e "   • Activity rate: ${CYAN}${avg_per_day} entries/day${NC} average"
fi

echo ""
echo -e "${BOLD}🔍 Query: ${CYAN}/gomemory \"pattern\"${NC} (search memories)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
