import pathlib
import time
import mylib
import subprocess
import requests


def filter_ics_content(content):
    lines = content.decode("utf-8").splitlines()
    filtered_lines = [line for line in lines if not line.strip().startswith("DTSTAMP")]
    filtered_content = "\n".join(filtered_lines).encode("utf-8")
    return filtered_content


def getICS(ics_file, url):
    response = requests.get(url)

    if response.status_code == 200:
        with open(ics_file, "wb") as f:
            f.write(filter_ics_content(response.content))
        print("iCalendar file downloaded successfully.")
    else:
        print("Failed to download iCalendar file.")


def main():
    script_dir = pathlib.Path(__file__).parent.absolute()
    getICS(mylib.ICS_FILE, mylib.ICS_URL)
    subprocess.run(["python", f"{script_dir}/ics2overlay.py"])
    subprocess.run(["python", f"{script_dir}/overlayImages.py"])
    mylib.changeWallpaper(mylib.OVERLAYED_FILE)
    mylib.setFirefoxWallpaper(mylib.OVERLAYED_FILE)


if __name__ == "__main__":
    main()
