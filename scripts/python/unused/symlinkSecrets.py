import os
import shutil
import sys
import pathlib

script_dir = str(pathlib.Path(__file__).parent.absolute())
sys.path.append(script_dir + "/..")
import mylib


def remove_path(fd_path):
    if os.path.exists(fd_path):
        if os.path.islink(fd_path):
            os.unlink(fd_path)
        elif os.path.isfile(fd_path):
            os.remove(fd_path)
        elif os.path.isdir(fd_path):
            shutil.rmtree(fd_path)


if __name__ == "__main__":
    secrets_dir = mylib.SECRETS_DIR
    items = [".gitconfig", ".ssh"]

    for item in items:
        src = secrets_dir / pathlib.Path(item)
        des = pathlib.Path(f"~/{item}").expanduser()
        remove_path(des)
        os.symlink(src, des)
