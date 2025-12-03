#!/bin/bash
# Teach Callback Script - Add new phrase-response pairs to callbacks.json
# Usage: teach-callback.sh "trigger phrase" "response phrase"

callbacks_file="/Volumes/DevDrive/Cache/feedback/callbacks.json"

# Check arguments
if [ $# -ne 2 ]; then
  echo "Usage: teach-callback.sh \"trigger phrase\" \"response phrase\""
  echo ""
  echo "Example:"
  echo "  teach-callback.sh \"may the force\" \"be with you\""
  exit 1
fi

trigger="$1"
response="$2"
learned_date=$(date '+%Y-%m-%d')

# Create callbacks file if it doesn't exist
if [ ! -f "$callbacks_file" ]; then
  echo '{"callbacks": []}' > "$callbacks_file"
fi

# Check if trigger already exists
existing=$(jq -r --arg trigger "$(echo "$trigger" | tr '[:upper:]' '[:lower:]')" \
  '.callbacks[] | select(.trigger | ascii_downcase == $trigger) | .trigger' \
  "$callbacks_file")

if [ -n "$existing" ]; then
  echo "⚠️  Callback already exists for trigger: \"$existing\""
  echo ""

  # Show existing callback
  jq -r --arg trigger "$(echo "$trigger" | tr '[:upper:]' '[:lower:]')" \
    '.callbacks[] | select(.trigger | ascii_downcase == $trigger) |
    "   Trigger: \(.trigger)\n   Response: \(.response)\n   Learned: \(.learned_date)\n   Used: \(.use_count) times"' \
    "$callbacks_file"

  echo ""
  read -p "Do you want to update it? (y/n): " update

  if [[ "$update" != "y" ]]; then
    echo "Cancelled."
    exit 0
  fi

  # Update existing callback
  updated_json=$(jq --arg trigger "$(echo "$trigger" | tr '[:upper:]' '[:lower:]')" \
    --arg new_response "$response" \
    --arg learned_date "$learned_date" \
    '(.callbacks[] | select(.trigger | ascii_downcase == $trigger)) |=
    {trigger: .trigger, response: $new_response, learned_date: $learned_date, use_count: .use_count}' \
    "$callbacks_file")

  echo "$updated_json" > "$callbacks_file"
  echo "✅ Updated callback!"
else
  # Add new callback
  updated_json=$(jq --arg trigger "$trigger" \
    --arg response "$response" \
    --arg learned_date "$learned_date" \
    '.callbacks += [{
      trigger: $trigger,
      response: $response,
      learned_date: $learned_date,
      use_count: 0
    }]' \
    "$callbacks_file")

  echo "$updated_json" > "$callbacks_file"
  echo "✅ Learned new callback!"
fi

echo ""
echo "   Trigger: \"$trigger\""
echo "   Response: \"$response\""
echo ""

# Show total callback count
total=$(jq -r '.callbacks | length' "$callbacks_file")
echo "Total callbacks: $total"

exit 0
