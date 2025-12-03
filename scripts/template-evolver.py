#!/usr/bin/env python3
"""
template-evolver.py
Analyzes template modification patterns and generates evolution proposals
"""

import json
import sys
from datetime import datetime
from collections import defaultdict
from pathlib import Path

# Configuration
CACHE_DIR = Path("/Volumes/DevDrive/Cache/templates")
MODIFICATIONS_LOG = CACHE_DIR / "template-modifications.jsonl"
OUTCOMES_LOG = CACHE_DIR / "template-outcomes.jsonl"
CONFIDENCE_SCORES = CACHE_DIR / "learning" / "confidence-scores.json"
OUTPUT_FILE = CACHE_DIR / "evolved" / "evolution-proposals.json"

# Thresholds
ADOPTION_THRESHOLD = 0.70  # 70% of projects must adopt
WIN_RATE_THRESHOLD = 0.75  # 75% win rate
CONFIDENCE_THRESHOLD = 0.70  # 70% confidence score

def load_jsonl(file_path):
    """Load JSONL file and return list of records"""
    records = []
    if not file_path.exists():
        return records

    with open(file_path, 'r') as f:
        for line in f:
            if line.strip():
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return records

def load_json(file_path):
    """Load JSON file"""
    if not file_path.exists():
        return []

    with open(file_path, 'r') as f:
        return json.load(f)

def aggregate_modifications():
    """Aggregate modification patterns by template"""
    print("Analyzing modification patterns...")

    modifications = load_jsonl(MODIFICATIONS_LOG)

    # Group by template_id
    template_mods = defaultdict(lambda: {
        'projects': set(),
        'additions': defaultdict(int)  # path -> count
    })

    for mod in modifications:
        template_id = mod.get('template_id')
        project_path = mod.get('project_path')
        mod_type = mod.get('type')
        path = mod.get('path', '')

        if not template_id or not project_path:
            continue

        data = template_mods[template_id]
        data['projects'].add(project_path)

        # Track additions (directories and files)
        if mod_type in ['directory_added', 'file_added']:
            data['additions'][path] += 1

    # Calculate adoption rates
    patterns = {}
    for template_id, data in template_mods.items():
        total_projects = len(data['projects'])
        if total_projects == 0:
            continue

        patterns[template_id] = {
            'total_projects': total_projects,
            'additions': {}
        }

        for path, count in data['additions'].items():
            adoption_rate = count / total_projects
            patterns[template_id]['additions'][path] = {
                'count': count,
                'adoption_rate': adoption_rate
            }

    return patterns

def load_template_outcomes():
    """Load template outcomes and calculate win rates"""
    print("Loading template outcomes...")

    outcomes = load_jsonl(OUTCOMES_LOG)

    template_outcomes = defaultdict(lambda: {'wins': 0, 'total': 0})

    for outcome in outcomes:
        template_id = outcome.get('template_id')
        outcome_type = outcome.get('outcome')

        if not template_id:
            continue

        data = template_outcomes[template_id]
        data['total'] += 1
        if outcome_type == 'win':
            data['wins'] += 1

    # Calculate win rates
    win_rates = {}
    for template_id, data in template_outcomes.items():
        if data['total'] > 0:
            win_rates[template_id] = data['wins'] / data['total']
        else:
            win_rates[template_id] = 0.5  # Neutral default

    return win_rates

def load_confidence_scores():
    """Load confidence scores"""
    print("Loading confidence scores...")

    scores = load_json(CONFIDENCE_SCORES)

    confidence_map = {}
    for score in scores:
        template_id = score.get('template_id')
        confidence = score.get('confidence_score', 0.0)
        confidence_map[template_id] = confidence

    return confidence_map

def generate_proposals(patterns, win_rates, confidence_scores):
    """Generate evolution proposals based on patterns and thresholds"""
    print("\nGenerating evolution proposals...")

    proposals = []
    proposal_id = 1

    for template_id, data in patterns.items():
        total_projects = data['total_projects']
        template_win_rate = win_rates.get(template_id, 0.5)
        template_confidence = confidence_scores.get(template_id, 0.0)

        # Check if template meets minimum criteria
        if template_win_rate < WIN_RATE_THRESHOLD:
            print(f"  Skipping {template_id}: win_rate {template_win_rate:.2%} < {WIN_RATE_THRESHOLD:.2%}")
            continue

        if template_confidence < CONFIDENCE_THRESHOLD:
            print(f"  Skipping {template_id}: confidence {template_confidence:.2%} < {CONFIDENCE_THRESHOLD:.2%}")
            continue

        # Find qualifying additions
        qualifying_changes = []
        for path, stats in data['additions'].items():
            adoption_rate = stats['adoption_rate']

            if adoption_rate >= ADOPTION_THRESHOLD:
                # Determine type
                change_type = 'directory' if not Path(path).suffix else 'file'

                qualifying_changes.append({
                    'type': change_type,
                    'path': path,
                    'adoption_rate': round(adoption_rate, 4),
                    'projects_count': stats['count']
                })

        # Create proposal if we have qualifying changes
        if qualifying_changes:
            # Get current version (would need to read from template.json)
            current_version = "1.0.0"  # Default, would parse from template

            # Increment minor version
            major, minor, patch = current_version.split('.')
            proposed_version = f"{major}.{int(minor) + 1}.0"

            proposal = {
                'proposal_id': f"PROP-{proposal_id:04d}",
                'template_id': template_id,
                'current_version': current_version,
                'proposed_version': proposed_version,
                'changes': qualifying_changes,
                'rationale': f"Based on analysis of {total_projects} projects with {template_win_rate:.1%} win rate and {template_confidence:.1%} confidence. {len(qualifying_changes)} patterns adopted by ≥{ADOPTION_THRESHOLD:.0%} of projects.",
                'metrics': {
                    'total_projects_analyzed': total_projects,
                    'win_rate': round(template_win_rate, 4),
                    'confidence_score': round(template_confidence, 4),
                    'changes_count': len(qualifying_changes)
                },
                'status': 'pending',
                'created_at': datetime.utcnow().isoformat() + 'Z'
            }

            proposals.append(proposal)
            proposal_id += 1

            print(f"  ✓ Created proposal for {template_id}: {len(qualifying_changes)} changes")

    return proposals

def save_proposals(proposals):
    """Save proposals to JSON file"""
    # Create output directory
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(proposals, f, indent=2)

    print(f"\nSaved {len(proposals)} proposals to: {OUTPUT_FILE}")

def main():
    print("Template Evolution Analyzer")
    print("=" * 50)

    # Aggregate modification patterns
    patterns = aggregate_modifications()
    print(f"Analyzed patterns for {len(patterns)} templates")

    # Load outcomes
    win_rates = load_template_outcomes()
    print(f"Loaded outcomes for {len(win_rates)} templates")

    # Load confidence scores
    confidence_scores = load_confidence_scores()
    print(f"Loaded confidence scores for {len(confidence_scores)} templates")

    # Generate proposals
    proposals = generate_proposals(patterns, win_rates, confidence_scores)

    # Save proposals
    if proposals:
        save_proposals(proposals)

        # Summary
        print("\n" + "=" * 50)
        print("SUMMARY:")
        print(f"  Total proposals: {len(proposals)}")
        for proposal in proposals:
            print(f"    - {proposal['proposal_id']}: {proposal['template_id']} ({proposal['changes_count']} changes)")
    else:
        print("\nNo proposals generated. Templates may not meet thresholds or no data available.")
        # Still create empty file
        OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(OUTPUT_FILE, 'w') as f:
            json.dump([], f, indent=2)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
