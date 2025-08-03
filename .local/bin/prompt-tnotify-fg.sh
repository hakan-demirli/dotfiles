#!/usr/bin/env bash

# This variable will hold the command of the job we are bringing to the foreground
TNOTIFY_FG_CMD=""

# The main notification logic
_telegram_notify_on_completion() {
    local exit_code=$?
    local last_cmd

    # PRIORITY: Check if we just ran a foregrounded job
    if [[ -n "$TNOTIFY_FG_CMD" ]]; then
        last_cmd="$TNOTIFY_FG_CMD"
        # Unset the variable so we don't re-use it
        TNOTIFY_FG_CMD=""
    else
        # Fallback to the history method for normal commands
        last_cmd=$(history 1 | sed 's/^[ ]*[0-9]\+[ ]*//')
    fi

    # The original exclusion logic. We also exclude our new fg-notify command.
    if [[ -z "$last_cmd" || "$last_cmd" == "fg"* || "$last_cmd" == "fg-notify"* || "$last_cmd" == "tnotify-toggle"* || "$last_cmd" == *"tnotify.sh"* || "$last_cmd" == *"prompt-tnotify-fg.sh"* ]]; then
        return
    fi

    # --- The rest of the notification logic is identical ---
    local status_icon status_text tags hostname_tag command_tag
    hostname_tag=$(hostname | tr -d '._-')
    command_tag=$(echo "$last_cmd" | awk '{print $1}' | tr -cd '[:alnum:]')
    if [ $exit_code -eq 0 ]; then
        status_icon="✅"; status_text="Succeeded"; tags="#success #${hostname_tag} #${command_tag} #command"
    else
        status_icon="❌"; status_text="Failed"; tags="#failure #${hostname_tag} #${command_tag} #command"
    fi
    local final_message
    final_message=$(cat <<EOF
${status_icon} Task on $(hostname) ${status_text}
Command: \`${last_cmd}\`
Exit Code: ${exit_code}
Tags: ${tags}
EOF
    )
    tnotify.sh "$final_message" &>/dev/null &
}

# A corrected, more robust function to replace 'fg'.
# You MUST use this instead of the built-in 'fg'.
fg-notify() {
    local job_spec="${1}"
    local search_pattern

    if [[ -z "$job_spec" ]]; then
        # CASE 1: No argument given. Find the "current" job, marked with a '+'.
        # This mimics the default behavior of the built-in 'fg' command.
        search_pattern='\[[0-9]+\]\+.*Stopped'
    else
        # CASE 2: An argument is given (e.g., '1' or '%1').
        # We strip the optional '%' and build a pattern for that specific job number.
        local job_num=${job_spec#%}
        search_pattern="\[${job_num}\].*Stopped"
    fi

    # Find the command text for the job using the correct pattern.
    # We use grep's -E flag for extended regex to correctly interpret '\+'.
    # The awk/sed combo strips the job status fields to isolate the command.
    TNOTIFY_FG_CMD=$(jobs -l | grep -E "$search_pattern" | head -n 1 | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ ]*//')

    if [[ -z "$TNOTIFY_FG_CMD" ]]; then
      echo "fg-notify: Job not found or not suspended."
      # Still try to run the original fg, as it might handle cases we don't (e.g., job by name).
      command fg "$@"
      return
    fi
    
    echo "Resuming job with notification armed: $TNOTIFY_FG_CMD"
    # Call the original, built-in 'fg' command
    command fg "$@"
}


# The toggle logic remains the same
NOTIFY_CMD="_telegram_notify_on_completion"
HOOK_MARKER="##TNOTIFY_COMPLETE_HOOK_ACTIVE##"

# Check if the hook is already active to prevent adding it multiple times
if [[ "$PROMPT_COMMAND" != *"$HOOK_MARKER"* ]]; then
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }$NOTIFY_CMD #$HOOK_MARKER"
    echo "Telegram completion notifications: ENABLED"
    echo "Use 'fg-notify' to resume jobs with notifications."
else
    # This block is for toggling OFF, but the original script didn't have a clear
    # toggle-off mechanism. This is a more complete implementation.
    PROMPT_COMMAND="${PROMPT_COMMAND//; $NOTIFY_CMD #$HOOK_MARKER/}"
    PROMPT_COMMAND="${PROMPT_COMMAND/#$NOTIFY_CMD #$HOOK_MARKER/}" # Handle case where it's at the start
    unset -f fg-notify
    echo "Telegram completion notifications: DISABLED"
fi
