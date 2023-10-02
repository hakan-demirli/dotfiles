import os
import shutil
import subprocess
import re
import sys
import pathlib

script_dir = str(pathlib.Path(__file__).parent.absolute())
sys.path.append(script_dir + "/..")
import mylib


def modify_sddm_config():
    config_file_path = "/usr/lib/sddm/sddm.conf.d/default.conf"

    # Use sed to find and get the line numbers of the two lines
    try:
        # Find the line number of "# Current theme name"
        theme_line_number = int(
            subprocess.check_output(
                ["sed", "-n", "/# Current theme name/=", config_file_path]
            )
        )

        # Find the line number of "Current="
        current_line_number = int(
            subprocess.check_output(["sed", "-n", "/^Current=/=", config_file_path])
        )

        # Ensure these two lines are just above/below each other
        if abs(theme_line_number - current_line_number) != 1:
            print("The lines are not adjacent.")
            return

        # Use sed to modify the "Current=" line to "Current=chili"
        subprocess.call(
            ["sed", "-i", f"{current_line_number}s/.*/Current=chili/", config_file_path]
        )

        print("Modification complete.")

    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
    except ValueError:
        print("Lines not found or not adjacent.")


def copy_sddm_themes():
    source_theme_dir = mylib.CONFIG_DIR + "/sddm"
    destination_dir = "/usr/share/sddm/themes"

    if not os.path.exists(source_theme_dir):
        print(f"Source directory {source_theme_dir} does not exist.")
        return

    if not os.path.exists(destination_dir):
        print(f"Destination directory {destination_dir} does not exist.")
        return

    for folder in os.listdir(source_theme_dir):
        source_folder = os.path.join(source_theme_dir, folder)
        if os.path.isdir(source_folder):
            destination_folder = os.path.join(destination_dir, folder)
            try:
                shutil.copytree(source_folder, destination_folder)
                print(f"Successfully copied {folder} to {destination_folder}")
            except Exception as e:
                print(f"Error copying {folder}: {str(e)}")


if __name__ == "__main__":
    copy_sddm_themes()
    modify_sddm_config()
