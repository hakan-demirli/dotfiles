#!/usr/bin/env python3

"""Transparent, resilient mirror cache for ``git clone``.

Cached clones keep the mirror as an alternate through checkout, then repack and
remove the alternate. Cache failures are cleaned up and retried from the remote.
"""

from __future__ import annotations

import contextlib
import fcntl
import hashlib
import logging
import os
import re
import shutil
import subprocess
import sys
import time
from urllib.parse import urlparse

GIT = "git"
DEFAULT_TTL_SECONDS = 300


def cache_root() -> str:
    xdg = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
    root = os.path.join(xdg, "git_cache")
    os.makedirs(root, exist_ok=True)
    os.makedirs(os.path.join(root, "locks"), exist_ok=True)
    return root


def setup_logger() -> None:
    log_file = os.path.join(cache_root(), "git_cache.log")
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


_SCP_RE = re.compile(r"^(?P<user>[^@/:]+@)?(?P<host>[^:/]+):(?P<path>[^/].*)$")


def normalize_url(url: str) -> tuple[str, str] | None:
    if not url:
        return None

    if (
        url.startswith("file://")
        or url.startswith("/")
        or url.startswith("./")
        or url.startswith("../")
    ):
        return None

    canonical_url = url.rstrip("/")
    if not canonical_url:
        return None

    host = None
    path = None

    m = _SCP_RE.match(canonical_url)
    if m and "://" not in canonical_url:
        host = m.group("host")
        path = m.group("path")
    else:
        parsed = urlparse(canonical_url)
        if parsed.scheme not in ("http", "https", "ssh", "git"):
            return None
        host = parsed.hostname
        path = parsed.path.lstrip("/")

    if not host or not path:
        return None

    key_path = path
    if key_path.endswith(".git"):
        key_path = key_path[:-4]
    key_path = key_path.rstrip("/")
    if not key_path or "/" not in key_path:
        return None

    host_l = host.lower()

    parts = [p for p in key_path.split("/") if p and p != "."]
    if any(p == ".." for p in parts):
        return None

    cache_key = os.path.join(host_l, *parts)
    return canonical_url, cache_key


def mirror_path(cache_key: str) -> str:
    return os.path.join(cache_root(), cache_key + ".git")


def lock_path(cache_key: str) -> str:
    h = hashlib.sha1(cache_key.encode()).hexdigest()
    return os.path.join(cache_root(), "locks", h + ".lock")


def run_git_capture(args, cwd=None) -> tuple[int, str, str]:
    p = subprocess.run([GIT, *args], cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def exec_git_passthrough(args) -> int:
    try:
        return subprocess.call([GIT, *args])
    except FileNotFoundError:
        sys.stderr.write("git_cached.py: 'git' not found on PATH\n")
        return 127


class _FileLock:
    def __init__(self, path: str):
        self.path = path
        self._fd: int | None = None

    def __enter__(self):
        self._fd = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o644)
        fcntl.flock(self._fd, fcntl.LOCK_EX)
        return self

    def __exit__(self, exc_type, exc, tb):
        try:
            fcntl.flock(self._fd, fcntl.LOCK_UN)
        finally:
            os.close(self._fd)
            self._fd = None


def _mirror_is_valid(path: str) -> bool:
    if not os.path.isdir(path):
        return False

    return os.path.isfile(os.path.join(path, "HEAD")) and os.path.isdir(
        os.path.join(path, "objects")
    )


def _mirror_age_seconds(path: str) -> float:
    candidates = [
        os.path.join(path, "FETCH_HEAD"),
        os.path.join(path, "packed-refs"),
        os.path.join(path, "HEAD"),
    ]
    newest = 0.0
    for c in candidates:
        with contextlib.suppress(OSError):
            newest = max(newest, os.path.getmtime(c))
    if newest == 0.0:
        return float("inf")
    return time.time() - newest


def _invalidate_mirror_locked(mpath: str, cache_key: str, reason: str) -> None:
    if os.path.exists(mpath):
        shutil.rmtree(mpath, ignore_errors=True)
        logging.info("invalidated mirror (%s): %s", reason, cache_key)


def invalidate_mirror(cache_key: str, reason: str) -> None:
    mpath = mirror_path(cache_key)
    try:
        with _FileLock(lock_path(cache_key)):
            _invalidate_mirror_locked(mpath, cache_key, reason)
    except OSError as error:
        logging.warning("could not invalidate mirror %s: %s", cache_key, error)


def _mirror_is_healthy(path: str) -> bool:
    if not _mirror_is_valid(path):
        return False
    rc, _, err = run_git_capture(["--git-dir", path, "fsck", "--connectivity-only"])
    if rc != 0:
        logging.warning(
            "mirror connectivity check failed for %s: %s",
            path,
            " | ".join(err.strip().splitlines()[-3:]),
        )
        return False
    return True


def ensure_mirror(url: str, cache_key: str, ttl: int) -> str | None:
    mpath = mirror_path(cache_key)
    os.makedirs(os.path.dirname(mpath), exist_ok=True)

    with _FileLock(lock_path(cache_key)):
        if _mirror_is_valid(mpath):
            age = _mirror_age_seconds(mpath)
            if age < ttl:
                if _mirror_is_healthy(mpath):
                    logging.info("mirror fresh (%.0fs) %s", age, cache_key)
                    return mpath
                _invalidate_mirror_locked(mpath, cache_key, "connectivity_failed")
            else:
                logging.info("mirror stale (%.0fs) updating %s", age, cache_key)
                rc, _, err = run_git_capture(
                    ["-C", mpath, "remote", "update", "--prune"]
                )
                if rc == 0 and _mirror_is_healthy(mpath):
                    fetch_head = os.path.join(mpath, "FETCH_HEAD")
                    with contextlib.suppress(OSError):
                        open(fetch_head, "a").close()
                        os.utime(fetch_head, None)
                    return mpath
                logging.warning(
                    "mirror update failed or produced an invalid mirror (%d) for %s: %s",
                    rc,
                    cache_key,
                    err.strip().splitlines()[-1:] or "",
                )
                _invalidate_mirror_locked(mpath, cache_key, "update_failed")

        if os.path.exists(mpath):
            logging.warning("removing invalid mirror dir %s", mpath)
            shutil.rmtree(mpath, ignore_errors=True)

        logging.info("creating mirror %s", cache_key)

        rc, _, err = run_git_capture(["clone", "--mirror", "--quiet", url, mpath])
        if rc != 0:
            logging.warning(
                "mirror creation failed (%d) for %s: %s",
                rc,
                cache_key,
                err.strip(),
            )
            shutil.rmtree(mpath, ignore_errors=True)
            return None
        if not _mirror_is_healthy(mpath):
            logging.warning("new mirror failed connectivity check: %s", cache_key)
            _invalidate_mirror_locked(mpath, cache_key, "creation_invalid")
            return None
        return mpath


_CLONE_VALUE_FLAGS = {
    "-o",
    "--origin",
    "-b",
    "--branch",
    "-u",
    "--upload-pack",
    "--reference",
    "--reference-if-able",
    "--separate-git-dir",
    "--depth",
    "--shallow-since",
    "--shallow-exclude",
    "--template",
    "--server-option",
    "--filter",
    "--bundle-uri",
    "-c",
    "--config",
    "-j",
    "--jobs",
}


def _clone_positional_indexes(clone_args) -> list[int]:
    i = 0
    positionals: list[int] = []
    while i < len(clone_args):
        a = clone_args[i]
        if a == "--":
            positionals.extend(range(i + 1, len(clone_args)))
            break
        if a.startswith("--") and "=" in a:
            i += 1
            continue
        if a in _CLONE_VALUE_FLAGS:
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        positionals.append(i)
        i += 1
    return positionals


def find_clone_url(clone_args) -> str | None:
    positionals = _clone_positional_indexes(clone_args)
    return clone_args[positionals[0]] if positionals else None


def find_clone_dest(clone_args, url: str) -> str | None:
    positionals = _clone_positional_indexes(clone_args)
    if len(positionals) >= 2:
        return clone_args[positionals[1]]

    name = url.rstrip("/").rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    if not name:
        return None
    if "--bare" in clone_args or "--mirror" in clone_args:
        name += ".git"
    return name


def replace_clone_url(clone_args, url: str) -> list[str]:
    positionals = _clone_positional_indexes(clone_args)
    normalized_args = list(clone_args)
    normalized_args[positionals[0]] = url
    return normalized_args


def _uses_custom_reference(clone_args) -> bool:
    reference_flags = {"--reference", "--reference-if-able", "--dissociate"}
    return any(
        arg in reference_flags
        or arg.startswith("--reference=")
        or arg.startswith("--reference-if-able=")
        for arg in clone_args
    )


def _replay(stdout: str, stderr: str) -> None:
    if stdout:
        sys.stdout.write(stdout)
        sys.stdout.flush()
    if stderr:
        sys.stderr.write(stderr)
        sys.stderr.flush()


def _dissociate_clone(dest: str) -> tuple[bool, str]:
    rc, git_dir, err = run_git_capture(["-C", dest, "rev-parse", "--absolute-git-dir"])
    if rc != 0:
        return False, err

    rc, _, err = run_git_capture(["-C", dest, "fsck", "--connectivity-only"])
    if rc != 0:
        return False, err

    rc, _, err = run_git_capture(["-C", dest, "repack", "-a", "-d"])
    if rc != 0:
        return False, err

    alternates = os.path.join(git_dir.strip(), "objects", "info", "alternates")
    with contextlib.suppress(FileNotFoundError):
        os.unlink(alternates)

    rc, _, err = run_git_capture(["-C", dest, "fsck", "--connectivity-only"])
    if rc != 0:
        return False, err
    return True, ""


def _try_cached_clone(cached_args, dest: str | None) -> int:
    try:
        process = subprocess.run([GIT, *cached_args], capture_output=True, text=True)
    except FileNotFoundError:
        sys.stderr.write("git_cached.py: 'git' not found on PATH\n")
        return 127

    if process.returncode != 0:
        tail = " | ".join(process.stderr.strip().splitlines()[-6:])
        logging.warning(
            "cached clone failed (rc=%d): %s", process.returncode, tail[:2000]
        )
        return process.returncode

    if dest is None:
        logging.warning("cached clone destination could not be determined")
        return 1

    healthy, err = _dissociate_clone(dest)
    if not healthy:
        logging.warning(
            "cached clone dissociation failed: %s",
            " | ".join(err.strip().splitlines()[-6:])[:2000],
        )
        return 1

    _replay(process.stdout, process.stderr)
    return 0


def _cleanup_failed_clone(dest: str | None, existed_before: bool) -> bool:
    if not dest or existed_before:
        return False
    absolute = os.path.abspath(dest)
    if not os.path.lexists(absolute):
        return True
    shutil.rmtree(absolute, ignore_errors=True)
    removed = not os.path.lexists(absolute)
    if removed:
        logging.info("removed failed clone destination: %s", absolute)
    return removed


def handle_clone(args) -> int:
    if os.environ.get("GIT_CACHE_DISABLE") == "1":
        return exec_git_passthrough(["clone", *args])

    url = find_clone_url(args)
    if not url or _uses_custom_reference(args):
        return exec_git_passthrough(["clone", *args])

    norm = normalize_url(url)
    if norm is None:
        logging.info("uncacheable url, passthrough: %s", url)
        return exec_git_passthrough(["clone", *args])

    canonical_url, cache_key = norm
    args = replace_clone_url(args, canonical_url)
    ttl = int(os.environ.get("GIT_CACHE_TTL", DEFAULT_TTL_SECONDS))
    dest = find_clone_dest(args, canonical_url)
    dest_existed_before = bool(dest) and os.path.lexists(dest)

    mpath = ensure_mirror(canonical_url, cache_key, ttl)
    if mpath is None:
        logging.info("no mirror, plain clone: %s", cache_key)
        return exec_git_passthrough(["clone", *args])

    cached_args = ["clone", "--reference-if-able", mpath, *args]
    logging.info("cached clone: %s", cache_key)
    with _FileLock(lock_path(cache_key)):
        rc = _try_cached_clone(cached_args, dest)
    if rc == 0:
        return 0

    with _FileLock(lock_path(cache_key)):
        mirror_healthy = _mirror_is_healthy(mpath)
    if not mirror_healthy:
        invalidate_mirror(cache_key, "clone_failed")
    if not _cleanup_failed_clone(dest, dest_existed_before):
        logging.warning(
            "cannot safely clean failed destination. Skipping plain retry: %s", dest
        )
        return rc

    logging.info("retrying plain clone after cache failure: %s", cache_key)
    return exec_git_passthrough(["clone", *args])


def main() -> int:
    setup_logger()
    argv = sys.argv[1:]
    if argv and argv[0] == "clone":
        return handle_clone(argv[1:])
    return exec_git_passthrough(argv)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
