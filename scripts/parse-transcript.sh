#!/bin/bash
# parse-transcript.sh
# Parses Claude Code transcript JSONL files and extracts structured activity events
#
# Usage: parse-transcript.sh <transcript_file> [start_seq]
# Output: JSONL stream of activity events

set -euo pipefail

TRANSCRIPT_FILE="${1:-}"
START_SEQ="${2:-0}"

if [ -z "$TRANSCRIPT_FILE" ] || [ ! -f "$TRANSCRIPT_FILE" ]; then
    echo "Error: Transcript file not found: $TRANSCRIPT_FILE" >&2
    exit 1
fi

# Event sequence counter
seq=$START_SEQ

# Redact sensitive information
redact_sensitive() {
    local content="$1"

    # Redact API keys (Anthropic, OpenAI patterns)
    content=$(echo "$content" | sed -E 's/sk-[a-zA-Z0-9]{48,}/[REDACTED-API-KEY]/g')
    content=$(echo "$content" | sed -E 's/sk-ant-[a-zA-Z0-9_-]{95}/[REDACTED-API-KEY]/g')

    # Redact common secret patterns
    if echo "$content" | grep -qiE "(password|api[_-]?key|secret|token|bearer|authorization)"; then
        # If content contains secret keywords, check if it's a .env file or credentials
        if echo "$content" | grep -qE "(\.env|credentials|config.*secret)"; then
            content="[REDACTED-SENSITIVE-CONTENT]"
        fi
    fi

    echo "$content"
}

# Count lines and chars
count_metrics() {
    local text="$1"
    local lines=$(echo "$text" | wc -l | tr -d ' ')
    local chars=$(echo "$text" | wc -c | tr -d ' ')
    echo "$lines|$chars"
}

# Escape JSON string
escape_json() {
    local str="$1"
    # Escape backslashes, quotes, newlines, tabs
    str=$(echo "$str" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\t/\\t/g')
    echo "$str"
}

# Process transcript line by line
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Extract message type
    msg_type=$(echo "$line" | jq -r '.type // empty')
    [ -z "$msg_type" ] && continue

    # Extract timestamp
    ts=$(echo "$line" | jq -r '.timestamp // empty')
    [ -z "$ts" ] && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    case "$msg_type" in
        "user")
            # User prompt
            seq=$((seq + 1))

            # Extract user message content
            user_content=$(echo "$line" | jq -r '
  if (.message.content | type) == "array" then
    .message.content[0].text // .message.content[0] // ""
  else
    .message.content // ""
  end
' | head -c 10000)

            if [ -n "$user_content" ]; then
                user_content=$(redact_sensitive "$user_content")
                user_content_escaped=$(escape_json "$user_content")

                metrics=$(count_metrics "$user_content")
                line_count=$(echo "$metrics" | cut -d'|' -f1)
                char_count=$(echo "$metrics" | cut -d'|' -f2)

                echo "{\"seq\":$seq,\"ts\":\"$ts\",\"type\":\"user_prompt\",\"content\":\"$user_content_escaped\",\"char_count\":$char_count,\"line_count\":$line_count}"
            fi
            ;;

        "assistant")
            # Assistant response - may contain multiple content blocks
            content_array=$(echo "$line" | jq -c '.message.content[]? // empty')

            if [ -z "$content_array" ]; then
                continue
            fi

            # Process each content block
            while IFS= read -r block; do
                block_type=$(echo "$block" | jq -r '.type // empty')

                case "$block_type" in
                    "text")
                        # Assistant text response
                        seq=$((seq + 1))

                        text_content=$(echo "$block" | jq -r '.text // empty' | head -c 50000)

                        if [ -n "$text_content" ]; then
                            text_content=$(redact_sensitive "$text_content")
                            text_content_escaped=$(escape_json "$text_content")

                            metrics=$(count_metrics "$text_content")
                            line_count=$(echo "$metrics" | cut -d'|' -f1)
                            char_count=$(echo "$metrics" | cut -d'|' -f2)

                            echo "{\"seq\":$seq,\"ts\":\"$ts\",\"type\":\"assistant_text\",\"content\":\"$text_content_escaped\",\"char_count\":$char_count,\"line_count\":$line_count}"
                        fi
                        ;;

                    "thinking")
                        # Internal reasoning (optional capture)
                        seq=$((seq + 1))

                        thinking_content=$(echo "$block" | jq -r '.thinking // empty' | head -c 20000)

                        if [ -n "$thinking_content" ]; then
                            thinking_content_escaped=$(escape_json "$thinking_content")

                            metrics=$(count_metrics "$thinking_content")
                            char_count=$(echo "$metrics" | cut -d'|' -f2)

                            echo "{\"seq\":$seq,\"ts\":\"$ts\",\"type\":\"thinking\",\"content\":\"$thinking_content_escaped\",\"char_count\":$char_count}"
                        fi
                        ;;

                    "tool_use")
                        # Tool invocation
                        seq=$((seq + 1))

                        tool_name=$(echo "$block" | jq -r '.name // empty')
                        tool_input=$(echo "$block" | jq -c '.input // {}')
                        tool_input_escaped=$(escape_json "$tool_input")

                        echo "{\"seq\":$seq,\"ts\":\"$ts\",\"type\":\"tool_use\",\"tool_name\":\"$tool_name\",\"tool_input\":$tool_input}"
                        ;;
                esac
            done < <(echo "$content_array")
            ;;

        "tool_result")
            # Tool result
            seq=$((seq + 1))

            tool_name=$(echo "$line" | jq -r '.message.tool_name // empty')
            tool_output=$(echo "$line" | jq -r '.message.content // .message.output // empty' | head -c 100000)
            error_detected=0

            # Check for errors in output
            if echo "$tool_output" | grep -qiE "(error|failed|exception|fatal)"; then
                error_detected=1
            fi

            if [ -n "$tool_output" ]; then
                tool_output=$(redact_sensitive "$tool_output")
                tool_output_escaped=$(escape_json "$tool_output")

                metrics=$(count_metrics "$tool_output")
                line_count=$(echo "$metrics" | cut -d'|' -f1)
                char_count=$(echo "$metrics" | cut -d'|' -f2)

                echo "{\"seq\":$seq,\"ts\":\"$ts\",\"type\":\"tool_result\",\"tool_name\":\"$tool_name\",\"tool_output\":\"$tool_output_escaped\",\"char_count\":$char_count,\"line_count\":$line_count,\"error_detected\":$error_detected}"
            fi
            ;;
    esac
done < "$TRANSCRIPT_FILE"
