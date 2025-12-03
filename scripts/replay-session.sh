#!/bin/bash
# replay-session.sh
# Replay a Claude Code session's terminal output from Claudarity
#
# Usage:
#   ./replay-session.sh <session-id> [--with-timing] [--type=<type>] [--no-truncate]

set -euo pipefail

DB="$HOME/.claude/claudarity.db"
SESSION_ID="${1:-}"
WITH_TIMING=false
FILTER_TYPE=""
NO_TRUNCATE=false

# Parse arguments
shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --with-timing)
            WITH_TIMING=true
            ;;
        --type=*)
            FILTER_TYPE="${1#*=}"
            ;;
        --no-truncate)
            NO_TRUNCATE=true
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ -z "$SESSION_ID" ]; then
    cat <<USAGE
replay-session.sh - Replay terminal output from a Claude Code session

USAGE:
    replay-session.sh <session-id> [options]

OPTIONS:
    --with-timing       Replay with time delays matching original timing
    --type=<type>       Filter by event type (user_prompt, assistant_text, tool_use, tool_result, error, thinking)
    --no-truncate       Show full content without truncation

EXAMPLES:
    # Basic replay
    replay-session.sh c7e0efff

    # Replay with original timing
    replay-session.sh c7e0efff --with-timing

    # Only show tool usage
    replay-session.sh c7e0efff --type=tool_use

    # Show full content
    replay-session.sh c7e0efff --no-truncate

USAGE
    exit 1
fi

if [ ! -f "$DB" ]; then
    echo "Error: Claudarity database not found: $DB" >&2
    exit 1
fi

# Check if session exists
session_exists=$(sqlite3 "$DB" "SELECT COUNT(*) FROM terminal_activity WHERE session_id='$SESSION_ID' LIMIT 1" 2>/dev/null || echo "0")

if [ "$session_exists" = "0" ]; then
    echo "Error: No terminal activity found for session: $SESSION_ID" >&2
    echo ""
    echo "Available sessions with terminal activity:"
    sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    substr(session_id, 1, 8) as sess_id,
    COUNT(*) as events,
    MIN(ts) as started,
    MAX(ts) as ended
FROM terminal_activity
GROUP BY session_id
ORDER BY started DESC
LIMIT 10;
SQL
    exit 1
fi

# Get session info
session_info=$(sqlite3 "$DB" <<SQL
SELECT
    session_id,
    project,
    MIN(ts) as started_at,
    MAX(ts) as ended_at,
    COUNT(*) as total_events
FROM terminal_activity
WHERE session_id='$SESSION_ID'
GROUP BY session_id;
SQL
)

IFS='|' read -r sess_id project started_at ended_at total_events <<< "$session_info"

# Header
echo "════════════════════════════════════════════════════════════════════════════════"
echo "SESSION REPLAY: $sess_id"
echo "Project: $project"
echo "Started: $started_at"
echo "Ended: $ended_at"
echo "Total Events: $total_events"
if [ -n "$FILTER_TYPE" ]; then
    echo "Filter: $FILTER_TYPE"
fi
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Get events
type_filter=""
if [ -n "$FILTER_TYPE" ]; then
    type_filter="AND event_type='$FILTER_TYPE'"
fi

# Format timestamps as elapsed time
first_ts=$(sqlite3 "$DB" "SELECT MIN(ts) FROM terminal_activity WHERE session_id='$SESSION_ID'")

prev_epoch=0

sqlite3 "$DB" <<SQL | while IFS='|' read -r ts event_type tool_name content tool_input tool_output char_count line_count error_detected; do
.separator '|'
SELECT
    ts,
    event_type,
    COALESCE(tool_name, ''),
    COALESCE(content, ''),
    COALESCE(tool_input, ''),
    COALESCE(tool_output, ''),
    COALESCE(char_count, 0),
    COALESCE(line_count, 0),
    COALESCE(error_detected, 0)
FROM terminal_activity
WHERE session_id='$SESSION_ID'
$type_filter
ORDER BY event_seq;
SQL

    # Calculate elapsed time
    curr_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$ts" "+%s" 2>/dev/null || echo "0")
    first_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$first_ts" "+%s" 2>/dev/null || echo "0")
    elapsed=$((curr_epoch - first_epoch))

    # Format as HH:MM:SS
    hours=$((elapsed / 3600))
    minutes=$(((elapsed % 3600) / 60))
    seconds=$((elapsed % 60))
    elapsed_fmt=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)

    # Timing delay
    if [ "$WITH_TIMING" = true ] && [ $prev_epoch -gt 0 ]; then
        delay=$((curr_epoch - prev_epoch))
        if [ $delay -gt 0 ] && [ $delay -lt 10 ]; then
            sleep $delay
        fi
    fi
    prev_epoch=$curr_epoch

    # Display event based on type
    case "$event_type" in
        user_prompt)
            echo "[$elapsed_fmt] 🎯 USER PROMPT"
            if [ "$NO_TRUNCATE" = true ]; then
                echo "$content"
            else
                echo "$content" | head -c 500
                if [ ${#content} -gt 500 ]; then
                    echo "... (truncated)"
                fi
            fi
            echo ""
            ;;

        assistant_text)
            echo "[$elapsed_fmt] 💬 ASSISTANT"
            if [ "$NO_TRUNCATE" = true ]; then
                echo "$content"
            else
                echo "$content" | head -c 1000
                if [ ${#content} -gt 1000 ]; then
                    echo "... (truncated)"
                fi
            fi
            echo ""
            ;;

        thinking)
            echo "[$elapsed_fmt] 🤔 THINKING"
            if [ "$NO_TRUNCATE" = true ]; then
                echo "$content"
            else
                echo "$content" | head -c 500
                if [ ${#content} -gt 500 ]; then
                    echo "... (truncated)"
                fi
            fi
            echo ""
            ;;

        tool_use)
            echo "[$elapsed_fmt] 🔧 TOOL USE: $tool_name"
            if [ -n "$tool_input" ]; then
                echo "   Input:"
                if [ "$NO_TRUNCATE" = true ]; then
                    echo "$tool_input" | sed 's/^/   /'
                else
                    echo "$tool_input" | head -c 300 | sed 's/^/   /'
                    if [ ${#tool_input} -gt 300 ]; then
                        echo "   ... (truncated)"
                    fi
                fi
            fi
            echo ""
            ;;

        tool_result)
            status_icon="✅"
            if [ "$error_detected" = "1" ]; then
                status_icon="❌"
            fi

            size_info=""
            if [ "$char_count" -gt 0 ]; then
                if [ "$char_count" -gt 1024 ]; then
                    kb=$((char_count / 1024))
                    size_info=" (${line_count} lines, ${kb} KB)"
                else
                    size_info=" (${line_count} lines, ${char_count} chars)"
                fi
            fi

            echo "[$elapsed_fmt] $status_icon TOOL RESULT: $tool_name$size_info"

            if [ -n "$tool_output" ]; then
                if [ "$NO_TRUNCATE" = true ]; then
                    echo "$tool_output" | sed 's/^/   /'
                else
                    # Show first 15 lines or 800 chars
                    output_preview=$(echo "$tool_output" | head -n 15 | head -c 800)
                    echo "$output_preview" | sed 's/^/   /'

                    output_lines=$(echo "$tool_output" | wc -l | tr -d ' ')
                    if [ "$output_lines" -gt 15 ] || [ ${#tool_output} -gt 800 ]; then
                        echo "   ... (truncated, use --no-truncate to see full output)"
                    fi
                fi
            fi
            echo ""
            ;;

        error)
            echo "[$elapsed_fmt] ❌ ERROR"
            if [ "$NO_TRUNCATE" = true ]; then
                echo "$content"
            else
                echo "$content" | head -c 500
                if [ ${#content} -gt 500 ]; then
                    echo "... (truncated)"
                fi
            fi
            echo ""
            ;;

        *)
            echo "[$elapsed_fmt] ❓ $event_type"
            if [ -n "$content" ]; then
                echo "$content" | head -c 200
            fi
            echo ""
            ;;
    esac
done

echo "════════════════════════════════════════════════════════════════════════════════"
echo "Replay complete"
echo "════════════════════════════════════════════════════════════════════════════════"
