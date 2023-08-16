import os
import shutil
import sys
import pathlib

script_dir = str(pathlib.Path(__file__).parent.absolute())
sys.path.append(script_dir + "/..")
import mylib

# Get the script directory
config_dir = mylib.CONFIG_DIR

# List all folders in config_dir
configs = [
    folder
    for folder in os.listdir(config_dir)
    if os.path.isdir(os.path.join(config_dir, folder))
]

# Loop through each config folder
for config in configs:
    # Remove existing folder in ~/.config (if it exists)
    target_folder = os.path.expanduser(os.path.join("~", ".config", config))
    if os.path.exists(target_folder):
        if os.path.isdir(target_folder):
            shutil.rmtree(target_folder)
        else:
            os.remove(target_folder)

    # Create a symbolic link to the folder
    os.symlink(os.path.join(config_dir, config), target_folder)
