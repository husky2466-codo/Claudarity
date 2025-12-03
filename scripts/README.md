# Claudarity Scripts

Core utility scripts for database management, analysis, and data processing.

## Database Management

- **init-claudarity-db.sh**: Initialize Claudarity SQLite database schema
- **migrate-to-sqlite.sh**: Migrate from JSONL to SQLite (legacy)
- **migrate-terminal-activity.sh**: Migrate terminal activity logs

## Context & Memory

- **auto-context-recall.sh**: Automatically retrieve relevant context
- **detect-context-triggers.sh**: Identify when context recall is needed
- **format-auto-context.sh**: Format context for Claude consumption

## Feedback & Learning

- **analyze-code-patterns.sh**: Analyze code patterns from feedback
- **populate-code-preferences.sh**: Extract and store coding preferences
- **query-preferences.sh**: Query learned preferences
- **cleanup-feedback-cache.sh**: Clean up old cached feedback

## Templates

- **template-engine.sh**: Template rendering and variable substitution
- **template-analyzer.sh**: Analyze template usage and effectiveness
- **template-evolver.py**: Machine learning for template evolution
- **apply-template-evolution.sh**: Apply evolved templates
- **template-stats.sh**: Generate template usage statistics

## Session Management

- **log-session-summary.sh**: Generate session summaries
- **replay-session.sh**: Replay historical sessions
- **capture-terminal-activity.sh**: Capture and log terminal commands
- **query-terminal-activity.sh**: Search terminal history

## Analytics & Reporting

- **baseline-summary.sh**: Generate win/loss baseline statistics
- **confidence-calculator.sh**: Calculate confidence scores
- **detect-compaction.sh**: Detect when database needs compaction
- **parse-transcript.sh**: Parse conversation transcripts

## Search & Retrieval

- **playwright-search.sh**: Search Playwright documentation and scrapers
- **rate-limiter.sh**: Rate limiting for API calls

## Debugging

- **rotate-debug-log.sh**: Rotate debug logs to prevent bloat

## Usage Examples

### Initialize Database
```bash
~/.claude/scripts/init-claudarity-db.sh
```

### Query Preferences
```bash
~/.claude/scripts/query-preferences.sh "error handling in TypeScript"
```

### Generate Baseline Stats
```bash
~/.claude/scripts/baseline-summary.sh
```

### Search Context
```bash
~/.claude/scripts/auto-context-recall.sh "authentication implementation"
```

## Script Conventions

All scripts follow these conventions:

1. **Shebang**: `#!/usr/bin/env bash`
2. **Error handling**: `set -euo pipefail`
3. **Database path**: `$HOME/.claude/claudarity.db`
4. **Logging**: Write to `$HOME/.claude/logs/`
5. **Exit codes**: 0 for success, non-zero for errors

## Database Schema

Scripts interact with these main tables:

- `feedback_log`: User feedback (praise/criticism)
- `code_preferences`: Learned coding preferences
- `context_memory`: Conversation history
- `session_log`: Session tracking
- `template_evolution`: Template learning data
- `terminal_activity`: Shell command history
