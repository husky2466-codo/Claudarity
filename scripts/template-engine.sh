#!/opt/homebrew/bin/bash

# Template Engine - Adaptive Template Learning System
# Created: 2025-12-01
# Author: WOO WOO (Nicolas Robert Myers)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TEMPLATE_DIR="/Volumes/DevDrive/Cache/templates"
BASE_DIR="${TEMPLATE_DIR}/base"
LEARNING_DIR="${TEMPLATE_DIR}/learning"
EVOLVED_DIR="${TEMPLATE_DIR}/evolved"

# Functions
function print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}Template Engine - Adaptive Project Creation${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

function print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

function print_error() {
    echo -e "${RED}✗${NC} $1"
}

function print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

function check_devdrive() {
    if [ ! -d "$TEMPLATE_DIR" ]; then
        print_error "Template directory not found at $TEMPLATE_DIR"
        print_info "Make sure DevDrive is mounted and templates are initialized"
        exit 1
    fi
}

function select_template() {
    echo -e "${CYAN}Available Templates:${NC}"
    echo ""

    local templates=()
    local index=1

    # List templates from base directory
    for template_dir in "$BASE_DIR"/*; do
        if [ -d "$template_dir" ] && [ -f "$template_dir/template.json" ]; then
            local template_name=$(basename "$template_dir")
            local description=$(jq -r '.description' "$template_dir/template.json" 2>/dev/null || echo "No description")
            local confidence=$(jq -r '.confidence_score' "$template_dir/template.json" 2>/dev/null || echo "0")
            local usage_count=$(jq -r '.usage_count' "$template_dir/template.json" 2>/dev/null || echo "0")

            templates+=("$template_dir")

            # Display with confidence indicator
            local confidence_display=""
            if (( $(echo "$confidence >= 0.9" | bc -l) )); then
                confidence_display="${GREEN}●●●${NC} ${confidence}"
            elif (( $(echo "$confidence >= 0.7" | bc -l) )); then
                confidence_display="${YELLOW}●●○${NC} ${confidence}"
            else
                confidence_display="${RED}●○○${NC} ${confidence}"
            fi

            echo -e "  ${BLUE}[$index]${NC} ${YELLOW}$template_name${NC}"
            echo -e "      $description"
            echo -e "      Confidence: $confidence_display | Used: ${usage_count}x"
            echo ""

            ((index++))
        fi
    done

    if [ ${#templates[@]} -eq 0 ]; then
        print_error "No templates found in $BASE_DIR"
        exit 1
    fi

    echo -n "Select template (1-${#templates[@]}): "
    read -r selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#templates[@]} ]; then
        print_error "Invalid selection"
        exit 1
    fi

    SELECTED_TEMPLATE="${templates[$((selection-1))]}"
    SELECTED_TEMPLATE_NAME=$(basename "$SELECTED_TEMPLATE")

    print_success "Selected template: ${YELLOW}$SELECTED_TEMPLATE_NAME${NC}"
    echo ""
}

function gather_variables() {
    print_info "Gathering template variables..."
    echo ""

    # Read template.json
    local template_json="$SELECTED_TEMPLATE/template.json"

    # Parse variables
    local var_count=$(jq '.variables | length' "$template_json")

    declare -g -A TEMPLATE_VARS

    for ((i=0; i<var_count; i++)); do
        local var_name=$(jq -r ".variables[$i].name" "$template_json")
        local var_desc=$(jq -r ".variables[$i].description" "$template_json")
        local var_required=$(jq -r ".variables[$i].required" "$template_json")
        local var_default=$(jq -r ".variables[$i].default" "$template_json")
        local var_auto_gen=$(jq -r ".variables[$i].auto_generate" "$template_json")
        local var_example=$(jq -r ".variables[$i].example" "$template_json")

        local value=""

        # Auto-generate if specified
        if [ "$var_auto_gen" != "null" ] && [ "$var_auto_gen" != "false" ]; then
            value=$(eval "$var_auto_gen")
            print_info "Auto-generated ${YELLOW}$var_name${NC}: $value"
        else
            # Prompt user
            local prompt_text="${CYAN}$var_name${NC} - $var_desc"
            if [ "$var_example" != "null" ]; then
                prompt_text="$prompt_text (e.g., $var_example)"
            fi
            if [ "$var_default" != "null" ]; then
                prompt_text="$prompt_text [default: $var_default]"
            fi

            echo -e "$prompt_text"
            echo -n "> "
            read -r value

            # Use default if empty and available
            if [ -z "$value" ] && [ "$var_default" != "null" ]; then
                value="$var_default"
            fi

            # Check required
            if [ "$var_required" == "true" ] && [ -z "$value" ]; then
                print_error "Required variable cannot be empty"
                exit 1
            fi
        fi

        TEMPLATE_VARS["$var_name"]="$value"
    done

    echo ""
    print_success "Variables collected"
    echo ""
}

function preview_structure() {
    echo -e "${CYAN}Preview Project Structure:${NC}"
    echo ""

    # Read structure.yaml and display
    if [ -f "$SELECTED_TEMPLATE/structure.yaml" ]; then
        echo -e "${YELLOW}Structure:${NC}"
        cat "$SELECTED_TEMPLATE/structure.yaml" | grep -E "^  - name:" | sed 's/^  - name: /  /'
        echo ""
    fi

    # Show files to be created
    echo -e "${YELLOW}Files to create:${NC}"
    local file_count=$(jq '.files | length' "$SELECTED_TEMPLATE/template.json")
    for ((i=0; i<file_count; i++)); do
        local dest=$(jq -r ".files[$i].destination" "$SELECTED_TEMPLATE/template.json")
        local desc=$(jq -r ".files[$i].description" "$SELECTED_TEMPLATE/template.json")
        echo "  - $dest ($desc)"
    done
    echo ""

    echo -n "Continue with project creation? (y/n): "
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "Project creation cancelled"
        exit 0
    fi
    echo ""
}

function substitute_variables() {
    local input_file="$1"
    local output_file="$2"

    # Start with input content
    local content=$(cat "$input_file")

    # Substitute each variable
    for var_name in "${!TEMPLATE_VARS[@]}"; do
        local var_value="${TEMPLATE_VARS[$var_name]}"
        # Escape special characters for sed
        var_value=$(echo "$var_value" | sed 's/[\/&]/\\&/g')
        content=$(echo "$content" | sed "s/{$var_name}/$var_value/g")
    done

    # Write to output
    echo "$content" > "$output_file"
}

function apply_template() {
    local project_name="${TEMPLATE_VARS[ProjectName]}"
    local target_dir="$PWD/$project_name"

    print_info "Creating project: ${YELLOW}$project_name${NC}"
    print_info "Target directory: ${YELLOW}$target_dir${NC}"
    echo ""

    # Check if directory exists
    if [ -d "$target_dir" ]; then
        print_error "Directory already exists: $target_dir"
        echo -n "Overwrite? (y/n): "
        read -r overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            print_warning "Project creation cancelled"
            exit 0
        fi
        rm -rf "$target_dir"
    fi

    # Create project directory
    mkdir -p "$target_dir"
    print_success "Created directory: $project_name"

    # Copy and process template files
    local file_count=$(jq '.files | length' "$SELECTED_TEMPLATE/template.json")

    for ((i=0; i<file_count; i++)); do
        local source=$(jq -r ".files[$i].source" "$SELECTED_TEMPLATE/template.json")
        local dest=$(jq -r ".files[$i].destination" "$SELECTED_TEMPLATE/template.json")

        local source_file="$SELECTED_TEMPLATE/files/$source"
        local dest_file="$target_dir/$dest"

        if [ -f "$source_file" ]; then
            # Create parent directories if needed
            mkdir -p "$(dirname "$dest_file")"

            # Substitute variables and create file
            substitute_variables "$source_file" "$dest_file"
            print_success "Created: $dest"
        else
            print_warning "Template file not found: $source"
        fi
    done

    echo ""
    print_success "Project created successfully!"
    echo ""

    # Show post-create steps
    echo -e "${CYAN}Next Steps:${NC}"
    local step_count=$(jq '.post_create_steps | length' "$SELECTED_TEMPLATE/template.json")
    for ((i=0; i<step_count; i++)); do
        local step=$(jq -r ".post_create_steps[$i]" "$SELECTED_TEMPLATE/template.json")
        echo "  $((i+1)). $step"
    done
    echo ""

    # Update template usage statistics
    update_template_stats

    print_info "Project location: ${YELLOW}$target_dir${NC}"
}

function capture_structure() {
    local base_path="$1"

    # Get all directories (relative to base_path)
    local dirs=$(find "$base_path" -type d \
        -not -path "*/\.*" \
        -not -path "*/node_modules/*" \
        -not -path "*/Build/*" \
        -not -path "*/DerivedData/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/venv/*" \
        2>/dev/null | \
        sed "s|^$base_path/||" | \
        grep -v "^$base_path$" | \
        sort | \
        jq -R . | jq -s .)

    # Get all files (relative to base_path)
    local files=$(find "$base_path" -type f \
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
        sort | \
        jq -R . | jq -s .)

    jq -n \
        --argjson dirs "$dirs" \
        --argjson files "$files" \
        '{directories: $dirs, files: $files}'
}

function update_template_stats() {
    local template_json="$SELECTED_TEMPLATE/template.json"
    local temp_file=$(mktemp)

    # Increment usage count
    jq '.usage_count += 1 | .last_used = now | .updated = (now | strftime("%Y-%m-%d"))' "$template_json" > "$temp_file"
    mv "$temp_file" "$template_json"

    # ============ ADAPTIVE LEARNING: USAGE TRACKING ============
    local project_name="${TEMPLATE_VARS[ProjectName]}"
    local target_dir="$PWD/$project_name"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Log template usage
    local usage_log="$LEARNING_DIR/template-usage.jsonl"
    mkdir -p "$LEARNING_DIR"
    echo "{\"timestamp\":\"$timestamp\",\"template_id\":\"$SELECTED_TEMPLATE_NAME\",\"project_name\":\"$project_name\",\"project_path\":\"$target_dir\"}" >> "$usage_log"

    # Create template metadata for tracking structural evolution
    mkdir -p "$target_dir/.claude"
    local initial_structure=$(capture_structure "$target_dir")

    jq -n \
        --arg template "$SELECTED_TEMPLATE_NAME" \
        --arg created "$timestamp" \
        --arg project "$project_name" \
        --argjson structure "$initial_structure" \
        '{
            template_id: $template,
            created_at: $created,
            project_name: $project,
            initial_structure: $structure
        }' > "$target_dir/.claude/template-metadata.json"

    print_success "Template tracking metadata created for adaptive learning"
}

# Main execution
function main() {
    print_header

    check_devdrive
    select_template
    gather_variables
    preview_structure
    apply_template

    print_success "Template engine completed successfully!"
}

# Run main function
main
