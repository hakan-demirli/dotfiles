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

    des_dir = pathlib.Path(f"~/.config/gtasks").expanduser()
    os.makedirs(des_dir, exist_ok=True)
    gtask_cred = "credentials.json"
    src = secrets_dir / pathlib.Path(gtask_cred)
    des = pathlib.Path(f"~/.config/gtasks/{gtask_cred}").expanduser()
    remove_path(des)
    os.symlink(src, des)

    des_dir = pathlib.Path(f"~/.config/yarr").expanduser()
    src = secrets_dir / pathlib.Path("yarr")
    remove_path(des_dir)
    os.symlink(src, des_dir)

    des_dir = pathlib.Path(f"~/.config/mtd").expanduser()
    src = secrets_dir / pathlib.Path("mtd")
    remove_path(des_dir)
    os.symlink(src, des_dir)
