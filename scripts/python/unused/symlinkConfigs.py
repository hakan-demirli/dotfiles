import os
import shutil
import sys
import pathlib

script_dir = str(pathlib.Path(__file__).parent.absolute())
sys.path.append(script_dir + "/..")
import mylib

# Get the script directory
config_dir = mylib.CONFIG_DIR

# List all entries in config_dir
entries = os.listdir(config_dir)

# Check if ~/.config directory exists, create it if not
config_home = os.path.expanduser("~")
config_dir_path = os.path.join(config_home, ".config")
if not os.path.exists(config_dir_path):
    os.makedirs(config_dir_path)

# Loop through each entry in config_dir
for entry in entries:
    # Determine the full path of the entry
    entry_path = os.path.join(config_dir, entry)

    # Remove existing entry in ~/.config (if it exists)
    target_entry = os.path.join(config_dir_path, entry)

    if os.path.exists(target_entry):
        if os.path.islink(target_entry):
            os.unlink(target_entry)  # Unlink the symlink
        elif os.path.isdir(target_entry):
            shutil.rmtree(target_entry)  # Remove the directory
        elif os.path.isfile(target_entry):
            os.remove(target_entry)  # Remove the file
    # Create a symbolic link to the entry
    os.symlink(entry_path, target_entry)
