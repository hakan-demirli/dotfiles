from dep.traymenu import TrayMenu, quitsystray
import mylib
import subprocess
import pathlib


if __name__ == "__main__":
    script_dir = pathlib.Path(__file__).parent.absolute()

    tm = TrayMenu(
        icon=mylib.APPLET_ICON_FILE,
        functions=(
            (
                "🎵 youtubeSync",
                lambda: subprocess.run(["python", f"{script_dir}/youtubeSync.py"]),
            ),
            (
                "🗓️ updateOverlay",
                lambda: subprocess.run(["python", f"{script_dir}/updateOverlay.py"]),
            ),
            (
                "📝 editTasks",
                lambda: subprocess.run(["python", f"{script_dir}/editTasks.py"]),
            ),
            "--",  # Separator
            (
                "🗣️ clipboardTTS",
                lambda: subprocess.run(["python", f"{script_dir}/clipboardTTS.py"]),
            ),
            ("Quit", lambda: quitsystray()),
        ),
    )

    tm.letsgo()
