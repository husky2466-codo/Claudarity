#!/bin/bash
# Debug log rotation script
# Rotates debug.log if it exceeds 500KB (512000 bytes)
# Called by log-feedback.sh before first log write

DEBUG_LOG="$HOME/.claude/logs/debug.log"
ARCHIVE_DIR="$HOME/.claude/logs/archive"
MAX_SIZE=512000  # 500KB in bytes

# Create archive directory if it doesn't exist
mkdir -p "$ARCHIVE_DIR"

# Check if debug.log exists
if [ ! -f "$DEBUG_LOG" ]; then
  # Create empty debug.log with rotation message
  echo "$(date '+%Y-%m-%d %H:%M:%S'): Debug log initialized" > "$DEBUG_LOG"
  exit 0
fi

# Get file size in bytes
file_size=$(stat -f%z "$DEBUG_LOG" 2>/dev/null || echo 0)

# Rotate if size exceeds threshold
if [ "$file_size" -gt "$MAX_SIZE" ]; then
  # Generate timestamp for archive filename
  timestamp=$(date '+%Y%m%d-%H%M%S')
  archive_file="$ARCHIVE_DIR/debug-$timestamp.log.gz"

  # Compress and archive the log
  gzip -c "$DEBUG_LOG" > "$archive_file"

  # Reset debug.log with rotation message
  cat > "$DEBUG_LOG" << EOF
$(date '+%Y-%m-%d %H:%M:%S'): Log rotated (previous size: $file_size bytes)
$(date '+%Y-%m-%d %H:%M:%S'): Archived to: $archive_file
$(date '+%Y-%m-%d %H:%M:%S'): Continuing debug logging...
EOF

  # Optional: Keep only last 10 archived logs (cleanup old archives)
  # This prevents unlimited archive growth
  archive_count=$(ls -1 "$ARCHIVE_DIR"/debug-*.log.gz 2>/dev/null | wc -l | xargs)
  if [ "$archive_count" -gt 10 ]; then
    # Delete oldest archives, keep newest 10
    ls -1t "$ARCHIVE_DIR"/debug-*.log.gz | tail -n +11 | xargs rm -f 2>/dev/null
  fi
fi

exit 0
