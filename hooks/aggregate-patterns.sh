#!/bin/bash

################################################################################
# aggregate-patterns.sh
#
# Purpose:
#   Aggregate feedback patterns across all projects from session logs and
#   generate cross-project-patterns.jsonl with confidence scores.
#
# Algorithm:
#   1. Read session-wins.jsonl and session-losses.jsonl
#   2. Group patterns by name across all projects
#   3. Calculate metrics: win_count, loss_count, win_rate, confidence
#   4. Determine global_scope based on project spread or high win rate
#   5. Write aggregated patterns to cross-project-patterns.jsonl
#
# Output Format:
#   One JSON object per line with pattern metrics and confidence scores
#
# Usage:
#   ./aggregate-patterns.sh
#
################################################################################

set -euo pipefail

# Paths
LOGS_DIR="$HOME/.claude/logs"
WINS_FILE="$LOGS_DIR/session-wins.jsonl"
LOSSES_FILE="$LOGS_DIR/session-losses.jsonl"
OUTPUT_FILE="$LOGS_DIR/cross-project-patterns.jsonl"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Initialize temporary files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

COMBINED_FILE="$TEMP_DIR/combined.jsonl"
PATTERNS_FILE="$TEMP_DIR/patterns.txt"
AGGREGATED_FILE="$TEMP_DIR/aggregated.jsonl"

# Function to calculate confidence score based on sample size
calculate_confidence() {
    local total_samples=$1

    if [ "$total_samples" -le 2 ]; then
        echo "0.3"
    elif [ "$total_samples" -le 5 ]; then
        echo "0.6"
    elif [ "$total_samples" -le 10 ]; then
        echo "0.8"
    else
        echo "0.95"
    fi
}

# Function to safely read JSONL file
read_jsonl_safe() {
    local file=$1
    if [ -f "$file" ] && [ -s "$file" ]; then
        # Filter out any malformed JSON lines
        while IFS= read -r line; do
            if echo "$line" | jq -e . >/dev/null 2>&1; then
                echo "$line"
            fi
        done < "$file"
    fi
}

# Combine wins and losses, marking each with its type
{
    read_jsonl_safe "$WINS_FILE" | jq -c '. + {entry_type: "win"}'
    read_jsonl_safe "$LOSSES_FILE" | jq -c '. + {entry_type: "loss"}'
} > "$COMBINED_FILE"

# Exit if no data
if [ ! -s "$COMBINED_FILE" ]; then
    # Create empty output file
    > "$OUTPUT_FILE"
    exit 0
fi

# Extract unique pattern names (using 'matched' field from session logs)
jq -r '.matched' "$COMBINED_FILE" 2>/dev/null | sort -u > "$PATTERNS_FILE" || {
    echo "Error: Failed to extract patterns" >&2
    > "$OUTPUT_FILE"
    exit 0
}

# Process each pattern
while IFS= read -r pattern; do
    # Skip empty patterns
    [ -z "$pattern" ] && continue

    # Extract all entries for this pattern (using 'matched' field)
    PATTERN_ENTRIES=$(jq -c --arg pat "$pattern" 'select(.matched == $pat)' "$COMBINED_FILE")

    # Skip if no entries (shouldn't happen, but be safe)
    [ -z "$PATTERN_ENTRIES" ] && continue

    # Calculate metrics using jq
    METRICS=$(echo "$PATTERN_ENTRIES" | jq -s --arg pat "$pattern" '
        {
            pattern: $pat,
            win_count: ([.[] | select(.entry_type == "win")] | length),
            loss_count: ([.[] | select(.entry_type == "loss")] | length),
            projects: ([.[].project] | unique),
            timestamps: [.[].ts],
            type: (
                if ([.[] | select(.entry_type == "win")] | length) >
                   ([.[] | select(.entry_type == "loss")] | length)
                then "win"
                else "loss"
                end
            )
        }
    ')

    # Extract values
    WIN_COUNT=$(echo "$METRICS" | jq -r '.win_count')
    LOSS_COUNT=$(echo "$METRICS" | jq -r '.loss_count')
    PROJECTS=$(echo "$METRICS" | jq -c '.projects')
    PROJECT_COUNT=$(echo "$PROJECTS" | jq 'length')
    TYPE=$(echo "$METRICS" | jq -r '.type')
    TIMESTAMPS=$(echo "$METRICS" | jq -r '.timestamps | sort | .[0], .[-1]')
    FIRST_SEEN=$(echo "$TIMESTAMPS" | head -n1)
    LAST_SEEN=$(echo "$TIMESTAMPS" | tail -n1)

    # Calculate total samples and win rate
    TOTAL_SAMPLES=$((WIN_COUNT + LOSS_COUNT))

    if [ "$TOTAL_SAMPLES" -eq 0 ]; then
        WIN_RATE=0
    else
        WIN_RATE=$(echo "scale=4; $WIN_COUNT / $TOTAL_SAMPLES" | bc)
    fi

    # Calculate confidence
    CONFIDENCE=$(calculate_confidence "$TOTAL_SAMPLES")

    # Determine global scope
    GLOBAL_SCOPE=false
    if [ "$PROJECT_COUNT" -ge 2 ]; then
        GLOBAL_SCOPE=true
    elif [ "$TOTAL_SAMPLES" -ge 5 ]; then
        # Check if win rate >= 0.95
        IS_HIGH_RATE=$(echo "$WIN_RATE >= 0.95" | bc)
        if [ "$IS_HIGH_RATE" -eq 1 ]; then
            GLOBAL_SCOPE=true
        fi
    fi

    # Build JSON object
    jq -n \
        --arg pattern "$pattern" \
        --arg type "$TYPE" \
        --argjson projects "$PROJECTS" \
        --argjson win_count "$WIN_COUNT" \
        --argjson loss_count "$LOSS_COUNT" \
        --argjson win_rate "$WIN_RATE" \
        --argjson confidence "$CONFIDENCE" \
        --argjson global_scope "$GLOBAL_SCOPE" \
        --arg first_seen "$FIRST_SEEN" \
        --arg last_seen "$LAST_SEEN" \
        '{
            pattern: $pattern,
            type: $type,
            projects: $projects,
            win_count: $win_count,
            loss_count: $loss_count,
            win_rate: $win_rate,
            confidence: $confidence,
            global_scope: $global_scope,
            first_seen: $first_seen,
            last_seen: $last_seen
        }' >> "$AGGREGATED_FILE"

done < "$PATTERNS_FILE"

# Sort by confidence (descending) and write to output
if [ -f "$AGGREGATED_FILE" ] && [ -s "$AGGREGATED_FILE" ]; then
    jq -s 'sort_by(-.confidence)[]' "$AGGREGATED_FILE" > "$OUTPUT_FILE"
else
    # Create empty output file
    > "$OUTPUT_FILE"
fi

exit 0
