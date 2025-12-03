# Claudarity Configuration

Configuration files for Claudarity system behavior and patterns.

## Configuration Files

### settings.template.json

Main Claude Code settings including:
- Hook registration
- Permissions
- Model selection
- Status line configuration
- MCP server configuration

**Setup**: Copy to `~/.claude/settings.json` and customize:
```bash
cp config/settings.template.json ~/.claude/settings.json
```

### feedback-patterns.template.json

Pattern definitions for detecting user feedback:
- **Praise patterns**: Words and phrases indicating positive feedback
- **Loss patterns**: Words and phrases indicating negative feedback

Used by `log-feedback.sh` hook to detect and categorize user sentiment.

**Setup**: Copy to `~/.claude/config/feedback-patterns.json`:
```bash
cp config/feedback-patterns.template.json ~/.claude/config/feedback-patterns.json
```

## Customizing Feedback Patterns

Edit `feedback-patterns.json` to match your communication style:

```json
{
  "praise": {
    "phrases": ["well done", "great job", "perfect"],
    "words": ["excellent", "outstanding", "brilliant"]
  },
  "loss": {
    "phrases": ["not good", "wrong approach", "poor choice"],
    "words": ["terrible", "awful", "bad"]
  }
}
```

### Tips for Customization

1. **Add your expressions**: Include phrases you commonly use
2. **Cultural context**: Add region-specific expressions
3. **Professional vs casual**: Balance formal and informal language
4. **Avoid ambiguity**: Exclude words with multiple meanings
5. **Test patterns**: Monitor `~/.claude/logs/feedback.log` to verify detection

## Hook Configuration

Hooks are configured in `settings.json`:

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
    ]
  }
}
```

### Available Hook Types

- **UserPromptSubmit**: Fired when user submits a prompt
- **Stop**: Fired when conversation stops or session ends
- **SessionStart**: Fired at session initialization
- **AssistantResponse**: Fired after Claude responds

## Permissions

Configure what Claudarity can access:

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:github.com)"
    ],
    "deny": [],
    "ask": [],
    "defaultMode": "acceptEdits"
  }
}
```

## Status Line

Customize the shell prompt integration:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude/statusline-p10k.sh"
  }
}
```

## MCP Servers

Configure Model Context Protocol servers for extended capabilities:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["package-name"],
      "env": {
        "API_KEY": "your-key-here"
      }
    }
  }
}
```

**Note**: Keep API keys in environment variables or `.env` files, not in committed config files.

## Environment-Specific Settings

For local overrides without affecting git:

1. Create `settings.local.json` (gitignored)
2. Claudarity will prefer local settings when present
3. Use for machine-specific paths or credentials

## Validation

Test your configuration:

```bash
# Validate JSON syntax
jq . ~/.claude/settings.json

# Test pattern loading
~/.claude/config/test-pattern-loading.sh
```

## Troubleshooting

**Hooks not firing**: Check hook paths in settings.json
**Feedback not detected**: Review feedback-patterns.json and logs
**Permission errors**: Verify script executable permissions
**Database errors**: Ensure database exists and is writable

## Security Notes

- Never commit API keys or tokens
- Use template files for examples
- Keep sensitive data in `.env` files
- Use `$HOME` instead of hardcoded paths
