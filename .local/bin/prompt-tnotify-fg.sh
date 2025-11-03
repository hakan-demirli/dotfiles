#!/usr/bin/env bash

TNOTIFY_FG_CMD=""

_telegram_notify_on_completion() {
  local exit_code=$?
  local last_cmd

  if [[ -n $TNOTIFY_FG_CMD ]]; then
    last_cmd="$TNOTIFY_FG_CMD"
    TNOTIFY_FG_CMD=""
  else
    last_cmd=$(history 1 | sed 's/^[ ]*[0-9]\+[ ]*//')
  fi

  if [[ -z $last_cmd || $last_cmd == "fg"* || $last_cmd == "fg-notify"* || $last_cmd == "tnotify-toggle"* || $last_cmd == *"tnotify.sh"* || $last_cmd == *"prompt-tnotify-fg.sh"* ]]; then
    return
  fi

  local status_icon status_text tags hostname_tag command_tag
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

fg-notify() {
  local job_spec="${1}"
  local search_pattern

  if [[ -z $job_spec ]]; then
    search_pattern='\[[0-9]+\]\+.*Stopped'
  else
    local job_num=${job_spec#%}
    search_pattern="\[${job_num}\].*Stopped"
  fi

  TNOTIFY_FG_CMD=$(jobs -l | grep -E "$search_pattern" | head -n 1 | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ ]*//')

  if [[ -z $TNOTIFY_FG_CMD ]]; then
    echo "fg-notify: Job not found or not suspended."
    command fg "$@"
    return
  fi

  echo "Resuming job with notification armed: $TNOTIFY_FG_CMD"
  command fg "$@"
}

NOTIFY_CMD="_telegram_notify_on_completion"
HOOK_MARKER="##TNOTIFY_COMPLETE_HOOK_ACTIVE##"

if [[ $PROMPT_COMMAND != *"$HOOK_MARKER"* ]]; then
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }$NOTIFY_CMD #$HOOK_MARKER"
  echo "Telegram completion notifications: ENABLED"
  echo "Use 'fg-notify' to resume jobs with notifications."
else
  PROMPT_COMMAND="${PROMPT_COMMAND//; $NOTIFY_CMD #$HOOK_MARKER/}"
  PROMPT_COMMAND="${PROMPT_COMMAND/#$NOTIFY_CMD #$HOOK_MARKER/}"
  unset -f fg-notify
  echo "Telegram completion notifications: DISABLED"
fi
