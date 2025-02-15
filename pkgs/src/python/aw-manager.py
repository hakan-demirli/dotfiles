#!/usr/bin/env python3

import argparse
import requests
import json

BASE_URL_SETTINGS = "http://localhost:5600/api/0/settings"
BASE_URL_BUCKETS = "http://localhost:5600/api/0"


def get_all_settings(output_file):
    """Fetch all settings from the server and save them to a file."""
    response = requests.get(BASE_URL_SETTINGS)
    if response.status_code == 200:
        settings = response.json()
        with open(output_file, "w") as f:
            json.dump(settings, f, indent=4)
        print(f"Settings saved to {output_file}")
    else:
        print("Failed to fetch settings:", response.text)


def set_settings(input_file):
    """Set settings from a JSON file."""
    try:
        with open(input_file, "r") as f:
            settings = json.load(f)

        for key, value in settings.items():
            response = requests.post(f"{BASE_URL_SETTINGS}/{key}", json=value)
            if response.status_code in (200, 201):
                try:
                    updated_value = response.json()
                    print(f"Successfully updated setting '{key}' to:", updated_value)
                except requests.exceptions.JSONDecodeError:
                    print(
                        f"Successfully updated setting '{key}', but no JSON response returned."
                    )
            else:
                print(f"Failed to update setting '{key}':", response.text)
    except FileNotFoundError:
        print(f"File not found: {input_file}")
    except json.JSONDecodeError:
        print(f"Invalid JSON format in file: {input_file}")


def get_all_buckets(output_file):
    """Fetch all buckets and save to a file."""
    response = requests.get(f"{BASE_URL_BUCKETS}/export")
    if response.status_code == 200:
        buckets = response.json()
        with open(output_file, "w") as f:
            json.dump(buckets, f, indent=4)
        print(f"Buckets saved to {output_file}")
    else:
        print("Failed to fetch buckets:", response.text)


def set_buckets(input_file):
    """Set buckets from a JSON file using multipart/form-data."""
    try:
        with open(input_file, "r") as f:
            buckets = json.load(f)

        # Prepare multipart form-data
        files = {
            "buckets.json": ("buckets.json", json.dumps(buckets), "application/json")
        }
        response = requests.post(
            f"{BASE_URL_BUCKETS}/import",
            files=files,
            headers={"Host": "127.0.0.1:5600"},
        )

        if response.status_code == 200:
            print("Buckets imported successfully.")
        elif response.status_code == 500:
            print(f"Failed to import: {response.json().get('message')}")
        else:
            print("Error importing buckets:", response.text)
    except FileNotFoundError:
        print(f"File not found: {input_file}")
    except json.JSONDecodeError:
        print(f"Invalid JSON format in file: {input_file}")


def main():
    """
    API specification:
        https://github.com/ActivityWatch/aw-server-rust/blob/a0cdef90cf86cd8d2cc89723f5751c1123ae7e2b/aw-server/tests/api.rs#L272
    """
    parser = argparse.ArgumentParser(description="Manage server settings and buckets.")
    subparsers = parser.add_subparsers(
        dest="mode", help="Choose to manage settings or buckets"
    )

    # Settings Subparser
    settings_parser = subparsers.add_parser("settings", help="Manage settings")
    settings_parser.add_argument(
        "--get",
        "-g",
        metavar="OUTPUT_FILE",
        help="Fetch all settings and save them to the specified JSON file.",
    )
    settings_parser.add_argument(
        "--set",
        "-s",
        metavar="INPUT_FILE",
        help="Read settings from the specified JSON file and update them on the server.",
    )

    # Buckets Subparser
    buckets_parser = subparsers.add_parser("buckets", help="Manage buckets")
    buckets_parser.add_argument(
        "--get",
        "-g",
        metavar="OUTPUT_FILE",
        help="Fetch all buckets and save them to the specified JSON file.",
    )
    buckets_parser.add_argument(
        "--set",
        "-s",
        metavar="INPUT_FILE",
        help="Read buckets from the specified JSON file and update them on the server.",
    )

    args = parser.parse_args()

    if args.mode == "settings":
        if args.get:
            get_all_settings(args.get)
        if args.set:
            set_settings(args.set)

    elif args.mode == "buckets":
        if args.get:
            get_all_buckets(args.get)
        if args.set:
            set_buckets(args.set)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
