#!/usr/bin/env python3

import glob
import os
import unicodedata
from multiprocessing import Pool
from pathlib import Path
import argparse
import yt_dlp


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
    ydl_opts = {
        "verbose": True,
        "outtmpl": f"{playlist_folder}/%(playlist_index)s_%(title)s.%(ext)s",
        "format": "bestaudio",
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "opus",
                "preferredquality": "best",
            },
            {"key": "EmbedThumbnail"},
        ],
        "download_archive": f"{playlist_folder}/downloaded.txt",
        "writethumbnail": True,
        "writedescription": True,
        "writeinfojson": True,
        "embedthumbnail": True,
        "embedmetadata": True,
        "ignoreerrors": True,
        "force_overwrites": True,
        "ignore_no_formats_error": True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([playlist_url])


def createPlaylistFolder(args):
    music_dir, playlist_url = args
    try:
        ydl_opts = {
            "flat_playlist": True,
            "dump_single_json": True,
            "skip_download": True,
            "ignore_no_formats_error": True,
            "playlistend": 1,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            new_metadata = ydl.extract_info(playlist_url, download=False)
        if new_metadata is None:
            print(
                f"ERROR: Can't access playlist. Be sure it is a public or unlisted playlist.URL: {playlist_url}"
            )
            return None

        folder_name = sanitizeString(new_metadata["title"])
        folder_path = music_dir + "/" + folder_name
        Path(folder_path).mkdir(parents=True, exist_ok=True)
        print(f"Generated path: {folder_path}")
        return folder_path
    except Exception as e:
        print(
            f"ERROR: An error occurred while processing the playlist {playlist_url}: {str(e)}"
        )
        return None


def syncYoutubePlaylist(music_dir, playlist_file):
    playlist_urls = []
    with open(playlist_file) as playlists_file:
        playlist_urls = [line.rstrip() for line in playlists_file]

    pool = Pool()
    args = [(music_dir, url) for url in playlist_urls]
    playlist_folders = pool.map(createPlaylistFolder, args)
    playlist_tuples = tuple(zip(playlist_folders, playlist_urls))

    pool.map(syncFolder, playlist_tuples)

    print("[COMPLETED]")


def clean_dir(directory):
    # Define the file types to delete
    file_types = [
        "*.jpg",
        "*.png",
        "*.webp",
        "*.json",
        "*.part",
        "*.description",
    ]
    for file_type in file_types:
        for dirpath, dirnames, filenames in os.walk(directory):
            for file in glob.glob(os.path.join(dirpath, file_type)):
                try:
                    os.remove(file)
                    print(f"Deleted {file}")
                except OSError as e:
                    print(f"Error: {file} : {e.strerror}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process some music files.")
    parser.add_argument(
        "--playlist_file",
        type=str,
        default="/mnt/second/music/playlists.txt",
        help="The playlist file.",
    )
    parser.add_argument(
        "--music_dir",
        type=str,
        default="/mnt/second/music",
        help="The music directory.",
    )

    # Parse the arguments
    args = parser.parse_args()

    syncYoutubePlaylist(args.music_dir, args.playlist_file)
    clean_dir(args.music_dir)
