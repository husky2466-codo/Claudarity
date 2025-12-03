#!/usr/bin/env bash
# apply-template-evolution.sh
# Applies an evolution proposal to a template, creating a new version

set -euo pipefail

# Configuration
CACHE_DIR="/Volumes/DevDrive/Cache/templates"
TEMPLATES_DIR="/Volumes/DevDrive/Cache/templates/library"
EVOLVED_DIR="/Volumes/DevDrive/Cache/templates/evolved"
PROPOSALS_FILE="${EVOLVED_DIR}/evolution-proposals.json"
HISTORY_LOG="${CACHE_DIR}/template-history.jsonl"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
    cat << EOF
Usage: $(basename "$0") PROPOSAL_ID

Apply a template evolution proposal

Arguments:
  PROPOSAL_ID    The proposal ID to apply (e.g., PROP-0001)

Example:
  $(basename "$0") PROP-0001

EOF
    exit 1
}

# Check arguments
if [[ $# -ne 1 ]]; then
    usage
fi

PROPOSAL_ID="$1"

# Check if proposals file exists
if [[ ! -f "$PROPOSALS_FILE" ]]; then
    echo -e "${RED}Error: Proposals file not found: $PROPOSALS_FILE${NC}"
    echo "Run template-evolver.py first to generate proposals."
    exit 1
fi

echo -e "${BLUE}Applying Template Evolution${NC}"
echo "================================"
echo

# Find proposal
echo "Looking for proposal: $PROPOSAL_ID"
PROPOSAL=$(jq -r --arg id "$PROPOSAL_ID" '.[] | select(.proposal_id == $id)' "$PROPOSALS_FILE")

if [[ -z "$PROPOSAL" ]]; then
    echo -e "${RED}Error: Proposal $PROPOSAL_ID not found${NC}"
    echo
    echo "Available proposals:"
    jq -r '.[] | "  - \(.proposal_id): \(.template_id) (\(.status))"' "$PROPOSALS_FILE"
    exit 1
fi

# Extract proposal details
TEMPLATE_ID=$(echo "$PROPOSAL" | jq -r '.template_id')
CURRENT_VERSION=$(echo "$PROPOSAL" | jq -r '.current_version')
PROPOSED_VERSION=$(echo "$PROPOSAL" | jq -r '.proposed_version')
STATUS=$(echo "$PROPOSAL" | jq -r '.status')
CHANGES=$(echo "$PROPOSAL" | jq -r '.changes')

echo -e "${GREEN}Found proposal:${NC}"
echo "  Template: $TEMPLATE_ID"
echo "  Current version: $CURRENT_VERSION"
echo "  Proposed version: $PROPOSED_VERSION"
echo "  Status: $STATUS"
echo

# Check if already applied
if [[ "$STATUS" == "applied" ]]; then
    echo -e "${YELLOW}Warning: This proposal has already been applied${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Find template directory
TEMPLATE_DIR="${TEMPLATES_DIR}/${TEMPLATE_ID}"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo -e "${RED}Error: Template directory not found: $TEMPLATE_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}Template found at: $TEMPLATE_DIR${NC}"
echo

# Show changes
echo "Changes to apply:"
echo "$CHANGES" | jq -r '.[] | "  [\(.type)] \(.path) (adopted by \(.adoption_rate * 100)% of projects)"'
echo

# Confirm
read -p "Apply these changes? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Create evolved template directory
EVOLVED_TEMPLATE_DIR="${EVOLVED_DIR}/${TEMPLATE_ID}-v${PROPOSED_VERSION}"
mkdir -p "$EVOLVED_TEMPLATE_DIR"

echo -e "${BLUE}Creating evolved template at: $EVOLVED_TEMPLATE_DIR${NC}"

# Copy current template
echo "Copying current template..."
cp -r "$TEMPLATE_DIR"/* "$EVOLVED_TEMPLATE_DIR/"

# Update template.json
TEMPLATE_JSON="${EVOLVED_TEMPLATE_DIR}/template.json"
if [[ -f "$TEMPLATE_JSON" ]]; then
    echo "Updating template.json version..."

    # Update version and add evolution metadata
    jq --arg version "$PROPOSED_VERSION" \
       --arg proposal_id "$PROPOSAL_ID" \
       --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '.version = $version | .evolution = {
           proposal_id: $proposal_id,
           previous_version: .version,
           evolved_at: $timestamp
       }' "$TEMPLATE_JSON" > "${TEMPLATE_JSON}.tmp"

    mv "${TEMPLATE_JSON}.tmp" "$TEMPLATE_JSON"
fi

# Update structure.yaml
STRUCTURE_YAML="${EVOLVED_TEMPLATE_DIR}/structure.yaml"
if [[ -f "$STRUCTURE_YAML" ]]; then
    echo "Updating structure.yaml..."

    # Create temporary Python script to update YAML
    python3 - <<'PYTHON_SCRIPT' "$STRUCTURE_YAML" "$CHANGES"
import sys
import yaml
from pathlib import Path
import json

structure_file = sys.argv[1]
changes_json = sys.argv[2]

# Load structure
with open(structure_file, 'r') as f:
    structure = yaml.safe_load(f)

# Load changes
changes = json.loads(changes_json)

# Initialize directories and files if not present
if 'directories' not in structure:
    structure['directories'] = []
if 'files' not in structure:
    structure['files'] = []

# Apply changes
for change in changes:
    change_type = change['type']
    path = change['path']

    if change_type == 'directory':
        # Add directory if not already present
        if path not in structure['directories']:
            structure['directories'].append(path)
            print(f"  + Added directory: {path}")

    elif change_type == 'file':
        # Add file if not already present
        file_exists = any(f.get('path') == path for f in structure['files'])
        if not file_exists:
            structure['files'].append({
                'path': path,
                'content': '# Auto-generated from evolution proposal\n'
            })
            print(f"  + Added file: {path}")

# Sort for consistency
structure['directories'].sort()

# Save updated structure
with open(structure_file, 'w') as f:
    yaml.dump(structure, f, default_flow_style=False, sort_keys=False)

PYTHON_SCRIPT
fi

# Log to history
echo "Logging to template history..."
mkdir -p "$(dirname "$HISTORY_LOG")"

cat >> "$HISTORY_LOG" << EOF
{"timestamp":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","template_id":"${TEMPLATE_ID}","action":"evolution_applied","proposal_id":"${PROPOSAL_ID}","previous_version":"${CURRENT_VERSION}","new_version":"${PROPOSED_VERSION}","changes_count":$(echo "$CHANGES" | jq 'length'),"evolved_path":"${EVOLVED_TEMPLATE_DIR}"}
EOF

# Update proposal status
echo "Updating proposal status..."
jq --arg id "$PROPOSAL_ID" \
   --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
   'map(if .proposal_id == $id then . + {status: "applied", applied_at: $timestamp} else . end)' \
   "$PROPOSALS_FILE" > "${PROPOSALS_FILE}.tmp"

mv "${PROPOSALS_FILE}.tmp" "$PROPOSALS_FILE"

# Summary
echo
echo -e "${GREEN}Evolution applied successfully!${NC}"
echo
echo "Summary:"
echo "  Proposal: $PROPOSAL_ID"
echo "  Template: $TEMPLATE_ID"
echo "  Version: $CURRENT_VERSION → $PROPOSED_VERSION"
echo "  Changes: $(echo "$CHANGES" | jq 'length')"
echo "  Location: $EVOLVED_TEMPLATE_DIR"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the evolved template at: $EVOLVED_TEMPLATE_DIR"
echo "  2. Test the template on a new project"
echo "  3. If satisfied, replace the original template in $TEMPLATES_DIR"
echo
