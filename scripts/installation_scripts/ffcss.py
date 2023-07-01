#!/usr/bin/env python3

import os
import subprocess

REPO_URL = "https://github.com/hakan-demirli/Firefox_Custom_CSS"

def find_firefox_profile_folder():
    # Search for profiles.ini in both locations
    locations = [
        os.path.expanduser('~/.mozilla/firefox/profiles.ini'),
        os.path.expanduser('~/snap/firefox/common/.mozilla/firefox/profiles.ini')
    ]
    for location in locations:
        if os.path.exists(location):
            with open(location, 'r') as file:
                for line in file:
                    if line.startswith('Path='):
                        folder_name = line.strip()[5:]
                        return os.path.join(os.path.dirname(location), folder_name)

    return None

def clone_repo_in_firefox_profile():
    profile_folder = find_firefox_profile_folder()
    if profile_folder:
        clone_folder = os.path.join(profile_folder, 'chrome')
        os.makedirs(clone_folder, exist_ok=True)

        # Clone the repository using Git
        git_command = ['git', 'clone', REPO_URL, clone_folder]
        subprocess.run(git_command, check=True)
        print('Repository cloned successfully.')
    else:
        print('Unable to find the Firefox profile folder.')

if __name__ == '__main__':
    clone_repo_in_firefox_profile()

