#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit

APP_NAME = "hydrate"
LINK_NAME = ".hydrate"
REPOS_DIRNAME = "repos"
METADATA_NAME = ".hydrate-project.json"
METADATA_VERSION = 1
DEFAULT_REPO_URL = "https://github.com/hakan-demirli/hydrate"


class HydrateError(RuntimeError):
    """An expected, user-facing error."""


@dataclass(frozen=True, slots=True)
class Settings:
    root: Path


@dataclass(frozen=True, slots=True)
class RepoIdentity:
    origin: str
    host: str
    path_parts: tuple[str, ...]

    @property
    def key(self) -> str:
        return "/".join((self.host, *self.path_parts))

    def overlay_path(self, hydration_root: Path) -> Path:
        return hydration_root / REPOS_DIRNAME / self.host / Path(*self.path_parts)


@dataclass(frozen=True, slots=True)
class ProjectContext:
    root: Path
    origin: str
    identity: RepoIdentity


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def default_hydration_root() -> Path:
    if override := os.environ.get("HYDRATE_HOME"):
        return Path(override).expanduser().resolve()

    cache = os.environ.get("XDG_CACHE_HOME")
    cache_root = Path(cache).expanduser() if cache else Path.home() / ".cache"
    return (cache_root / APP_NAME).resolve()


def run_git(
    *args: str,
    cwd: Path | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    command = ["git", *args]
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            check=False,
            text=True,
            capture_output=True,
        )
    except FileNotFoundError as exc:
        raise HydrateError("git was not found in PATH") from exc

    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise HydrateError(f"command failed: {' '.join(command)}\n{detail}")

    return result


def git_stdout(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    return run_git(*args, cwd=cwd, check=check).stdout.strip()


def ensure_hydration_repo(path: Path) -> None:
    if not path.is_dir():
        raise HydrateError(
            f"hydration repository does not exist: {path}\nrun: hydrate pull"
        )

    result = run_git("rev-parse", "--is-inside-work-tree", cwd=path, check=False)
    if result.returncode != 0 or result.stdout.strip() != "true":
        raise HydrateError(f"not a Git repository: {path}")


def repo_is_dirty(path: Path) -> bool:
    return bool(git_stdout("status", "--porcelain", cwd=path))


def has_head_commit(path: Path) -> bool:
    result = run_git("rev-parse", "--verify", "HEAD", cwd=path, check=False)
    return result.returncode == 0


def has_upstream(path: Path) -> bool:
    result = run_git(
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
        cwd=path,
        check=False,
    )
    return result.returncode == 0


def normalize_origin(origin: str) -> RepoIdentity:
    raw = origin.strip()
    if not raw:
        raise HydrateError("empty Git origin URL")

    host: str
    repo_path: str

    scp_match: re.Match[str] | None = None
    if "://" not in raw and not raw.startswith(("/", "./", "../", "~")):
        scp_match = re.fullmatch(r"(?:[^@/]+@)?([^:/]+):(.+)", raw)

    if scp_match is not None:
        host = scp_match.group(1).lower()
        repo_path = scp_match.group(2)
    else:
        parsed = urlsplit(raw)
        if parsed.scheme and parsed.hostname:
            host = parsed.hostname.lower()
            if parsed.port is not None:
                host = f"{host}__{parsed.port}"
            repo_path = unquote(parsed.path).lstrip("/")
        else:
            local = str(Path(raw).expanduser().resolve())
            digest = hashlib.sha256(local.encode()).hexdigest()[:16]
            basename = Path(local).name or "repo"
            host = "_local"
            repo_path = f"{basename}-{digest}"

    repo_path = repo_path.rstrip("/")
    repo_path = repo_path.removesuffix(".git")

    parts = tuple(part for part in repo_path.split("/") if part)
    if not parts or any(part in {".", ".."} for part in parts):
        raise HydrateError(
            f"cannot derive a safe repository identity from origin: {origin!r}"
        )

    return RepoIdentity(origin=origin, host=host, path_parts=parts)


def current_project(start: Path | None = None) -> ProjectContext:
    cwd = (start or Path.cwd()).resolve()
    root = Path(git_stdout("rev-parse", "--show-toplevel", cwd=cwd)).resolve()
    origin = git_stdout("remote", "get-url", "origin", cwd=root)
    if not origin:
        raise HydrateError(f"repository has no 'origin' remote: {root}")
    return ProjectContext(root=root, origin=origin, identity=normalize_origin(origin))


def ensure_overlay(context: ProjectContext, hydration_root: Path) -> Path:
    overlay = context.identity.overlay_path(hydration_root)
    overlay.mkdir(parents=True, exist_ok=True)

    metadata = overlay / METADATA_NAME
    if not metadata.exists():
        payload: dict[str, object] = {
            "version": METADATA_VERSION,
            "identity": context.identity.key,
            "origin": context.origin,
            "created_at": now_utc(),
        }
        metadata.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    elif not metadata.is_file():
        raise HydrateError(f"metadata path is not a regular file: {metadata}")

    return overlay


def git_exclude_path(project_root: Path) -> Path:
    raw = git_stdout("rev-parse", "--git-path", "info/exclude", cwd=project_root)
    path = Path(raw)
    return path if path.is_absolute() else (project_root / path).resolve()


def ensure_ignored(project_root: Path) -> None:
    exclude = git_exclude_path(project_root)
    exclude.parent.mkdir(parents=True, exist_ok=True)

    pattern = f"/{LINK_NAME}"
    existing = exclude.read_text(encoding="utf-8") if exclude.exists() else ""
    if pattern in {line.strip() for line in existing.splitlines()}:
        return

    prefix = "" if not existing or existing.endswith("\n") else "\n"
    with exclude.open("a", encoding="utf-8") as handle:
        handle.write(f"{prefix}{pattern}\n")


def ensure_link(project_root: Path, overlay: Path) -> Path:
    link = project_root / LINK_NAME

    if link.is_symlink():
        actual = link.resolve(strict=False)
        expected = overlay.resolve()
        if actual == expected:
            return link
        raise HydrateError(
            f"{link} already points elsewhere:\n"
            f"  actual:   {actual}\n"
            f"  expected: {expected}"
        )

    if link.exists():
        raise HydrateError(f"refusing to replace existing path: {link}")

    link.symlink_to(overlay, target_is_directory=True)
    return link


def pull_repo(path: Path) -> None:
    if not has_upstream(path):
        run_git("fetch", "origin", cwd=path)
        return
    run_git("pull", "--rebase", cwd=path)


def command_attach(settings: Settings) -> int:
    ensure_hydration_repo(settings.root)
    context = current_project()

    if context.root == settings.root:
        raise HydrateError("refusing to attach the hydration repository to itself")

    overlay = ensure_overlay(context, settings.root)
    link = ensure_link(context.root, overlay)
    ensure_ignored(context.root)

    print(f"{link} -> {overlay}")
    return 0


def command_pull(settings: Settings, remote: str | None) -> int:
    root = settings.root

    if not root.exists():
        clone_remote = remote or DEFAULT_REPO_URL
        root.parent.mkdir(parents=True, exist_ok=True)
        run_git("clone", clone_remote, str(root))
        print(f"cloned {clone_remote} -> {root}")
        return 0

    ensure_hydration_repo(root)

    if remote is not None:
        configured = git_stdout("remote", "get-url", "origin", cwd=root)
        if configured != remote:
            raise HydrateError(
                "hydration repository already has a different origin:\n"
                f"  configured: {configured}\n"
                f"  requested:  {remote}"
            )

    if repo_is_dirty(root):
        raise HydrateError(
            "hydration repository has local changes; "
            "run 'hydrate push' or commit/stash them first"
        )

    pull_repo(root)
    print(f"updated {root}")
    return 0


def command_push(settings: Settings, message: str | None) -> int:
    root = settings.root
    ensure_hydration_repo(root)

    run_git("add", "-A", cwd=root)
    diff = run_git("diff", "--cached", "--quiet", cwd=root, check=False)
    if diff.returncode not in (0, 1):
        raise HydrateError(diff.stderr.strip() or "git diff --cached --quiet failed")

    if diff.returncode == 1:
        commit_message = message or f"hydrate: update {now_utc()}"
        run_git("commit", "-m", commit_message, cwd=root)
        print(f"committed: {commit_message}")
    else:
        print("nothing to commit")

    if not has_head_commit(root):
        print("nothing to push")
        return 0

    if has_upstream(root):
        run_git("pull", "--rebase", cwd=root)
        run_git("push", cwd=root)
    else:
        run_git("push", "--set-upstream", "origin", "HEAD", cwd=root)

    print("pushed")
    return 0


def link_status(link: Path, expected: Path) -> str:
    if link.is_symlink():
        actual = link.resolve(strict=False)
        return "linked" if actual == expected.resolve() else f"wrong target -> {actual}"
    if link.exists():
        return "occupied by non-symlink"
    return "not linked"


def command_info(settings: Settings) -> int:
    context = current_project()
    overlay = context.identity.overlay_path(settings.root)
    link = context.root / LINK_NAME

    if settings.root.is_dir():
        result = run_git("remote", "get-url", "origin", cwd=settings.root, check=False)
        hydrate_origin = (
            result.stdout.strip() if result.returncode == 0 else "(not a Git repo)"
        )
    else:
        hydrate_origin = "(not cloned)"

    print(f"project root:      {context.root}")
    print(f"project origin:    {context.origin}")
    print(f"identity:          {context.identity.key}")
    print(f"hydration root:    {settings.root}")
    print(f"hydration remote:  {hydrate_origin}")
    print(f"overlay path:      {overlay}")
    print(f"local link:        {link}")
    print(f"link status:       {link_status(link, overlay)}")
    print(f"overlay exists:    {'yes' if overlay.is_dir() else 'no'}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=APP_NAME,
        description="Private Git-backed per-repository overlays.",
    )
    parser.add_argument(
        "--home",
        type=Path,
        help="override hydration repo path (otherwise $HYDRATE_HOME or ~/.cache/hydrate)",
    )

    commands = parser.add_subparsers(dest="command", required=True)

    pull = commands.add_parser("pull", help="clone or update the hydration repo")
    pull.add_argument(
        "remote",
        nargs="?",
        help=f"hydration Git remote (default: {DEFAULT_REPO_URL})",
    )

    push = commands.add_parser(
        "push", help="commit, rebase, and push hydration changes"
    )
    push.add_argument("-m", "--message", help="commit message")

    commands.add_parser("info", help="show hydration info for the current repo")
    commands.add_parser(".", aliases=["attach"], help="attach the current repo")

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    root = args.home.expanduser().resolve() if args.home else default_hydration_root()
    settings = Settings(root=root)

    try:
        if args.command in {".", "attach"}:
            return command_attach(settings)
        if args.command == "pull":
            return command_pull(settings, args.remote)
        if args.command == "push":
            return command_push(settings, args.message)
        if args.command == "info":
            return command_info(settings)
        parser.error(f"unknown command: {args.command}")
    except HydrateError as exc:
        print(f"{APP_NAME}: {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
