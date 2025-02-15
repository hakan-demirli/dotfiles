import mylib
import os
import argparse


def findVscodeSettingsJson():
    app_data = (
        os.getenv("APPDATA") if os.name == "nt" else os.path.expanduser("~/.config")
    )
    settings_json_files = []

    for root, dirs, files in os.walk(os.path.join(app_data, "Code", "User")):
        if "settings.json" in files:
            settings_json_files.append(os.path.join(root, "settings.json"))

    return settings_json_files[0]


def toggleVscodeCursor(from_style, to_style):
    search_string = f'"editor.cursorStyle": "{from_style}",'
    replacement_string = f'"editor.cursorStyle": "{to_style}",'

    settings_path = findVscodeSettingsJson()
    print(settings_path)
    status = mylib.changeStringInPlace(search_string, replacement_string, settings_path)
    if status == 0:
        return
    else:
        _ = mylib.changeStringInPlace(replacement_string, search_string, settings_path)
        return


def setVscodeCursor(from_style, to_style):
    search_string = f'"editor.cursorStyle": "{from_style}",'
    replacement_string = f'"editor.cursorStyle": "{to_style}",'

    settings_path = findVscodeSettingsJson()
    print(settings_path)
    _ = mylib.changeStringInPlace(search_string, replacement_string, settings_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Set cursor style in VSCode settings.")
    parser.add_argument(
        "--style", default="block", help="cursor style (default: 'line')"
    )

    args = parser.parse_args()

    setVscodeCursor("line", args.style)
    setVscodeCursor("block", args.style)
