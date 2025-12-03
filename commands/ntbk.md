---
description: Backup current project to NIC THANGS hard drive (MacMini backup repo)
---

# NIC THANGS Backup (NTBK) Command

Backup the current project to the NIC THANGS external hard drive at `/Volumes/NIC THANGS/MacMini/`.

## Pre-flight Checks

Before syncing, verify:

1. **Drive is mounted:**
   ```bash
   ls -d "/Volumes/NIC THANGS" 2>/dev/null || echo "DRIVE NOT MOUNTED"
   ```

2. **Get current project info:**
   - Working directory path
   - Project name (folder name)

## Backup Process

### Step 1: Verify Drive
Run: `ls -d "/Volumes/NIC THANGS/MacMini" 2>/dev/null`

If drive not found, inform user:
> "NIC THANGS drive is not mounted. Please connect the drive and try again."

### Step 2: Determine Project Name
Extract the project folder name from the current working directory.

### Step 3: Sync Files
Use rsync to backup while avoiding duplicates:

```bash
rsync -avh --progress --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='.build' \
  --exclude='Build' \
  --exclude='DerivedData' \
  --exclude='*.xcuserstate' \
  --exclude='.DS_Store' \
  --exclude='Pods' \
  --exclude='venv' \
  --exclude='.venv' \
  --exclude='__pycache__' \
  --exclude='.env' \
  --exclude='.env.local' \
  "$PWD/" "/Volumes/NIC THANGS/MacMini/$PROJECT_NAME/"
```

**Important flags:**
- `-a` = archive mode (preserves permissions, timestamps, etc.)
- `-v` = verbose
- `-h` = human-readable sizes
- `--progress` = show transfer progress
- `--delete` = remove files from destination that no longer exist in source (keeps backup clean, no duplicates)

### Step 4: Log the Backup
Append to backup log:
```bash
echo "$(date '+%Y-%m-%d %H:%M:%S') | $PROJECT_NAME | Backed up from $PWD" >> "/Volumes/NIC THANGS/MacMini/.backup_log"
```

### Step 5: Open Finder
Open the backup destination in Finder:
```bash
open "/Volumes/NIC THANGS/MacMini"
```

### Step 6: Report Results
Display:
- Number of files synced
- Total size transferred
- Backup location path
- Timestamp

## Execution Instructions

1. Check if NIC THANGS drive is mounted
2. Get the current working directory and extract project name
3. Create the project backup folder if it doesn't exist
4. Run rsync with the exclude patterns and --delete flag to prevent duplicates
5. Log the backup operation
6. Display summary to user

## Example Output

```
Backing up: PMNotesApp
Source: $HOME/PMNotesApp
Destination: /Volumes/NIC THANGS/MacMini/PMNotesApp

[rsync output...]

Backup Complete!
- Files synced: 247
- Size: 12.5 MB
- Location: /Volumes/NIC THANGS/MacMini/PMNotesApp
- Time: 2025-11-30 14:32:15
```
