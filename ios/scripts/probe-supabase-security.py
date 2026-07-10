#!/usr/bin/env python3
"""Read-only Supabase launch security probe for Prismet.

This script uses the shipped anon client key because that is the credential any
App Store user can extract. It never prints keys, bearer tokens, or raw table
rows; it reports only endpoint status and redacted shape information.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
SECRETS_SWIFT = ROOT / "Sources" / "Backend" / "Secrets.swift"
READ_ONLY_SUPABASE_PROBE = "READ_ONLY_SUPABASE_PROBE"

JWT_RE = re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")
UUID_RE = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")


def redact(value: Any) -> str:
    text = value if isinstance(value, str) else json.dumps(value, sort_keys=True)
    text = JWT_RE.sub("[REDACTED_JWT]", text)
    text = UUID_RE.sub("[REDACTED_UUID]", text)
    return text[:260]


def read_swift_secret(name: str) -> str:
    contents = SECRETS_SWIFT.read_text(encoding="utf-8")
    match = re.search(rf"static\s+let\s+{re.escape(name)}\s*=\s*\"([^\"]+)\"", contents)
    if not match:
        raise RuntimeError(f"Could not find Secrets.{name}")
    return match.group(1)


def auth_headers(anon_key: str) -> dict[str, str]:
    return {
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}",
        "Accept": "application/json",
    }


def request_json(url: str, headers: dict[str, str] | None = None, timeout: float = 12.0) -> tuple[int, str, Any]:
    request = Request(url, headers=headers or {}, method="GET")
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read(8192)
            content_type = response.headers.get("content-type", "")
            return response.status, content_type, parse_body(body)
    except HTTPError as error:
        body = error.read(8192)
        return error.code, error.headers.get("content-type", ""), parse_body(body)
    except URLError as error:
        return 0, "network-error", {"error": str(error.reason)}


def parse_body(body: bytes) -> Any:
    if not body:
        return None
    try:
        return json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return body[:160].decode("utf-8", errors="replace")


def shape(payload: Any) -> str:
    if isinstance(payload, list):
        if not payload:
            return "list[0]"
        first = payload[0]
        if isinstance(first, dict):
            return f"list[{len(payload)}] keys={sorted(first.keys())}"
        return f"list[{len(payload)}] item={type(first).__name__}"
    if isinstance(payload, dict):
        keys = sorted(payload.keys())
        if "code" in payload or "error" in payload or "message" in payload:
            return f"dict keys={keys} sample={redact(payload)}"
        return f"dict keys={keys}"
    return redact(payload)


def probe_table(base_url: str, anon_key: str, table: str) -> tuple[str, int]:
    query = urlencode({"select": "*", "limit": "1"})
    url = f"{base_url.rstrip('/')}/rest/v1/{table}?{query}"
    status, content_type, payload = request_json(url, auth_headers(anon_key))
    print(f"{table}: status={status} content_type={content_type.split(';')[0]} shape={shape(payload)}")
    return table, status


def probe_daily_word(base_url: str) -> int:
    url = f"{base_url.rstrip('/')}/storage/v1/object/public/kaleidoscope-public/wordle/daily.json"
    status, content_type, payload = request_json(url)
    print(f"public_wordgame_daily: status={status} content_type={content_type.split(';')[0]} shape={shape(payload)}")
    return status


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Prismet's read-only Supabase security probe.")
    parser.add_argument("--json-summary", action="store_true", help="Also print a redacted machine-readable summary.")
    args = parser.parse_args()

    try:
        base_url = read_swift_secret("supabaseURL")
        anon_key = read_swift_secret("supabaseAnonKey")
    except Exception as error:
        print(f"{READ_ONLY_SUPABASE_PROBE}: config_error={redact(str(error))}", file=sys.stderr)
        return 2

    print(f"{READ_ONLY_SUPABASE_PROBE}: project={redact(base_url)} credential=anon")
    statuses: dict[str, int] = {}
    for table in ("profiles", "game_saves", "multiplayer_matches", "leaderboard_scores", "api_rate_limits"):
        name, status = probe_table(base_url, anon_key, table)
        statuses[name] = status
    statuses["public_wordgame_daily"] = probe_daily_word(base_url)

    if args.json_summary:
        print(json.dumps({"probe": READ_ONLY_SUPABASE_PROBE, "statuses": statuses}, sort_keys=True))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
