#!/bin/bash
# capture-terminal-activity.sh
# Main orchestrator for capturing terminal activity from Claude Code sessions
#
# Usage: capture-terminal-activity.sh <session_id> <transcript_path> <project_dir> [--final]
# Runs in background, processes transcripts incrementally

set -euo pipefail

SESSION_ID="${1:-}"
TRANSCRIPT_PATH="${2:-}"
PROJECT_DIR="${3:-$PWD}"
FINAL_MODE="${4:-}"

DB="$HOME/.claude/claudarity.db"
CACHE_DIR="/Volumes/DevDrive/Cache/terminal-activity"
PARSE_SCRIPT="$HOME/.claude/scripts/parse-transcript.sh"

# Validation
if [ -z "$SESSION_ID" ]; then
    echo "Error: SESSION_ID required" >&2
    exit 1
fi

if [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "Error: Transcript file not found: $TRANSCRIPT_PATH" >&2
    exit 1
fi

if [ ! -f "$DB" ]; then
    echo "Error: Claudarity database not found: $DB" >&2
    exit 1
fi

if [ ! -x "$PARSE_SCRIPT" ]; then
    echo "Error: Parse script not executable: $PARSE_SCRIPT" >&2
    exit 1
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# JSONL log file for this session
LOG_FILE="$CACHE_DIR/${SESSION_ID}.jsonl"

# Get last processed event sequence from database
last_seq=$(sqlite3 "$DB" "SELECT COALESCE(MAX(event_seq), 0) FROM terminal_activity WHERE session_id='$SESSION_ID'" 2>/dev/null || echo "0")

# Parse transcript for new events
new_events=$("$PARSE_SCRIPT" "$TRANSCRIPT_PATH" "$last_seq" 2>/dev/null || echo "")

if [ -z "$new_events" ]; then
    # No new events to process
    exit 0
fi

# Process each event
event_count=0
while IFS= read -r event_json; do
    [ -z "$event_json" ] && continue

    # Append to JSONL log
    echo "$event_json" >> "$LOG_FILE"

    # Extract fields for SQLite insertion
    event_seq=$(echo "$event_json" | jq -r '.seq')
    ts=$(echo "$event_json" | jq -r '.ts')
    event_type=$(echo "$event_json" | jq -r '.type')
    content=$(echo "$event_json" | jq -r '.content // empty')
    tool_name=$(echo "$event_json" | jq -r '.tool_name // empty')
    tool_input=$(echo "$event_json" | jq -r '.tool_input // empty')
    tool_output=$(echo "$event_json" | jq -r '.tool_output // empty')
    char_count=$(echo "$event_json" | jq -r '.char_count // 0')
    line_count=$(echo "$event_json" | jq -r '.line_count // 0')
    error_detected=$(echo "$event_json" | jq -r '.error_detected // 0')

    # Escape single quotes for SQL
    content=$(echo "$content" | sed "s/'/''/g")
    tool_name=$(echo "$tool_name" | sed "s/'/''/g")
    tool_input=$(echo "$tool_input" | sed "s/'/''/g")
    tool_output=$(echo "$tool_output" | sed "s/'/''/g")

    # Insert into SQLite (handle empty values)
    sqlite3 "$DB" <<SQL
INSERT INTO terminal_activity (
    session_id, project, event_seq, ts, event_type,
    content, tool_name, tool_input, tool_output,
    char_count, line_count, error_detected
) VALUES (
    '$SESSION_ID',
    '$PROJECT_DIR',
    $event_seq,
    '$ts',
    '$event_type',
    $([ -n "$content" ] && echo "'$content'" || echo "NULL"),
    $([ -n "$tool_name" ] && echo "'$tool_name'" || echo "NULL"),
    $([ -n "$tool_input" ] && echo "'$tool_input'" || echo "NULL"),
    $([ -n "$tool_output" ] && echo "'$tool_output'" || echo "NULL"),
    $char_count,
    $line_count,
    $error_detected
);
SQL

    event_count=$((event_count + 1))
done <<< "$new_events"

# Update session metadata
if [ $event_count -gt 0 ]; then
    # Ensure session exists
    sqlite3 "$DB" "INSERT OR IGNORE INTO sessions (session_id, project, started_at) VALUES ('$SESSION_ID', '$PROJECT_DIR', datetime('now'));"

    # Update session with terminal activity stats
    sqlite3 "$DB" <<SQL
UPDATE sessions
SET terminal_log_path = '$LOG_FILE',
    total_activity_events = (SELECT COUNT(*) FROM terminal_activity WHERE session_id='$SESSION_ID'),
    last_activity_ts = (SELECT MAX(ts) FROM terminal_activity WHERE session_id='$SESSION_ID')
WHERE session_id = '$SESSION_ID';
SQL
fi

# If final mode, update session end time
if [ "$FINAL_MODE" = "--final" ]; then
    sqlite3 "$DB" "UPDATE sessions SET ended_at = datetime('now') WHERE session_id='$SESSION_ID';"
fi

exit 0
