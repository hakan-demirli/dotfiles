#!/usr/bin/env bash

_telegram_notify_on_completion() {
  local exit_code=$?
  local last_cmd
  last_cmd=$(history 1 | sed 's/^[ ]*[0-9]\+[ ]*//')

  if [[ -z $last_cmd || $last_cmd == "fg"* || $last_cmd == "tnotify-toggle"* || $last_cmd == *"tnotify.sh"* || $last_cmd == *"prompt-tnotify.sh"* ]]; then
    return
  fi

  local status_icon status_text tags
  local hostname_tag command_tag

  hostname_tag=$(hostname | tr -d '._-')

  command_tag=$(echo "$last_cmd" | awk '{print $1}' | tr -cd '[:alnum:]')

  if [ $exit_code -eq 0 ]; then
    status_icon="✅"
    status_text="Succeeded"
    tags="#success #${hostname_tag} #${command_tag} #command"
  else
    status_icon="❌"
    status_text="Failed"
    tags="#failure #${hostname_tag} #${command_tag} #command"
  fi

  local final_message
  final_message=$(
    cat << EOF
${status_icon} Task on $(hostname) ${status_text}
Command: \`${last_cmd}\`
Exit Code: ${exit_code}
Tags: ${tags}
EOF
  )

  tnotify.sh "$final_message" &> /dev/null &
}

NOTIFY_CMD="_telegram_notify_on_completion"
HOOK_MARKER="##TNOTIFY_COMPLETE_HOOK_ACTIVE##"

if [[ $PROMPT_COMMAND == *"$HOOK_MARKER"* ]]; then
  PROMPT_COMMAND="${PROMPT_COMMAND//; $NOTIFY_CMD #$HOOK_MARKER/}"
  echo "Telegram completion notifications: DISABLED"
else
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }$NOTIFY_CMD #$HOOK_MARKER"
  echo "Telegram completion notifications: ENABLED"
fi
