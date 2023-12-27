import os
import shutil
import datetime
import time


def create_directory_and_files():
    config_dir = os.path.expanduser("~/.config/mtd")
    os.makedirs(config_dir, exist_ok=True)

    mtd_file = os.path.join(config_dir, "mtd.md")
    mtdr_file = os.path.join(config_dir, "mtdr.md")

    if not os.path.exists(mtd_file):
        with open(mtd_file, "w") as f:
            pass  # Create an empty file if it doesn't exist

    if not os.path.exists(mtdr_file):
        with open(mtdr_file, "w") as f:
            pass  # Create an empty file if it doesn't exist

    return mtd_file, mtdr_file


def update_mtd_file(mtd_file, mtdr_file):
    today = datetime.date.today()
    current_day = None

    while True:
        if today != current_day:
            current_day = today

            # Read contents of mtdr.md
            with open(mtdr_file, "r") as mtdr:
                mtdr_contents = mtdr.readlines()
                mtdr_contents = [line for line in mtdr_contents if line.strip() != ""]

            # Read contents of mtd.md
            with open(mtd_file, "r") as mtd:
                mtd_contents = mtd.readlines()
                mtd_contents = [
                    line for line in mtd_contents if not line.startswith("[ ]")
                ]

            # Prepend mtdr.md contents to mtd.md
            mtd_contents = mtdr_contents + mtd_contents

            # Write updated contents back to mtd.md
            with open(mtd_file, "w") as mtd:
                mtd.writelines(mtd_contents)

        # Sleep for a short duration and then check again
        time.sleep(600)  # Sleep for 60 seconds (1 minute)


if __name__ == "__main__":
    mtd_file, mtdr_file = create_directory_and_files()
    update_mtd_file(mtd_file, mtdr_file)
