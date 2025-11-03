import json
import os
import shutil
import subprocess
from pathlib import Path

import gdb

USE_HELIX = True

EDITOR_COMMAND = "hx"
SOURCE_PANE_NAME = "source"
SUBSEQUENT_CMD_FORMAT = ":o {location}"
EDITOR_BREAKPOINT_KEYS = ["Space", "G", "b", "Escape", "Escape"]
EDITOR_INIT_COMMAND = ":toggle-option line-number absolute"

setup_is_active = False
source_editor_initialized = False
source_pane_id = None
last_known_editor_location = None
editor_breakpoints = set()
LAYOUT_FILE = Path(os.path.expanduser("~/.config/gdb/gdb-layout.json"))


def cleanup(event=None):
    """Function to tear down the tmux layout and clean up resources."""
    global \
        setup_is_active, \
        source_editor_initialized, \
        source_pane_id, \
        last_known_editor_location, \
        editor_breakpoints
    if not setup_is_active:
        return

    print("Cleaning up GDB-Dashboard tmux session...")

    # Conditionally disconnect event hooks
    if USE_HELIX:
        gdb.events.stop.disconnect(update_source_editor)
        gdb.events.breakpoint_created.disconnect(on_breakpoint_created)
        gdb.events.breakpoint_deleted.disconnect(on_breakpoint_deleted)

    try:
        current_window_id = gdb.execute(
            "!echo $TMUX_PANE | cut -d . -f 1", to_string=True
        ).strip()
        if current_window_id:
            subprocess.run(
                ["tmux", "kill-window", "-t", current_window_id],
                check=False,
                capture_output=True,
            )
    except Exception:
        pass

    pid = os.getpid()
    pipe_dir = Path(f"/tmp/gdb-dashboard-{pid}")
    if pipe_dir.exists():
        shutil.rmtree(pipe_dir)

    print("Cleanup complete.")

    setup_is_active = False
    source_editor_initialized = False
    source_pane_id = None
    last_known_editor_location = None
    editor_breakpoints.clear()


gdb.events.gdb_exiting.connect(cleanup)


def _send_editor_breakpoint_keys(location_str):
    """Helper function to send the breakpoint key sequence for a given location."""
    if not source_pane_id:
        return

    jump_cmd = SUBSEQUENT_CMD_FORMAT.format(location=location_str)
    subprocess.run(
        ["tmux", "send-keys", "-t", source_pane_id, jump_cmd, "C-m"], check=True
    )

    keys_to_send = list(EDITOR_BREAKPOINT_KEYS)
    subprocess.run(
        ["tmux", "send-keys", "-t", source_pane_id, *keys_to_send], check=True
    )

    if last_known_editor_location:
        restore_cmd = SUBSEQUENT_CMD_FORMAT.format(location=last_known_editor_location)
        subprocess.run(
            ["tmux", "send-keys", "-t", source_pane_id, restore_cmd, "C-m"], check=True
        )


def get_resolved_locations(bp):
    """Gets the *actual* file:line locations where GDB placed the breakpoint."""
    locations = set()
    if not hasattr(bp, "locations") or not bp.locations:
        return locations

    for loc in bp.locations:
        if loc.source:
            try:
                if len(loc.source) == 2:
                    filename, line = loc.source
                else:  # Handles 3-element tuple
                    filename, line, _ = loc.source

                if filename and line:
                    locations.add(f"{filename}:{line}")
            except (ValueError, TypeError):
                continue
    return locations


def on_breakpoint_created(bp):
    """Only toggle a marker ON if it's not already on AND editor is running."""
    if not setup_is_active or not source_editor_initialized:
        return

    for location in get_resolved_locations(bp):
        if location not in editor_breakpoints:
            print(f"Adding editor marker at resolved location: {location}")
            _send_editor_breakpoint_keys(location)
            editor_breakpoints.add(location)


def on_breakpoint_deleted(bp):
    """Only toggle a marker OFF if no other GDB breakpoints exist there."""
    if not setup_is_active or not source_editor_initialized:
        return

    active_locations = set()
    for existing_bp in gdb.breakpoints():
        if existing_bp.is_valid() and existing_bp.enabled:
            active_locations.update(get_resolved_locations(existing_bp))

    for location in get_resolved_locations(bp):
        if location in editor_breakpoints and location not in active_locations:
            print(f"Removing editor marker at resolved location: {location}")
            _send_editor_breakpoint_keys(location)
            editor_breakpoints.remove(location)


def update_source_editor(event):
    """GDB 'stop' event handler. Updates the editor pane AND saves the location."""
    global source_editor_initialized, last_known_editor_location
    if not setup_is_active or not source_pane_id:
        return

    try:
        sal = gdb.selected_frame().find_sal()
        if not sal or not sal.symtab:
            return

        filename = sal.symtab.fullname()
        line = sal.line
        location = f"{filename}:{line}"

        last_known_editor_location = location

        if not source_editor_initialized:
            keys_to_send = [f"{EDITOR_COMMAND} {location}", "C-m"]
            if EDITOR_INIT_COMMAND:
                keys_to_send.append(EDITOR_INIT_COMMAND)
                keys_to_send.append("C-m")
            subprocess.run(
                ["tmux", "send-keys", "-t", source_pane_id, *keys_to_send], check=True
            )
            source_editor_initialized = True
        else:
            command_to_run = SUBSEQUENT_CMD_FORMAT.format(location=location)
            subprocess.run(
                ["tmux", "send-keys", "-t", source_pane_id, command_to_run, "C-m"],
                check=True,
            )

    except gdb.error:
        pass


class DashboardTmuxCommand(gdb.Command):
    """Sets up gdb-dashboard within a custom tmux layout."""

    def __init__(self):
        super().__init__("dashboard-tmux", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        global \
            setup_is_active, \
            source_pane_id, \
            source_editor_initialized, \
            last_known_editor_location, \
            editor_breakpoints
        if setup_is_active:
            print("tmux dashboard is already active.")
            gdb.execute("dashboard")
            return

        try:
            global dashboard
            if "dashboard" not in globals():
                raise RuntimeError("'dashboard' object not found...")

            with open(LAYOUT_FILE) as f:
                layout_config = json.load(f)
            modules_to_activate = layout_config.get("all_panes", [])
            if "gdb_prompt" not in modules_to_activate:
                raise RuntimeError("The 'all_panes' list must include 'gdb_prompt'.")

            source_editor_initialized = False
            source_pane_id = None
            last_known_editor_location = None
            editor_breakpoints.clear()

            dashboard.disable()
            print("Discovering tmux layout...")
            pane_ids = {}
            current_window_id = gdb.execute(
                "!echo $TMUX_PANE | cut -d . -f 1", to_string=True
            ).strip()

            result = subprocess.run(
                [
                    "tmux",
                    "list-panes",
                    "-t",
                    current_window_id,
                    "-F",
                    "#{pane_title},#{pane_id}",
                ],
                capture_output=True,
                text=True,
                check=True,
            )

            for line in result.stdout.strip().split("\n"):
                if "," in line:
                    title, pane_id_val = line.split(",", 1)
                    pane_ids[title.strip()] = pane_id_val.strip()

            print(f"Discovered panes: {pane_ids}")

            pid = os.getpid()
            pipe_dir = Path(f"/tmp/gdb-dashboard-{pid}")
            pipe_dir.mkdir(exist_ok=True, parents=True)

            for pane_name in modules_to_activate:
                if pane_name not in pane_ids:
                    print(
                        f"Warning: Pane '{pane_name}' declared but not found. Skipping."
                    )
                    continue

                current_pane_id = pane_ids[pane_name]

                if USE_HELIX and pane_name == SOURCE_PANE_NAME:
                    # If using Helix, treat the source pane specially.
                    print(
                        f"Designating '{pane_name}' as the editor pane ({current_pane_id})."
                    )
                    source_pane_id = current_pane_id
                elif pane_name != "gdb_prompt":
                    # Otherwise, set it up as a standard dashboard pane.
                    # This now correctly handles the 'source' pane when USE_HELIX is False.
                    pipe_path = pipe_dir / f"{pane_name}.pipe"
                    os.mkfifo(pipe_path)
                    command_to_run = f"clear; while true; do cat {pipe_path}; done"

                    if pane_name == "output":
                        gdb.execute(f"set inferior-tty {pipe_path}")
                    else:
                        gdb.execute(f"dashboard {pane_name} -output {pipe_path}")

                    subprocess.run(
                        [
                            "tmux",
                            "send-keys",
                            "-t",
                            current_pane_id,
                            command_to_run,
                            "C-m",
                        ],
                        check=True,
                    )

            gdb.execute("dashboard -output /dev/null")

            print("Re-enabling dashboard event listeners...")
            dashboard.enable()

            if USE_HELIX:
                gdb.events.stop.connect(update_source_editor)
                gdb.events.breakpoint_created.connect(on_breakpoint_created)
                gdb.events.breakpoint_deleted.connect(on_breakpoint_deleted)

            setup_is_active = True

            if dashboard.is_running():
                gdb.execute("dashboard")

            print("\n>>> Tmux dashboard is now active. <<<")

        except Exception as e:
            print(f"\nError setting up tmux dashboard: {e}")
            cleanup()


if "dashboard" not in globals():
    gdb.execute("python Dashboard.start()")
    global dashboard
    dashboard.disable()

DashboardTmuxCommand()
