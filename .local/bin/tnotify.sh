#!/usr/bin/env bash

TOKEN="$TELEGRAMBOT0_API_KEY"
CHAT_ID="$TELEGRAM_CHAT_ID"

if [[ -z "$TOKEN" ]]; then
    echo "Error: TELEGRAMBOT0_API_KEY environment variable is not set." >&2
    exit 1
fi

if [[ -z "$CHAT_ID" ]]; then
    echo "Error: TELEGRAM_CHAT_ID environment variable is not set." >&2
    exit 1
fi

PARSE_MODE=""
DISABLE_NOTIFICATION=true
MESSAGE_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --html)
      PARSE_MODE="HTML"
      ;;
    --notify)
      DISABLE_NOTIFICATION=false
      ;;
    *)
      MESSAGE_ARGS+=("$arg")
      ;;
  esac
done

if [[ ${#MESSAGE_ARGS[@]} -gt 0 ]]; then
  MESSAGE="${MESSAGE_ARGS[*]}"
else
  if ! [ -t 0 ]; then
    MESSAGE="$(cat)"
  fi
fi

if [[ -z "$MESSAGE" ]]; then
    echo "Error: Message is empty. Nothing to send." >&2
    exit 1
fi

JSON_PAYLOAD=$(jq -n \
                  --arg chat_id "$CHAT_ID" \
                  --arg text "$MESSAGE" \
                  --arg parse_mode "$PARSE_MODE" \
                  --argjson disable_notification "$DISABLE_NOTIFICATION" \
                  '{chat_id: $chat_id, text: $text, parse_mode: $parse_mode, disable_notification: $disable_notification}')

RESPONSE=$(curl -s -X POST \
     -H 'Content-Type: application/json' \
     -d "$JSON_PAYLOAD" \
     "https://api.telegram.org/bot$TOKEN/sendMessage")

if [[ "$(echo "$RESPONSE" | jq -r '.ok')" != "true" ]]; then
    echo "Error sending notification to Telegram:" >&2
    echo "$RESPONSE" | jq -r '"Status: \(.error_code)\nDescription: \(.description)"' >&2
    exit 1
fi

exit 0
