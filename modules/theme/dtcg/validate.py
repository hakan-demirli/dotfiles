import json
import sys
from pathlib import Path

from jsonschema import Draft7Validator
from jsonschema.exceptions import best_match
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT7

ROOT_SCHEMA = "https://www.designtokens.org/schemas/2025.10/format.json"


def registry(schema_dir: Path) -> Registry:
    resources = []
    for path in sorted(schema_dir.rglob("*.json")):
        contents = json.loads(path.read_text())
        identifier = contents.get("$id")
        if identifier is None:
            print(f"validate: {path} declares no $id", file=sys.stderr)
            raise SystemExit(1)
        resources.append(
            (identifier, Resource.from_contents(contents, default_specification=DRAFT7))
        )
    return Registry().with_resources(resources)


def location(error) -> str:
    return "/".join(str(part) for part in error.absolute_path) or "<root>"


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: validate.py SCHEMA_DIR TOKENS_FILE...", file=sys.stderr)
        return 2

    schema_dir = Path(argv[1])
    store = registry(schema_dir)
    validator = Draft7Validator(
        store.contents(ROOT_SCHEMA),
        registry=store,
    )

    failed = False
    for name in argv[2:]:
        path = Path(name)
        document = json.loads(path.read_text())

        errors = sorted(validator.iter_errors(document), key=location)
        if not errors:
            continue

        failed = True
        print(f"validate: {path} does not conform to DTCG 2025.10:", file=sys.stderr)
        for error in errors:
            detail = best_match([error]) or error
            print(f"  {location(error)}: {detail.message}", file=sys.stderr)

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
