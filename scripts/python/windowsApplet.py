from traymenu import TrayMenu, quitsystray


if __name__ == "__main__":
    # Adapted from: https://gist.github.com/jasonbot/5759510 (Python 2)

    tm = TrayMenu(
        icon=r"C:/Users/emre/Downloads/gear.ico",
        functions=(
            ("Men1", lambda: print(331)),
            ("Men2", False),  # not clickable
            ("!Default", lambda: print(22)),  # default [bold]
            "--",  # Separator
            ("Men3", lambda: print(str(1))),
            ("Quit", lambda: quitsystray()),
        ),
    )

    tm.letsgo()
