#!/usr/bin/env python3
import subprocess
from pathlib import Path
import json
from multiprocessing import Pool
import random
import string
import unicodedata
import os
"""
This script creates/syncs youtube playlists in a folder with the same playlist name.
    Save your playlist youtube urls in PLAYLISTS_FILE. Newline separated.
    Ensure Paths are to your liking.
    Run the script.
Ignore all `ERROR: [youtube] Video unavailable.` errors.
"""

# Paths
ROOT_PATH             = Path(os.getenv('MY_MUSIC_DIR')) #Path(__file__).parent
PLAYLISTS_FILE        = ROOT_PATH / "playlists.txt"
# Config Convention
METADATA_NAME         = ".metadata"
ID_SEPERATOR          = "_yurl_"                         # Video url ID will be added to the file names after this separator.
PLAYLIST_ID_SEPERATOR = "?list="
REMOVED_SEPARATOR     = "rem_"                          # be sure this is 4 characters long.
# File Naming
BANNED_CHARACTERS     = """\/:*?<>|`;![]()^#%&!@:+=},"{'~"""
RESERVED_NAMES        = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
CONTROL_CHARACTERS    = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x0b\x0c\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x7f"


def sanitizeString(in_str):
    """
        Get a valid directory name.
        Remove control characters. Remove banned symbols.
        Replace white spaces with underscore.
    """
    for banned_character in BANNED_CHARACTERS:
        in_str = str(in_str).replace(banned_character, "")

    in_str = "".join(ch for ch in in_str if ((unicodedata.category(ch)[0]!="C") or (ch == ' ')) )

    in_str = "".join(ch for ch in in_str if ch not in CONTROL_CHARACTERS)

    in_str = in_str.replace(" ", "_")

    for reserved_name in RESERVED_NAMES:
        if(in_str == reserved_name):
            in_str = "RESERVED_NAME"
            break

    return in_str


def downloadMusic(music_path, music_id):
    """
        Downloads the music specified by the youtube url music_id and saves it to music_path
        example:
            downloadMusic("./my_song_name", "bacQ0RJzxSxV")
    """
    music_url =  "https://www.youtube.com/watch?v=" + music_id
    process = subprocess.Popen(["yt-dlp",
                    "-o", music_path,
                    "--remux-video","opus",
                    "-f","bestaudio",
                    "--embed-thumbnail",
                    "--embed-metadata",
                    "-v", music_url], stdout=subprocess.PIPE)
    process.wait()


def createMetadata(playlist_id):
    """
        Saves the json dump of a playlist in a folder with the same name as the playlist and returns the json dump.
        example:
            createMetadata("bacQ0RJzxSxV")
    """
    playlist_url =  "https://www.youtube.com/playlist?list=" + playlist_id
    new_metadata_raw = subprocess.Popen(["yt-dlp","--flat-playlist","-J",playlist_url], stdout=subprocess.PIPE)
    data, err        = new_metadata_raw.communicate()
    new_metadata     = json.loads(data.decode('utf-8'))
    if(new_metadata == None):
            print(f"[ERROR] Can't access playlist. Be sure it is a public or unlisted playlist.URL: {playlist_url}")
            raise SystemExit()

    folder_path      = ROOT_PATH   / sanitizeString(new_metadata['title'])
    metadata_path    = folder_path / METADATA_NAME
    try:
        Path(folder_path).mkdir(parents=True)
    except:
        print("[WARNING] Folder with the same name as the playlist already exists.")

    with open(metadata_path, 'w') as outfile:
        json.dump(new_metadata, outfile, indent=4)

    return new_metadata


def findExistingMusics(playlist_title):
    """
        returns all musics as a list of music dictionaries in the playlist folder.
        If a filename contains ID_SEPERATOR it is a music
    """
    folder_path = ROOT_PATH / sanitizeString(playlist_title)
    musics = []

    for idx, file in enumerate(folder_path.iterdir()):
        music = {}
        if ((not file.is_dir()) and (ID_SEPERATOR in file.stem)):
            music["path"] = file
            musics.append(music)

    for music in musics:
        music["name"]      = music["path"].stem
        music["extension"] = music["path"].suffix
        music["title"]     = music["name"].split(ID_SEPERATOR)[0][4:] # delete first 4 characters (index,separator, e.g. "012_", "rem_")
        music["id"]        = music["name"].split(ID_SEPERATOR)[1]

    return musics


def syncFolder(folder_name):
    """
        Download a playlist in order. Add REMOVED_SEPARATOR to the beginning of the removed musics (from playlist).
        Assumes .metadata exist in the folder.
    """
    folder_path = ROOT_PATH / sanitizeString(folder_name)
    metadata_path = folder_path / METADATA_NAME
    metadata = {}
    with open(metadata_path) as metadata_file:
        metadata = json.load(metadata_file)
    musics = findExistingMusics(folder_name)

    # Download new musics
    new_index = 0
    for entry in metadata['entries']:
        if(entry['title'] == "[Private video]" or entry['title'] == "[Deleted video]"):
            continue

        exists = False
        music_path = ""
        for music in musics:
            if(entry['id'] == music["id"]):
                exists = True
                music_path = folder_path / (music["name"] + music['extension'])
                break

        if(not exists):
            random_name = '.'+''.join(random.choice(string.ascii_uppercase) for _ in range(15)) + ".opus" # just in case if we need more threads. Temp files shouold be unique.
            music_path = folder_path / random_name
            downloadMusic(music_path,entry['id'])

        music_title =  sanitizeString(entry['title'])
        new_music_path = folder_path / str(f"{new_index:03}_" + music_title + ID_SEPERATOR + entry['id'] + ".opus")
        if music_path.is_file():
            music_path.rename(new_music_path)
        else:
            print("[WARNING] Can't file downloaded/existing music.")

        new_index = new_index + 1

    # Rename deleted musics (from online playlist)
    for music in musics:
        exists = False
        for entry in metadata['entries']:
            if(entry['title'] == "[Private video]" or entry['title'] == "[Deleted video]"):
                continue
            if(entry['id'] == music["id"]):
                exists = True
                break
        if(not exists):
            music_path = folder_path / (music["name"] + music['extension'])
            new_music_path = folder_path / str(REMOVED_SEPARATOR + music["title"] + ID_SEPERATOR + music["id"] + ".opus")
            music_path.rename(new_music_path)

        new_index = new_index + 1


if __name__ == "__main__":

    playlist_urls = []
    with open(PLAYLISTS_FILE) as playlists_file:
        playlist_urls = [line.rstrip() for line in playlists_file]

    for playlist_url in playlist_urls:
        _, playlist_id = playlist_url.split(PLAYLIST_ID_SEPERATOR)
        _ = createMetadata(playlist_id)

    playlist_folder_names = []
    playlist_folder_paths = [x for x in ROOT_PATH.iterdir() if x.is_dir()]
    for folder_path in playlist_folder_paths:
        playlist_folder_names.append(str(folder_path.relative_to(ROOT_PATH).with_suffix('')).replace('\\','.'))

    pool = Pool()
    pool.map(syncFolder, playlist_folder_names) # sync folders in parallel

    print("[COMPLETED]")
