#!/bin/bash
# Log feedback hook - detects praise (wins) and criticism (losses)
# Runs on UserPromptSubmit event
# Forks to background to avoid blocking user input

# Read JSON input from stdin first (before forking)
input=$(cat)

# Rotate debug log if needed (before first write)
"$HOME/.claude/scripts/rotate-debug-log.sh"

# Debug: log raw input to see what we're getting
echo "$(date): RAW INPUT: $input" >> "$HOME/.claude/logs/debug.log"

# ============ CALLBACK CHECKING (synchronous) ============
# Check for callback triggers BEFORE forking so response shows immediately
callbacks_file="/Volumes/DevDrive/Cache/feedback/callbacks.json"
if [ -f "$callbacks_file" ]; then
  user_msg=$(echo "$input" | jq -r '.prompt // ""')
  if [ -n "$user_msg" ]; then
    # Normalize message (lowercase, trim, remove punctuation)
    normalized=$(echo "$user_msg" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/[!?."'\'']//g')

    # Check each callback trigger
    callbacks_json=$(cat "$callbacks_file")
    callback_count=$(echo "$callbacks_json" | jq -r '.callbacks | length')

    for ((i=0; i<callback_count; i++)); do
      trigger=$(echo "$callbacks_json" | jq -r ".callbacks[$i].trigger" | tr '[:upper:]' '[:lower:]')
      response=$(echo "$callbacks_json" | jq -r ".callbacks[$i].response")

      # Check if normalized message contains the trigger
      if echo "$normalized" | grep -q "$trigger"; then
        # Output the callback response immediately
        echo ""
        echo "$response"
        echo ""

        # Increment use_count (in background, non-blocking)
        (
          updated=$(jq ".callbacks[$i].use_count += 1" "$callbacks_file")
          echo "$updated" > "$callbacks_file"
        ) &

        break
      fi
    done
  fi
fi

# ============ NEW SESSION DETECTION (synchronous) ============
# Check if this is a new session and show feedback summary BEFORE forking
current_session=$(echo "$input" | jq -r '.session_id // ""')
last_session_file="$HOME/.claude/logs/last-session-id"

if [ -n "$current_session" ]; then
  last_session=$(cat "$last_session_file" 2>/dev/null || echo "")

  if [ "$current_session" != "$last_session" ]; then
    # New session detected! Show feedback summary
    echo "$current_session" > "$last_session_file"

    # Run the feedback summary script (output goes to user and Claude)
    $HOME/.claude/hooks/session-start.sh
  fi
fi

# Fork to background immediately
(
  # Extract user message and working directory
  # Claude Code uses "prompt" field, not "user_prompt"
  user_message=$(echo "$input" | jq -r '.prompt // ""')
  working_dir=$(echo "$input" | jq -r '.cwd // ""')

  # Debug: log extracted values
  echo "$(date): user_message='$user_message' working_dir='$working_dir'" >> "$HOME/.claude/logs/debug.log"

  # Skip if no message
  [ -z "$user_message" ] && exit 0

  # Save transcript path for compaction detection
  current_session=$(echo "$input" | jq -r '.session_id // ""')
  last_transcript_file="$HOME/.claude/logs/last-session-transcript"
  transcript_file=$(echo "$input" | jq -r '.transcript_path // ""')

  if [ -n "$current_session" ] && [ -n "$transcript_file" ] && [ -f "$transcript_file" ]; then
    echo "$transcript_file" > "$last_transcript_file"
  fi

  # Only log short feedback - filter out long messages where praise/loss words appear incidentally
  word_count=$(echo "$user_message" | wc -w | xargs)
  char_count=${#user_message}

  # Skip if message is longer than 5 words OR longer than 50 characters
  # This captures quick feedback like "good job", "awesome", "that's sick"
  # but filters out longer conversations
  if [ "$word_count" -gt 5 ] || [ "$char_count" -gt 50 ]; then
    exit 0
  fi

  # Get project name from working directory
  project=$(basename "$working_dir" 2>/dev/null || echo "unknown")

  # Convert message to lowercase for matching
  lower_message=$(echo "$user_message" | tr '[:upper:]' '[:lower:]')

  # Generate context summary from recent transcript
  # Extract transcript path directly from input (Claude Code provides this)
  transcript_file=$(echo "$input" | jq -r '.transcript_path // ""')

  # Debug: log transcript path
  echo "$(date): transcript_file='$transcript_file'" >> "$HOME/.claude/logs/debug.log"

  context_summary=""
  if [ -f "$transcript_file" ]; then
    # Get last 1000 lines, extract file operations only
    # Show only files that were accessed (Read/Edit/Write)
    # Simplified format: icon + filename, comma-separated
    context_lines=$(tail -n 1000 "$transcript_file" | \
      jq -r '
        if .type == "assistant" then
          .message.content[] |
          select(.type == "tool_use") |
          # Show file edits/writes
          if .name == "Edit" or .name == "Write" then
            "✏️ " + (.input.file_path | split("/") | .[-1])
          # Show file reads (exclude log files)
          elif .name == "Read" and (.input.file_path | test("(debug\\.log|session-wins|session-losses)") | not) then
            "📖 " + (.input.file_path | split("/") | .[-1])
          else
            empty
          end
        else
          empty
        end
      ' 2>/dev/null | \
      tail -n 25 | \
      tr '\n' '|' | \
      sed 's/|/, /g' | \
      sed 's/, $//')

    # Create concise summary (max 1000 chars)
    if [ -n "$context_lines" ]; then
      context_summary="${context_lines:0:1000}"
      # Clean up
      context_summary=$(echo "$context_summary" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ ${#context_summary} -eq 1000 ] && context_summary="${context_summary}..."
    fi
  fi

  # Fallback to user message if no context available
  [ -z "$context_summary" ] && context_summary="$user_message"

  # Logs directory
  log_dir="$HOME/.claude/logs"

  # Timestamp
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  ts_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  date_header=$(date '+%Y-%m-%d')

  # ============ LOAD PATTERNS FROM CONFIG ============
  config_file="$HOME/.claude/config/feedback-patterns.json"

  if [ ! -f "$config_file" ]; then
    echo "$(date): ERROR - Config file not found: $config_file" >> "$HOME/.claude/logs/debug.log"
    exit 1
  fi

  # Load patterns from JSON into arrays (bash 3.x compatible)
  praise_phrases=()
  while IFS= read -r line; do
    praise_phrases+=("$line")
  done < <(jq -r '.praise.phrases[]' "$config_file")

  praise_words=()
  while IFS= read -r line; do
    praise_words+=("$line")
  done < <(jq -r '.praise.words[]' "$config_file")

  loss_phrases=()
  while IFS= read -r line; do
    loss_phrases+=("$line")
  done < <(jq -r '.loss.phrases[]' "$config_file")

  loss_words=()
  while IFS= read -r line; do
    loss_words+=("$line")
  done < <(jq -r '.loss.words[]' "$config_file")

  # Debug: log pattern counts
  echo "$(date): Loaded patterns - praise_phrases: ${#praise_phrases[@]}, praise_words: ${#praise_words[@]}, loss_phrases: ${#loss_phrases[@]}, loss_words: ${#loss_words[@]}" >> "$HOME/.claude/logs/debug.log"

  # Function to check if message contains pattern
  check_patterns() {
    local msg="$1"
    shift
    local patterns=("$@")
    for pattern in "${patterns[@]}"; do
      if echo "$msg" | grep -qi "\b${pattern}\b"; then
        echo "$pattern"
        return 0
      fi
    done
    return 1
  }

  # Check for praise (wins)
  matched_praise=""
  for phrase in "${praise_phrases[@]}"; do
    if echo "$lower_message" | grep -qi "$phrase"; then
      matched_praise="$phrase"
      break
    fi
  done

  if [ -z "$matched_praise" ]; then
    for word in "${praise_words[@]}"; do
      if echo "$lower_message" | grep -qiw "$word"; then
        matched_praise="$word"
        break
      fi
    done
  fi

  # Check for losses
  matched_loss=""
  for phrase in "${loss_phrases[@]}"; do
    if echo "$lower_message" | grep -qi "$phrase"; then
      matched_loss="$phrase"
      break
    fi
  done

  if [ -z "$matched_loss" ]; then
    for word in "${loss_words[@]}"; do
      if echo "$lower_message" | grep -qiw "$word"; then
        matched_loss="$word"
        break
      fi
    done
  fi

  # Function to generate AI summary of recent conversation
  generate_summary() {
    local transcript_file="$1"

    # Load API key from .env files (per user's credential rule)
    local api_key="${ANTHROPIC_API_KEY:-}"

    # Check common .env locations if not already set
    if [ -z "$api_key" ]; then
      for env_file in "$HOME/4Techz/.env" "$HOME/.env" "$HOME/.claude/.env"; do
        if [ -f "$env_file" ]; then
          # Extract ANTHROPIC_API_KEY or Anthropic_API_Key from .env (trim whitespace properly)
          api_key=$(grep -E "^(ANTHROPIC_API_KEY|Anthropic_API_Key)" "$env_file" 2>/dev/null | sed 's/^[^=]*=//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | head -n1)
          [ -n "$api_key" ] && break
        fi
      done
    fi

    # Extract recent conversation (last 150 lines, user + assistant messages)
    local recent_convo=$(tail -n 150 "$transcript_file" | \
      jq -r '
        if .type == "user" then
          "USER: " + (.message.content | gsub("\\n"; " "))
        elif .type == "assistant" then
          (.message.content[] |
           if .type == "text" then
             "ASSISTANT: " + (.text | gsub("\\n"; " "))
           else
             empty
           end)
        else
          empty
        end
      ' 2>/dev/null | tail -n 50)

    if [ -z "$api_key" ]; then
      echo "Recent conversation:\n\n$recent_convo"
      return
    fi

    # Build JSON payload using jq for proper escaping
    local json_payload=$(jq -n \
      --arg convo "$recent_convo" \
      '{
        model: "claude-3-haiku-20240307",
        max_tokens: 500,
        messages: [{
          role: "user",
          content: ("Summarize this conversation in 2-3 concise paragraphs. Focus on: what problem was being solved, what was implemented/changed, and the outcome.\n\nConversation:\n" + $convo)
        }]
      }')

    # Call Claude API for summary (using Haiku - faster and cheaper)
    local api_response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
      --header "x-api-key: $api_key" \
      --header "anthropic-version: 2023-06-01" \
      --header "content-type: application/json" \
      --data "$json_payload" 2>&1)

    # Debug: log API response
    echo "$(date): API Response: $api_response" >> "$HOME/.claude/logs/debug.log"

    local summary=$(echo "$api_response" | jq -r '.content[0].text // "Summary generation failed"' 2>/dev/null)

    echo "$summary"
  }

  # Log wins
  if [ -n "$matched_praise" ]; then
    # Generate AI summary for SQLite storage
    ai_summary=$(generate_summary "$transcript_file")

    # ============ SQLite ONLY WRITE (Phase 2) ============
    DB="$HOME/.claude/claudarity.db"
    if [ -f "$DB" ]; then
      # Escape strings for SQL (replace single quotes with two single quotes)
      ts_safe=$(echo "$ts_iso" | sed "s/'/''/g")
      project_safe=$(echo "$project" | sed "s/'/''/g")
      pattern_safe=$(echo "$matched_praise" | sed "s/'/''/g")
      user_message_safe=$(echo "$user_message" | sed "s/'/''/g")
      context_summary_safe=$(echo "$context_summary" | sed "s/'/''/g")
      ai_summary_safe=$(echo "$ai_summary" | sed "s/'/''/g")

      # Insert into main table (also stores cache_file reference)
      sqlite3 "$DB" "INSERT INTO feedback_entries (ts, project, pattern, type, user_message, context_summary, ai_summary) VALUES ('$ts_safe', '$project_safe', '$pattern_safe', 'win', '$user_message_safe', '$context_summary_safe', '$ai_summary_safe');" 2>/dev/null

      # Insert into FTS5 for full-text search
      last_id=$(sqlite3 "$DB" "SELECT last_insert_rowid();" 2>/dev/null)
      if [ -n "$last_id" ]; then
        sqlite3 "$DB" "INSERT INTO feedback_fts (feedback_id, user_message, context_summary, ai_summary) VALUES ($last_id, '$user_message_safe', '$context_summary_safe', '$ai_summary_safe');" 2>/dev/null
      fi
    fi

    # ============ CREATE MARKDOWN CACHE FILE ============
    # Generate cache file for human readability and backup
    cache_dir="/Volumes/DevDrive/Cache/feedback"
    mkdir -p "$cache_dir"

    # Filename: win-YYYY-MM-DD-HH-MM-SS.md
    ts_file=$(echo "$ts_iso" | sed 's/T/ /' | sed 's/Z$//' | awk '{print $1 " " substr($2,1,8)}')
    cache_file="$cache_dir/win-$ts_file.md"
    cache_file=$(echo "$cache_file" | tr ' ' '-' | tr ':' '-')

    # Write markdown file
    cat > "$cache_file" << EOF
# Win: $matched_praise

**Time:** $ts
**Project:** $project
**Pattern:** $matched_praise

## AI Summary
$ai_summary

## Quick Context
$context_summary

## User Message
$user_message
EOF

    # Update SQLite with cache_file path
    if [ -f "$DB" ] && [ -n "$last_id" ]; then
      cache_file_safe=$(echo "$cache_file" | sed "s/'/''/g")
      sqlite3 "$DB" "UPDATE feedback_entries SET cache_file = '$cache_file_safe' WHERE rowid = $last_id;" 2>/dev/null
    fi

    # ============ TEMPLATE OUTCOME TRACKING (WIN) ============
    template_metadata="$working_dir/.claude/template-metadata.json"
    if [ -f "$template_metadata" ]; then
      template_id=$(jq -r '.template_id // ""' "$template_metadata" 2>/dev/null || echo "")
      if [ -n "$template_id" ]; then
        template_outcomes_log="/Volumes/DevDrive/Cache/templates/learning/template-outcomes.jsonl"
        mkdir -p "$(dirname "$template_outcomes_log")"
        echo "{\"timestamp\":\"$ts_iso\",\"project\":\"$project\",\"template_id\":\"$template_id\",\"outcome\":\"win\"}" >> "$template_outcomes_log"
      fi
    fi
  fi

  # Log losses
  if [ -n "$matched_loss" ]; then
    # Generate AI summary for SQLite storage
    ai_summary=$(generate_summary "$transcript_file")

    # ============ SQLite ONLY WRITE (Phase 2) ============
    DB="$HOME/.claude/claudarity.db"
    if [ -f "$DB" ]; then
      # Escape strings for SQL (replace single quotes with two single quotes)
      ts_safe=$(echo "$ts_iso" | sed "s/'/''/g")
      project_safe=$(echo "$project" | sed "s/'/''/g")
      pattern_safe=$(echo "$matched_loss" | sed "s/'/''/g")
      user_message_safe=$(echo "$user_message" | sed "s/'/''/g")
      context_summary_safe=$(echo "$context_summary" | sed "s/'/''/g")
      ai_summary_safe=$(echo "$ai_summary" | sed "s/'/''/g")

      # Insert into main table (also stores cache_file reference)
      sqlite3 "$DB" "INSERT INTO feedback_entries (ts, project, pattern, type, user_message, context_summary, ai_summary) VALUES ('$ts_safe', '$project_safe', '$pattern_safe', 'loss', '$user_message_safe', '$context_summary_safe', '$ai_summary_safe');" 2>/dev/null

      # Insert into FTS5 for full-text search
      last_id=$(sqlite3 "$DB" "SELECT last_insert_rowid();" 2>/dev/null)
      if [ -n "$last_id" ]; then
        sqlite3 "$DB" "INSERT INTO feedback_fts (feedback_id, user_message, context_summary, ai_summary) VALUES ($last_id, '$user_message_safe', '$context_summary_safe', '$ai_summary_safe');" 2>/dev/null
      fi
    fi

    # ============ CREATE MARKDOWN CACHE FILE ============
    # Generate cache file for human readability and backup
    cache_dir="/Volumes/DevDrive/Cache/feedback"
    mkdir -p "$cache_dir"

    # Filename: loss-YYYY-MM-DD-HH-MM-SS.md
    ts_file=$(echo "$ts_iso" | sed 's/T/ /' | sed 's/Z$//' | awk '{print $1 " " substr($2,1,8)}')
    cache_file="$cache_dir/loss-$ts_file.md"
    cache_file=$(echo "$cache_file" | tr ' ' '-' | tr ':' '-')

    # Write markdown file
    cat > "$cache_file" << EOF
# Loss: $matched_loss

**Time:** $ts
**Project:** $project
**Pattern:** $matched_loss

## AI Summary
$ai_summary

## Quick Context
$context_summary

## User Message
$user_message
EOF

    # Update SQLite with cache_file path
    if [ -f "$DB" ] && [ -n "$last_id" ]; then
      cache_file_safe=$(echo "$cache_file" | sed "s/'/''/g")
      sqlite3 "$DB" "UPDATE feedback_entries SET cache_file = '$cache_file_safe' WHERE rowid = $last_id;" 2>/dev/null
    fi

    # ============ TEMPLATE OUTCOME TRACKING (LOSS) ============
    template_metadata="$working_dir/.claude/template-metadata.json"
    if [ -f "$template_metadata" ]; then
      template_id=$(jq -r '.template_id // ""' "$template_metadata" 2>/dev/null || echo "")
      if [ -n "$template_id" ]; then
        template_outcomes_log="/Volumes/DevDrive/Cache/templates/learning/template-outcomes.jsonl"
        mkdir -p "$(dirname "$template_outcomes_log")"
        echo "{\"timestamp\":\"$ts_iso\",\"project\":\"$project\",\"template_id\":\"$template_id\",\"outcome\":\"loss\"}" >> "$template_outcomes_log"
      fi
    fi
  fi

) &

# ============ TERMINAL ACTIVITY CAPTURE ============
# Capture full terminal activity for Claudarity (background, non-blocking)
(
  session_id=$(echo "$input" | jq -r '.session_id // ""')
  transcript_file=$(echo "$input" | jq -r '.transcript_path // ""')
  working_dir=$(echo "$input" | jq -r '.cwd // ""')

  if [ -n "$session_id" ] && [ -f "$transcript_file" ]; then
    # Run activity capture in background
    "$HOME/.claude/scripts/capture-terminal-activity.sh" \
      "$session_id" \
      "$transcript_file" \
      "$working_dir" \
      &>/dev/null &
  fi
) &

# Return immediately - don't block user input
exit 0
