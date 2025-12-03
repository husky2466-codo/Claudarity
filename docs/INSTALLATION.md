# Claudarity Installation Guide

Step-by-step instructions for installing and configuring Claudarity.

## Prerequisites

Before installing Claudarity, ensure you have:

### Required

- **Claude Code CLI**: Install from [claude.ai](https://claude.ai/download)
- **bash**: Version 4.0 or higher
- **sqlite3**: For database operations
- **jq**: For JSON processing

### Optional

- **Python 3.8+**: For template evolution features
- **git**: For version control and updates

## Checking Prerequisites

```bash
# Check bash version (should be 4.0+)
bash --version

# Check sqlite3
sqlite3 --version

# Check jq
jq --version

# Check Python (optional)
python3 --version
```

### Installing Prerequisites

**macOS:**
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install prerequisites
brew install bash sqlite3 jq python3
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install bash sqlite3 jq python3
```

**Linux (RHEL/CentOS):**
```bash
sudo yum install bash sqlite jq python3
```

## Installation Methods

### Method 1: Git Clone (Recommended)

```bash
# Clone to ~/.claude directory
git clone git@github.com:husky2466-codo/Claudarity.git ~/.claude

# Make scripts executable
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.claude/scripts/*.sh
chmod +x ~/.claude/scripts/*.py

# Initialize database
~/.claude/scripts/init-claudarity-db.sh
```

### Method 2: Manual Download

```bash
# Download and extract
curl -L https://github.com/husky2466-codo/Claudarity/archive/main.zip -o claudarity.zip
unzip claudarity.zip
mv Claudarity-main ~/.claude

# Make scripts executable
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.claude/scripts/*.sh
chmod +x ~/.claude/scripts/*.py

# Initialize database
~/.claude/scripts/init-claudarity-db.sh
```

## Configuration

### 1. Settings Configuration

```bash
# Copy template to settings.json
cp ~/.claude/config/settings.template.json ~/.claude/settings.json

# Edit settings (optional)
nano ~/.claude/settings.json
```

**Key settings to review:**
- `hooks`: Which hooks to enable
- `permissions`: WebFetch and file access permissions
- `model`: Claude model selection
- `mcpServers`: Add any MCP servers you use

### 2. Feedback Patterns Configuration

```bash
# Copy feedback patterns template
cp ~/.claude/config/feedback-patterns.template.json ~/.claude/config/feedback-patterns.json

# Customize patterns (optional)
nano ~/.claude/config/feedback-patterns.json
```

Add phrases and words you commonly use for feedback.

### 3. Environment Variables (Optional)

If using MCP servers or external integrations:

```bash
# Create .env file
cat > ~/.claude/.env << 'EOF'
# API Keys
N8N_API_KEY=your-key-here
GITHUB_TOKEN=your-token-here

# Paths
BACKUP_PATH=/path/to/backups
EOF

# Secure the file
chmod 600 ~/.claude/.env
```

## Verification

### 1. Check Database Initialization

```bash
# Verify database exists
ls -lh ~/.claude/claudarity.db

# Check tables
sqlite3 ~/.claude/claudarity.db ".tables"
```

Expected tables:
- context_memory
- code_preferences
- feedback_log
- session_log
- template_evolution
- terminal_activity

### 2. Test Scripts

```bash
# Test database query
~/.claude/scripts/baseline-summary.sh

# Test pattern loading
~/.claude/config/test-pattern-loading.sh

# Test context search (should return empty initially)
~/.claude/scripts/auto-context-recall.sh "test query"
```

### 3. Test Claude Code Integration

```bash
# Start Claude Code
claude

# Try a slash command
/baseline

# Give feedback to test learning
# Type: "great job" or "perfect"
# Check logs
tail ~/.claude/logs/feedback.log
```

## Directory Structure Verification

After installation, verify this structure:

```bash
tree -L 2 ~/.claude
```

Expected output:
```
~/.claude/
├── claudarity.db
├── commands/
│   ├── *.md (slash commands)
│   └── README.md
├── config/
│   ├── feedback-patterns.json
│   ├── settings.json
│   └── README.md
├── hooks/
│   ├── *.sh (hook scripts)
│   └── README.md
├── scripts/
│   ├── *.sh (utility scripts)
│   ├── *.py (Python scripts)
│   └── README.md
├── logs/ (created automatically)
├── session-env/ (created automatically)
└── settings.json
```

## Troubleshooting Installation

### Database Initialization Fails

```bash
# Remove existing database
rm ~/.claude/claudarity.db*

# Re-initialize
~/.claude/scripts/init-claudarity-db.sh
```

### Permission Errors

```bash
# Fix permissions on entire directory
chmod -R u+rw ~/.claude
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.claude/scripts/*.sh
```

### Hooks Not Triggering

1. Check `settings.json` syntax:
   ```bash
   jq . ~/.claude/settings.json
   ```

2. Verify hook paths are correct:
   ```bash
   grep "hooks" ~/.claude/settings.json
   ```

3. Check hook execution permissions:
   ```bash
   ls -l ~/.claude/hooks/
   ```

### Missing Dependencies

```bash
# Check what's missing
command -v bash || echo "bash missing"
command -v sqlite3 || echo "sqlite3 missing"
command -v jq || echo "jq missing"
command -v python3 || echo "python3 missing (optional)"
```

## Post-Installation

### 1. Customize for Your Workflow

- Add custom slash commands in `~/.claude/commands/`
- Modify feedback patterns to match your style
- Create project-specific hooks

### 2. Start Using Claudarity

```bash
# Launch Claude Code
claude

# Try memory search
/gomemory "your topic"

# Give feedback to start learning
# "great job" or "this is perfect"

# View statistics
/baseline
```

### 3. Regular Maintenance

```bash
# Weekly: Check database size
ls -lh ~/.claude/claudarity.db

# Monthly: Rotate logs
~/.claude/scripts/rotate-debug-log.sh

# As needed: Clean up old data
~/.claude/scripts/cleanup-feedback-cache.sh
```

## Updating Claudarity

```bash
# Pull latest changes
cd ~/.claude
git pull origin main

# Re-run initialization to update schema
~/.claude/scripts/init-claudarity-db.sh

# Restart Claude Code
```

## Uninstallation

```bash
# Backup your data first
cp ~/.claude/claudarity.db ~/claudarity-backup.db

# Remove Claudarity
rm -rf ~/.claude

# Note: This removes all hooks, scripts, and data
```

## Getting Help

- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Review logs in `~/.claude/logs/`
- Open an issue on GitHub
- Check existing issues for solutions
