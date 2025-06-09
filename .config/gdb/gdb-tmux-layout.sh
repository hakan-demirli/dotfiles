#!/usr/bin/env bash
#
# gdb-tmux-layout.sh
# Reads a high-level JSON recipe and interprets it into valid tmux commands,
# correctly handling pane ID lookups.

# --- Prerequisites and Configuration ---
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it to use custom layouts." >&2
    exit 1
fi

LAYOUT_FILE="$HOME/.config/gdb/gdb-layout.json"
WINDOW_ID="$1"

if [ -z "$WINDOW_ID" ]; then
    echo "Error: Window ID not provided." >&2
    exit 1
fi

# Create a default layout file if it doesn't exist
if [ ! -f "$LAYOUT_FILE" ]; then
    echo "Layout file not found. Creating default at $LAYOUT_FILE" >&2
    cat > "$LAYOUT_FILE" << EOL
{
  "all_panes": ["gdb_prompt", "source", "stack"],
  "layout_commands": [
    "name_current gdb_prompt",
    "split h 50",
    "name_current source",
    "select_pane gdb_prompt",
    "split v 50",
    "name_current stack"
  ]
}
EOL
fi

# --- Helper Function to get Pane ID from Name ---
get_id_by_name() {
    local name_to_find="$1"
    tmux list-panes -t "$WINDOW_ID" -F '#{pane_title},#{pane_id}' | awk -F, -v name="$name_to_find" '$1 == name {print $2; exit}'
}

# --- Main Execution ---

# Set pane borders to show titles, which is essential for our lookup logic
tmux set-window-option -t "$WINDOW_ID" pane-border-status top

# Read the commands array from the JSON file and interpret each one
while IFS= read -r line; do
    # Parse the command and its arguments
    read -r cmd arg1 arg2 <<< "$line"

    # Select the target window to ensure all commands apply correctly
    tmux select-window -t "$WINDOW_ID"

    case "$cmd" in
        "name_current")
            # Get the ID of the currently focused pane and name it
            current_pane_id=$(tmux display-message -p -t "$WINDOW_ID" '#{pane_id}')
            tmux select-pane -t "$current_pane_id" -T "$arg1"
            ;;
        "split")
            # Split the currently focused pane
            split_direction=$([[ "$arg1" == "h" ]] && echo "-h" || echo "-v")
            tmux split-window "$split_direction" -p "$arg2"
            ;;
        "select_pane")
            # Find the pane ID by its name and select it
            target_id=$(get_id_by_name "$arg1")
            if [ -n "$target_id" ]; then
                tmux select-pane -t "$target_id"
            else
                echo "Error in layout: Could not find pane named '$arg1' to select." >&2
            fi
            ;;
        *)
            echo "Error: Unknown layout command '$cmd' in $LAYOUT_FILE" >&2
            ;;
    esac
done < <(jq -r '.layout_commands[]' "$LAYOUT_FILE")


# --- Validation ---
mapfile -t declared_panes < <(jq -r '.all_panes[]' "$LAYOUT_FILE")
for pane_name in "${declared_panes[@]}"; do
    if ! get_id_by_name "$pane_name" &> /dev/null; then
        echo "Error: Validation failed. Pane '${pane_name}' was declared in JSON but not created by the layout commands." >&2
    fi
done

GDB_PANE_ID=$(get_id_by_name "gdb_prompt")

if [ -z "$GDB_PANE_ID" ]; then
    echo "Error: Layout file '$LAYOUT_FILE' must result in a pane named 'gdb_prompt'." >&2
    exit 1
fi

# Final output is the ID of the prompt pane
echo "$GDB_PANE_ID"
