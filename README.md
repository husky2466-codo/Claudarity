# Claudarity

A powerful memory and learning system for Claude Code that enables contextual awareness, feedback learning, and intelligent automation through hooks, scripts, and slash commands.

## Overview

Claudarity transforms Claude Code into a learning system that remembers your preferences, learns from feedback, and automatically recalls relevant context. It uses SQLite for persistent storage, bash hooks for event-driven automation, and intelligent pattern matching for feedback analysis.

## Key Features

- **Contextual Memory**: Automatically stores and retrieves relevant conversation history
- **Feedback Learning**: Learns from user praise and criticism to improve responses
- **Code Preferences**: Remembers your coding style, patterns, and preferences
- **Session Management**: Tracks terminal activity and session history
- **Template System**: Evolving templates based on successful patterns
- **Slash Commands**: Quick access to common workflows
- **Event Hooks**: Automated actions on session events
- **Baseline Stats**: Win/loss tracking for continuous improvement

## Architecture

Claudarity consists of four main components:

1. **Database Layer** (`claudarity.db`): SQLite database storing feedback, preferences, sessions, and templates
2. **Hooks** (`hooks/`): Event-driven scripts triggered by Claude Code lifecycle events
3. **Scripts** (`scripts/`): Utility scripts for data management, analysis, and queries
4. **Commands** (`commands/`): Slash commands for user-facing workflows

## Installation

1. Clone this repository to `~/.claude/`:
   ```bash
   git clone git@github.com:husky2466-codo/Claudarity.git ~/.claude
   ```

2. Initialize the database:
   ```bash
   ~/.claude/scripts/init-claudarity-db.sh
   ```

3. Copy and configure settings:
   ```bash
   cp ~/.claude/config/settings.template.json ~/.claude/settings.json
   cp ~/.claude/config/feedback-patterns.template.json ~/.claude/config/feedback-patterns.json
   ```

4. Make scripts executable (if not already):
   ```bash
   chmod +x ~/.claude/hooks/*.sh
   chmod +x ~/.claude/scripts/*.sh
   ```

## Quick Start

After installation, Claudarity works automatically in the background:

- **Feedback Learning**: Just give feedback naturally ("great job", "this is wrong")
- **Context Recall**: Use `/gomemory <query>` to search conversation history
- **Preferences**: Use `/prefs <query>` to query learned code preferences
- **Baseline Stats**: Use `/baseline` to see win/loss statistics

## Directory Structure

```
~/.claude/
├── hooks/              # Event-driven automation scripts
├── scripts/            # Core utility and processing scripts
├── commands/           # Slash command definitions
├── config/             # Configuration files
├── claudarity.db       # SQLite database (auto-created)
├── logs/               # Session logs (auto-generated)
└── settings.json       # Claude Code settings
```

## Documentation

- [Features Guide](docs/FEATURES.md) - Detailed feature descriptions
- [Installation Guide](docs/INSTALLATION.md) - Step-by-step setup instructions
- [Architecture Overview](docs/ARCHITECTURE.md) - System design and components
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## Requirements

- Claude Code CLI
- macOS or Linux
- bash 4.0+
- sqlite3
- Python 3.8+ (for template evolution)
- jq (for JSON processing)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to Claudarity.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Created by Nicolas Robert Myers as part of the Claude Code enhancement suite.

---

**Note**: This is the public open-source version of Claudarity. Your local instance will generate additional runtime files (database, logs, sessions) that are excluded via `.gitignore`.
