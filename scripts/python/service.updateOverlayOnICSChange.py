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
    last_ics_content = None
    script_dir = pathlib.Path(__file__).parent.absolute()
    while True:
        getICS(mylib.ICS_FILE, mylib.ICS_URL)

        with open(mylib.ICS_FILE, "rb") as f:
            new_ics_content = f.read()

        if last_ics_content is not None and new_ics_content != last_ics_content:
            subprocess.run(["python", f"{script_dir}/ics2overlay.py"])

        last_ics_content = new_ics_content
        time.sleep(120)


if __name__ == "__main__":
    main()
