#!/bin/bash
# Claudarity SQLite Database Initialization Script
# Creates and configures the SQLite database for Claudarity memory system

set -e  # Exit on error

DB="$HOME/.claude/claudarity.db"

echo "🚀 Initializing Claudarity SQLite database..."
echo "Location: $DB"

# Check if database already exists
if [ -f "$DB" ]; then
    read -p "⚠️  Database already exists. Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    echo "Backing up existing database..."
    mv "$DB" "$DB.backup-$(date +%s)"
fi

# Create database and configure
sqlite3 "$DB" <<'SQL'
-- Performance configuration
PRAGMA journal_mode=WAL;              -- Write-Ahead Log for concurrent reads
PRAGMA synchronous=NORMAL;            -- Balance safety/speed
PRAGMA cache_size=-64000;             -- 64MB cache
PRAGMA temp_store=MEMORY;             -- Use memory for temp tables
PRAGMA mmap_size=268435456;           -- 256MB memory-mapped I/O

-- ============================================================
-- Core Tables
-- ============================================================

-- feedback_entries: Primary memory storage
CREATE TABLE feedback_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,                    -- ISO 8601 timestamp
    session_id TEXT,
    project TEXT NOT NULL,
    pattern TEXT NOT NULL,               -- Matched phrase
    type TEXT NOT NULL CHECK(type IN ('win', 'loss')),
    user_message TEXT,
    context_summary TEXT,                -- Quick context from transcript
    ai_summary TEXT,                     -- Claude-generated summary
    transcript_path TEXT,
    cache_file TEXT,                     -- Legacy .md file path
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_ts ON feedback_entries(ts);
CREATE INDEX idx_project ON feedback_entries(project);
CREATE INDEX idx_type ON feedback_entries(type);
CREATE INDEX idx_pattern ON feedback_entries(pattern);
CREATE INDEX idx_project_type_ts ON feedback_entries(project, type, ts DESC);

-- ============================================================
-- Full-Text Search (FTS5)
-- ============================================================

-- feedback_fts: Full-text search index
-- Note: Using external content table for better control during migration
CREATE VIRTUAL TABLE feedback_fts USING fts5(
    feedback_id UNINDEXED,
    user_message,
    context_summary,
    ai_summary,
    tokenize='porter unicode61'  -- Stemming + Unicode
);

-- ============================================================
-- Metadata Tables
-- ============================================================

-- context_index: Extracted keywords/metadata
CREATE TABLE context_index (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feedback_id INTEGER NOT NULL REFERENCES feedback_entries(id) ON DELETE CASCADE,
    keyword TEXT NOT NULL,
    keyword_type TEXT NOT NULL CHECK(keyword_type IN ('technology', 'task_type', 'file_pattern'))
);

CREATE INDEX idx_keyword ON context_index(keyword);
CREATE INDEX idx_feedback_id ON context_index(feedback_id);
CREATE INDEX idx_keyword_type ON context_index(keyword, keyword_type);

-- cross_project_patterns: Aggregated pattern metrics
CREATE TABLE cross_project_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL CHECK(type IN ('win', 'loss')),
    win_count INTEGER DEFAULT 0,
    loss_count INTEGER DEFAULT 0,
    win_rate REAL DEFAULT 0.0,
    confidence REAL DEFAULT 0.0,
    global_scope INTEGER DEFAULT 0,
    first_seen TEXT,
    last_seen TEXT,
    projects TEXT,                       -- JSON array
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_pattern_global ON cross_project_patterns(global_scope, confidence DESC);
CREATE INDEX idx_pattern_text ON cross_project_patterns(pattern);

-- code_preferences: Technology/tool preferences
CREATE TABLE code_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,              -- 'technology', 'pattern', 'tool'
    item TEXT NOT NULL,
    preference TEXT NOT NULL CHECK(preference IN ('preferred', 'avoided')),
    win_count INTEGER DEFAULT 0,
    loss_count INTEGER DEFAULT 0,
    win_rate REAL DEFAULT 0.0,
    confidence REAL DEFAULT 0.0,
    total_occurrences INTEGER DEFAULT 0,
    last_seen TEXT,
    UNIQUE(category, item)
);

CREATE INDEX idx_preferences_category ON code_preferences(category, preference);
CREATE INDEX idx_preferences_item ON code_preferences(item);

-- sessions: Session tracking
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL UNIQUE,
    project TEXT,
    started_at TEXT,
    ended_at TEXT,
    win_count INTEGER DEFAULT 0,
    loss_count INTEGER DEFAULT 0,
    terminal_log_path TEXT,
    total_activity_events INTEGER DEFAULT 0,
    last_activity_ts TEXT
);

CREATE INDEX idx_session_id ON sessions(session_id);
CREATE INDEX idx_session_project ON sessions(project);

-- terminal_activity: Full session terminal output capture
CREATE TABLE terminal_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
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

    feedback_id INTEGER REFERENCES feedback_entries(id) ON DELETE SET NULL,

    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_terminal_session ON terminal_activity(session_id, event_seq);
CREATE INDEX idx_terminal_ts ON terminal_activity(ts DESC);
CREATE INDEX idx_terminal_project ON terminal_activity(project, ts DESC);
CREATE INDEX idx_terminal_tool ON terminal_activity(tool_name, ts DESC);
CREATE INDEX idx_terminal_error ON terminal_activity(error_detected, ts DESC);
CREATE INDEX idx_terminal_type ON terminal_activity(event_type, ts DESC);

-- terminal_activity_fts: Full-text search for terminal output
CREATE VIRTUAL TABLE terminal_activity_fts USING fts5(
    activity_id UNINDEXED,
    content,
    tool_output,
    tokenize='porter unicode61'
);

-- Triggers to keep FTS in sync with terminal_activity
CREATE TRIGGER terminal_activity_fts_insert
AFTER INSERT ON terminal_activity
BEGIN
  INSERT INTO terminal_activity_fts (activity_id, content, tool_output)
  VALUES (NEW.id, NEW.content, NEW.tool_output);
END;

CREATE TRIGGER terminal_activity_fts_delete
AFTER DELETE ON terminal_activity
BEGIN
  DELETE FROM terminal_activity_fts WHERE activity_id = OLD.id;
END;

CREATE TRIGGER terminal_activity_fts_update
AFTER UPDATE ON terminal_activity
BEGIN
  DELETE FROM terminal_activity_fts WHERE activity_id = OLD.id;
  INSERT INTO terminal_activity_fts (activity_id, content, tool_output)
  VALUES (NEW.id, NEW.content, NEW.tool_output);
END;

-- ============================================================
-- Desktop Claude Context (Phase 4)
-- ============================================================

-- context_knowledge: Desktop Claude conversation history
CREATE TABLE context_knowledge (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,              -- 'identity', 'project', 'technical', 'preference', 'wealth'
    subcategory TEXT,                    -- 'ios_dev', 'hardware', 'api', 'communication', etc.
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    keywords TEXT,                       -- Comma-separated tech/topics
    source TEXT DEFAULT 'desktop_claude',
    imported_at TEXT DEFAULT (strftime('%Y-%m-%d', 'now'))
);

CREATE INDEX idx_context_category ON context_knowledge(category, subcategory);
CREATE INDEX idx_context_source ON context_knowledge(source);

-- context_knowledge_fts: Full-text search for desktop context
CREATE VIRTUAL TABLE context_knowledge_fts USING fts5(
    context_id UNINDEXED,
    title,
    content,
    keywords,
    tokenize='porter unicode61'
);

-- ============================================================
-- Metadata
-- ============================================================

CREATE TABLE schema_metadata (
    key TEXT PRIMARY KEY,
    value TEXT
);

INSERT INTO schema_metadata (key, value) VALUES
    ('version', '1.0.0'),
    ('created_at', datetime('now')),
    ('migration_phase', 'initialized');

SQL

# Verify database creation
if sqlite3 "$DB" "PRAGMA integrity_check;" | grep -q "ok"; then
    echo "✅ Database created successfully"
    echo ""
    echo "Tables created:"
    sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    echo ""
    echo "FTS5 virtual tables:"
    sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_fts' ORDER BY name;"
    echo ""
    echo "📊 Database info:"
    sqlite3 "$DB" "PRAGMA database_list;"
    echo ""
    echo "🎉 Claudarity SQLite database ready!"
else
    echo "❌ Database integrity check failed!"
    exit 1
fi
