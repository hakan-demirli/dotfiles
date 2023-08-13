#!/usr/bin/env python3
import subprocess
from pathlib import Path
import json
from multiprocessing import Pool
import unicodedata
import mylib


def sanitizeString(in_str):
    """
    Get a valid directory name.
    Replace white spaces with underscore.
    """
    BANNED_CHARACTERS = "\\/:*?<>|`;![\\]()^#%&!@:+=},\"{'~"
    for banned_character in BANNED_CHARACTERS:
        in_str = str(in_str).replace(banned_character, "")

    in_str = "".join(
        ch for ch in in_str if ((unicodedata.category(ch)[0] != "C") or (ch == " "))
    )

    in_str = in_str.replace(" ", "_")

    return in_str


def syncFolder(playlist_tuple):
    playlist_folder = playlist_tuple[0]
    playlist_url = playlist_tuple[1]
    command = f'cd {playlist_folder} && yt-dlp --remux-video opus -f bestaudio --embed-metadata --embed-thumbnail --download-archive downloaded.txt -o "./%(playlist_index)s_%(title)s.%(ext)s" -v "{playlist_url}"'
    subprocess.run(command, shell=True)


def createPlaylistFolder(playlist_url):
    new_metadata_raw = subprocess.Popen(
        [
            "yt-dlp",
            "--flat-playlist",
            "-J",
            playlist_url,
        ],
        stdout=subprocess.PIPE,
    )
    data, err = new_metadata_raw.communicate()
    new_metadata = json.loads(data.decode("utf-8"))
    if new_metadata == None:
        print(
            f"ERROR: Can't access playlist. Be sure it is a public or unlisted playlist.URL: {playlist_url}"
        )
        raise SystemExit()

    folder_path = mylib.MUSIC_DIR + "/" + sanitizeString(new_metadata["title"])
    try:
        Path(folder_path).mkdir(parents=True)
        print(f"Generated path: {folder_path}")
    except:
        print(
            "WARNING: Folder with the same name as the playlist already exists. Updating existing playlist."
        )
    return folder_path


def syncYoutubePlaylist(playlist_file):
    playlist_urls = []
    with open(playlist_file) as playlists_file:
        playlist_urls = [line.rstrip() for line in playlists_file]

    pool = Pool()
    playlist_folders = pool.map(createPlaylistFolder, playlist_urls)

    playlist_tuples = tuple(zip(playlist_folders, playlist_urls))

    pool.map(syncFolder, playlist_tuples)

    print("[COMPLETED]")


if __name__ == "__main__":
    syncYoutubePlaylist(mylib.PLAYLIST_FILE)
