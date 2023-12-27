import requests
import os
import tempfile
import json


def filter_ics_content(content):
    lines = content.decode("utf-8").splitlines()
    filtered_lines = [line for line in lines if not line.strip().startswith("DTSTAMP")]
    filtered_content = "\n".join(filtered_lines).encode("utf-8")
    return filtered_content


def get_file(ics_file, url):
    response = requests.get(url)

    if response.status_code == 200:
        with open(ics_file, "wb") as f:
            f.write(filter_ics_content(response.content))
        print("iCalendar file downloaded successfully.")
    else:
        print("Failed to download iCalendar file.")


def get_ics():
    config_dir = os.path.expanduser("~/.config/mylib/")
    ics_url_file = config_dir + "ics.json"
    ics_file = tempfile.gettempdir() + "/calendar_events.ics"

    with open(ics_url_file, "r") as f:
        data = json.load(f)
    ics_url = data.get("ics_url")

    get_file(ics_file, ics_url)


if __name__ == "__main__":
    get_ics()
