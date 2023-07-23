#!/usr/bin/env python3

import os
import subprocess

REPO_URL = "https://github.com/hakan-demirli/Firefox_Custom_CSS"


def findFirefoxPorfileFolder():
    # Search for profiles.ini in both locations
    locations = [
        os.path.expanduser("~/.mozilla/firefox/profiles.ini"),
        os.path.expanduser("~/snap/firefox/common/.mozilla/firefox/profiles.ini"),
        os.path.expanduser("~/AppData/Roaming/Mozilla/Firefox/profiles.ini"),
    ]
    for location in locations:
        if os.path.exists(location):
            with open(location, "r") as file:
                for line in file:
                    key = "Default="
                    if line.startswith(key):
                        folder_name = line.strip().replace(key, "").strip()
                        return os.path.join(os.path.dirname(location), folder_name)

    return None


def cloneRepoToChromeFolder():
    profile_folder = findFirefoxPorfileFolder()
    if profile_folder:
        clone_folder = os.path.join(profile_folder, "chrome")
        os.makedirs(clone_folder, exist_ok=True)

        # Clone the repository using Git
        git_command = ["git", "clone", REPO_URL, clone_folder]
        subprocess.run(git_command, check=True)
        print("Repository cloned successfully.")
    else:
        print("Unable to find the Firefox profile folder.")


if __name__ == "__main__":
    cloneRepoToChromeFolder()
