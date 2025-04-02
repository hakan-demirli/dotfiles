#!/usr/bin/env sh
# This wrapper script is invoked by xdg-desktop-portal-termfilechooser.
#
# For more information about input/output arguments read `xdg-desktop-portal-termfilechooser(5)`

set -ex

logfile="$HOME/yazi-chooser.log"
echo "--- $(date) ---" >> "$logfile"
echo "Args: $@" >> "$logfile"

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"

cmd="yazi"
termcmd="${TERMCMD:-kitty --title 'termfilechooser'}"

if [ "$save" = "1" ]; then
    set -- --chooser-file="$out"
    [ -n "$path" ] && set -- "$@" "$path"
elif [ "$directory" = "1" ]; then
    set -- --chooser-file="$out" --cwd-file="$out"
    [ -n "$path" ] && set -- "$@" "$path"
elif [ "$multiple" = "1" ]; then
    set -- --chooser-file="$out"
    [ -n "$path" ] && set -- "$@" "$path"
else
    set -- --chooser-file="$out"
    [ -n "$path" ] && set -- "$@" "$path"
fi

echo "Processed args: $@" >> "$logfile"

command="$termcmd $cmd"
for arg in "$@"; do
    escaped=$(printf "%s" "$arg" | sed 's/"/\\"/g')
    command="$command \"$escaped\""
done

echo "Final command: $command" >> "$logfile"
sh -c "$command"
