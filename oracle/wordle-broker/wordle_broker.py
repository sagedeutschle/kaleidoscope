#!/usr/bin/env python3
"""Wordgame Daily broker: archbox runtime (2026-10-01).

Publishes today's answer to the Supabase object that https://prismet.xyz/api/wordle
proxies, a few minutes after the US-Eastern midnight rollover. Runs on Spelltower
(archbox) from the systemd user timer in ./systemd/.

Legal posture, carried over from the 2026-07-09 clean-room rebuild. Do not weaken:
  1. NEVER contacts nytimes.com or any NYT infrastructure. The answer is read from
     public games/news coverage that prints it openly every day. A single day's
     answer is an uncopyrightable fact.
  2. Publishes ONLY today's word. No archive is kept or served, so the curated
     list is never reproduced as a compilation.
  3. Cross-checked: at least two independent publishers must state the same
     answer for the exact date and puzzle number, and no other answer may tie it.
  4. The payload never uses the "Wordle" trademark (sourceName stays "Daily").

Stdlib only (runs on the system python3 of both the Mac and Arch).
Exit codes: 0 published or already current, 1 no consensus / publish failed,
2 configuration error.
"""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Callable, Dict, List, Optional
from zoneinfo import ZoneInfo

EASTERN = ZoneInfo("America/New_York")
PUZZLE_EPOCH = date(2021, 6, 19)  # puzzle #0; #1846 = 2026-07-09, #1930 = 2026-10-01

PROJECT_REF = "cmufcjysgbiqhohozkrf"
OBJECT_PATH = "kaleidoscope-public/wordle/daily.json"
STORAGE_BASE = f"https://{PROJECT_REF}.supabase.co/storage/v1"
PUBLIC_URL = f"{STORAGE_BASE}/object/public/{OBJECT_PATH}"
UPLOAD_URL = f"{STORAGE_BASE}/object/{OBJECT_PATH}"
PROXY_URL = "https://prismet.xyz/api/wordle"
SOURCE_NAME = "Daily"

DEFAULT_KEY_FILE = Path.home() / ".config" / "prismet-wordle-broker" / "supabase-key"
DEFAULT_STATE_DIR = Path.home() / ".local" / "state" / "prismet-wordle-broker"
MAX_LLM_ATTEMPTS_PER_DAY = 4

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/140.0 Safari/537.36"
)
FETCH_TIMEOUT_S = 20
MAX_PAGE_BYTES = 8 * 1024 * 1024
ANSWER_RE = re.compile(r"[a-z]{5}")


class BrokerError(Exception):
    pass


def log(msg: str) -> None:
    stamp = datetime.now(EASTERN).strftime("%Y-%m-%d %H:%M:%S %Z")
    print(f"{stamp} {msg}", file=sys.stderr, flush=True)


def today_eastern(now: Optional[datetime] = None) -> date:
    return (now or datetime.now(EASTERN)).astimezone(EASTERN).date()


def puzzle_number(day: date) -> int:
    return (day - PUZZLE_EPOCH).days


def number_pattern(number: int) -> str:
    """'1930' matches '#1930' and '#1,930'."""
    return re.escape(f"{number:,}").replace(",", ",?")


def is_forbidden_host(url: str) -> bool:
    host = (urllib.parse.urlsplit(url).hostname or "").lower()
    return "nytimes" in host or host.endswith("nyt.com")


def visible_text(page: str) -> str:
    page = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", page)
    page = re.sub(r"<[^>]+>", " ", page)
    return " ".join(html.unescape(page).split())


# --- sources ----------------------------------------------------------------
# Each parser must return an answer ONLY when the page ties it to the exact
# date and/or puzzle number. A markup change must yield None, never a guess.

def parse_wordtips(page: str, day: date, number: int) -> Optional[str]:
    # Embedded page data: {date:"2026-10-01",number:1930,answer:"RITZY",...}
    pattern = (
        r'\{"?date"?\s*:\s*"' + re.escape(day.isoformat()) + r'"\s*,\s*'
        r'"?number"?\s*:\s*' + str(number) + r'\s*,\s*'
        r'"?answer"?\s*:\s*"([A-Za-z]{5})"'
    )
    m = re.search(pattern, page)
    return m.group(1).lower() if m else None


def parse_wordfinder(page: str, day: date, number: int) -> Optional[str]:
    # Embedded page data: {date:"261001",index:1930,answer:"RITZY"}
    pattern = (
        r'\{"?date"?\s*:\s*"' + day.strftime("%y%m%d") + r'"\s*,\s*'
        r'"?index"?\s*:\s*' + str(number) + r'\s*,\s*'
        r'"?answer"?\s*:\s*"([A-Za-z]{5})"'
    )
    m = re.search(pattern, page)
    return m.group(1).lower() if m else None


def parse_techradar(page: str, day: date, number: int) -> Optional[str]:
    # "Today's Wordle answer (game #1930) is… RITZY ."
    pattern = (
        r"answer \(game #" + number_pattern(number) + r"\) is\W{0,12}([A-Z]{5})(?![A-Za-z])"
    )
    m = re.search(pattern, visible_text(page))
    return m.group(1).lower() if m else None


def parse_tomsguide(page: str, day: date, number: int) -> Optional[str]:
    # "what is today's Wordle answer for game #1,930? Drumroll, please — it's RITZY."
    pattern = (
        r"answer for game #" + number_pattern(number) + r"\?.{0,80}?"
        r"\bit[’']s ([A-Z]{5})(?![A-Za-z])"
    )
    m = re.search(pattern, visible_text(page))
    return m.group(1).lower() if m else None


def parse_rockpapershotgun(page: str, day: date, number: int) -> Optional[str]:
    # Per-day URL, then "answer on October 1? ... The word is... RITZY."
    month_day = f"{day.strftime('%B')} {day.day}"
    pattern = (
        r"answer on " + re.escape(month_day) + r"\?.{0,200}?"
        r"The word is\W{0,12}([A-Z]{5})(?![A-Za-z])"
    )
    m = re.search(pattern, visible_text(page))
    return m.group(1).lower() if m else None


@dataclass(frozen=True)
class Source:
    name: str
    publisher: str  # sources sharing a publisher count as ONE independent vote
    url: Callable[[date], str]
    parse: Callable[[str, date, int], Optional[str]]


SOURCES: List[Source] = [
    Source("word.tips", "word.tips",
           lambda d: "https://word.tips/todays-wordle-answer/", parse_wordtips),
    Source("wordfinder.yourdictionary.com", "yourdictionary",
           lambda d: "https://wordfinder.yourdictionary.com/wordle/answers/", parse_wordfinder),
    Source("techradar.com", "future-plc",
           lambda d: "https://www.techradar.com/news/wordle-today", parse_techradar),
    Source("tomsguide.com", "future-plc",
           lambda d: "https://www.tomsguide.com/news/what-is-todays-wordle-answer", parse_tomsguide),
    Source("rockpapershotgun.com", "rockpapershotgun",
           lambda d: ("https://www.rockpapershotgun.com/wordle-hint-and-answer-today-"
                      + d.strftime("%d-%m-%y")),
           parse_rockpapershotgun),
]


# --- consensus ----------------------------------------------------------------

@dataclass
class Vote:
    source: str
    publisher: str
    answer: Optional[str] = None
    error: Optional[str] = None


@dataclass
class Decision:
    answer: Optional[str]
    support: Dict[str, List[str]] = field(default_factory=dict)  # answer -> publishers
    reason: str = ""


def decide(votes: List[Vote], min_publishers: int = 2) -> Decision:
    per_publisher: Dict[str, set] = {}
    for v in votes:
        if v.answer:
            per_publisher.setdefault(v.publisher, set()).add(v.answer)
    support: Dict[str, List[str]] = {}
    for publisher, answers in sorted(per_publisher.items()):
        if len(answers) == 1:  # a publisher contradicting itself abstains
            support.setdefault(next(iter(answers)), []).append(publisher)
    if not support:
        return Decision(None, support, "no source produced an answer")
    ranked = sorted(support.items(), key=lambda kv: len(kv[1]), reverse=True)
    best, backers = ranked[0]
    if len(backers) < min_publishers:
        return Decision(None, support, f"only {len(backers)} independent publisher(s) agree")
    if len(ranked) > 1 and len(ranked[1][1]) == len(backers):
        return Decision(None, support, "tie between conflicting answers")
    return Decision(best, support, "consensus")


# --- network ------------------------------------------------------------------

class NoNytRedirects(urllib.request.HTTPRedirectHandler):
    """Refuse a redirect to NYT before it is followed, not after."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if is_forbidden_host(newurl):
            raise BrokerError(f"refusing redirect to NYT infrastructure: {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


OPENER = urllib.request.build_opener(NoNytRedirects)


def http_get(url: str, headers: Optional[Dict[str, str]] = None, limit: int = MAX_PAGE_BYTES) -> str:
    if is_forbidden_host(url):
        raise BrokerError(f"refusing to contact NYT infrastructure: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **(headers or {})})
    with OPENER.open(req, timeout=FETCH_TIMEOUT_S) as resp:
        return resp.read(limit).decode("utf-8", errors="replace")


def collect_votes(day: date, fetch: Callable[[str], str] = http_get) -> List[Vote]:
    number = puzzle_number(day)
    votes = []
    for src in SOURCES:
        vote = Vote(src.name, src.publisher)
        try:
            vote.answer = src.parse(fetch(src.url(day)), day, number)
            if vote.answer is None:
                vote.error = "no answer for this date/number on page"
        except Exception as exc:  # one broken source must not sink the run
            vote.error = f"{type(exc).__name__}: {exc}"[:200]
        votes.append(vote)
    return votes


# --- optional LLM vote (Codex web search) --------------------------------------

def llm_prompt(day: date) -> str:
    human = f"{day.strftime('%B')} {day.day}, {day.year}"
    return (
        "Use web search to find the daily Wordle answer for game #"
        f"{puzzle_number(day)} ({human}, US Eastern) as printed by games/news outlets "
        "(e.g. Parade, TheGamer, Tom's Guide, Rock Paper Shotgun). Do NOT open or cite "
        "nytimes.com. Confirm the same 5-letter answer on at least two independent "
        "domains for exactly that date. Reply with ONLY one line of minified JSON: "
        '{"answer":"<5 lowercase letters>","date":"' + day.isoformat() + '",'
        '"sources":["<domain1>","<domain2>"]} '
        'or exactly {"error":"unconfirmed"} if you cannot confirm it.'
    )


def parse_llm_reply(raw: str, day: date) -> Optional[str]:
    for line in reversed(raw.strip().splitlines()):
        line = line.strip().strip("`")
        if not (line.startswith("{") and line.endswith("}")):
            continue
        try:
            payload = json.loads(line)
        except ValueError:
            continue
        if "error" in payload:
            return None
        answer = str(payload.get("answer", "")).strip().lower()
        domains = {
            re.sub(r"^www\.", "", str(s).lower().split("://")[-1].split("/")[0])
            for s in payload.get("sources") or [] if s
        }
        if (ANSWER_RE.fullmatch(answer) and payload.get("date") == day.isoformat()
                and len(domains) >= 2 and not any("nytimes" in d for d in domains)):
            return answer
        return None
    return None


def llm_vote(day: date, state_dir: Path,
             runner: Optional[Callable[[str], str]] = None) -> Vote:
    vote = Vote("codex-web-search", "llm:codex")
    counter = state_dir / f"llm-attempts-{day.isoformat()}"
    try:
        attempts = int(counter.read_text()) if counter.exists() else 0
    except ValueError:
        attempts = 0
    if attempts >= MAX_LLM_ATTEMPTS_PER_DAY:
        vote.error = "daily LLM attempt budget spent"
        return vote
    state_dir.mkdir(parents=True, exist_ok=True)
    counter.write_text(str(attempts + 1))
    try:
        raw = (runner or run_codex)(llm_prompt(day))
        vote.answer = parse_llm_reply(raw, day)
        if vote.answer is None:
            vote.error = "LLM reply unconfirmed or failed validation"
    except Exception as exc:
        vote.error = f"{type(exc).__name__}: {exc}"[:200]
    return vote


def run_codex(prompt: str) -> str:
    codex = shutil.which("codex")
    if not codex:
        raise BrokerError("codex CLI not on PATH")
    proc = subprocess.run(
        [codex, "--search", "exec", "--skip-git-repo-check", "--sandbox", "read-only",
         "--color", "never", prompt],
        capture_output=True, text=True, timeout=600, cwd=str(Path.home()),
        stdin=subprocess.DEVNULL,
    )
    if proc.returncode != 0:
        raise BrokerError(f"codex exited {proc.returncode}: {proc.stderr.strip()[-200:]}")
    return proc.stdout


# --- publish --------------------------------------------------------------------

def build_payload(answer: str, day: date) -> Dict[str, str]:
    answer = answer.strip().lower()
    if not ANSWER_RE.fullmatch(answer):
        raise BrokerError(f"refusing to publish malformed answer {answer!r}")
    return {"answer": answer, "date": day.isoformat(), "sourceName": SOURCE_NAME}


def fresh_url(url: str) -> str:
    # Supabase's CDN keeps serving the old object for ~1 minute after an upload;
    # a unique query string reads through to origin.
    return f"{url}?v={uuid.uuid4().hex}"


def read_json(url: str) -> Optional[Dict[str, str]]:
    try:
        payload = json.loads(http_get(fresh_url(url), {"Cache-Control": "no-cache"}, 64 * 1024))
        return payload if isinstance(payload, dict) else None
    except Exception:
        return None


def read_published() -> Optional[Dict[str, str]]:
    return read_json(PUBLIC_URL)


def proxy_serves(payload: Dict[str, str], attempts: int = 7, delay: float = 30.0) -> bool:
    """What the apps actually see. Allows for the CDN window before prismet.xyz catches up."""
    for i in range(attempts):
        live = read_json(PROXY_URL)
        if live and live.get("date") == payload["date"] and live.get("answer") == payload["answer"]:
            return True
        if i + 1 < attempts:
            time.sleep(delay)
    return False


def load_key(path: Path) -> str:
    if not path.exists():
        raise BrokerError(f"missing Supabase key file {path} (run deploy_archbox.sh --provision-key)")
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        raise BrokerError(f"{path} is mode {oct(mode)}; must not be group/world readable (chmod 600)")
    key = path.read_text().strip()
    if not key:
        raise BrokerError(f"{path} is empty")
    return key


def upload(payload: Dict[str, str], key: str) -> int:
    body = json.dumps(payload, separators=(",", ":")).encode()
    req = urllib.request.Request(UPLOAD_URL, data=body, method="PUT", headers={
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Cache-Control": "no-cache",
        "x-upsert": "true",
    })
    try:
        with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT_S) as resp:
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code


def check_key(path: Path) -> int:
    """Authenticated read of the bucket's metadata: proves the key works, writes nothing."""
    try:
        key = load_key(path)
    except BrokerError as exc:
        log(f"FAIL: {exc}")
        return 2
    bucket = OBJECT_PATH.split("/", 1)[0]
    req = urllib.request.Request(f"{STORAGE_BASE}/bucket/{bucket}",
                                 headers={"apikey": key, "Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT_S) as resp:
            status = resp.status
    except urllib.error.HTTPError as exc:
        status = exc.code
    log(f"key check: GET bucket/{bucket} -> {status}")
    return 0 if status == 200 else 1


# --- main -----------------------------------------------------------------------

def run(args: argparse.Namespace,
        fetch: Callable[[str], str] = http_get,
        read_current: Callable[[], Optional[Dict[str, str]]] = read_published,
        publish: Callable[[Dict[str, str], str], int] = upload,
        llm: Optional[Callable[[date, Path], Vote]] = None,
        proxy_check: Callable[[Dict[str, str]], bool] = proxy_serves) -> int:
    day = date.fromisoformat(args.date) if args.date else today_eastern()
    log(f"broker run for {day.isoformat()} (puzzle #{puzzle_number(day)})")

    current = read_current()
    if (not args.force and current and current.get("date") == day.isoformat()
            and ANSWER_RE.fullmatch(str(current.get("answer", "")))):
        log(f"already published for {day.isoformat()}; nothing to do")
        return 0

    votes = collect_votes(day, fetch)
    for v in votes:
        log(f"  vote {v.source:<32} {v.answer or '-':<6} {v.error or ''}".rstrip())
    decision = decide(votes)

    if decision.answer is None and not args.no_llm:
        log(f"no deterministic consensus ({decision.reason}); asking Codex for one more vote")
        vote = (llm or llm_vote)(day, Path(args.state_dir))
        log(f"  vote {vote.source:<32} {vote.answer or '-':<6} {vote.error or ''}".rstrip())
        votes.append(vote)
        decision = decide(votes)

    if decision.answer is None:
        log(f"FAIL: no consensus ({decision.reason}); support={decision.support}")
        return 1
    backers = decision.support[decision.answer]
    dissent = {a: p for a, p in decision.support.items() if a != decision.answer}
    log(f"consensus {decision.answer!r} from {backers}" + (f"; dissent {dissent}" if dissent else ""))

    payload = build_payload(decision.answer, day)
    if args.dry_run:
        log(f"dry run: would publish {json.dumps(payload)}")
        return 0
    if day != today_eastern() and not args.force:
        log("FAIL: refusing to publish a date other than today (US Eastern) without --force")
        return 2

    try:
        key = load_key(Path(args.key_file))
    except BrokerError as exc:
        log(f"FAIL: {exc}")
        return 2
    status = publish(payload, key)
    if status != 200:
        log(f"FAIL: storage PUT returned {status}")
        return 1

    for _ in range(3):
        after = read_current()
        if after and after.get("date") == payload["date"] and after.get("answer") == payload["answer"]:
            break
        time.sleep(args.verify_delay)
    else:
        log("FAIL: upload returned 200 but the object did not read back from origin")
        return 1
    log(f"OK: published {json.dumps(payload)}")
    if proxy_check(payload):
        log(f"OK: {PROXY_URL} serves it")
    else:  # storage is right; the proxy/CDN is the thing to look at, not the broker
        log(f"WARN: {PROXY_URL} still not serving today's word after ~3 min")
    return 0


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--dry-run", action="store_true", help="resolve consensus, publish nothing")
    p.add_argument("--force", action="store_true",
                   help="republish even if today's date is already live")
    p.add_argument("--date", help="YYYY-MM-DD (testing; publishing needs --force)")
    p.add_argument("--no-llm", action="store_true", help="never ask Codex for a fallback vote")
    p.add_argument("--check-key", action="store_true", help="verify the Supabase key, publish nothing")
    p.add_argument("--key-file", default=os.environ.get("WORDLE_BROKER_KEY_FILE", str(DEFAULT_KEY_FILE)))
    p.add_argument("--state-dir", default=os.environ.get("WORDLE_BROKER_STATE_DIR", str(DEFAULT_STATE_DIR)))
    p.add_argument("--verify-delay", type=float, default=3.0, help=argparse.SUPPRESS)
    return p.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    if args.check_key:
        return check_key(Path(args.key_file))
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
