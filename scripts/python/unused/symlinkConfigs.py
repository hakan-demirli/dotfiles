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
    source_dotfiles_dir = mylib.CONFIG_DIR

    target_home = os.path.expanduser("~")
    target_dotfiles_dir = os.path.join(target_home, ".config")
    if not os.path.exists(target_dotfiles_dir):
        os.makedirs(target_dotfiles_dir)

    for dotfile_entry in os.listdir(source_dotfiles_dir):
        source_dotfile_path = os.path.join(source_dotfiles_dir, dotfile_entry)

        target_dotfile_path = os.path.join(target_dotfiles_dir, dotfile_entry)

        # Remove the existing target dotfile (if it exists)
        remove_path(target_dotfile_path)

        os.symlink(source_dotfile_path, target_dotfile_path)


def symlink_cargo_config():
    # Define the source and target directories
    source_config_dir = os.path.join(mylib.CONFIG_DIR, "cargo")
    source_config_file = "config"
    target_home = os.path.expanduser("~")
    target_config_dir = os.path.join(target_home, ".cargo")

    # Ensure the target directory exists; create it if not
    if not os.path.exists(target_config_dir):
        os.makedirs(target_config_dir)

    # Construct source and target paths
    source_config_path = os.path.join(source_config_dir, source_config_file)
    target_config_path = os.path.join(target_config_dir, source_config_file)

    # Remove existing target config file if it exists
    remove_path(target_config_path)

    # Create a symbolic link from the source to the target
    os.symlink(source_config_path, target_config_path)


def symlink_bin():
    # Define the source and target directories
    source_dir = os.path.abspath(os.path.join(mylib.HOME_DIR, ".local/bin"))
    target_home = os.path.expanduser("~")
    target_dir = os.path.join(target_home, ".local/bin")

    # Ensure the target directory exists; create it if not
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    # Iterate through files in the source directory
    for filename in os.listdir(source_dir):
        source_path = os.path.join(source_dir, filename)
        target_path = os.path.join(target_dir, filename)

        # Remove existing target if it exists
        remove_path(target_path)

        # Create a symbolic link from the source to the target
        os.symlink(source_path, target_path)


def symlink_desktop_files():
    # Define the source and target directories
    source_dir = os.path.abspath(
        os.path.join(mylib.HOME_DIR, ".local/share/applications")
    )
    target_home = os.path.expanduser("~")
    target_dir = os.path.join(target_home, ".local/share/applications")

    # Ensure the target directory exists; create it if not
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    # Iterate through files in the source directory
    for filename in os.listdir(source_dir):
        source_path = os.path.join(source_dir, filename)
        target_path = os.path.join(target_dir, filename)

        # Remove existing target if it exists
        remove_path(target_path)

        # Create a symbolic link from the source to the target
        os.symlink(source_path, target_path)


def main():
    symlink_dotfiles()
    symlink_cargo_config()

    if not "nt" in os.name:
        symlink_bin()
        symlink_desktop_files()


if __name__ == "__main__":
    main()
