#!/bin/bash
################################################################################
# cleanup-feedback-cache.sh
#
# Purpose:
#   Clean up old markdown cache files from feedback directory
#   Keeps files for 30 days, then deletes them
#   SQLite database retains all data permanently
#
# Retention Policy:
#   - Markdown files: 30 days (temporary cache)
#   - SQLite database: Forever (permanent storage)
#
################################################################################

CACHE_DIR="/Volumes/DevDrive/Cache/feedback"
RETENTION_DAYS=30

# Only run if cache directory exists
if [ ! -d "$CACHE_DIR" ]; then
  exit 0
fi

# Find and delete win/loss markdown files older than 30 days
# Exclude special files like README, QUICKSTART, callbacks.json, session-summary files
find "$CACHE_DIR" -type f \
  \( -name "win-*.md" -o -name "loss-*.md" \) \
  -mtime +${RETENTION_DAYS} \
  -delete 2>/dev/null

# Log cleanup action
echo "$(date): Cleaned up feedback cache files older than ${RETENTION_DAYS} days" >> "$HOME/.claude/logs/cleanup.log"

exit 0
