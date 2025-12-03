# Claudarity Slash Commands

Slash commands provide quick access to Claudarity features directly from the Claude Code CLI.

## Available Commands

### Memory & Context

- **/gomemory**: Load relevant context from conversation history
  ```
  /gomemory authentication implementation
  ```
  Searches Claudarity's memory for relevant past conversations and injects them into the current session.

- **/prefs**: Query learned code preferences
  ```
  /prefs error handling in React
  ```
  Retrieves coding preferences learned from past feedback and successful patterns.

### Structured Analysis

- **/sa**: Structure a raw query for better analysis
  ```
  /sa How should I implement user authentication?
  ```
  Structures your query before passing to subagents for analysis.

- **/sab**: Execute a pre-approved structured query
  ```
  /sab analyze authentication patterns
  ```
  Executes an already-structured query using the subagent system.

### Project Management

- **/audit**: Comprehensive project audit using subagents
  ```
  /audit security
  ```
  Performs deep analysis of current project with optional focus area.

- **/baseline**: Show win/loss statistics
  ```
  /baseline
  ```
  Displays all-time feedback statistics and learning trends.

- **/template-stats**: Display template system statistics
  ```
  /template-stats
  ```
  Shows template usage, evolution, and effectiveness metrics.

### Project-Specific

- **/goplaywright**: Search Playwright documentation and scrapers
  ```
  /goplaywright browser automation
  ```
  Searches COOLFORK project's Playwright implementation and docs.

- **/ntbk**: Backup current project to NIC THANGS drive
  ```
  /ntbk
  ```
  Creates backup of current project to MacMini backup repository.

- **/ruby**: Add missing files to Xcode project
  ```
  /ruby
  ```
  Runs Ruby script to sync Xcode project file with file system.

### Development Tools

- **/review-templates**: Review template evolution proposals
  ```
  /review-templates
  ```
  Shows pending template evolution changes and system health.

## Creating Custom Commands

Slash commands are markdown files in `~/.claude/commands/` with this structure:

```markdown
---
description: Brief description shown in command list
---

# Command Name

Your prompt or script here. This content is expanded into the conversation
when the slash command is invoked.

Can include:
- Markdown formatting
- Code blocks
- Dynamic content from scripts
- Variable substitution
```

### Example: Simple Command

File: `~/.claude/commands/status.md`

```markdown
---
description: Show current project status
---

Show me the current status of this project including:
- Git status
- Recent commits
- Open todos
- Test coverage
```

### Example: Script-Backed Command

File: `~/.claude/commands/cleanup.md`

```markdown
---
description: Clean up project artifacts
---

$(~/.claude/scripts/cleanup-project.sh)
```

## Command Naming

- Use lowercase with hyphens for multi-word commands
- Keep names short and memorable
- Avoid conflicts with Claude Code built-in commands
- Use descriptive names that indicate purpose

## Best Practices

1. **Keep prompts focused**: One clear purpose per command
2. **Document parameters**: Explain expected inputs
3. **Include examples**: Show typical usage
4. **Error handling**: Handle missing parameters gracefully
5. **Performance**: Keep script-backed commands fast

## Command Variables

Commands can use environment variables:

- `$HOME`: User home directory
- `$PWD`: Current working directory
- `$CLAUDE_SESSION_ID`: Current session ID
- Custom variables from `~/.claude/session-env/`

## Debugging Commands

Test your command content:

```bash
cat ~/.claude/commands/mycommand.md
```

View command execution in logs:

```bash
tail -f ~/.claude/logs/commands.log
```
