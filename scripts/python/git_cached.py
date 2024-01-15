#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
from urllib.parse import urlparse

GIT = "git"


def create_cache_dir():
    xdg_cache_dir = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
    cache_dir = os.path.join(xdg_cache_dir, "git_cache")
    os.makedirs(cache_dir, exist_ok=True)
    return cache_dir


def gitc_clone(url):
    cache_dir = create_cache_dir()

    parsed_url = urlparse(url)
    path_parts = parsed_url.path.strip("/").split("/")
    if len(path_parts) < 2:
        print(f"Cant handle URL: {url}")
        print("Deferring to original git.")
        git(url)
        return

    website_dir = os.path.join(cache_dir, parsed_url.netloc)
    os.makedirs(website_dir, exist_ok=True)

    user_dir = os.path.join(website_dir, path_parts[-2])
    os.makedirs(user_dir, exist_ok=True)

    repo_dir = os.path.join(user_dir, path_parts[-1])
    if os.path.exists(repo_dir):
        subprocess.run([GIT, "-C", repo_dir, "pull"])
    else:
        subprocess.run([GIT, "clone", url, repo_dir])

    dst_dir = os.path.join(os.getcwd(), path_parts[-1])
    if os.path.exists(dst_dir):
        print(
            f"Directory {dst_dir} already exists. Please remove it before running the script."
        )
    else:
        shutil.copytree(repo_dir, dst_dir)


def git(args):
    subprocess.run([GIT] + args)


def git_command(args):
    if args[0] == "clone" and len(args) == 2:
        gitc_clone(args[1])
    else:
        git(args)


if __name__ == "__main__":
    git_command(sys.argv[1:])
