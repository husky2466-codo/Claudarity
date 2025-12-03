#!/usr/bin/env bash
# template-stats.sh
# Displays comprehensive template system statistics

set -euo pipefail

# Configuration
CACHE_DIR="/Volumes/DevDrive/Cache/templates"
TEMPLATES_DIR="${CACHE_DIR}/library"
USAGE_LOG="${CACHE_DIR}/template-usage.jsonl"
OUTCOMES_LOG="${CACHE_DIR}/template-outcomes.jsonl"
MODIFICATIONS_LOG="${CACHE_DIR}/template-modifications.jsonl"
CONFIDENCE_SCORES="${CACHE_DIR}/learning/confidence-scores.json"
PROPOSALS_FILE="${CACHE_DIR}/evolved/evolution-proposals.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Header
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║     TEMPLATE SYSTEM STATISTICS            ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════╝${NC}"
echo

# Check if cache directory exists
if [[ ! -d "$CACHE_DIR" ]]; then
    echo -e "${RED}Error: Cache directory not found: $CACHE_DIR${NC}"
    exit 1
fi

# 1. TEMPLATE LIBRARY
echo -e "${CYAN}${BOLD}📚 Template Library${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -d "$TEMPLATES_DIR" ]]; then
    TOTAL_TEMPLATES=$(find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    echo -e "Total templates: ${GREEN}${TOTAL_TEMPLATES}${NC}"

    if [[ $TOTAL_TEMPLATES -gt 0 ]]; then
        echo
        echo "Templates:"
        find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r template_dir; do
            template_name=$(basename "$template_dir")
            template_json="${template_dir}/template.json"

            if [[ -f "$template_json" ]]; then
                version=$(jq -r '.version // "unknown"' "$template_json")
                description=$(jq -r '.description // "No description"' "$template_json" | head -c 60)
                echo -e "  • ${BOLD}${template_name}${NC} (v${version})"
                echo -e "    ${description}"
            else
                echo -e "  • ${BOLD}${template_name}${NC} (no metadata)"
            fi
        done
    fi
else
    echo -e "${YELLOW}No templates directory found${NC}"
fi

echo

# 2. USAGE STATISTICS
echo -e "${CYAN}${BOLD}📊 Usage Statistics${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$USAGE_LOG" ]]; then
    TOTAL_APPLICATIONS=$(wc -l < "$USAGE_LOG" | tr -d ' ')
    echo -e "Total applications: ${GREEN}${TOTAL_APPLICATIONS}${NC}"

    if [[ $TOTAL_APPLICATIONS -gt 0 ]]; then
        echo
        echo "Usage by template:"

        # Count and display usage per template
        jq -r '.template_id' "$USAGE_LOG" 2>/dev/null | sort | uniq -c | sort -rn | while read -r count template_id; do
            percentage=$(awk "BEGIN {printf \"%.1f\", ($count / $TOTAL_APPLICATIONS) * 100}")
            bar_length=$(awk "BEGIN {printf \"%.0f\", ($count / $TOTAL_APPLICATIONS) * 30}")

            # Create bar
            bar=""
            for ((i=0; i<bar_length; i++)); do
                bar="${bar}█"
            done

            printf "  %-30s ${GREEN}%s${NC} %3d (%s%%)\n" "$template_id" "$bar" "$count" "$percentage"
        done

        # Recent activity
        echo
        echo "Recent applications (last 5):"
        tail -n 5 "$USAGE_LOG" | jq -r '"  • \(.template_id) → \(.project_path) (\(.timestamp))"' 2>/dev/null || echo "  No recent applications"
    fi
else
    echo -e "${YELLOW}No usage data available${NC}"
fi

echo

# 3. SUCCESS METRICS
echo -e "${CYAN}${BOLD}🎯 Success Metrics${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$OUTCOMES_LOG" ]]; then
    TOTAL_OUTCOMES=$(wc -l < "$OUTCOMES_LOG" | tr -d ' ')
    TOTAL_WINS=$(grep -c '"outcome":"win"' "$OUTCOMES_LOG" || echo "0")
    TOTAL_LOSSES=$(grep -c '"outcome":"loss"' "$OUTCOMES_LOG" || echo "0")

    if [[ $TOTAL_OUTCOMES -gt 0 ]]; then
        OVERALL_WIN_RATE=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_WINS / $TOTAL_OUTCOMES) * 100}")

        echo -e "Total outcomes: ${GREEN}${TOTAL_OUTCOMES}${NC}"
        echo -e "Wins: ${GREEN}${TOTAL_WINS}${NC}"
        echo -e "Losses: ${RED}${TOTAL_LOSSES}${NC}"
        echo -e "Overall win rate: ${GREEN}${OVERALL_WIN_RATE}%${NC}"

        echo
        echo "Win rate by template:"

        # Calculate win rate per template
        python3 - <<'PYTHON_SCRIPT' "$OUTCOMES_LOG"
import sys
import json
from collections import defaultdict

outcomes_file = sys.argv[1]

template_outcomes = defaultdict(lambda: {'wins': 0, 'total': 0})

with open(outcomes_file, 'r') as f:
    for line in f:
        if line.strip():
            try:
                outcome = json.loads(line)
                template_id = outcome.get('template_id')
                outcome_type = outcome.get('outcome')

                if template_id:
                    template_outcomes[template_id]['total'] += 1
                    if outcome_type == 'win':
                        template_outcomes[template_id]['wins'] += 1
            except:
                pass

# Sort by win rate
sorted_templates = sorted(
    template_outcomes.items(),
    key=lambda x: x[1]['wins'] / x[1]['total'] if x[1]['total'] > 0 else 0,
    reverse=True
)

for template_id, data in sorted_templates:
    if data['total'] > 0:
        win_rate = (data['wins'] / data['total']) * 100
        print(f"  {template_id:30} {win_rate:5.1f}% ({data['wins']}/{data['total']})")

PYTHON_SCRIPT
    else
        echo -e "${YELLOW}No outcome data available${NC}"
    fi
else
    echo -e "${YELLOW}No outcome data available${NC}"
fi

echo

# 4. CONFIDENCE SCORES
echo -e "${CYAN}${BOLD}🎓 Confidence Scores${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$CONFIDENCE_SCORES" ]]; then
    SCORED_TEMPLATES=$(jq 'length' "$CONFIDENCE_SCORES")
    echo -e "Templates with scores: ${GREEN}${SCORED_TEMPLATES}${NC}"

    if [[ $SCORED_TEMPLATES -gt 0 ]]; then
        echo
        echo "Top templates by confidence:"

        jq -r 'sort_by(-.confidence_score) | .[:5] | .[] |
            "\(.template_id)|\(.confidence_score)|\(.application_count)|\(.win_rate)"' \
            "$CONFIDENCE_SCORES" | while IFS='|' read -r template_id confidence apps win_rate; do

            confidence_pct=$(awk "BEGIN {printf \"%.1f\", $confidence * 100}")
            win_rate_pct=$(awk "BEGIN {printf \"%.1f\", $win_rate * 100}")

            echo -e "  ${BOLD}${template_id}${NC}"
            echo -e "    Confidence: ${GREEN}${confidence_pct}%${NC} | Applications: ${apps} | Win rate: ${win_rate_pct}%"
        done
    fi
else
    echo -e "${YELLOW}No confidence scores calculated${NC}"
    echo "Run: confidence-calculator.sh"
fi

echo

# 5. EVOLUTION PROPOSALS
echo -e "${CYAN}${BOLD}🧬 Evolution Proposals${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$PROPOSALS_FILE" ]]; then
    TOTAL_PROPOSALS=$(jq 'length' "$PROPOSALS_FILE")
    PENDING_PROPOSALS=$(jq '[.[] | select(.status == "pending")] | length' "$PROPOSALS_FILE")
    APPLIED_PROPOSALS=$(jq '[.[] | select(.status == "applied")] | length' "$PROPOSALS_FILE")

    echo -e "Total proposals: ${GREEN}${TOTAL_PROPOSALS}${NC}"
    echo -e "Pending: ${YELLOW}${PENDING_PROPOSALS}${NC}"
    echo -e "Applied: ${GREEN}${APPLIED_PROPOSALS}${NC}"

    if [[ $PENDING_PROPOSALS -gt 0 ]]; then
        echo
        echo "Pending proposals:"

        jq -r '.[] | select(.status == "pending") |
            "\(.proposal_id)|\(.template_id)|\(.changes | length)|\(.metrics.win_rate)"' \
            "$PROPOSALS_FILE" | while IFS='|' read -r proposal_id template_id changes_count win_rate; do

            win_rate_pct=$(awk "BEGIN {printf \"%.1f\", $win_rate * 100}")
            echo -e "  ${BOLD}${proposal_id}${NC}: ${template_id} (${changes_count} changes, ${win_rate_pct}% win rate)"
        done
    fi
else
    echo -e "${YELLOW}No evolution proposals${NC}"
    echo "Run: template-evolver.py"
fi

echo

# 6. MODIFICATIONS
echo -e "${CYAN}${BOLD}🔧 Template Modifications${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$MODIFICATIONS_LOG" ]]; then
    TOTAL_MODS=$(wc -l < "$MODIFICATIONS_LOG" | tr -d ' ')
    echo -e "Total modifications logged: ${GREEN}${TOTAL_MODS}${NC}"

    if [[ $TOTAL_MODS -gt 0 ]]; then
        echo
        echo "Modification types:"

        jq -r '.type' "$MODIFICATIONS_LOG" 2>/dev/null | sort | uniq -c | sort -rn | while read -r count mod_type; do
            printf "  %-30s %d\n" "$mod_type" "$count"
        done
    fi
else
    echo -e "${YELLOW}No modification data${NC}"
fi

echo

# Footer
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Cache directory: ${CACHE_DIR}"
echo -e "Last updated: $(date)"
echo
