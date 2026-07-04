"""Harvester — assemble a queue of falsifiable "matters" for the King (SPEC §6, §7).

The harvester pulls candidate matters from two **injectable** sources:

* a :class:`NewsFetcher` — datable upcoming events from news / events calendars
  (scheduled releases, votes, meetings, deadlines), and
* a :class:`MarketQuestionClient` — prediction-market / forecasting questions,
  harvested only for their *falsifiable questions* (never traded) and carrying a
  crowd ``market_implied_prob`` for the beat-the-crowd benchmark (SPEC §7, §11).

Both are plain duck-typed objects exposing ``fetch() -> list[dict]``. The real
implementations (:class:`FeedparserNewsFetcher`, :class:`HttpxMarketQuestionClient`)
lazy-import ``feedparser`` / ``httpx`` *inside* ``fetch`` so importing this module
never needs those packages and the offline test-suite passes simple fakes instead.

Pipeline (per harvest):

    fetch raw items
      -> normalize into MatterCandidate (tolerant of varying key names)
      -> reasoning-favored DOMAIN FILTER (sports / pure-chance excluded, SPEC §7)
      -> FALSIFIABILITY GATE  (is_falsifiable: future date + objective criteria, §6)
      -> DEDUP vs existing events and within the batch
      -> persist Event(status=pending), capturing market_implied_prob

``harvest`` returns the list of newly-persisted :class:`~wkd.models.Event` rows.
Clock reads are injectable via ``now`` so tests are deterministic.
"""

from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from typing import Any, Protocol, runtime_checkable

from .models import Domain, Event, EventStatus, ModelRun, Source

# ---------------------------------------------------------------------------
# Injectable source interfaces (real impls lazy-import; never tested live)
# ---------------------------------------------------------------------------


@runtime_checkable
class NewsFetcher(Protocol):
    """Anything that returns a list of raw news/event dicts via ``fetch()``."""

    def fetch(self) -> list[dict]:  # pragma: no cover - interface only
        ...


@runtime_checkable
class MarketQuestionClient(Protocol):
    """Anything that returns a list of raw market-question dicts via ``fetch()``."""

    def fetch(self) -> list[dict]:  # pragma: no cover - interface only
        ...


# ---------------------------------------------------------------------------
# Candidate matter (pre-persistence, normalized)
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class MatterCandidate:
    """A normalized matter before it is gated, deduped, and persisted as an Event."""

    title: str
    domain: str
    description: str = ""
    resolution_date: str | None = None
    resolution_criteria: str = ""
    market_implied_prob: float | None = None
    source: str = Source.HARVESTED
    source_ref: str | None = None

    def to_event(self, *, harvested_at: str) -> Event:
        """Project this candidate onto a pending :class:`Event` row (SPEC §14)."""
        return Event(
            source=str(self.source),
            title=self.title,
            domain=str(self.domain),
            description=self.description,
            resolution_date=self.resolution_date,
            resolution_criteria=self.resolution_criteria,
            market_implied_prob=self.market_implied_prob,
            source_ref=self.source_ref,
            harvested_at=harvested_at,
            status=EventStatus.PENDING,
        )


# ---------------------------------------------------------------------------
# Domain normalization & reasoning-favored filter (SPEC §7)
# ---------------------------------------------------------------------------

# Canonical reasoning-favored domains.
_CANON: frozenset[str] = frozenset(d.value for d in Domain)

# Sports / pure-chance are excluded outright (matched as whole tokens).
EXCLUDED_DOMAIN_TOKENS: frozenset[str] = frozenset({
    # sports
    "sport", "sports", "nfl", "nba", "mlb", "nhl", "ncaa", "soccer", "football",
    "basketball", "baseball", "hockey", "tennis", "golf", "cricket", "rugby",
    "olympics", "olympic", "ufc", "mma", "boxing", "racing", "f1", "nascar",
    "esports",
    # pure chance / gambling
    "lottery", "lotto", "powerball", "megamillions", "raffle", "sweepstakes",
    "jackpot", "bingo", "casino", "roulette", "dice", "coinflip", "slots",
    "slot", "gamble", "gambling", "wager",
})

# Synonym tokens mapped onto a canonical domain. Checked most-specific-first so
# e.g. a "crypto market" question lands in crypto, not econ.
_DOMAIN_SYNONYMS: tuple[tuple[str, frozenset[str]], ...] = (
    ("crypto", frozenset({
        "crypto", "cryptocurrency", "cryptocurrencies", "bitcoin", "btc",
        "ethereum", "eth", "blockchain", "defi", "altcoin", "altcoins",
        "stablecoin", "solana", "sol", "dogecoin", "nft",
    })),
    ("econ", frozenset({
        "econ", "economy", "economic", "economics", "finance", "financial",
        "fed", "fomc", "inflation", "deflation", "gdp", "jobs", "unemployment",
        "employment", "payrolls", "rate", "rates", "interest", "monetary",
        "fiscal", "stocks", "stock", "equities", "earnings", "recession",
        "cpi", "ppi", "treasury", "bond", "bonds", "yields", "markets",
    })),
    ("politics", frozenset({
        "politics", "political", "election", "elections", "policy", "gov",
        "government", "congress", "senate", "house", "legislation", "vote",
        "votes", "ballot", "primary", "primaries", "governance", "parliament",
        "referendum", "impeachment", "cabinet", "nomination", "campaign",
    })),
    ("world-news", frozenset({
        "world", "international", "foreign", "global", "geopolitics",
        "geopolitical", "war", "conflict", "diplomacy", "nato", "sanctions",
        "border", "treaty", "ceasefire", "summit",
    })),
    ("current-events", frozenset({
        "current", "events", "event", "news", "breaking", "general",
        "headlines", "headline",
    })),
)


def _tokens(text: str) -> set[str]:
    return {t for t in re.split(r"[^a-z0-9]+", text.lower()) if t}


def normalize_domain(raw: Any) -> str | None:
    """Map a free-form domain label onto a canonical reasoning-favored domain.

    Returns the canonical string (one of :class:`~wkd.models.Domain`) or ``None``
    when the matter is excluded (sports / pure-chance) or unrecognized — those are
    dropped, keeping the experiment reasoning-favored (SPEC §7).
    """
    if raw is None:
        return None
    s = str(raw).strip().lower()
    if not s:
        return None
    if s in _CANON:
        return s
    toks = _tokens(s)
    if toks & EXCLUDED_DOMAIN_TOKENS:
        return None
    for canon, keys in _DOMAIN_SYNONYMS:
        if toks & keys:
            return canon
    return None


# ---------------------------------------------------------------------------
# Falsifiability gate (SPEC §6, §16.5)
# ---------------------------------------------------------------------------

_MIN_CRITERIA_LEN = 10
_MIN_TITLE_LEN = 12

# Hedge words that make a "no-hedge" claim ungradeable. (Deliberately omits the
# bare word "may" so the month "May" in a date phrase is not mistaken for a hedge.)
_VAGUE_TERMS: frozenset[str] = frozenset({
    "might", "maybe", "perhaps", "possibly", "unclear", "uncertain",
    "someday", "sometime", "somewhat", "arguably", "presumably",
})


def _parse_iso(value: Any) -> datetime | None:
    """Parse an ISO-8601 date/datetime (``Z`` or offset, date-only ok) to aware UTC."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    txt = str(value).strip()
    if not txt:
        return None
    if txt.endswith(("Z", "z")):
        txt = txt[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(txt)
    except ValueError:
        try:  # bare date -> midnight UTC
            dt = datetime.fromisoformat(txt + "T00:00:00+00:00")
        except ValueError:
            return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _coerce_now(now: Any) -> datetime:
    dt = _parse_iso(now)
    return dt if dt is not None else datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def is_falsifiable(candidate: MatterCandidate, *, now: Any = None) -> tuple[bool, str]:
    """Automated gate: is this matter undeniably right-or-wrong later? (SPEC §6).

    Requires a concrete ``resolution_date`` strictly in the future, objective
    ``resolution_criteria``, and a non-vague claim. Returns ``(ok, reason)`` so
    callers can log *why* a candidate was rejected. The gate applies equally to
    harvested and free-pick matters — it is the backstop that keeps a no-human
    pipeline from rotting into ungradeable mush.
    """
    now_dt = _coerce_now(now)

    rd = candidate.resolution_date
    if not rd or not str(rd).strip():
        return False, "no resolution date (matter is not datable)"
    rd_dt = _parse_iso(rd)
    if rd_dt is None:
        return False, f"unparseable resolution date: {rd!r}"
    if rd_dt <= now_dt:
        return False, "resolution date is not strictly in the future"

    criteria = (candidate.resolution_criteria or "").strip()
    if len(criteria) < _MIN_CRITERIA_LEN:
        return False, "missing or too-thin resolution criteria"

    title = (candidate.title or "").strip()
    if len(title) < _MIN_TITLE_LEN:
        return False, "claim too short to be checkable"
    if _tokens(title) & _VAGUE_TERMS:
        return False, "vague / hedged language in the claim"

    return True, "ok"


# ---------------------------------------------------------------------------
# Raw-item normalization (tolerant of varying upstream key names)
# ---------------------------------------------------------------------------


def _first(raw: dict, *keys: str) -> Any:
    """Return the first present, non-None value among ``keys`` (empty str ok)."""
    for k in keys:
        if k in raw and raw[k] is not None:
            return raw[k]
    return None


def _clean(value: Any) -> str:
    return str(value).strip() if value is not None else ""


def _coerce_prob(value: Any) -> float | None:
    """Coerce a crowd probability to a [0,1] fraction (treat >1 as a percentage)."""
    try:
        p = float(value)
    except (TypeError, ValueError):
        return None
    if p > 1.0:
        p = p / 100.0
    return max(0.0, min(1.0, p))


def _extract_prob(raw: dict) -> float | None:
    val = _first(
        raw,
        "market_implied_prob", "implied_prob", "implied_probability",
        "probability", "prob", "yes_prob", "yes_price", "mid", "last_price",
    )
    return _coerce_prob(val) if val is not None else None


def _news_to_candidate(raw: dict, *, default_domain: str) -> MatterCandidate | None:
    title = _clean(_first(raw, "title", "headline", "name"))
    if not title:
        return None
    domain = normalize_domain(_first(raw, "domain", "category") or default_domain)
    if domain is None:
        return None
    return MatterCandidate(
        title=title,
        domain=domain,
        description=_clean(_first(raw, "description", "summary", "abstract")),
        resolution_date=_first(raw, "resolution_date", "end_date", "endDate", "date", "deadline"),
        resolution_criteria=_clean(_first(raw, "resolution_criteria", "criteria", "rules")),
        market_implied_prob=None,
        source=_clean(_first(raw, "source")) or Source.HARVESTED,
        source_ref=_first(raw, "source_ref", "link", "url", "guid", "id"),
    )


def _market_to_candidate(raw: dict, *, default_domain: str) -> MatterCandidate | None:
    title = _clean(_first(raw, "title", "question", "name"))
    if not title:
        return None
    domain = normalize_domain(_first(raw, "domain", "category", "tag") or default_domain)
    if domain is None:
        return None
    description = _clean(_first(raw, "description", "summary"))
    # For market questions the rules/description ARE the resolution criteria;
    # fall back to the description so a well-specified question can pass the gate.
    criteria = _clean(_first(raw, "resolution_criteria", "criteria", "rules", "resolution")) or description
    return MatterCandidate(
        title=title,
        domain=domain,
        description=description,
        resolution_date=_first(raw, "resolution_date", "end_date", "endDate", "close_date", "closeTime", "deadline"),
        resolution_criteria=criteria,
        market_implied_prob=_extract_prob(raw),
        source=_clean(_first(raw, "source")) or Source.HARVESTED,
        source_ref=_first(raw, "source_ref", "url", "id", "slug", "ticker", "condition_id"),
    )


# ---------------------------------------------------------------------------
# Free-pick origination (SPEC §7) — the King surveys headlines and proposes
# matters of his OWN choosing, subject to the same falsifiability gate.
# ---------------------------------------------------------------------------

#: ``model_runs.component`` tag for the free-pick origination call.
COMPONENT_FREE_PICK = "free-pick"

FREE_PICK_SYSTEM = (
    "You are the Wizard King sourcing your OWN matters to decree upon. USE WEB "
    "SEARCH to find CONCRETE, upcoming, real-world events that are FALSIFIABLE — "
    "events whose outcome will become undeniably known soon. Each matter MUST "
    "resolve in the next 1-21 days, carrying a specific resolution_date (ISO-8601) "
    "and objective, checkable resolution_criteria that a neutral observer could "
    "verify from public reporting. Do NOT invent events — search for ones that are "
    "actually scheduled or imminent (releases, votes, decisions, data prints, "
    "launches, rulings, deadlines). Favor concrete developments in news, economics, "
    "technology, world affairs, politics, crypto, and culture; never pure-chance or "
    'gambling. Set "domain" to one of: politics, econ, current-events, crypto, '
    "world-news. Respond with ONLY a JSON array (no prose) of objects with keys: "
    '"title", "resolution_date", "resolution_criteria", "domain".'
)


def _free_pick_prompt(headlines: list[str], max_picks: int) -> str:
    lines = [
        f"Use web search to find up to {max_picks} concrete, upcoming, FALSIFIABLE "
        "real-world events (resolving in the next 1-21 days) and propose each as a "
        "matter to decree upon.",
        "",
    ]
    clean = [h for h in (str(h).strip() for h in headlines) if h]
    if clean:
        lines.append(
            "Recent headlines for inspiration — search for the underlying upcoming, "
            "datable events; do not merely restate these:"
        )
        lines += [f"- {h}" for h in clean[:25]]
    else:
        lines.append(
            "No headlines were supplied — search the live web yourself for imminent, "
            "datable events worth prophesying."
        )
    lines += [
        "",
        "Each matter needs a specific resolution_date (ISO-8601) within the next "
        "1-21 days and objective resolution_criteria. Return ONLY the JSON array of "
        "{title, resolution_date, resolution_criteria, domain} now.",
    ]
    return "\n".join(lines)


def _parse_free_pick_items(text: str) -> list[dict]:
    """Best-effort parse of a free-pick completion into a list of raw dicts.

    Tolerant of code fences and of either a bare JSON array or an object wrapping
    one (``{"matters": [...]}`` / ``{"picks": [...]}``). Never raises — a garbled
    completion simply yields no free-picks rather than crashing the harvest.
    """
    s = (text or "").strip()
    # Web-search replies often wrap the JSON in a ```json ... ``` block with prose
    # before it and a trailing "Sources:\n- [text](url)" list; those markdown links
    # contain brackets that break naive array extraction, so pull the FIRST fenced
    # code block's contents first when present.
    fence = re.search(r"```(?:json|JSON)?\s*\n?(.*?)```", s, re.DOTALL)
    if fence:
        s = fence.group(1).strip()
    elif s.startswith("```"):
        nl = s.find("\n")
        if nl != -1:
            s = s[nl + 1 :]
        if s.endswith("```"):
            s = s[:-3]
        s = s.strip()
    data: Any = None
    try:
        data = json.loads(s)
    except Exception:
        m = re.search(r"\[.*\]", s, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group(0))
            except Exception:
                data = None
    if isinstance(data, dict):
        for k in ("matters", "picks", "items", "results", "decrees"):
            if isinstance(data.get(k), list):
                data = data[k]
                break
        else:
            data = [data]
    if not isinstance(data, list):
        return []
    return [it for it in data if isinstance(it, dict)]


def _free_pick_to_candidate(raw: dict, *, default_domain: str) -> MatterCandidate | None:
    """Normalize a free-pick raw dict, FORCING ``source = free-pick`` (SPEC §7, §11).

    The free-pick label is set by origin, not by anything the model self-reports,
    so the harvested-vs-free-pick split (§11, §18) can never be gamed by a model
    mislabeling its own matter.
    """
    cand = _news_to_candidate(raw, default_domain=default_domain)
    if cand is None:
        return None
    return replace(cand, source=Source.FREE_PICK)


def _originate_free_picks(
    conn,
    provider,
    headlines: list[str],
    *,
    max_picks: int,
    created_at: str,
) -> list[dict]:
    """Call the injected free-pick provider, audit the run, return raw picks.

    The model call is logged to ``model_runs`` (component ``free-pick``) for the
    cost/usage audit (SPEC §16.7) just like every other model call in the system.
    """
    from . import db  # foundation layer (consumed, not edited)

    started = time.perf_counter()
    # search=True so a search-capable provider (e.g. the live claude-cli King)
    # actually WEB-SEARCHES for concrete upcoming events to auto-source matters;
    # providers without web search (MockProvider) simply ignore the flag.
    resp = provider.complete(
        FREE_PICK_SYSTEM,
        _free_pick_prompt(headlines, max_picks),
        temperature=0.7,
        want_json=True,
        search=True,
    )
    latency_ms = int((time.perf_counter() - started) * 1000)
    db.insert_model_run(
        conn,
        ModelRun(
            component=COMPONENT_FREE_PICK,
            model=resp.model,
            prompt_tokens=resp.prompt_tokens,
            completion_tokens=resp.completion_tokens,
            cost=resp.cost,
            latency_ms=latency_ms,
            created_at=created_at,
        ),
    )
    return _parse_free_pick_items(resp.text)[: max(0, max_picks)]


# ---------------------------------------------------------------------------
# Dedup
# ---------------------------------------------------------------------------


def _signature(title: str, domain: str) -> str:
    """A normalized title+domain key used to detect duplicate matters."""
    norm = re.sub(r"[^a-z0-9]+", " ", (title or "").lower()).strip()
    return f"{domain}|{norm}"


def _existing_index(conn) -> tuple[set[str], set[str]]:
    sigs: set[str] = set()
    refs: set[str] = set()
    for ev in _list_events(conn):
        sigs.add(_signature(ev.title, str(ev.domain)))
        if ev.source_ref:
            refs.add(str(ev.source_ref))
    return sigs, refs


def _list_events(conn) -> list[Event]:
    # Local import keeps wkd.db out of this module's import-time graph and makes
    # the dependency obvious; db is a foundation module (consumed, never edited).
    from . import db

    return db.list_events(conn)


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def harvest(
    conn,
    *,
    news_fetcher: NewsFetcher | None = None,
    market_client: MarketQuestionClient | None = None,
    free_pick_provider: Any = None,
    free_pick_headlines: list[str] | None = None,
    free_pick_max: int = 0,
    domains: list[str] | None = None,
    default_domain: str = Domain.CURRENT_EVENTS,
    now: Any = None,
    limit: int | None = None,
) -> list[Event]:
    """Harvest, gate, dedup, and persist new matters as pending Events (SPEC §7).

    Args:
        conn: an open SQLite connection (``wkd.db`` foundation layer).
        news_fetcher: injected datable-news source (``fetch() -> list[dict]``).
        market_client: injected market-question source (``fetch() -> list[dict]``).
        free_pick_provider: optional injected :class:`~wkd.providers.LLMProvider`.
            When supplied (and ``free_pick_max > 0``) the King surveys headlines and
            proposes up to ``free_pick_max`` matters of his OWN choosing (SPEC §7);
            they are tagged ``source=free-pick`` and pass the same gate + dedup.
        free_pick_headlines: headlines to feed the free-pick prompt. Defaults to the
            titles of this run's news candidates (the live headlines the King saw).
        free_pick_max: cap on free-pick matters proposed this run (0 disables).
        domains: allow-list of canonical domains to keep (defaults to all five).
        default_domain: domain assumed when a raw item omits one.
        now: injectable clock (ISO-8601 str or ``datetime``); drives ``harvested_at``
            and the falsifiability gate's "strictly in the future" check.
        limit: optional cap on how many new events to persist this run.

    Returns:
        The newly-persisted :class:`Event` rows (status ``pending``), in fetch order.
        Candidates that are excluded by domain, fail the gate, or duplicate an
        existing/just-seen matter are silently dropped.
    """
    from . import db  # foundation layer (consumed, not edited)

    allowed = set(domains) if domains is not None else set(_CANON)
    now_dt = _coerce_now(now)
    harvested_at = _iso(now_dt)

    seen_sigs, seen_refs = _existing_index(conn)

    # Gather normalized candidates from both injected sources, in order.
    candidates: list[MatterCandidate] = []
    news_candidates: list[MatterCandidate] = []
    if news_fetcher is not None:
        for raw in news_fetcher.fetch() or []:
            cand = _news_to_candidate(raw, default_domain=default_domain)
            if cand is not None:
                news_candidates.append(cand)
    candidates.extend(news_candidates)
    if market_client is not None:
        for raw in market_client.fetch() or []:
            cand = _market_to_candidate(raw, default_domain=default_domain)
            if cand is not None:
                candidates.append(cand)

    # Free-pick leg (SPEC §7): the King proposes his own matters from live headlines.
    if free_pick_provider is not None and free_pick_max > 0:
        headlines = (
            free_pick_headlines
            if free_pick_headlines is not None
            else [c.title for c in news_candidates]
        )
        for raw in _originate_free_picks(
            conn,
            free_pick_provider,
            headlines,
            max_picks=free_pick_max,
            created_at=harvested_at,
        ):
            cand = _free_pick_to_candidate(raw, default_domain=default_domain)
            if cand is not None:
                candidates.append(cand)

    persisted: list[Event] = []
    for cand in candidates:
        if limit is not None and len(persisted) >= limit:
            break
        if str(cand.domain) not in allowed:
            continue
        ok, _reason = is_falsifiable(cand, now=now_dt)
        if not ok:
            continue
        sig = _signature(cand.title, str(cand.domain))
        ref = str(cand.source_ref) if cand.source_ref else None
        if sig in seen_sigs or (ref is not None and ref in seen_refs):
            continue
        event = db.insert_event(conn, cand.to_event(harvested_at=harvested_at))
        persisted.append(event)
        seen_sigs.add(sig)
        if ref is not None:
            seen_refs.add(ref)

    return persisted


# ---------------------------------------------------------------------------
# Real source implementations (lazy-import; NOT exercised by the test-suite)
# ---------------------------------------------------------------------------


class FeedparserNewsFetcher:
    """Real :class:`NewsFetcher` over RSS/Atom feeds (lazy-imports ``feedparser``).

    Feeds that are events calendars can supply ``resolution_date`` /
    ``resolution_criteria`` per entry; plain headline feeds will mostly be
    dropped by the falsifiability gate (they are not yet datable) — that is by
    design. Construction touches no third-party package; ``feedparser`` is
    imported only inside :meth:`fetch`.
    """

    def __init__(
        self,
        feeds: list[str],
        *,
        default_domain: str = Domain.CURRENT_EVENTS,
        limit_per_feed: int = 25,
    ):
        self.feeds = list(feeds)
        self.default_domain = str(default_domain)
        self.limit_per_feed = limit_per_feed

    def fetch(self) -> list[dict]:
        import feedparser  # lazy import (live path only)

        out: list[dict] = []
        for url in self.feeds:
            parsed = feedparser.parse(url)
            for entry in list(getattr(parsed, "entries", []))[: self.limit_per_feed]:
                out.append({
                    "title": entry.get("title", ""),
                    "description": entry.get("summary", ""),
                    "link": entry.get("link"),
                    "guid": entry.get("id") or entry.get("guid"),
                    "date": entry.get("published") or entry.get("updated"),
                    "domain": entry.get("tags", [{}])[0].get("term") if entry.get("tags") else self.default_domain,
                })
        return out


class HttpxMarketQuestionClient:
    """Real :class:`MarketQuestionClient` over an HTTP JSON endpoint (lazy ``httpx``).

    Generic template for a Polymarket/Metaculus-style questions endpoint: it GETs
    a JSON list (or ``{"results": [...]}``) of market questions and passes the raw
    dicts straight through — :func:`_market_to_candidate` does the tolerant key
    mapping (title/question, end date, implied probability, etc.). Questions are
    harvested for their falsifiable wording only; **nothing is ever traded**
    (SPEC §2, §7). ``httpx`` is imported only inside :meth:`fetch`.
    """

    def __init__(
        self,
        endpoint: str,
        *,
        default_domain: str = Domain.CURRENT_EVENTS,
        params: dict | None = None,
        headers: dict | None = None,
        timeout: float = 10.0,
        results_key: str | None = "results",
    ):
        self.endpoint = endpoint
        self.default_domain = str(default_domain)
        self.params = params or {}
        self.headers = headers or {}
        self.timeout = timeout
        self.results_key = results_key

    def fetch(self) -> list[dict]:
        import httpx  # lazy import (live path only)

        resp = httpx.get(
            self.endpoint, params=self.params, headers=self.headers, timeout=self.timeout
        )
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, dict):
            items = data.get(self.results_key) if self.results_key else None
            items = items if isinstance(items, list) else data.get("data", [])
        else:
            items = data
        out: list[dict] = []
        for item in items or []:
            if isinstance(item, dict):
                item.setdefault("domain", self.default_domain)
                out.append(item)
        return out


__all__ = [
    "NewsFetcher",
    "MarketQuestionClient",
    "MatterCandidate",
    "normalize_domain",
    "EXCLUDED_DOMAIN_TOKENS",
    "is_falsifiable",
    "harvest",
    "FeedparserNewsFetcher",
    "HttpxMarketQuestionClient",
    "FREE_PICK_SYSTEM",
    "COMPONENT_FREE_PICK",
]
