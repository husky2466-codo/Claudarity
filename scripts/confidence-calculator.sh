#!/usr/bin/env bash
# confidence-calculator.sh
# Calculates confidence scores for templates based on usage, outcomes, and recency

set -euo pipefail

# Configuration
CACHE_DIR="/Volumes/DevDrive/Cache/templates"
USAGE_LOG="${CACHE_DIR}/template-usage.jsonl"
OUTCOMES_LOG="${CACHE_DIR}/template-outcomes.jsonl"
OUTPUT_FILE="${CACHE_DIR}/learning/confidence-scores.json"

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if required files exist
if [[ ! -f "$USAGE_LOG" ]]; then
    echo "Warning: $USAGE_LOG not found. Creating empty confidence scores."
    echo "[]" > "$OUTPUT_FILE"
    exit 0
fi

# Initialize output
echo "Calculating template confidence scores..."
echo "Reading from: $USAGE_LOG"
echo "Reading from: $OUTCOMES_LOG"

# Create temporary files
TEMP_USAGE=$(mktemp)
TEMP_OUTCOMES=$(mktemp)
TEMP_SCORES=$(mktemp)

# Cleanup on exit
trap 'rm -f "$TEMP_USAGE" "$TEMP_OUTCOMES" "$TEMP_SCORES"' EXIT

# Extract template usage counts
if [[ -f "$USAGE_LOG" ]]; then
    jq -r '.template_id' "$USAGE_LOG" 2>/dev/null | sort | uniq -c | \
    awk '{print $2 "," $1}' > "$TEMP_USAGE" || echo "" > "$TEMP_USAGE"
else
    echo "" > "$TEMP_USAGE"
fi

# Process outcomes if available
if [[ -f "$OUTCOMES_LOG" ]]; then
    # Create Python script to calculate metrics
    python3 - <<'PYTHON_SCRIPT' "$OUTCOMES_LOG" "$TEMP_OUTCOMES"
import sys
import json
from datetime import datetime
from collections import defaultdict

outcomes_file = sys.argv[1]
output_file = sys.argv[2]

# Read outcomes
template_data = defaultdict(lambda: {
    'wins': 0,
    'total': 0,
    'recent_wins': 0,
    'recent_total': 0,
    'project_ages': []
})

now = datetime.now()

try:
    with open(outcomes_file, 'r') as f:
        for line in f:
            if line.strip():
                try:
                    outcome = json.loads(line)
                    template_id = outcome.get('template_id')
                    outcome_type = outcome.get('outcome')
                    timestamp = outcome.get('timestamp', '')
                    project_age_days = outcome.get('project_age_days', 0)

                    if not template_id:
                        continue

                    data = template_data[template_id]
                    data['total'] += 1

                    if outcome_type == 'win':
                        data['wins'] += 1

                    # Calculate recency (within last 90 days)
                    try:
                        outcome_date = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        days_ago = (now - outcome_date).days
                        if days_ago <= 90:
                            data['recent_total'] += 1
                            if outcome_type == 'win':
                                data['recent_wins'] += 1
                    except:
                        pass

                    # Track project ages
                    if project_age_days > 0:
                        data['project_ages'].append(project_age_days)

                except json.JSONDecodeError:
                    continue

    # Write processed data
    with open(output_file, 'w') as f:
        for template_id, data in template_data.items():
            win_rate = data['wins'] / data['total'] if data['total'] > 0 else 0.0
            recency_factor = data['recent_wins'] / data['recent_total'] if data['recent_total'] > 0 else 0.0
            avg_project_age = sum(data['project_ages']) / len(data['project_ages']) if data['project_ages'] else 0.0

            f.write(f"{template_id},{win_rate},{recency_factor},{avg_project_age}\n")

except FileNotFoundError:
    pass

PYTHON_SCRIPT
else
    echo "" > "$TEMP_OUTCOMES"
fi

# Combine usage and outcome data to calculate confidence
python3 - <<'PYTHON_SCRIPT' "$TEMP_USAGE" "$TEMP_OUTCOMES" "$OUTPUT_FILE"
import sys
import json
from datetime import datetime

usage_file = sys.argv[1]
outcomes_file = sys.argv[2]
output_file = sys.argv[3]

# Read usage counts
usage_counts = {}
try:
    with open(usage_file, 'r') as f:
        for line in f:
            if line.strip():
                parts = line.strip().split(',')
                if len(parts) == 2:
                    template_id, count = parts
                    usage_counts[template_id] = int(count)
except FileNotFoundError:
    pass

# Read outcome metrics
outcome_metrics = {}
try:
    with open(outcomes_file, 'r') as f:
        for line in f:
            if line.strip():
                parts = line.strip().split(',')
                if len(parts) == 4:
                    template_id, win_rate, recency_factor, avg_project_age = parts
                    outcome_metrics[template_id] = {
                        'win_rate': float(win_rate),
                        'recency_factor': float(recency_factor),
                        'avg_project_age': float(avg_project_age)
                    }
except FileNotFoundError:
    pass

# Calculate confidence scores
scores = []
all_templates = set(usage_counts.keys()) | set(outcome_metrics.keys())

for template_id in all_templates:
    application_count = usage_counts.get(template_id, 0)
    metrics = outcome_metrics.get(template_id, {
        'win_rate': 0.5,  # Default neutral
        'recency_factor': 0.0,
        'avg_project_age': 0.0
    })

    # Confidence formula
    confidence = (
        min(application_count / 10, 1.0) * 0.3 +
        metrics['win_rate'] * 0.4 +
        min(metrics['recency_factor'], 1.0) * 0.1 +
        min(metrics['avg_project_age'] / 90, 1.0) * 0.2
    )

    scores.append({
        'template_id': template_id,
        'confidence_score': round(confidence, 4),
        'application_count': application_count,
        'win_rate': round(metrics['win_rate'], 4),
        'recency_factor': round(metrics['recency_factor'], 4),
        'avg_project_age_days': round(metrics['avg_project_age'], 2),
        'last_calculated': datetime.utcnow().isoformat() + 'Z'
    })

# Sort by confidence score descending
scores.sort(key=lambda x: x['confidence_score'], reverse=True)

# Write output
with open(output_file, 'w') as f:
    json.dump(scores, f, indent=2)

print(f"Calculated confidence scores for {len(scores)} templates")
print(f"Output written to: {output_file}")

PYTHON_SCRIPT

echo "Confidence calculation complete!"
