# Claudarity Troubleshooting Guide

Common issues and their solutions.

## Installation Issues

### Database Initialization Fails

**Symptom:** `init-claudarity-db.sh` errors or database missing

**Solutions:**
```bash
# Check sqlite3 is installed
sqlite3 --version

# Remove corrupt database
rm ~/.claude/claudarity.db*

# Re-initialize
~/.claude/scripts/init-claudarity-db.sh

# Verify tables created
sqlite3 ~/.claude/claudarity.db ".tables"
```

### Permission Denied Errors

**Symptom:** "Permission denied" when running scripts

**Solutions:**
```bash
# Make all scripts executable
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.claude/scripts/*.sh
chmod +x ~/.claude/scripts/*.py

# Fix directory permissions
chmod 755 ~/.claude
chmod 755 ~/.claude/{hooks,scripts,commands,config}

# Fix file permissions
chmod 644 ~/.claude/config/*.json
chmod 644 ~/.claude/commands/*.md
```

### Missing Dependencies

**Symptom:** "command not found" errors

**Solutions:**
```bash
# Check required tools
command -v bash || echo "Install bash 4.0+"
command -v sqlite3 || echo "Install sqlite3"
command -v jq || echo "Install jq"

# macOS installation
brew install bash sqlite3 jq python3

# Linux installation
sudo apt install bash sqlite3 jq python3  # Debian/Ubuntu
sudo yum install bash sqlite jq python3   # RHEL/CentOS
```

## Hook Issues

### Hooks Not Firing

**Symptom:** No logs, features not working

**Diagnosis:**
```bash
# Check settings.json syntax
jq . ~/.claude/settings.json

# Verify hook paths exist
cat ~/.claude/settings.json | jq '.hooks'

# Test hook directly
bash ~/.claude/hooks/log-feedback.sh
```

**Solutions:**
1. Fix JSON syntax errors
2. Update paths to use `$HOME` instead of hardcoded paths
3. Verify hooks are registered correctly:
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

### Hook Execution Errors

**Symptom:** Hooks registered but failing

**Diagnosis:**
```bash
# Check hook logs
tail -f ~/.claude/logs/hooks.log

# Run hook with debug output
bash -x ~/.claude/hooks/log-feedback.sh
```

**Solutions:**
- Check environment variables are set
- Verify database is accessible
- Ensure dependencies (jq, sqlite3) are available
- Fix script errors shown in logs

## Database Issues

### Database Locked

**Symptom:** "database is locked" errors

**Solutions:**
```bash
# Check for long-running queries
ps aux | grep sqlite3

# Kill stuck processes
killall sqlite3

# Check for journal files
ls -la ~/.claude/claudarity.db*

# Remove journal if safe
rm ~/.claude/claudarity.db-shm
rm ~/.claude/claudarity.db-wal

# Verify database
sqlite3 ~/.claude/claudarity.db "PRAGMA integrity_check;"
```

### Database Corruption

**Symptom:** "database disk image is malformed"

**Solutions:**
```bash
# Backup first!
cp ~/.claude/claudarity.db ~/claudarity-backup.db

# Attempt recovery
sqlite3 ~/.claude/claudarity.db ".recover" | sqlite3 recovered.db
mv recovered.db ~/.claude/claudarity.db

# If recovery fails, rebuild
rm ~/.claude/claudarity.db
~/.claude/scripts/init-claudarity-db.sh

# Restore from backup if available
cp ~/claudarity-backup.db ~/.claude/claudarity.db
```

### Database Growing Too Large

**Symptom:** Database file > 1GB

**Solutions:**
```bash
# Check size
ls -lh ~/.claude/claudarity.db

# Clean up old data
~/.claude/scripts/cleanup-feedback-cache.sh

# Vacuum database
sqlite3 ~/.claude/claudarity.db "VACUUM;"

# Delete old sessions (keep last 30 days)
sqlite3 ~/.claude/claudarity.db "DELETE FROM context_memory WHERE timestamp < datetime('now', '-30 days');"
sqlite3 ~/.claude/claudarity.db "DELETE FROM terminal_activity WHERE timestamp < datetime('now', '-30 days');"
sqlite3 ~/.claude/claudarity.db "VACUUM;"
```

## Feedback Learning Issues

### Feedback Not Detected

**Symptom:** Saying "great job" doesn't log feedback

**Diagnosis:**
```bash
# Check feedback log
tail ~/.claude/logs/feedback.log

# Test pattern matching
~/.claude/config/test-pattern-loading.sh

# Verify patterns loaded
cat ~/.claude/config/feedback-patterns.json
```

**Solutions:**
1. Ensure `log-feedback.sh` hook is registered
2. Verify feedback-patterns.json exists and is valid JSON
3. Add your phrases to the patterns:
```json
{
  "praise": {
    "phrases": ["your custom phrase here"],
    "words": ["your", "custom", "words"]
  }
}
```

### Wrong Feedback Type Detected

**Symptom:** Praise detected as criticism or vice versa

**Solutions:**
```bash
# Review patterns
cat ~/.claude/config/feedback-patterns.json

# Remove ambiguous words
# Edit to remove words that could be both positive and negative

# Test with specific input
echo "great job" | ~/.claude/hooks/log-feedback.sh
```

## Context Recall Issues

### No Context Returned

**Symptom:** `/gomemory` returns nothing

**Diagnosis:**
```bash
# Check if context exists
sqlite3 ~/.claude/claudarity.db "SELECT COUNT(*) FROM context_memory;"

# Test search directly
~/.claude/scripts/auto-context-recall.sh "test query"

# Check FTS5 index
sqlite3 ~/.claude/claudarity.db "SELECT * FROM context_memory_fts LIMIT 5;"
```

**Solutions:**
1. If no context stored yet, use Claude more and it will build up
2. Rebuild FTS5 index:
```bash
sqlite3 ~/.claude/claudarity.db "INSERT INTO context_memory_fts(context_memory_fts) VALUES('rebuild');"
```

### Irrelevant Context Returned

**Symptom:** Context doesn't match query

**Solutions:**
- Be more specific in queries
- Use quoted phrases for exact matches
- Adjust search parameters in `auto-context-recall.sh`

## Slash Command Issues

### Command Not Found

**Symptom:** `/gomemory` not recognized

**Diagnosis:**
```bash
# Check command file exists
ls -la ~/.claude/commands/gomemory.md

# Verify Claude Code sees it
# In Claude: Type / and see if it appears
```

**Solutions:**
```bash
# Ensure file exists and has content
cat ~/.claude/commands/gomemory.md

# Fix permissions
chmod 644 ~/.claude/commands/*.md

# Restart Claude Code
```

### Command Execution Fails

**Symptom:** Command runs but errors

**Diagnosis:**
```bash
# Check command logs
tail ~/.claude/logs/commands.log

# Test script directly
bash ~/.claude/scripts/auto-context-recall.sh "test"
```

**Solutions:**
- Verify script paths in command `.md` files
- Check script has execute permissions
- Review script error output in logs

## Performance Issues

### Slow Context Searches

**Symptom:** `/gomemory` takes too long

**Solutions:**
```bash
# Rebuild indexes
sqlite3 ~/.claude/claudarity.db "REINDEX;"

# Analyze query performance
sqlite3 ~/.claude/claudarity.db "EXPLAIN QUERY PLAN SELECT * FROM context_memory WHERE content LIKE '%test%';"

# Clean up old data
~/.claude/scripts/cleanup-feedback-cache.sh
```

### High Memory Usage

**Symptom:** System slowing down

**Solutions:**
```bash
# Check running processes
ps aux | grep claude

# Limit cache size in scripts
# Edit scripts to reduce CACHE_SIZE variables

# Reduce logging verbosity
# Edit hooks to log less frequently
```

### Disk Space Issues

**Symptom:** Running out of disk space

**Solutions:**
```bash
# Check Claudarity disk usage
du -sh ~/.claude/*

# Clean up logs
~/.claude/scripts/rotate-debug-log.sh

# Remove old backups
find ~/.claude/logs -name "*.backup" -mtime +30 -delete

# Compact database
sqlite3 ~/.claude/claudarity.db "VACUUM;"
```

## Template System Issues

### Templates Not Evolving

**Symptom:** `/template-stats` shows no evolution

**Diagnosis:**
```bash
# Check template data
sqlite3 ~/.claude/claudarity.db "SELECT * FROM template_evolution;"

# Verify Python is available
python3 --version

# Test evolver script
python3 ~/.claude/scripts/template-evolver.py
```

**Solutions:**
- Ensure enough data collected (need 10+ uses per template)
- Run evolver manually: `python3 ~/.claude/scripts/template-evolver.py`
- Check for Python errors in logs

### Template Stats Empty

**Symptom:** `/template-stats` shows nothing

**Solutions:**
```bash
# Check if templates tracked
sqlite3 ~/.claude/claudarity.db "SELECT COUNT(*) FROM template_evolution;"

# If empty, templates haven't been used yet
# Continue using Claude and stats will accumulate
```

## Log Issues

### Logs Not Being Created

**Symptom:** No logs in `~/.claude/logs/`

**Solutions:**
```bash
# Create logs directory
mkdir -p ~/.claude/logs

# Fix permissions
chmod 755 ~/.claude/logs

# Verify hooks can write
touch ~/.claude/logs/test.log && rm ~/.claude/logs/test.log
```

### Logs Growing Too Large

**Symptom:** Log files > 100MB

**Solutions:**
```bash
# Rotate logs
~/.claude/scripts/rotate-debug-log.sh

# Clean old logs
find ~/.claude/logs -name "*.log" -mtime +30 -delete

# Reduce logging in hooks
# Edit hooks to log less verbosely
```

## Debugging Tips

### Enable Debug Mode

```bash
# Run scripts with debug output
bash -x ~/.claude/scripts/script-name.sh

# Add debug logging to hooks
# Add to top of hook file:
set -x  # Enable debug output
```

### Check System Resources

```bash
# Memory usage
top -l 1 | grep PhysMem

# Disk usage
df -h

# Process list
ps aux | grep -E 'claude|sqlite'
```

### Verify Dependencies

```bash
# Create dependency check script
cat > ~/check-deps.sh << 'EOF'
#!/bin/bash
for cmd in bash sqlite3 jq python3; do
  if command -v $cmd &> /dev/null; then
    echo "✓ $cmd: $(command -v $cmd)"
  else
    echo "✗ $cmd: MISSING"
  fi
done
EOF

chmod +x ~/check-deps.sh
~/check-deps.sh
```

## Getting Help

If none of these solutions work:

1. **Check logs**: Review all logs in `~/.claude/logs/`
2. **Enable debug mode**: Run problematic scripts with `bash -x`
3. **Verify installation**: Re-run installation steps
4. **Check GitHub issues**: Look for similar problems
5. **Open new issue**: Include:
   - Claudarity version (`git -C ~/.claude describe --tags`)
   - Operating system and version
   - Error messages and logs
   - Steps to reproduce

## Resetting Claudarity

Last resort: Complete reset

```bash
# Backup important data
cp ~/.claude/claudarity.db ~/claudarity-backup-$(date +%Y%m%d).db

# Remove Claudarity
rm -rf ~/.claude

# Reinstall
git clone git@github.com:husky2466-codo/Claudarity.git ~/.claude
~/.claude/scripts/init-claudarity-db.sh

# Reconfigure
cp ~/.claude/config/settings.template.json ~/.claude/settings.json
cp ~/.claude/config/feedback-patterns.template.json ~/.claude/config/feedback-patterns.json
```
