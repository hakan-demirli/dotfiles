"""Compare a generated stylesheet against the application's own stylesheet.

An application's stylesheet documents every element it can render, so it is the
authoritative list of what a theme has to cover. Rules carrying no declarations
are documentation placeholders and are not required.

Usage: coverage.py UPSTREAM_CSS THEME_CSS
"""

import re
import sys


def rules(path: str) -> dict[str, str]:
    with open(path) as handle:
        source = handle.read()

    text = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    text = re.sub(r"@[a-zA-Z-]+[^;{}]*;", "", text)

    found: dict[str, str] = {}
    for match in re.finditer(r"([^{}]+)\{([^{}]*)\}", text):
        selector = match.group(1).strip()
        if not selector or selector.startswith("@"):
            continue
        for part in selector.split(","):
            part = part.strip()
            if part:
                found[part] = found.get(part, "") + match.group(2).strip()
    return found


def leaf(selector: str) -> str:
    parts = selector.replace(">", " ").split()
    return parts[-1] if parts else selector


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: coverage.py UPSTREAM_CSS THEME_CSS", file=sys.stderr)
        return 2

    upstream, theme = rules(argv[1]), rules(argv[2])

    required = {leaf(s) for s, body in upstream.items() if body}
    required.discard(":root")
    covered = {leaf(s) for s in theme}

    missing = sorted(required - covered)
    if missing:
        print(
            "theme-coverage: the application renders these but the theme never "
            "styles them:",
            file=sys.stderr,
        )
        for name in missing:
            print(f"  {name}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
