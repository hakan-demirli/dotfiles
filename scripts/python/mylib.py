import pathlib
import datetime
import subprocess
import os
import ctypes
import tkinter
import string
import random
import sys
import tempfile
import shutil
import importlib.util
from PIL import Image

Image.MAX_IMAGE_PIXELS = 933120000

"""
Dependencies:
    Windows:
        python -m venv venv
        pip install clipboard
        pip install Pillow
        pip install gcalcli
        pip install gtasks-md
        pip install pandoc
        # Pandoc.exe == pandoc 2.19.2
        # gtasks-md auth ./credentials.json
"""

##########
if "nt" in os.name:
    SECOND_ROOT_DIR = "D:"
    TTS_DIR = SECOND_ROOT_DIR + "/software/win/piper"
    TERMINAL = "wt"
else:
    SECOND_ROOT_DIR = "/mnt/second"
    TTS_DIR = SECOND_ROOT_DIR + "/software/lin/piper"
    TERMINAL = "kitty"

MYLIB_DIR = str(pathlib.Path(__file__).parent.absolute())
CONFIG_DIR = MYLIB_DIR + "/../../.config"
SECRETS_DIR = SECOND_ROOT_DIR + "/rep/personal_repo/secrets"
MUSIC_DIR = SECOND_ROOT_DIR + "/music"
WALLPAPERS_PC_DIR = SECOND_ROOT_DIR + "/images/art/wallpapers_pc"

APPLET_ICON_FILE = SECOND_ROOT_DIR + "/images/icons/gear_light.ico"
PLAYLIST_FILE = MUSIC_DIR + "/playlists.txt"
ICS_FILE = tempfile.gettempdir() + "/calendar_events.ics"
CALENDAR_OVERLAY_FILE = tempfile.gettempdir() + "/calendar_overlay.png"
TASKS_OVERLAY_FILE = tempfile.gettempdir() + "/tasks_overlay.png"
TASKS_FILE = tempfile.gettempdir() + "/tasks.md"
OVERLAYED_FILE = tempfile.gettempdir() + "/overlayed.png"
ANON_FONT_FILE = SECOND_ROOT_DIR + "/fonts/anonymous.ttf"

FIREFOX_CSS_URL = "https://github.com/hakan-demirli/Firefox_Custom_CSS"

# Secrets
sys.path.append(SECRETS_DIR)
try:
    from my_secrets import *
except:
    pass


#############


def runInVenv(python_script_path):
    subprocess.run([sys.executable, python_script_path])


def changeStringInPlace(old_string: str, new_string: str, file: str) -> int:
    with open(file) as f:
        s = f.read()
        if old_string not in s:
            print(f'"{old_string}" not found')
            return -1
    with open(file, "w") as f:
        s = s.replace(old_string, new_string)
        f.write(s)

    return 0


def removeAllFiles(dir: str, extensions: list) -> None:
    for ext in extensions:
        for index, path in enumerate(pathlib.Path(dir).glob(ext)):
            os.remove(path)


def setFirefoxWallpaper(wallpaper_path: str) -> None:
    chrome_folder_path = chromeFolderPath()
    css_file = chrome_folder_path + "userContent.css"
    types = [".jpg", ".png", ".jpeg"]
    removeAllFiles(chromeFolderPath(), types)  # del old wp
    new_wallpaper_path = pathlib.Path(wallpaper_path)
    shutil.copy2(wallpaper_path, chrome_folder_path)
    new_wallpaper_name = (
        chrome_folder_path + "my_wallpaper" + str(new_wallpaper_path.suffix)
    )

    shutil.move(
        chrome_folder_path + str(new_wallpaper_path.stem + new_wallpaper_path.suffix),
        new_wallpaper_name,
    )
    for type in types:
        changeStringInPlace(type, str(new_wallpaper_path.suffix), css_file)


def chromeFolderPath() -> str:
    return f"{findFirefoxProfileFolder()}/chrome/"


def checkFileModification(filename, last_mod_time):
    current_mod_time = os.path.getmtime(filename)
    return current_mod_time > last_mod_time


def getRandomFileName(extension: str, length: int = 32) -> str:
    letters = string.ascii_lowercase
    return "".join(random.choice(letters) for _ in range(length)) + extension


def overlayImages(
    background_image: str,
    overlay_image: str,
    output_image: str,
    x_offset: int,
    y_offset: int,
) -> None:
    # Open the background and overlay images
    background = Image.open(background_image)
    overlay = Image.open(overlay_image)

    # Create a copy of the background image to work with
    combined = background.copy()

    # Apply transparency to the overlay
    overlay = overlay.convert("RGBA")
    overlay_with_transparency = Image.new("RGBA", overlay.size)
    for x in range(overlay.width):
        for y in range(overlay.height):
            r, g, b, a = overlay.getpixel((x, y))
            overlay_with_transparency.putpixel(
                (x, y), (r, g, b, int(0.85 * a))
            )  # 85% transparency

    # Paste the overlay onto the background
    combined.paste(
        overlay_with_transparency, (x_offset, y_offset), overlay_with_transparency
    )

    # Save the result to the output file
    combined.save(output_image, format="PNG")

    print(f"Overlay complete. Result saved as {output_image}")


def resizeImage(input_image: str, output_image: str, width: int, height: int) -> None:
    # Open the input image
    img = Image.open(input_image)

    # Calculate the aspect ratios
    original_aspect_ratio = img.width / img.height
    target_aspect_ratio = width / height

    # Calculate scaling factor to match the biggest dimension
    if original_aspect_ratio > target_aspect_ratio:
        scaling_factor = width / img.width
    else:
        scaling_factor = height / img.height

    # Calculate scaled dimensions
    new_width = max(int(img.width * scaling_factor), width)
    new_height = max(int(img.height * scaling_factor), height)

    # Resize the image while maintaining aspect ratio
    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    # Calculate cropping dimensions
    crop_width = min(new_width, width)
    crop_height = min(new_height, height)
    left = (new_width - crop_width) // 2
    top = (new_height - crop_height) // 2
    right = left + crop_width
    bottom = top + crop_height

    # Crop the image
    img = img.crop((left, top, right, bottom))

    # Save the final image
    img.save(output_image)


def getMonitorResolution() -> tuple[int, int]:
    """
    Get the monitor's screen width and height in pixels.
    """
    root = tkinter.Tk()
    screen_width = root.winfo_screenwidth()
    screen_height = root.winfo_screenheight()
    root.destroy()
    return screen_width, screen_height


def daysSinceEpoch():
    return (datetime.datetime.now() - datetime.datetime(1970, 1, 1)).days


def findFirefoxProfileFolder():
    # Search for profiles.ini in all locations
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


def getDesktopEnvironment() -> str:
    """
    Get the current desktop environment.

    Returns:
        str: The name of the current desktop environment (lowercase).
    """
    command = "echo $XDG_CURRENT_DESKTOP"
    try:
        output = subprocess.check_output(command, shell=True, text=True).strip()
        if os.name == "nt":
            return "windows".lower()
        else:
            return output.lower()
    except subprocess.CalledProcessError as e:
        print("Error:", e)
        return "unknown"


def timeToIndex(range: int) -> int:
    """
    Calculate an index based on the current time and a given range.

    Args:
        range (int): The range value used to calculate the index.

    Returns:
        int: The calculated index.
    """
    idx = daysSinceEpoch() % range
    return idx


def getFilesByType(dir: str, types: list) -> list:
    """
    Retrieve files of specified types from the given directory.

    Args:
        dir (str): The directory path.
        types (list): List of file extensions to search for.

    Returns:
        list: List of paths to files of specified types.
    """
    directory = pathlib.Path(dir)
    paths = []

    for path in directory.glob("*"):
        if path.suffix in types:
            paths.append(str(path.absolute()))

    return paths


def changeWallpaper(file: str) -> None:
    de = getDesktopEnvironment()

    if "gnome" in de:
        # picture-uri-dark -> picture-uri for light theme
        info = subprocess.run(
            [
                "gsettings",
                "set",
                "org.gnome.desktop.background",
                "picture-uri-dark",
                str("file://" + str(file)),
            ]
        )
        return

    if ("sway" in de) or ("hyprland" in de):
        info = subprocess.run(
            [
                "swww",
                "img",
                f"{file}",
                "-t",
                "any",
                "--transition-fps",
                "144",
                "--transition-step",
                "90",
            ]
        )
        # Set the wallpaper style (0 = Fill, 1 = Fit, 2 = Stretch, 3 = Tile, 4 = Center)
        return

    if "windows" in de:
        """
        There is a weird bug in windows 11.
        If you have changed wallpapers individually even for once
        this can only change the wp of the current workspace
        but if you go to Settings->Personalization->Background->Picture->RightClick
        -> Set for All workspaces. Then it will start to work for all workspaces.
        """
        ctypes.windll.user32.SystemParametersInfoW(20, 0, file, 3)

        # Alternative to set for all workspaces.
        # Change for all workspaces: https://github.com/MScholtes/VirtualDesktop
        # info = subprocess.run(["./dep/VirtualDesktop11.exe", '/AllWallpapers:"{file}"'])
