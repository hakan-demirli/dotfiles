#!/usr/bin/env python3

import os
import subprocess
import shutil
import pathlib
import sys

script_dir = str(pathlib.Path(__file__).parent.absolute())
sys.path.append(script_dir + "/..")
import mylib


def cloneRepoToChromeFolder():
    profile_folder = mylib.findFirefoxProfileFolder()
    if profile_folder:
        chrome_folder_path = mylib.chromeFolderPath()

        if os.path.exists(chrome_folder_path):
            shutil.rmtree(chrome_folder_path)

        os.makedirs(chrome_folder_path)

        git_command = ["git", "clone", mylib.FIREFOX_CSS_URL, chrome_folder_path]
        subprocess.run(git_command, check=True)
        print("Repository cloned successfully.")
    else:
        print("Unable to find the Firefox profile folder.")


if __name__ == "__main__":
    cloneRepoToChromeFolder()
