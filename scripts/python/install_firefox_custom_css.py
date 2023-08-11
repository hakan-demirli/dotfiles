#!/usr/bin/env python3

import os
import subprocess
import mylib

REPO_URL = "https://github.com/hakan-demirli/Firefox_Custom_CSS"


def cloneRepoToChromeFolder():
    profile_folder = mylib.findFirefoxPorfileFolder()
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
