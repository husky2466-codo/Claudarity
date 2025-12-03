#!/bin/bash
# migrate-terminal-activity.sh
# Add terminal_activity tables to existing Claudarity database
#
# Safe migration - only adds new tables/columns, doesn't drop anything

set -euo pipefail

DB="$HOME/.claude/claudarity.db"

echo "🔄 Migrating Claudarity database for terminal activity support..."
echo "Database: $DB"
echo ""

if [ ! -f "$DB" ]; then
    echo "❌ Error: Database not found: $DB" >&2
    exit 1
fi

# Check if migration already applied
if sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='terminal_activity'" | grep -q terminal_activity; then
    echo "✅ Terminal activity tables already exist. No migration needed."
    exit 0
fi

echo "📝 Creating terminal_activity table..."

sqlite3 "$DB" <<'EOF'
-- ============ TERMINAL ACTIVITY TABLE ============
CREATE TABLE IF NOT EXISTS terminal_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    project TEXT,
    event_seq INTEGER NOT NULL,
    ts TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK(event_type IN ('user_prompt', 'assistant_text', 'tool_use', 'tool_result', 'error', 'thinking')),

    content TEXT,
    tool_name TEXT,
    tool_input TEXT,
    tool_output TEXT,

    char_count INTEGER,
    line_count INTEGER,
    error_detected BOOLEAN DEFAULT 0,

    feedback_id INTEGER,

    created_at INTEGER DEFAULT (strftime('%s', 'now')),

    FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE,
    FOREIGN KEY (feedback_id) REFERENCES feedback_entries(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_terminal_session ON terminal_activity(session_id, event_seq);
CREATE INDEX IF NOT EXISTS idx_terminal_ts ON terminal_activity(ts DESC);
CREATE INDEX IF NOT EXISTS idx_terminal_project ON terminal_activity(project, ts DESC);
CREATE INDEX IF NOT EXISTS idx_terminal_tool ON terminal_activity(tool_name, ts DESC);
CREATE INDEX IF NOT EXISTS idx_terminal_error ON terminal_activity(error_detected, ts DESC);

-- Full-text search support
CREATE VIRTUAL TABLE IF NOT EXISTS terminal_activity_fts USING fts5(
    activity_id UNINDEXED,
    content,
    tool_output,
    tokenize='porter unicode61'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS terminal_activity_ai AFTER INSERT ON terminal_activity BEGIN
    INSERT INTO terminal_activity_fts(activity_id, content, tool_output)
    VALUES (new.id, new.content, new.tool_output);
END;

CREATE TRIGGER IF NOT EXISTS terminal_activity_ad AFTER DELETE ON terminal_activity BEGIN
    DELETE FROM terminal_activity_fts WHERE activity_id = old.id;
END;

CREATE TRIGGER IF NOT EXISTS terminal_activity_au AFTER UPDATE ON terminal_activity BEGIN
    DELETE FROM terminal_activity_fts WHERE activity_id = old.id;
    INSERT INTO terminal_activity_fts(activity_id, content, tool_output)
    VALUES (new.id, new.content, new.tool_output);
END;
EOF

echo "✅ Terminal activity table created"
echo ""

# Add columns to sessions table if they don't exist
echo "📝 Adding terminal activity columns to sessions table..."

# Check each column and add if missing
for col in "terminal_log_path:TEXT" "total_activity_events:INTEGER DEFAULT 0" "last_activity_ts:TEXT"; do
    col_name="${col%%:*}"
    col_type="${col#*:}"

    if ! sqlite3 "$DB" "PRAGMA table_info(sessions)" | grep -q "^[0-9]*|$col_name|"; then
        echo "   Adding column: $col_name"
        sqlite3 "$DB" "ALTER TABLE sessions ADD COLUMN $col_name $col_type;"
    else
        echo "   ✓ Column exists: $col_name"
    fi
done

echo "✅ Sessions table updated"
echo ""
echo "🎉 Migration complete!"
echo ""
echo "Next steps:"
echo "  - Terminal activity will be captured automatically via log-feedback.sh hook"
echo "  - Query activity: ~/.claude/scripts/query-terminal-activity.sh"
echo "  - Replay sessions: ~/.claude/scripts/replay-session.sh"
