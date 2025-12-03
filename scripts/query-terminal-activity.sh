#!/bin/bash
# query-terminal-activity.sh
# Query interface for terminal activity stored in Claudarity
#
# Usage:
#   ./query-terminal-activity.sh search "query"        # Full-text search
#   ./query-terminal-activity.sh session <session-id>  # Get session activity
#   ./query-terminal-activity.sh recent [hours]        # Recent activity
#   ./query-terminal-activity.sh errors [days]         # Recent errors
#   ./query-terminal-activity.sh tool <tool-name>      # Tool usage

set -euo pipefail

DB="$HOME/.claude/claudarity.db"

if [ ! -f "$DB" ]; then
    echo "Error: Claudarity database not found: $DB" >&2
    exit 1
fi

COMMAND="${1:-help}"
ARG="${2:-}"

case "$COMMAND" in
    search)
        # Full-text search across all terminal activity
        if [ -z "$ARG" ]; then
            echo "Error: Search query required" >&2
            exit 1
        fi

        echo "Searching terminal activity for: $ARG"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    substr(ta.session_id, 1, 8) as sess_id,
    substr(ta.ts, 1, 19) as timestamp,
    ta.event_type,
    ta.tool_name,
    substr(ta.content, 1, 80) as preview
FROM terminal_activity ta
JOIN terminal_activity_fts fts ON ta.id = fts.activity_id
WHERE terminal_activity_fts MATCH '$ARG'
ORDER BY ta.ts DESC
LIMIT 50;
SQL
        ;;

    session)
        # Get all activity for a specific session
        if [ -z "$ARG" ]; then
            echo "Error: Session ID required" >&2
            exit 1
        fi

        echo "Terminal activity for session: $ARG"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    event_seq as seq,
    substr(ts, 12, 8) as time,
    event_type as type,
    tool_name as tool,
    char_count as chars,
    CASE
        WHEN error_detected = 1 THEN '❌'
        ELSE ''
    END as err,
    substr(content, 1, 60) as preview
FROM terminal_activity
WHERE session_id = '$ARG'
ORDER BY event_seq;
SQL
        ;;

    recent)
        # Get recent terminal activity
        HOURS="${ARG:-24}"

        echo "Terminal activity (last $HOURS hours)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    substr(session_id, 1, 8) as sess_id,
    substr(ts, 1, 19) as timestamp,
    event_type,
    tool_name,
    char_count,
    substr(content, 1, 60) as preview
FROM terminal_activity
WHERE ts >= datetime('now', '-$HOURS hours')
ORDER BY ts DESC
LIMIT 100;
SQL
        ;;

    errors)
        # Get recent errors
        DAYS="${ARG:-7}"

        echo "Terminal errors (last $DAYS days)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    substr(session_id, 1, 8) as sess_id,
    substr(ts, 1, 19) as timestamp,
    tool_name,
    substr(content, 1, 100) as error_message
FROM terminal_activity
WHERE error_detected = 1
  AND ts >= datetime('now', '-$DAYS days')
ORDER BY ts DESC
LIMIT 50;
SQL
        ;;

    tool)
        # Get tool usage statistics
        if [ -z "$ARG" ]; then
            # Show all tools
            echo "Tool usage statistics"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    tool_name,
    COUNT(*) as usage_count,
    COUNT(CASE WHEN error_detected=1 THEN 1 END) as errors,
    ROUND(AVG(char_count), 0) as avg_output_size,
    MAX(ts) as last_used
FROM terminal_activity
WHERE event_type = 'tool_result'
  AND ts >= datetime('now', '-30 days')
GROUP BY tool_name
ORDER BY usage_count DESC;
SQL
        else
            # Show specific tool usage
            echo "Usage of tool: $ARG"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    substr(session_id, 1, 8) as sess_id,
    substr(ts, 1, 19) as timestamp,
    char_count as output_size,
    CASE
        WHEN error_detected = 1 THEN '❌'
        ELSE '✓'
    END as status,
    substr(tool_output, 1, 80) as preview
FROM terminal_activity
WHERE tool_name = '$ARG'
  AND event_type = 'tool_result'
ORDER BY ts DESC
LIMIT 50;
SQL
        fi
        ;;

    stats)
        # Show overall statistics
        echo "Terminal Activity Statistics"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    'Total Events' as metric,
    COUNT(*) as value
FROM terminal_activity
UNION ALL
SELECT
    'Total Sessions',
    COUNT(DISTINCT session_id)
FROM terminal_activity
UNION ALL
SELECT
    'Total Errors',
    COUNT(*)
FROM terminal_activity
WHERE error_detected = 1
UNION ALL
SELECT
    'Oldest Event',
    MIN(ts)
FROM terminal_activity
UNION ALL
SELECT
    'Newest Event',
    MAX(ts)
FROM terminal_activity;
SQL

        echo ""
        echo "Events by Type:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        sqlite3 "$DB" <<SQL
.mode column
.headers on
SELECT
    event_type,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM terminal_activity), 1) as percentage
FROM terminal_activity
GROUP BY event_type
ORDER BY count DESC;
SQL
        ;;

    help|*)
        cat <<HELP
query-terminal-activity.sh - Query terminal activity in Claudarity

USAGE:
    query-terminal-activity.sh search "query"        Full-text search
    query-terminal-activity.sh session <session-id>  Get session timeline
    query-terminal-activity.sh recent [hours]        Recent activity (default: 24h)
    query-terminal-activity.sh errors [days]         Recent errors (default: 7 days)
    query-terminal-activity.sh tool [tool-name]      Tool usage stats
    query-terminal-activity.sh stats                 Overall statistics

EXAMPLES:
    # Search for "database"
    query-terminal-activity.sh search "database"

    # View specific session
    query-terminal-activity.sh session c7e0efff

    # Last 48 hours of activity
    query-terminal-activity.sh recent 48

    # All errors in last 30 days
    query-terminal-activity.sh errors 30

    # Read tool usage
    query-terminal-activity.sh tool Read

    # Overall stats
    query-terminal-activity.sh stats

HELP
        ;;
esac
