# Claudarity Architecture

Technical overview of Claudarity's system design and components.

## System Overview

Claudarity is a learning and memory system built on four core pillars:

1. **Storage Layer**: SQLite database for persistent data
2. **Event System**: Bash hooks for lifecycle automation
3. **Processing Layer**: Shell and Python scripts for data analysis
4. **Interface Layer**: Slash commands for user interaction

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
│  (Claude Code CLI + Slash Commands)                     │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────┴────────────────────────────────────────┐
│                  Event Hooks                             │
│  UserPromptSubmit │ Stop │ SessionStart                 │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────┴────────────────────────────────────────┐
│              Processing Scripts                          │
│  Analysis │ Learning │ Search │ Template Engine         │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────┴────────────────────────────────────────┐
│              Storage Layer (SQLite)                      │
│  feedback │ context │ preferences │ templates            │
└─────────────────────────────────────────────────────────┘
```

## Storage Layer

### Database Schema

**claudarity.db** - SQLite database with the following tables:

#### feedback_log
Stores user feedback (praise/criticism)
```sql
CREATE TABLE feedback_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    session_id TEXT,
    user_input TEXT NOT NULL,
    feedback_type TEXT CHECK(feedback_type IN ('praise', 'loss')),
    matched_pattern TEXT,
    context TEXT,
    project_path TEXT
);
```

#### context_memory
Conversation history for context recall
```sql
CREATE TABLE context_memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    session_id TEXT,
    role TEXT CHECK(role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    tokens INTEGER,
    project_path TEXT,
    files_mentioned TEXT,
    commands_used TEXT
);
```

#### code_preferences
Learned coding patterns and preferences
```sql
CREATE TABLE code_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    language TEXT,
    category TEXT,
    preference TEXT NOT NULL,
    example_code TEXT,
    confidence_score REAL DEFAULT 1.0,
    usage_count INTEGER DEFAULT 1,
    last_used TEXT
);
```

#### session_log
Session tracking and metadata
```sql
CREATE TABLE session_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    project_path TEXT,
    total_interactions INTEGER DEFAULT 0,
    praise_count INTEGER DEFAULT 0,
    loss_count INTEGER DEFAULT 0
);
```

#### template_evolution
Template performance and evolution tracking
```sql
CREATE TABLE template_evolution (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_name TEXT NOT NULL,
    template_version TEXT,
    usage_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    avg_confidence REAL,
    last_evolved TEXT,
    evolution_reason TEXT
);
```

#### terminal_activity
Shell command history
```sql
CREATE TABLE terminal_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    session_id TEXT,
    command TEXT NOT NULL,
    working_dir TEXT,
    exit_code INTEGER,
    duration_ms INTEGER
);
```

### Database Access Patterns

**Read-heavy workload:**
- Context searches: Full-text search with FTS5
- Preference queries: Indexed by language and category
- Template lookups: Cached in memory

**Write patterns:**
- Feedback logging: Async, buffered writes
- Context storage: Batched inserts
- Session updates: Incremental updates

**Maintenance:**
- VACUUM on compaction detection
- Index optimization weekly
- Log rotation monthly

## Event System

### Hook Lifecycle

```
User submits prompt
    ↓
UserPromptSubmit hooks fire
    ↓
    ├─→ log-feedback.sh (detect sentiment)
    ├─→ context-detector.sh (check if context needed)
    └─→ auto-create-todos-from-plan.sh (extract tasks)
    ↓
Claude processes request
    ↓
User stops or session ends
    ↓
Stop hooks fire
    ↓
    ├─→ backup-session-log.sh (archive conversation)
    ├─→ stop-plan-sab.sh (save partial plans)
    └─→ Session summary generated
```

### Hook Registration

Hooks are registered in `settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [...],
    "Stop": [...],
    "SessionStart": [...],
    "AssistantResponse": [...]
  }
}
```

### Hook Communication

Hooks communicate via:
1. **Environment variables**: Session ID, user input
2. **Database**: Shared state via SQLite
3. **File system**: Temporary files in `session-env/`
4. **Exit codes**: Success/failure signaling

## Processing Layer

### Script Categories

#### Data Collection
- `capture-terminal-activity.sh`: Records shell commands
- `log-feedback.sh`: Detects and logs feedback
- `build-context-index.sh`: Indexes conversations

#### Analysis & Learning
- `analyze-code-patterns.sh`: Extracts coding patterns
- `template-evolver.py`: ML-based template improvement
- `confidence-calculator.sh`: Calculates response confidence

#### Retrieval
- `auto-context-recall.sh`: Semantic context search
- `query-preferences.sh`: Preference lookup
- `playwright-search.sh`: Project-specific search

#### Maintenance
- `cleanup-feedback-cache.sh`: Removes stale data
- `rotate-debug-log.sh`: Log management
- `detect-compaction.sh`: Database optimization

### Script Communication

Scripts follow a pipeline pattern:

```
Input → Validation → Processing → Storage → Output
```

**Example: Feedback Processing**
```
User input
    ↓
log-feedback.sh (pattern matching)
    ↓
feedback_log table (storage)
    ↓
aggregate-patterns.sh (analysis)
    ↓
code_preferences table (learning)
    ↓
Query results (retrieval)
```

## Interface Layer

### Slash Command Flow

```
User types: /gomemory authentication
    ↓
Claude Code loads: commands/gomemory.md
    ↓
Script execution: auto-context-recall.sh "authentication"
    ↓
Database query: SELECT * FROM context_memory WHERE ...
    ↓
Results formatted and returned
    ↓
Context injected into conversation
```

### Command Types

1. **Simple prompts**: Direct markdown expansion
2. **Script-backed**: Execute shell/Python scripts
3. **Interactive**: Multiple steps with user input
4. **Composite**: Combine multiple commands

## Data Flow Diagrams

### Feedback Learning Flow

```
User: "great job!"
    ↓
UserPromptSubmit hook
    ↓
log-feedback.sh
    ↓
Pattern match: "great job" → PRAISE
    ↓
INSERT INTO feedback_log (...)
    ↓
aggregate-patterns.sh (nightly)
    ↓
Extract successful patterns
    ↓
UPDATE code_preferences
    ↓
Future responses influenced
```

### Context Recall Flow

```
User: "How did I implement auth before?"
    ↓
context-detector.sh
    ↓
Trigger detected: "before"
    ↓
auto-context-recall.sh
    ↓
FTS5 search: "implement auth"
    ↓
Rank by: recency, relevance, project
    ↓
Format top 5 results
    ↓
Inject into prompt
    ↓
Claude responds with historical context
```

### Template Evolution Flow

```
Template used in response
    ↓
User gives feedback
    ↓
Associate feedback with template
    ↓
template_evolution table updated
    ↓
template-evolver.py (weekly)
    ↓
Analyze success patterns
    ↓
Propose template changes
    ↓
/review-templates shows proposals
    ↓
Apply approved changes
    ↓
New template version created
```

## Performance Considerations

### Database Optimization

- **Indexes**: Created on frequently queried columns
- **FTS5**: Full-text search for context queries
- **Connection pooling**: Reuse connections in scripts
- **Prepared statements**: Prevent SQL injection, improve speed

### Caching Strategy

- **In-memory cache**: Recently used preferences
- **File-based cache**: Expensive query results (TTL: 1 hour)
- **Invalidation**: On data updates via hooks

### Async Processing

- **Background jobs**: Long-running analysis scripts
- **Queue system**: Batch processing of logs
- **Rate limiting**: Prevent overwhelming system

## Security Architecture

### Data Protection

- **Local storage**: All data stays on local machine
- **No cloud sync**: Privacy-first design
- **Encrypted credentials**: Use system keychain

### Script Safety

- **Input validation**: All user input sanitized
- **SQL injection prevention**: Parameterized queries
- **Path traversal protection**: Validate file paths
- **Execute permissions**: Only necessary scripts

### Access Control

- **File permissions**: 600 for sensitive files
- **Database permissions**: User-only access
- **Hook execution**: Validated scripts only

## Extensibility

### Adding New Features

1. **New table**: Add to `init-claudarity-db.sh`
2. **New hook**: Create in `hooks/`, register in `settings.json`
3. **New script**: Add to `scripts/`, document in README
4. **New command**: Create `.md` in `commands/`

### Integration Points

- **MCP servers**: Add to `settings.json` mcpServers
- **External APIs**: Use environment variables for credentials
- **Third-party tools**: Call via shell scripts

### Plugin Architecture

Future: Plugin system for community extensions
- Plugin manifest: `plugin.json`
- Isolated execution: Sandboxed environment
- API versioning: Stable interfaces

## Monitoring & Debugging

### Logging Levels

1. **Error**: Critical failures → `logs/error.log`
2. **Warning**: Non-fatal issues → `logs/warning.log`
3. **Info**: General events → `logs/info.log`
4. **Debug**: Detailed traces → `logs/debug.log`

### Debug Tools

```bash
# Check hook execution
tail -f ~/.claude/logs/hooks.log

# Monitor database queries
sqlite3 ~/.claude/claudarity.db ".log on"

# Profile script performance
time ~/.claude/scripts/auto-context-recall.sh "test"
```

### Health Checks

```bash
# Database integrity
sqlite3 ~/.claude/claudarity.db "PRAGMA integrity_check;"

# Disk usage
du -sh ~/.claude/

# Table statistics
~/.claude/scripts/template-stats.sh
```

## Future Architecture Plans

- **Distributed storage**: Multi-machine sync
- **Graph database**: Relationship mapping
- **ML models**: Local embeddings for semantic search
- **Real-time processing**: Event streaming
- **Web interface**: Visual analytics dashboard
