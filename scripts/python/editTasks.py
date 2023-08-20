import subprocess
import mylib
import pathlib


if __name__ == "__main__":
    script_dir = pathlib.Path(__file__).parent.absolute()
    terminal = mylib.TERMINAL
    command = terminal + " gtasks-md edit"

    subprocess.run(command, check=True)
    mylib.runInVenv(f"{script_dir}/updateOverlay.py"),
