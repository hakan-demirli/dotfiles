"""Verify every configured Waybar module has a style rule.

Waybar's shipped stylesheet is a sample rather than a catalogue of widgets, so
the authoritative list of what must be styled is the set of modules named in
the configuration.

Usage: waybar-coverage.py WAYBAR_CONFIG WAYBAR_CSS
"""

import json
import re
import sys


def load_config(path: str) -> dict:
    with open(path) as handle:
        text = handle.read()

    # Waybar accepts comments and trailing commas; strict JSON does not.
    text = re.sub(r"//.*$", "", text, flags=re.M)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def modules(config: dict) -> list[str]:
    found: list[str] = []
    for key in ("modules-left", "modules-center", "modules-right"):
        found += config.get(key, [])
    for key, value in config.items():
        if key.startswith("group/") and isinstance(value, dict):
            found += value.get("modules", [])
    return found


def selector(module: str) -> str:
    base, _, suffix = module.partition("#")
    if base.startswith("custom/"):
        core = "#custom-" + base[len("custom/") :]
    elif "/" in base:
        core = "#" + base.split("/")[-1]
    else:
        core = "#" + base
    return core + ("." + suffix if suffix else "")


def selectors(path: str) -> set[str]:
    with open(path) as handle:
        text = handle.read()

    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"@[a-zA-Z-]+[^;{}]*;", "", text)

    found: set[str] = set()
    for match in re.finditer(r"([^{}]+)\{", text):
        head = match.group(1).strip()
        if not head or head.startswith("@"):
            continue
        for part in head.split(","):
            part = part.strip()
            if part:
                found.add(part)
    return found


def covered(target: str, styled: set[str]) -> bool:
    core = target.split(".")[0]
    for rule in styled:
        for token in rule.replace(">", " ").split():
            if token in (target, core):
                return True
            if token.startswith(core + ":") or token.startswith(core + "."):
                return True
    return False


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    config = load_config(argv[1])
    styled = selectors(argv[2])

    wanted = {selector(m) for m in modules(config)}
    missing = sorted(s for s in wanted if not covered(s, styled))

    if missing:
        print(
            "theme-coverage: these Waybar modules are configured but unstyled:",
            file=sys.stderr,
        )
        for name in missing:
            print(f"  {name}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
