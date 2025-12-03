#!/bin/bash
# Backup session logs to DevDrive on session stop
# Runs on Stop event

# Backup destination
BACKUP_DIR="/Volumes/DevDrive/Backups/claude-sessions"
LOG_DIR="$HOME/.claude/logs"

# Check if DevDrive is mounted
if [ ! -d "$BACKUP_DIR" ]; then
  # Drive not mounted - silently skip backup
  exit 0
fi

# Check if logs directory exists and has files
if [ ! -d "$LOG_DIR" ] || [ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
  exit 0
fi

# Sync logs to DevDrive (runs in background to not block)
(
  rsync -a --update "$LOG_DIR/" "$BACKUP_DIR/"

  # Log the backup
  echo "$(date '+%Y-%m-%d %H:%M:%S') | Synced session logs to DevDrive" >> "$BACKUP_DIR/.backup_log"
) &

exit 0
