import os
import shutil
import sys
import pathlib

script_dir = str(pathlib.Path(__file__).parent.absolute())
sys.path.append(script_dir + "/..")
import mylib


def remove_path(p):
    if os.path.exists(p):
        if os.path.islink(p) and not os.path.exists(p):
            os.unlink(p)
        elif os.path.islink(p):
            os.unlink(p)  # Unlink the symlink
        elif os.path.isdir(p):
            shutil.rmtree(p)  # Remove the directory
        elif os.path.isfile(p):
            os.remove(p)  # Remove the file
        try:
            os.remove(p)
        except:
            pass


def symlink_dotfiles():
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
        remove_path(target_entry)
        # Create a symbolic link to the entry
        os.symlink(entry_path, target_entry)


def symlink_cargo():
    """copies entry to target"""
    # Check if ~/.cargo directory exists, create it if not
    target_home = os.path.expanduser("~")
    target_dir = os.path.join(target_home, ".cargo")
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    # Get the script directory
    entry_folder = "cargo"
    entry_file = "config"
    entries_dir = mylib.CONFIG_DIR
    entry_dir = os.path.join(entries_dir, entry_folder)
    entry_path = os.path.join(entry_dir, entry_file)
    # Remove existing entry in ~/.config (if it exists)
    target_path = os.path.join(target_dir, entry_file)
    remove_path(target_path)

    # Create a symbolic link to the entry
    os.symlink(entry_path, target_path)


def main():
    symlink_dotfiles()
    symlink_cargo()


if __name__ == "__main__":
    main()
