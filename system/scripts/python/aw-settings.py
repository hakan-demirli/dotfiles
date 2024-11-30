#!/usr/bin/env python3

import argparse
import requests
import json

BASE_URL = "http://localhost:5600/api/0/settings"


def get_all_settings(output_file):
    """Fetch all settings from the server and save them to a file."""
    response = requests.get(BASE_URL)
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
            response = requests.post(f"{BASE_URL}/{key}", json=value)
            if response.status_code in (200, 201):
                try:
                    updated_value = response.json()  # Try to parse JSON if present
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


def main():
    parser = argparse.ArgumentParser(description="Manage server settings.")
    parser.add_argument(
        "--get-settings",
        "-g",
        metavar="OUTPUT_FILE",
        help="Fetch all settings and save them to the specified JSON file.",
    )
    parser.add_argument(
        "--set-settings",
        "-s",
        metavar="INPUT_FILE",
        help="Read settings from the specified JSON file and update them on the server.",
    )

    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        return

    if args.get_settings:
        get_all_settings(args.get_settings)

    if args.set_settings:
        set_settings(args.set_settings)


if __name__ == "__main__":
    main()
