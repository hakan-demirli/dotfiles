import os
import sys
import shutil


def add_script(path):
    if not os.path.exists(path):
        print(f"Error: Script path '{path}' does not exist.")
        return

    script_name = os.path.basename(path)

    # Add the script to the startup folder.
    startup_folder = os.path.join(
        os.path.expanduser("~"),
        "AppData",
        "Roaming",
        "Microsoft",
        "Windows",
        "Start Menu",
        "Programs",
        "Startup",
    )
    shutil.copy(path, startup_folder)

    print(f"Script '{script_name}' added to startup folder.")


def get_scripts():
    scripts = []
    startup_folder = os.path.join(
        os.path.expanduser("~"),
        "AppData",
        "Roaming",
        "Microsoft",
        "Windows",
        "Start Menu",
        "Programs",
        "Startup",
    )
    for file in os.listdir(startup_folder):
        if file.endswith(".py"):
            scripts.append(file)
    return scripts


def list_scripts():
    print(f"Active scripts:")
    for i, script in enumerate(get_scripts()):
        print(f"  {i + 1}: {script}")


def remove_script(path_or_number):
    scripts = get_scripts()
    try:
        index = int(path_or_number) - 1
    except ValueError:
        index = scripts.index(path_or_number)

    script_name = scripts[index]

    # Remove the script from the startup folder.
    startup_folder = os.path.join(
        os.path.expanduser("~"),
        "AppData",
        "Roaming",
        "Microsoft",
        "Windows",
        "Start Menu",
        "Programs",
        "Startup",
    )
    os.remove(os.path.join(startup_folder, script_name))

    print(f"Script '{script_name}' removed from startup folder.")


def main():
    command = sys.argv[1]

    if command == "add":
        path = sys.argv[2]
        add_script(path)
    elif command == "list":
        list_scripts()
    elif command == "remove":
        path_or_number = sys.argv[2]
        remove_script(path_or_number)
    else:
        print(f"Unknown command '{command}'.")


if __name__ == "__main__":
    main()
