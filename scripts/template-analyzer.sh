#!/bin/bash
# Template Analyzer - Adaptive Template Learning System
# Scans projects with template metadata and tracks structural evolution
# Logs modifications to learn which directories/files are commonly added/removed

set -euo pipefail

# Configuration
LEARNING_DIR="/Volumes/DevDrive/Cache/templates/learning"
MODIFICATIONS_LOG="$LEARNING_DIR/modifications.jsonl"
SEARCH_ROOTS=(
  "$HOME"
  "/Volumes/DevDrive/Projects"
)

# Ensure learning directory exists
mkdir -p "$LEARNING_DIR"

# Function to calculate days since creation
days_since_creation() {
  local created_ts="$1"
  local now_ts=$(date +%s)
  local diff=$((now_ts - created_ts))
  echo $((diff / 86400))
}

# Function to normalize paths for comparison
normalize_path() {
  echo "$1" | sed 's|/$||' | sed 's|^\./||'
}

# Function to find all directories in a path
get_directories() {
  local base_path="$1"
  find "$base_path" -type d \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/Build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/venv/*" \
    2>/dev/null | \
    sed "s|^$base_path/||" | \
    grep -v "^$base_path$" | \
    sort
}

# Function to find all files in a path
get_files() {
  local base_path="$1"
  find "$base_path" -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/Build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/venv/*" \
    -not -name "*.xcuserstate" \
    -not -name ".DS_Store" \
    2>/dev/null | \
    sed "s|^$base_path/||" | \
    grep -v "^$base_path$" | \
    sort
}

# Function to compare arrays and find differences
array_diff() {
  local -n arr1=$1
  local -n arr2=$2
  local result=()

  for item in "${arr1[@]}"; do
    local found=0
    for check in "${arr2[@]}"; do
      if [ "$item" = "$check" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      result+=("$item")
    fi
  done

  printf '%s\n' "${result[@]}"
}

# Function to analyze a single project
analyze_project() {
  local metadata_file="$1"
  local project_dir=$(dirname "$metadata_file")

  # Read metadata
  if [ ! -f "$metadata_file" ]; then
    return
  fi

  local template_id=$(jq -r '.template_id // ""' "$metadata_file")
  local created_at=$(jq -r '.created_at // ""' "$metadata_file")
  local initial_structure=$(jq -r '.initial_structure // {}' "$metadata_file")

  if [ -z "$template_id" ] || [ -z "$created_at" ]; then
    echo "Warning: Invalid metadata in $metadata_file" >&2
    return
  fi

  # Calculate days since creation
  local created_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" "+%s" 2>/dev/null || echo "0")
  local days_old=$(days_since_creation "$created_ts")

  # Get initial structure
  mapfile -t initial_dirs < <(echo "$initial_structure" | jq -r '.directories[]? // empty' | sort)
  mapfile -t initial_files < <(echo "$initial_structure" | jq -r '.files[]? // empty' | sort)

  # Get current structure
  mapfile -t current_dirs < <(get_directories "$project_dir")
  mapfile -t current_files < <(get_files "$project_dir")

  # Calculate differences
  local dirs_added=()
  local dirs_removed=()
  local files_added=()
  local files_removed=()

  # Find added directories
  for dir in "${current_dirs[@]}"; do
    local found=0
    for initial_dir in "${initial_dirs[@]}"; do
      if [ "$dir" = "$initial_dir" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      dirs_added+=("$dir")
    fi
  done

  # Find removed directories
  for initial_dir in "${initial_dirs[@]}"; do
    local found=0
    for dir in "${current_dirs[@]}"; do
      if [ "$initial_dir" = "$dir" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      dirs_removed+=("$initial_dir")
    fi
  done

  # Find added files
  for file in "${current_files[@]}"; do
    local found=0
    for initial_file in "${initial_files[@]}"; do
      if [ "$file" = "$initial_file" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      files_added+=("$file")
    fi
  done

  # Find removed files
  for initial_file in "${initial_files[@]}"; do
    local found=0
    for file in "${current_files[@]}"; do
      if [ "$initial_file" = "$file" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      files_removed+=("$initial_file")
    fi
  done

  # Only log if there are modifications
  if [ ${#dirs_added[@]} -gt 0 ] || [ ${#dirs_removed[@]} -gt 0 ] || \
     [ ${#files_added[@]} -gt 0 ] || [ ${#files_removed[@]} -gt 0 ]; then

    local project_name=$(basename "$project_dir")
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Build JSON entry
    local json_entry=$(jq -n \
      --arg ts "$timestamp" \
      --arg project "$project_name" \
      --arg template "$template_id" \
      --arg days "$days_old" \
      --argjson dirs_added "$(printf '%s\n' "${dirs_added[@]}" | jq -R . | jq -s .)" \
      --argjson dirs_removed "$(printf '%s\n' "${dirs_removed[@]}" | jq -R . | jq -s .)" \
      --argjson files_added "$(printf '%s\n' "${files_added[@]}" | jq -R . | jq -s .)" \
      --argjson files_removed "$(printf '%s\n' "${files_removed[@]}" | jq -R . | jq -s .)" \
      '{
        timestamp: $ts,
        project_name: $project,
        template_id: $template,
        days_since_creation: ($days | tonumber),
        modifications: {
          directories_added: $dirs_added,
          directories_removed: $dirs_removed,
          files_added: $files_added,
          files_removed: $files_removed
        }
      }')

    # Append to log
    echo "$json_entry" >> "$MODIFICATIONS_LOG"

    echo "Analyzed: $project_name (template: $template_id, age: $days_old days)"
    echo "  Dirs +${#dirs_added[@]} -${#dirs_removed[@]}, Files +${#files_added[@]} -${#files_removed[@]}"
  fi
}

# Main execution
main() {
  echo "Template Analyzer - Scanning for projects with template metadata..."
  echo "Logging to: $MODIFICATIONS_LOG"
  echo ""

  local projects_found=0
  local projects_analyzed=0

  # Search for all template-metadata.json files
  for root in "${SEARCH_ROOTS[@]}"; do
    if [ ! -d "$root" ]; then
      continue
    fi

    while IFS= read -r metadata_file; do
      projects_found=$((projects_found + 1))
      echo "Found: $metadata_file"

      if analyze_project "$metadata_file"; then
        projects_analyzed=$((projects_analyzed + 1))
      fi
    done < <(find "$root" -type f -name "template-metadata.json" -path "*/.claude/*" 2>/dev/null)
  done

  echo ""
  echo "Scan complete: $projects_found projects found, $projects_analyzed analyzed"

  # Show summary if modifications were logged
  if [ -f "$MODIFICATIONS_LOG" ]; then
    local total_entries=$(wc -l < "$MODIFICATIONS_LOG" | xargs)
    echo "Total modification entries: $total_entries"
  fi
}

# Run main function
main "$@"
