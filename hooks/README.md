# Claudarity Hooks

This directory contains event-driven automation scripts that are triggered by Claude Code lifecycle events.

## Available Hooks

### Session Lifecycle

- **session-start.sh**: Initializes session tracking and loads context
- **context-aware-start.sh**: Provides contextual suggestions at session start
- **backup-session-log.sh**: Archives session logs on session end

### User Interaction

- **user-prompt-submit.sh**: Processes user input before sending to Claude
- **log-feedback.sh**: Detects and logs user feedback (praise/criticism)
- **auto-create-todos-from-plan.sh**: Automatically creates todos from planning responses

### Context Management

- **context-detector.sh**: Identifies when context recall is needed
- **context-search.sh**: Searches for relevant historical context
- **build-context-index.sh**: Maintains searchable context index

### Learning & Feedback

- **teach-callback.sh**: Processes explicit teaching from users
- **aggregate-patterns.sh**: Aggregates feedback patterns for learning

### Stop Events

- **stop-plan-sab.sh**: Handles interrupted planning sessions

## Hook Configuration

Hooks are registered in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/log-feedback.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/backup-session-log.sh"
          }
        ]
      }
    ]
  }
}
```

## Creating Custom Hooks

Hooks should:
1. Be executable (`chmod +x`)
2. Use `#!/usr/bin/env bash`
3. Handle errors gracefully
4. Complete quickly (use background jobs for heavy operations)
5. Log to `~/.claude/logs/hooks.log`

Example hook structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Your logic here
echo "Hook executed at $(date)" >> "$HOME/.claude/logs/hooks.log"
```

## Database Access

Hooks can query the Claudarity database:

```bash
sqlite3 "$HOME/.claude/claudarity.db" "SELECT * FROM feedback_log LIMIT 10;"
```

## Environment Variables

Hooks receive Claude Code context via environment variables:
- `CLAUDE_SESSION_ID`: Current session identifier
- `CLAUDE_USER_INPUT`: User's input (for UserPromptSubmit hooks)
- Additional variables depending on hook type
