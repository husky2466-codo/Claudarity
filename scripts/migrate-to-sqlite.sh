#!/bin/bash
# Claudarity JSONL to SQLite Migration Script
# Imports existing feedback data from JSONL files into SQLite database

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

DB="$HOME/.claude/claudarity.db"
LOGS_DIR="$HOME/.claude/logs"
CACHE_DIR="/Volumes/DevDrive/Cache/feedback"

echo "🔄 Starting Claudarity migration from JSONL to SQLite..."
echo "Database: $DB"
echo ""

# Check if database exists
if [ ! -f "$DB" ]; then
    echo "❌ Database not found. Run init-claudarity-db.sh first."
    exit 1
fi

# Backup database before migration
echo "💾 Creating backup..."
cp "$DB" "$DB.pre-migration-$(date +%s)"

# Counter for statistics
wins_imported=0
losses_imported=0
patterns_imported=0
prefs_imported=0

echo "📊 Importing feedback entries..."

# Function to extract AI summary from markdown file
get_ai_summary() {
    local md_file="$1"
    if [ -f "$md_file" ]; then
        # Extract text between ## AI Summary and next ## header
        awk '/## AI Summary/,/^##/ {if ($0 !~ /^##/) print}' "$md_file" | sed '/^$/d'
    else
        echo ""
    fi
}

# Function to extract quick context from markdown file
get_quick_context() {
    local md_file="$1"
    if [ -f "$md_file" ]; then
        # Extract text between ## Quick Context and next ## header
        awk '/## Quick Context/,/^##/ {if ($0 !~ /^##/) print}' "$md_file" | sed '/^$/d' | tr '\n' ' '
    else
        echo ""
    fi
}

# Function to safely escape SQL strings
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

# Import wins from session-wins.jsonl
if [ -f "$LOGS_DIR/session-wins.jsonl" ]; then
    echo "Importing wins from session-wins.jsonl..."

    while IFS= read -r line; do
        # Parse JSON fields
        ts=$(echo "$line" | jq -r '.ts // empty')
        project=$(echo "$line" | jq -r '.project // "unknown"')
        matched=$(echo "$line" | jq -r '.matched // .pattern // empty')
        cache_file=$(echo "$line" | jq -r '.cache_file // empty')

        # Skip if essential fields missing
        if [ -z "$ts" ] || [ -z "$matched" ]; then
            continue
        fi

        # Extract AI summary and context from markdown file if it exists
        ai_summary=""
        context_summary=""
        user_message="$matched"

        if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
            ai_summary=$(get_ai_summary "$cache_file")
            context_summary=$(get_quick_context "$cache_file")

            # Extract user message from markdown (last line before end)
            user_msg_from_md=$(awk '/## User Message/,0 {if ($0 !~ /^##/) print}' "$cache_file" | sed '/^$/d' | head -1)
            if [ -n "$user_msg_from_md" ]; then
                user_message="$user_msg_from_md"
            fi
        fi

        # Escape strings for SQL
        ts_safe=$(escape_sql "$ts")
        project_safe=$(escape_sql "$project")
        pattern_safe=$(escape_sql "$matched")
        user_message_safe=$(escape_sql "$user_message")
        context_summary_safe=$(escape_sql "$context_summary")
        ai_summary_safe=$(escape_sql "$ai_summary")
        cache_file_safe=$(escape_sql "$cache_file")

        # Insert into database
        sqlite3 "$DB" "INSERT INTO feedback_entries (ts, project, pattern, type, user_message, context_summary, ai_summary, cache_file) VALUES ('$ts_safe', '$project_safe', '$pattern_safe', 'win', '$user_message_safe', '$context_summary_safe', '$ai_summary_safe', '$cache_file_safe');"

        # Get the last inserted ID and insert into FTS table
        last_id=$(sqlite3 "$DB" "SELECT last_insert_rowid();")
        sqlite3 "$DB" "INSERT INTO feedback_fts (feedback_id, user_message, context_summary, ai_summary) VALUES ($last_id, '$user_message_safe', '$context_summary_safe', '$ai_summary_safe');"

        wins_imported=$((wins_imported + 1))

    done < "$LOGS_DIR/session-wins.jsonl"

    echo "✅ Imported $wins_imported wins"
else
    echo "⚠️  session-wins.jsonl not found"
fi

# Import losses from session-losses.jsonl
if [ -f "$LOGS_DIR/session-losses.jsonl" ]; then
    echo "Importing losses from session-losses.jsonl..."

    while IFS= read -r line; do
        # Parse JSON fields
        ts=$(echo "$line" | jq -r '.ts // empty')
        project=$(echo "$line" | jq -r '.project // "unknown"')
        matched=$(echo "$line" | jq -r '.matched // .pattern // empty')
        cache_file=$(echo "$line" | jq -r '.cache_file // empty')

        # Skip if essential fields missing
        if [ -z "$ts" ] || [ -z "$matched" ]; then
            continue
        fi

        # Extract AI summary and context from markdown file
        ai_summary=""
        context_summary=""
        user_message="$matched"

        if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
            ai_summary=$(get_ai_summary "$cache_file")
            context_summary=$(get_quick_context "$cache_file")

            user_msg_from_md=$(awk '/## User Message/,0 {if ($0 !~ /^##/) print}' "$cache_file" | sed '/^$/d' | head -1)
            if [ -n "$user_msg_from_md" ]; then
                user_message="$user_msg_from_md"
            fi
        fi

        # Escape strings for SQL
        ts_safe=$(escape_sql "$ts")
        project_safe=$(escape_sql "$project")
        pattern_safe=$(escape_sql "$matched")
        user_message_safe=$(escape_sql "$user_message")
        context_summary_safe=$(escape_sql "$context_summary")
        ai_summary_safe=$(escape_sql "$ai_summary")
        cache_file_safe=$(escape_sql "$cache_file")

        # Insert into database
        sqlite3 "$DB" "INSERT INTO feedback_entries (ts, project, pattern, type, user_message, context_summary, ai_summary, cache_file) VALUES ('$ts_safe', '$project_safe', '$pattern_safe', 'loss', '$user_message_safe', '$context_summary_safe', '$ai_summary_safe', '$cache_file_safe');"

        # Get the last inserted ID and insert into FTS table
        last_id=$(sqlite3 "$DB" "SELECT last_insert_rowid();")
        sqlite3 "$DB" "INSERT INTO feedback_fts (feedback_id, user_message, context_summary, ai_summary) VALUES ($last_id, '$user_message_safe', '$context_summary_safe', '$ai_summary_safe');"

        losses_imported=$((losses_imported + 1))

    done < "$LOGS_DIR/session-losses.jsonl"

    echo "✅ Imported $losses_imported losses"
else
    echo "⚠️  session-losses.jsonl not found"
fi

# Import cross-project patterns
if [ -f "$LOGS_DIR/cross-project-patterns.jsonl" ]; then
    echo "Importing cross-project patterns..."

    # Slurp all objects into array and iterate (handles pretty-printed JSONL)
    jq -sc '.[]' "$LOGS_DIR/cross-project-patterns.jsonl" 2>/dev/null | while IFS= read -r line; do
        [ -z "$line" ] && continue

        pattern=$(echo "$line" | jq -r '.pattern // empty')
        type=$(echo "$line" | jq -r '.type // empty')
        win_count=$(echo "$line" | jq -r '.win_count // 0')
        loss_count=$(echo "$line" | jq -r '.loss_count // 0')
        win_rate=$(echo "$line" | jq -r '.win_rate // 0.0')
        confidence=$(echo "$line" | jq -r '.confidence // 0.0')
        global_scope=$(echo "$line" | jq -r '.global_scope // 0')
        first_seen=$(echo "$line" | jq -r '.first_seen // empty')
        last_seen=$(echo "$line" | jq -r '.last_seen // empty')
        projects=$(echo "$line" | jq -r '.projects | tojson')

        if [ -z "$pattern" ]; then
            continue
        fi

        # Escape for SQL
        pattern_safe=$(escape_sql "$pattern")
        type_safe=$(escape_sql "$type")
        first_seen_safe=$(escape_sql "$first_seen")
        last_seen_safe=$(escape_sql "$last_seen")
        projects_safe=$(escape_sql "$projects")

        sqlite3 "$DB" "INSERT INTO cross_project_patterns (pattern, type, win_count, loss_count, win_rate, confidence, global_scope, first_seen, last_seen, projects) VALUES ('$pattern_safe', '$type_safe', $win_count, $loss_count, $win_rate, $confidence, $global_scope, '$first_seen_safe', '$last_seen_safe', '$projects_safe');" || true

        patterns_imported=$((patterns_imported + 1))
    done

    echo "✅ Imported $patterns_imported patterns"
else
    echo "⚠️  cross-project-patterns.jsonl not found"
fi

# Import code preferences
if [ -f "$LOGS_DIR/code-preferences.json" ]; then
    echo "Importing code preferences..."

    # Extract technologies
    jq -r '.technologies.preferred[]? | @json' "$LOGS_DIR/code-preferences.json" 2>/dev/null | while read -r tech_json; do
        item=$(echo "$tech_json" | jq -r '.item // empty')
        win_count=$(echo "$tech_json" | jq -r '.win_count // 0')
        loss_count=$(echo "$tech_json" | jq -r '.loss_count // 0')
        win_rate=$(echo "$tech_json" | jq -r '.win_rate // 0.0')
        confidence=$(echo "$tech_json" | jq -r '.confidence // 0.0')
        last_seen=$(echo "$tech_json" | jq -r '.last_seen // empty')

        if [ -n "$item" ]; then
            item_safe=$(escape_sql "$item")
            last_seen_safe=$(escape_sql "$last_seen")
            total=$((win_count + loss_count))

            sqlite3 "$DB" "INSERT OR IGNORE INTO code_preferences (category, item, preference, win_count, loss_count, win_rate, confidence, total_occurrences, last_seen) VALUES ('technology', '$item_safe', 'preferred', $win_count, $loss_count, $win_rate, $confidence, $total, '$last_seen_safe');"
            prefs_imported=$((prefs_imported + 1))
        fi
    done

    # Extract avoided technologies
    jq -r '.technologies.avoided[]? | @json' "$LOGS_DIR/code-preferences.json" 2>/dev/null | while read -r tech_json; do
        item=$(echo "$tech_json" | jq -r '.item // empty')
        win_count=$(echo "$tech_json" | jq -r '.win_count // 0')
        loss_count=$(echo "$tech_json" | jq -r '.loss_count // 0')
        win_rate=$(echo "$tech_json" | jq -r '.win_rate // 0.0')
        confidence=$(echo "$tech_json" | jq -r '.confidence // 0.0')
        last_seen=$(echo "$tech_json" | jq -r '.last_seen // empty')

        if [ -n "$item" ]; then
            item_safe=$(escape_sql "$item")
            last_seen_safe=$(escape_sql "$last_seen")
            total=$((win_count + loss_count))

            sqlite3 "$DB" "INSERT OR IGNORE INTO code_preferences (category, item, preference, win_count, loss_count, win_rate, confidence, total_occurrences, last_seen) VALUES ('technology', '$item_safe', 'avoided', $win_count, $loss_count, $win_rate, $confidence, $total, '$last_seen_safe');"
            prefs_imported=$((prefs_imported + 1))
        fi
    done

    echo "✅ Imported $prefs_imported code preferences"
else
    echo "⚠️  code-preferences.json not found"
fi

# Update schema metadata
sqlite3 "$DB" "UPDATE schema_metadata SET value = 'migrated' WHERE key = 'migration_phase';"
sqlite3 "$DB" "INSERT OR REPLACE INTO schema_metadata (key, value) VALUES ('migration_date', datetime('now'));"

# Run ANALYZE to optimize query planner
echo "📈 Analyzing database..."
sqlite3 "$DB" "ANALYZE;"

# Integrity check
echo "🔍 Running integrity check..."
if sqlite3 "$DB" "PRAGMA integrity_check;" | grep -q "ok"; then
    echo "✅ Database integrity verified"
else
    echo "❌ Database integrity check failed!"
    exit 1
fi

# Display statistics
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Migration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Wins imported:        $wins_imported"
echo "Losses imported:      $losses_imported"
echo "Patterns imported:    $patterns_imported"
echo "Preferences imported: $prefs_imported"
echo ""
echo "Database validation:"
sqlite3 "$DB" <<SQL
SELECT
    'Total entries: ' || COUNT(*) as stat
FROM feedback_entries
UNION ALL
SELECT
    'Wins: ' || COUNT(*)
FROM feedback_entries WHERE type = 'win'
UNION ALL
SELECT
    'Losses: ' || COUNT(*)
FROM feedback_entries WHERE type = 'loss'
UNION ALL
SELECT
    'Patterns: ' || COUNT(*)
FROM cross_project_patterns
UNION ALL
SELECT
    'Code preferences: ' || COUNT(*)
FROM code_preferences;
SQL
echo ""
echo "✅ Ready for Phase 1: Dual-write testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
