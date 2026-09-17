#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_TTL = 300
DEFAULT_PROFILES = ("ehd", "etz", "work")

CLAUDE_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CODEX_USAGE_URL = "https://chatgpt.com/backend-api/codex/usage"


def cache_dir() -> Path:
    root = Path(
        os.environ.get(
            "AI_USAGE_CACHE_DIR",
            Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "ai-usage",
        )
    )
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    return root


def cache_path() -> Path:
    return cache_dir() / "usage.json"


def lock_path() -> Path:
    return cache_dir() / "refresh.lock"


def claude_root() -> Path:
    return Path(
        os.environ.get(
            "AI_USAGE_CLAUDE_ROOT",
            Path.home() / ".cache" / "claude-multi",
        )
    )


def claude_profiles() -> list[str]:
    raw = os.environ.get(
        "AI_USAGE_CLAUDE_PROFILES",
        " ".join(DEFAULT_PROFILES),
    )
    return raw.split()


def codex_auth_path() -> Path:
    if value := os.environ.get("AI_USAGE_CODEX_AUTH"):
        return Path(value)

    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    return codex_home / "auth.json"


def ttl_seconds() -> int:
    return int(os.environ.get("AI_USAGE_TTL", DEFAULT_TTL))


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def read_json(path: Path) -> dict[str, Any]:
    with path.open() as f:
        value = json.load(f)

    if not isinstance(value, dict):
        raise ValueError(f"{path} does not contain a JSON object")

    return value


def read_cache() -> dict[str, Any] | None:
    path = cache_path()

    try:
        value = read_json(path)
    except (OSError, ValueError, json.JSONDecodeError):
        return None

    if value.get("version") != 1:
        return None

    return value


def cache_is_fresh(cache: dict[str, Any]) -> bool:
    refreshed = cache.get("refreshed_at_epoch")

    if not isinstance(refreshed, int):
        return False

    age = int(time.time()) - refreshed
    return 0 <= age < ttl_seconds()


def write_cache(value: dict[str, Any]) -> None:
    directory = cache_dir()

    fd, tmp_name = tempfile.mkstemp(
        prefix=".usage.",
        suffix=".json",
        dir=directory,
    )

    tmp = Path(tmp_name)

    try:
        with os.fdopen(fd, "w") as f:
            json.dump(value, f, indent=2, sort_keys=True)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())

        os.chmod(tmp, 0o600)
        os.replace(tmp, cache_path())

    finally:
        tmp.unlink(missing_ok=True)


def http_json(
    url: str,
    *,
    headers: dict[str, str],
    timeout: float = 10,
) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            **headers,
        },
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        value = json.load(response)

    if not isinstance(value, dict):
        raise ValueError("API returned non-object JSON")

    return value


def stale(previous: dict[str, Any] | None, reason: str) -> dict[str, Any]:
    if previous is None:
        return {
            "available": False,
            "stale": True,
            "refresh_error": reason,
        }

    result = dict(previous)
    result["stale"] = True
    result["refresh_error"] = reason
    return result


def fetch_claude(
    profile: str,
    previous: dict[str, Any] | None,
) -> dict[str, Any]:
    credentials = claude_root() / profile / ".claude" / ".credentials.json"

    if not credentials.is_file():
        return {
            "available": False,
            "stale": False,
            "reason": "credentials_missing",
        }

    try:
        auth = read_json(credentials)
        token = auth["claudeAiOauth"]["accessToken"]

        if not isinstance(token, str) or not token:
            raise ValueError("invalid access token")

    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return stale(previous, "credential_parse_failed")

    try:
        raw = http_json(
            CLAUDE_USAGE_URL,
            headers={
                "Authorization": f"Bearer {token}",
                "anthropic-beta": "oauth-2025-04-20",
            },
        )

    except urllib.error.HTTPError as exc:
        reason = f"http_{exc.code}"

        if retry_after := exc.headers.get("Retry-After"):
            reason += f" retry_after={retry_after}"

        return stale(previous, reason)
    except urllib.error.URLError as exc:
        return stale(previous, f"request_failed: {exc.reason}")
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return stale(previous, f"request_failed: {exc}")

    limits = raw.get("limits") or []

    session_limit = next(
        (item for item in limits if item.get("kind") == "session"),
        {},
    )

    weekly_limit = next(
        (item for item in limits if item.get("kind") == "weekly_all"),
        {},
    )

    five_hour = raw.get("five_hour") or {}
    seven_day = raw.get("seven_day") or {}

    return {
        "available": True,
        "stale": False,
        "fetched_at": utc_now().isoformat(),
        "five_hour": {
            "used_percent": five_hour.get("utilization"),
            "resets_at": five_hour.get("resets_at"),
            "severity": session_limit.get("severity"),
        },
        "seven_day": {
            "used_percent": seven_day.get("utilization"),
            "resets_at": seven_day.get("resets_at"),
            "severity": weekly_limit.get("severity"),
        },
    }


def normalize_codex_window(
    window: dict[str, Any] | None,
) -> dict[str, Any] | None:
    if not window:
        return None

    seconds = window.get("limit_window_seconds")

    if seconds == 18_000:
        label = "5h"
    elif seconds == 604_800:
        label = "7d"
    elif isinstance(seconds, int) and seconds % 3600 == 0:
        label = f"{seconds // 3600}h"
    else:
        label = f"{seconds}s"

    return {
        "label": label,
        "used_percent": window.get("used_percent"),
        "window_seconds": seconds,
        "reset_at": window.get("reset_at"),
    }


def normalize_codex_rate_limit(
    value: dict[str, Any] | None,
) -> dict[str, Any]:
    value = value or {}

    windows = [
        normalized
        for window in (
            value.get("primary_window"),
            value.get("secondary_window"),
        )
        if (normalized := normalize_codex_window(window)) is not None
    ]

    return {
        "allowed": value.get("allowed"),
        "limit_reached": value.get("limit_reached"),
        "windows": windows,
    }


def fetch_codex(previous: dict[str, Any] | None) -> dict[str, Any]:
    credentials = codex_auth_path()

    if not credentials.is_file():
        return {
            "available": False,
            "stale": False,
            "reason": "credentials_missing",
        }

    try:
        auth = read_json(credentials)
        token = auth["tokens"]["access_token"]
        account = auth["tokens"]["account_id"]

        if not isinstance(token, str) or not isinstance(account, str):
            raise ValueError("invalid credentials")

    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return stale(previous, "credential_parse_failed")

    try:
        raw = http_json(
            CODEX_USAGE_URL,
            headers={
                "Authorization": f"Bearer {token}",
                "ChatGPT-Account-Id": account,
                "User-Agent": "codex-cli",
            },
        )

    except (
        OSError,
        ValueError,
        json.JSONDecodeError,
        urllib.error.URLError,
    ):
        return stale(previous, "request_failed")

    additional = []

    for item in raw.get("additional_rate_limits") or []:
        additional.append(
            {
                "name": item.get("limit_name"),
                "model": item.get("normal_model_slug"),
                **normalize_codex_rate_limit(item.get("rate_limit")),
            }
        )

    credits = raw.get("credits") or {}

    return {
        "available": True,
        "stale": False,
        "fetched_at": utc_now().isoformat(),
        "plan": raw.get("plan_type"),
        "default": normalize_codex_rate_limit(raw.get("rate_limit")),
        "additional": additional,
        "credits": {
            "has_credits": credits.get("has_credits", False),
            "unlimited": credits.get("unlimited", False),
            "balance": credits.get("balance"),
        },
    }


def refresh(previous: dict[str, Any] | None) -> dict[str, Any]:
    previous = previous or {}

    old_claude = previous.get("claude") or {}
    old_codex = previous.get("codex")

    claude = {
        profile: fetch_claude(profile, old_claude.get(profile))
        for profile in claude_profiles()
    }

    now = int(time.time())

    return {
        "version": 1,
        "refreshed_at": utc_now().isoformat(),
        "refreshed_at_epoch": now,
        "ttl_seconds": ttl_seconds(),
        "claude": claude,
        "codex": fetch_codex(old_codex),
    }


def get_usage(*, force_refresh: bool, no_refresh: bool) -> dict[str, Any]:
    current = read_cache()

    if no_refresh:
        if current is None:
            raise RuntimeError("no cache exists; run ai-usage --refresh first")
        return current

    if current is not None and not force_refresh and cache_is_fresh(current):
        return current

    with lock_path().open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)

        current = read_cache()

        if current is not None and not force_refresh and cache_is_fresh(current):
            return current

        updated = refresh(current)
        write_cache(updated)
        return updated


def format_percent(value: Any) -> str:
    if not isinstance(value, (int, float)):
        return "--"

    return f"{value:.0f}%"


def duration_until_epoch(value: Any) -> str:
    if not isinstance(value, (int, float)):
        return "--"

    seconds = int(value - time.time())

    if seconds <= 0:
        return "now"

    days, seconds = divmod(seconds, 86_400)
    hours, seconds = divmod(seconds, 3600)
    minutes = seconds // 60

    if days:
        return f"{days}d{hours}h"

    if hours:
        return f"{hours}h{minutes}m"

    return f"{minutes}m"


def duration_until_iso(value: Any) -> str:
    if not isinstance(value, str):
        return "--"

    try:
        target = dt.datetime.fromisoformat(value)
    except ValueError:
        return "--"

    return duration_until_epoch(target.timestamp())


def color_enabled() -> bool:
    return sys.stdout.isatty() and "NO_COLOR" not in os.environ


def colorize(text: str, code: str) -> str:
    if not color_enabled():
        return text
    return f"\033[{code}m{text}\033[0m"


def pad(text: Any, width: int, align: str = "<") -> str:
    return format(str(text), f"{align}{width}")


def usage_cell(value: Any, width: int = 8) -> str:
    text = format_percent(value)
    padded = pad(text, width, ">")

    if not isinstance(value, (int, float)):
        return padded
    if value >= 95:
        return colorize(padded, "1;31")
    if value >= 80:
        return colorize(padded, "33")
    if value >= 60:
        return colorize(padded, "35")
    return colorize(padded, "32")


def status_cell(
    *,
    available: bool,
    stale: bool,
    limited: bool = False,
    stale_reason: str | None = None,
    width: int = 10,
) -> str:
    if not available:
        return colorize(pad("LOGGED OUT", width), "90")
    if stale:
        label = "RATE LIMIT" if stale_reason == "http_429" else "STALE"
        return colorize(pad(label, width), "33")
    if limited:
        return colorize(pad("LIMIT", width), "1;31")
    return colorize(pad("OK", width), "32")


def render_human(data: dict[str, Any]) -> None:
    account_w = 10
    used_w = 8
    reset_w = 9
    status_w = 10

    print("Claude")
    print(
        "  ".join(
            [
                pad("ACCOUNT", account_w),
                pad("5H USED", used_w, ">"),
                pad("5H RESET", reset_w),
                pad("7D USED", used_w, ">"),
                pad("7D RESET", reset_w),
                pad("STATUS", status_w),
            ]
        )
    )

    for profile in claude_profiles():
        item = data["claude"].get(profile, {})
        available = bool(item.get("available"))
        is_stale = bool(item.get("stale"))

        if not available:
            print(
                "  ".join(
                    [
                        pad(profile, account_w),
                        pad("--", used_w, ">"),
                        pad("--", reset_w),
                        pad("--", used_w, ">"),
                        pad("--", reset_w),
                        status_cell(
                            available=False,
                            stale=is_stale,
                            width=status_w,
                        ),
                    ]
                )
            )
            continue

        five = item.get("five_hour") or {}
        seven = item.get("seven_day") or {}

        five_used = five.get("used_percent")
        seven_used = seven.get("used_percent")

        limited = any(
            isinstance(value, (int, float)) and value >= 100
            for value in (five_used, seven_used)
        )

        print(
            "  ".join(
                [
                    pad(profile, account_w),
                    usage_cell(five_used, used_w),
                    pad(
                        duration_until_iso(five.get("resets_at")),
                        reset_w,
                    ),
                    usage_cell(seven_used, used_w),
                    pad(
                        duration_until_iso(seven.get("resets_at")),
                        reset_w,
                    ),
                    status_cell(
                        available=True,
                        stale=is_stale,
                        limited=limited,
                        stale_reason=item.get("refresh_error"),
                        width=status_w,
                    ),
                ]
            )
        )

    print()
    print("Codex")

    limit_w = 32
    window_w = 8
    codex_used_w = 7

    print(
        "  ".join(
            [
                pad("LIMIT", limit_w),
                pad("WINDOW", window_w),
                pad("USED", codex_used_w, ">"),
                pad("RESET", reset_w),
                pad("STATUS", status_w),
            ]
        )
    )

    codex = data["codex"]

    if not codex.get("available"):
        print(
            "  ".join(
                [
                    pad("default", limit_w),
                    pad("--", window_w),
                    pad("--", codex_used_w, ">"),
                    pad("--", reset_w),
                    status_cell(
                        available=False,
                        stale=bool(codex.get("stale")),
                        width=status_w,
                    ),
                ]
            )
        )
        return

    codex_stale = bool(codex.get("stale"))

    render_codex_limit(
        "default",
        codex.get("default") or {},
        stale=codex_stale,
        limit_w=limit_w,
        window_w=window_w,
        used_w=codex_used_w,
        reset_w=reset_w,
        status_w=status_w,
    )

    for item in codex.get("additional") or []:
        name = item.get("name") or "unknown"
        model = item.get("model")

        label = f"{name} ({model})" if model and model != name else name

        render_codex_limit(
            label,
            item,
            stale=codex_stale,
            limit_w=limit_w,
            window_w=window_w,
            used_w=codex_used_w,
            reset_w=reset_w,
            status_w=status_w,
        )


def render_codex_limit(
    label: str,
    item: dict[str, Any],
    *,
    stale: bool,
    limit_w: int,
    window_w: int,
    used_w: int,
    reset_w: int,
    status_w: int,
) -> None:
    windows = item.get("windows") or []

    if not windows:
        print(
            "  ".join(
                [
                    pad(label, limit_w),
                    pad("--", window_w),
                    pad("--", used_w, ">"),
                    pad("--", reset_w),
                    status_cell(
                        available=True,
                        stale=stale,
                        width=status_w,
                    ),
                ]
            )
        )
        return

    for index, window in enumerate(windows):
        used = window.get("used_percent")
        limited = isinstance(used, (int, float)) and used >= 100

        print(
            "  ".join(
                [
                    pad(label if index == 0 else "", limit_w),
                    pad(window.get("label", "--"), window_w),
                    usage_cell(used, used_w),
                    pad(
                        duration_until_epoch(window.get("reset_at")),
                        reset_w,
                    ),
                    status_cell(
                        available=True,
                        stale=stale,
                        limited=limited,
                        width=status_w,
                    ),
                ]
            )
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="ai-usage",
        description="Show Claude Code and Codex subscription usage.",
        epilog="""
environment:
  AI_USAGE_TTL               cache lifetime in seconds (default: 300)
  AI_USAGE_CACHE_DIR         cache directory
  AI_USAGE_CLAUDE_ROOT       Claude multi-account root
  AI_USAGE_CLAUDE_PROFILES   space-separated Claude profiles
  AI_USAGE_CODEX_AUTH        path to Codex auth.json
""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    group = parser.add_mutually_exclusive_group()

    group.add_argument(
        "--refresh",
        action="store_true",
        help="ignore the cache TTL and fetch fresh usage",
    )

    group.add_argument(
        "--no-refresh",
        action="store_true",
        help="never access the network; use cached data only",
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="print normalized JSON",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        data = get_usage(
            force_refresh=args.refresh,
            no_refresh=args.no_refresh,
        )
    except RuntimeError as exc:
        print(f"ai-usage: {exc}", file=sys.stderr)
        return 1

    if args.json:
        json.dump(data, sys.stdout, indent=2, sort_keys=True)
        print()
    else:
        render_human(data)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
