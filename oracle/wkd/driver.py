"""The idempotent daily driver — orchestration (SPEC §8, §13, §16.8).

One :func:`run_daily` call performs the whole day's work, deciding internally
what is *due* from the database state and the injected wall-clock ``now`` so it
is **idempotent** and **catches up** if days were missed:

1. **Harvest** new matters from the injected sources (gated, deduped) → pending
   :class:`~wkd.models.Event` rows.
2. **Deliberate** on up to ``daily_decree_cap`` pending matters → forged
   standing decrees, or ``divided`` events (the King holds his tongue).
3. **Checkpoint** standing decrees whose event is unresolved, whose resolution
   date has *not* yet passed, and whose last checkpoint (or issuance) is older
   than ``checkpoint_interval_days`` — the council may reaffirm / amend / withdraw
   (append-only; the original decree is never silently edited).
4. **Resolve** standing decrees past their ``resolution_date`` via the Court
   Historian (search-grounded, cited, corroborated; may abstain).
5. **Score** — recompute and persist a :class:`~wkd.models.MetricsSnapshot`.
6. **Publish** — regenerate the static Chronicle.

Every external dependency is **injectable** so the whole pipeline runs offline in
tests: the four model providers, the two harvest sources, the SQLite connection,
and ``now``. In production they default to providers built from ``config`` (via
:func:`~wkd.providers.get_provider`) and harvest sources built from environment
configuration (:func:`build_fetchers`).
"""

from __future__ import annotations

import json
import os
import re
import time
import warnings
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any

from . import chronicle, council, db, historian, scoring
from .config import Config
from .harvester import MarketQuestionClient, NewsFetcher, harvest
from .models import (
    Checkpoint,
    CheckpointAction,
    Decree,
    DecreeStatus,
    Event,
    EventStatus,
    ModelRun,
    Ruling,
)
from .providers import LLMProvider, get_provider

# ``model_runs.component`` tag for the weekly checkpoint pass.
COMPONENT_CHECKPOINT = "checkpoint"

# Environment keys for the production harvest sources (kept out of Config so the
# frozen config surface is untouched; documented in .env.example / README).
ENV_NEWS_FEEDS = "WKD_NEWS_FEEDS"          # comma-separated RSS/Atom URLs
ENV_MARKET_ENDPOINT = "WKD_MARKET_ENDPOINT"  # market-questions JSON endpoint


# ---------------------------------------------------------------------------
# Clock
# ---------------------------------------------------------------------------


def _coerce_now(now: datetime | str | None) -> tuple[datetime, str]:
    """Normalize the injectable ``now`` to ``(aware-UTC datetime, ISO 'â€¦Z' str)``."""
    if now is None:
        dt = datetime.now(timezone.utc)
    elif isinstance(now, datetime):
        dt = now if now.tzinfo is not None else now.replace(tzinfo=timezone.utc)
    elif isinstance(now, str):
        dt = _parse_ts(now)
        if dt is None:
            raise ValueError(f"cannot parse now={now!r} as ISO-8601")
    else:  # pragma: no cover - defensive
        raise TypeError(f"now must be datetime|str|None, got {type(now).__name__}")
    iso = dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return dt, iso


def _parse_ts(value: Any) -> datetime | None:
    """Best-effort parse of an ISO date/datetime (``Z``/offset/bare-date) to UTC."""
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
        try:
            dt = datetime.fromisoformat(txt + "T00:00:00+00:00")
        except ValueError:
            return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ---------------------------------------------------------------------------
# Run report
# ---------------------------------------------------------------------------


@dataclass
class DailyRunReport:
    """A concise, serializable summary of one :func:`run_daily` pass."""

    now: str
    harvested: int = 0
    deliberated: int = 0
    forged: int = 0
    divided: int = 0
    checkpoints: int = 0
    resolved: int = 0
    abstained: int = 0
    metrics_snapshot_id: int | None = None
    chronicle_files: list[str] = field(default_factory=list)
    # Richer artifacts for callers/tests (not serialized by to_dict).
    forged_decrees: list[Decree] = field(default_factory=list)
    council_results: list[council.CouncilResult] = field(default_factory=list)
    rulings: list[Ruling] = field(default_factory=list)
    checkpoint_rows: list[Checkpoint] = field(default_factory=list)
    harvested_events: list[Event] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Counts-only view, safe to log/print."""
        return {
            "now": self.now,
            "harvested": self.harvested,
            "deliberated": self.deliberated,
            "forged": self.forged,
            "divided": self.divided,
            "checkpoints": self.checkpoints,
            "resolved": self.resolved,
            "abstained": self.abstained,
            "metrics_snapshot_id": self.metrics_snapshot_id,
            "chronicle_files": list(self.chronicle_files),
        }


# ---------------------------------------------------------------------------
# Dependency builders (production defaults)
# ---------------------------------------------------------------------------


def check_judge_independence(config: Config) -> None:
    """Enforce the Court Historian's independence at runtime (SPEC §3, §16.1).

    The Historian must be a *different model family* than both council mages and
    must never be a literal council member. This is core to the experiment's
    validity, so it is checked every run rather than merely trusted as a config
    default:

    * If the Historian's provider **and** model exactly equal a council mage's,
      the judge *is* a council member — that is never valid; we **raise**.
    * If the Historian merely shares a *provider* (family) with a mage but uses a
      different model, independence is weakened. That is the documented §17.1
      fallback (a walled-off Claude/GPT Historian when Gemini is unavailable), so
      we **warn loudly** rather than block.

    The ``mock`` provider is exempt — it is a test double, not a real model family.
    """
    h = config.historian
    if str(h.provider).lower() == "mock":
        return
    for role, mage in (("mage_a", config.mage_a), ("mage_b", config.mage_b)):
        if str(mage.provider).lower() == "mock":
            continue
        if h.provider == mage.provider and h.model == mage.model:
            raise ValueError(
                "Court Historian independence violated (SPEC §3/§16.1): historian "
                f"'{h.provider}/{h.model}' is identical to council {role}. The judge "
                "must not be a council member."
            )
        if h.provider == mage.provider:
            warnings.warn(
                "Court Historian shares a model family with council "
                f"{role} (provider '{h.provider}'); independence is weakened "
                "(SPEC §16.1). This is acceptable only as the documented §17.1 "
                "fallback when an independent Gemini judge is unavailable.",
                stacklevel=2,
            )


def build_providers(
    config: Config,
) -> tuple[LLMProvider, LLMProvider, LLMProvider, LLMProvider]:
    """Build ``(mage_a, mage_b, king, historian)`` providers from ``config``.

    Refuses (or warns) on an independence-violating configuration first, so the
    judge can never silently become a council member (SPEC §16.1).
    """
    check_judge_independence(config)
    return (
        get_provider(config.mage_a, config),
        get_provider(config.mage_b, config),
        get_provider(config.king, config),
        get_provider(config.historian, config),
    )


def build_fetchers(
    config: Config,
) -> tuple[NewsFetcher | None, MarketQuestionClient | None]:
    """Build harvest sources from environment configuration (production path).

    ``WKD_NEWS_FEEDS`` (comma-separated RSS/Atom URLs) → a
    :class:`~wkd.harvester.FeedparserNewsFetcher`; ``WKD_MARKET_ENDPOINT`` (a
    questions JSON endpoint) → a :class:`~wkd.harvester.HttpxMarketQuestionClient`.
    Either may be unset (→ ``None``); a harvest with no sources is a clean no-op.
    The real fetchers lazy-import ``feedparser`` / ``httpx`` only when ``fetch``
    is actually called, so this stays import-light.
    """
    from .harvester import FeedparserNewsFetcher, HttpxMarketQuestionClient

    news: NewsFetcher | None = None
    market: MarketQuestionClient | None = None
    feeds = os.environ.get(ENV_NEWS_FEEDS, "").strip()
    if feeds:
        urls = [u.strip() for u in feeds.split(",") if u.strip()]
        if urls:
            news = FeedparserNewsFetcher(urls)
    endpoint = os.environ.get(ENV_MARKET_ENDPOINT, "").strip()
    if endpoint:
        market = HttpxMarketQuestionClient(endpoint)
    return news, market


def _resolve(injected: Any, spec: Any, config: Config) -> LLMProvider:
    return injected if injected is not None else get_provider(spec, config)


def _provider_ready(provider: LLMProvider | None) -> bool:
    """True if an LLM leg backed by ``provider`` can actually run right now.

    Injected fakes / :class:`~wkd.providers.MockProvider` report ready; live
    providers report ready only when their API key *and* SDK are both present
    (SPEC §17). ``None`` is never ready. This lets an unconfigured ``run`` do its
    non-LLM work (harvest from configured sources, score, publish) and skip the
    model legs with a clear warning instead of crashing.
    """
    if provider is None:
        return False
    checker = getattr(provider, "is_ready", None)
    return bool(checker()) if callable(checker) else True


def _warn_unconfigured(leg: str, provider: LLMProvider | None) -> None:
    """Warn that an LLM leg was skipped because its provider is unconfigured."""
    name = getattr(provider, "name", "?")
    model = getattr(provider, "model", "?")
    warnings.warn(
        f"Skipping {leg}: provider '{name}/{model}' is not ready "
        "(missing API key or SDK). Set the relevant API key and "
        "`pip install -r requirements.txt` to enable it.",
        stacklevel=2,
    )


# ---------------------------------------------------------------------------
# Pipeline steps (each reused by run_daily and the matching CLI subcommand)
# ---------------------------------------------------------------------------


def harvest_step(
    conn,
    config: Config,
    *,
    now: datetime | str | None = None,
    news_fetcher: NewsFetcher | None = None,
    market_client: MarketQuestionClient | None = None,
    free_pick_provider: LLMProvider | None = None,
) -> list[Event]:
    """Harvest new matters into pending events (SPEC §7). No sources → no-op.

    The free-pick leg runs only when a ``free_pick_provider`` is supplied and
    ``config.free_pick_max > 0``; it lets the King originate his own matters from
    the run's live headlines (tagged ``source=free-pick``).
    """
    now_dt, _ = _coerce_now(now)
    free_pick_max = config.free_pick_max if free_pick_provider is not None else 0
    if news_fetcher is None and market_client is None and free_pick_max <= 0:
        return []
    return harvest(
        conn,
        news_fetcher=news_fetcher,
        market_client=market_client,
        free_pick_provider=free_pick_provider,
        free_pick_max=free_pick_max,
        domains=list(config.domains),
        now=now_dt,
    )


def deliberate_step(
    conn,
    config: Config,
    *,
    mage_a: LLMProvider,
    mage_b: LLMProvider,
    king: LLMProvider,
    now: datetime | str | None = None,
    cap: int | None = None,
) -> list[council.CouncilResult]:
    """Deliberate pending matters up to the daily cap (SPEC §5)."""
    now_dt, _ = _coerce_now(now)
    limit = config.daily_decree_cap if cap is None else cap
    pending = db.list_events(conn, status=EventStatus.PENDING)
    results: list[council.CouncilResult] = []
    for event in pending[: max(0, limit)]:
        results.append(
            council.deliberate(
                event,
                mage_a,
                mage_b,
                king,
                conn,
                max_rounds=config.deliberation_max_rounds,
                now=now_dt,
            )
        )
    return results


def checkpoint_step(
    conn,
    config: Config,
    *,
    mage: LLMProvider,
    now: datetime | str | None = None,
) -> list[Checkpoint]:
    """Re-affirm/amend/withdraw standing decrees that are due for review (SPEC §8).

    A decree is *due* when its event is unresolved, its ``resolution_date`` has
    not yet passed (otherwise it belongs to the resolution sweep), and its last
    checkpoint — or, failing that, its issuance — is older than
    ``checkpoint_interval_days``.
    """
    now_dt, now_iso = _coerce_now(now)
    horizon = now_dt - timedelta(days=config.checkpoint_interval_days)
    out: list[Checkpoint] = []
    for decree in db.list_standing_decrees(conn):
        event = db.get_event(conn, decree.event_id)
        if event is None:
            continue
        # Past-resolution decrees are handled by the resolution sweep, not here.
        rd = (event.resolution_date or "").strip()
        if rd and rd <= now_iso:
            continue
        last = db.last_checkpoint(conn, decree.id)
        ref = _parse_ts(last.checked_at if last else decree.issued_at)
        if ref is not None and ref > horizon:
            continue  # not yet due
        cp = _checkpoint_decree(conn, decree, event, mage, now_iso)
        if cp is not None:
            out.append(cp)
    return out


def resolve_step(
    conn,
    config: Config,
    *,
    historian_provider: LLMProvider,
    now: datetime | str | None = None,
) -> tuple[list[Ruling], int]:
    """Summon the Historian for every decree past its resolution date (SPEC §9).

    Returns ``(rulings, abstentions)``; an abstention (``rule`` → ``None``) leaves
    the decree standing to be retried on a later sweep.
    """
    _, now_iso = _coerce_now(now)
    rulings: list[Ruling] = []
    abstained = 0
    for decree in db.list_decrees_due(conn, now_iso):
        ruling = historian.rule(decree, historian_provider, conn, now=now_iso)
        if ruling is None:
            abstained += 1
        else:
            rulings.append(ruling)
    return rulings, abstained


# ---------------------------------------------------------------------------
# Checkpoint internals
# ---------------------------------------------------------------------------

CHECKPOINT_SYSTEM = (
    "You are a Mage of the Wizard King's Council reviewing a STANDING decree as "
    "news develops before it resolves. Decide whether to REAFFIRM it as-is, AMEND "
    "your confidence, or WITHDRAW it. Respond with ONLY a single JSON object: "
    '{"action": "reaffirm|amend|withdraw", "confidence": <0.0-1.0 private '
    'probability the claim is still on track>, "notes": "<brief justification>"}.'
)


def _checkpoint_prompt(decree: Decree, event: Event) -> str:
    return (
        "Review this standing decree.\n\n"
        f"Claim: {decree.claim_text}\n"
        f"Direction: {decree.direction}\n"
        f"Resolves on: {event.resolution_date}\n"
        f"Resolution criteria: {event.resolution_criteria}\n"
        f"Your prior private confidence: {decree.private_confidence}\n\n"
        "Return the JSON object."
    )


def _strip_fences(text: str) -> str:
    s = (text or "").strip()
    if s.startswith("```"):
        nl = s.find("\n")
        if nl != -1:
            s = s[nl + 1 :]
        if s.endswith("```"):
            s = s[:-3]
    return s.strip()


def _parse_checkpoint(text: str) -> tuple[str, float | None, str]:
    """Parse a checkpoint completion into ``(action, new_confidence, notes)``.

    Tolerant of fences/prose; unparseable output defaults to a quiet reaffirm so
    the daily driver never crashes on a bad model turn.
    """
    s = _strip_fences(text)
    data: Any = None
    try:
        data = json.loads(s)
    except Exception:
        m = re.search(r"\{.*\}", s, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group(0))
            except Exception:
                data = None
    if not isinstance(data, dict):
        return CheckpointAction.REAFFIRM.value, None, ""
    action_raw = str(data.get("action", "reaffirm")).strip().lower()
    action = {
        "reaffirm": CheckpointAction.REAFFIRM,
        "amend": CheckpointAction.AMEND,
        "withdraw": CheckpointAction.WITHDRAW,
    }.get(action_raw, CheckpointAction.REAFFIRM).value
    conf: float | None
    try:
        conf = float(data["confidence"]) if data.get("confidence") is not None else None
    except (TypeError, ValueError, KeyError):
        conf = None
    if conf is not None:
        conf = min(1.0, max(0.0, conf))
    notes = str(data.get("notes", "") or "").strip()
    return action, conf, notes


def _checkpoint_decree(
    conn, decree: Decree, event: Event, mage: LLMProvider, now_iso: str
) -> Checkpoint | None:
    """Run one checkpoint review, persist it, and ENFORCE the chosen action.

    The parsed action is not merely logged — it changes the standing decree's
    fate (SPEC §8, §16.8), all in one atomic transaction so the checkpoint row and
    the status change land together:

    * **reaffirm** — the decree stands unchanged (only the checkpoint is recorded).
    * **withdraw** — the council retracts the prophecy before it resolves; the
      decree moves to :data:`DecreeStatus.WITHDRAWN`, so the resolution sweep
      (:func:`db.list_decrees_due`, standing-only) skips it and it never scores
      for/against the council.
    * **amend** — a new superseding decree is forged (``supersedes_id`` set, the
      amended private confidence), and the prior decree is retired to
      :data:`DecreeStatus.SUPERSEDED`. The original row is never silently edited
      (SPEC §16.8 — amendments supersede); the new decree carries on as standing.
    """
    started = time.perf_counter()
    resp = mage.complete(
        CHECKPOINT_SYSTEM,
        _checkpoint_prompt(decree, event),
        temperature=0.4,
        want_json=True,
    )
    latency_ms = int((time.perf_counter() - started) * 1000)
    db.insert_model_run(
        conn,
        ModelRun(
            component=COMPONENT_CHECKPOINT,
            model=resp.model,
            prompt_tokens=resp.prompt_tokens,
            completion_tokens=resp.completion_tokens,
            cost=resp.cost,
            latency_ms=latency_ms,
            created_at=now_iso,
        ),
    )
    action, conf, notes = _parse_checkpoint(resp.text)

    with db.transaction(conn):
        checkpoint = db.insert_checkpoint(
            conn,
            Checkpoint(
                decree_id=decree.id,
                action=action,
                new_confidence=conf,
                notes=notes,
                checked_at=now_iso,
            ),
            commit=False,
        )
        if action == CheckpointAction.WITHDRAW.value:
            db.update_decree_status(
                conn, decree.id, DecreeStatus.WITHDRAWN, commit=False
            )
        elif action == CheckpointAction.AMEND.value:
            # Supersede: forge a new standing decree, retire the old one.
            db.insert_decree(
                conn,
                Decree(
                    event_id=decree.event_id,
                    claim_text=decree.claim_text,
                    regal_text=decree.regal_text,
                    direction=decree.direction,
                    private_confidence=conf if conf is not None else decree.private_confidence,
                    consensus_rounds=decree.consensus_rounds,
                    status=DecreeStatus.STANDING,
                    issued_at=now_iso,
                    supersedes_id=decree.id,
                ),
                commit=False,
            )
            db.update_decree_status(
                conn, decree.id, DecreeStatus.SUPERSEDED, commit=False
            )
    return checkpoint


# ---------------------------------------------------------------------------
# The daily driver
# ---------------------------------------------------------------------------


def run_daily(
    config: Config,
    *,
    now: datetime | str | None = None,
    conn=None,
    mage_a: LLMProvider | None = None,
    mage_b: LLMProvider | None = None,
    king: LLMProvider | None = None,
    historian_provider: LLMProvider | None = None,
    news_fetcher: NewsFetcher | None = None,
    market_client: MarketQuestionClient | None = None,
    free_pick_provider: LLMProvider | None = None,
) -> DailyRunReport:
    """Run one idempotent daily pass (SPEC §8). Returns a :class:`DailyRunReport`.

    All dependencies are injectable for offline tests; production builds them from
    ``config`` (providers via :func:`build_providers`) and the environment (harvest
    sources via :func:`build_fetchers`). If ``conn`` is supplied the caller owns it
    (it is *not* closed); otherwise a connection is opened on ``config.db_path``,
    its schema ensured, and closed before returning.
    """
    now_dt, now_iso = _coerce_now(now)

    # Guard the judge's independence before any work (SPEC §3/§16.1); fires even
    # when providers are injected, since it validates the declared config roles.
    check_judge_independence(config)

    owns_conn = conn is None
    if conn is None:
        conn = db.connect(config.db_path)
    db.init_db(conn)  # idempotent: ensure schema exists

    try:
        ma = _resolve(mage_a, config.mage_a, config)
        mb = _resolve(mage_b, config.mage_b, config)
        kg = _resolve(king, config.king, config)
        hist = _resolve(historian_provider, config.historian, config)

        if news_fetcher is None and market_client is None:
            news_fetcher, market_client = build_fetchers(config)

        # The King surveys headlines for free-picks (SPEC §7). Built fresh from the
        # King's model spec (not the styling-pass instance, whose script is reserved
        # for proclamations) unless a provider is explicitly injected.
        fp = free_pick_provider
        if fp is None and config.free_pick_max > 0:
            fp = get_provider(config.king, config)
        if fp is not None and not _provider_ready(fp):
            _warn_unconfigured("free-pick origination", fp)
            fp = None

        report = DailyRunReport(now=now_iso)

        # 1) Harvest -----------------------------------------------------------
        harvested = harvest_step(
            conn,
            config,
            now=now_dt,
            news_fetcher=news_fetcher,
            market_client=market_client,
            free_pick_provider=fp,
        )
        report.harvested = len(harvested)
        report.harvested_events = harvested

        # 2) Deliberate --------------------------------------------------------
        if _provider_ready(ma) and _provider_ready(mb) and _provider_ready(kg):
            results = deliberate_step(
                conn, config, mage_a=ma, mage_b=mb, king=kg, now=now_dt
            )
        else:
            results = []
            if db.list_events(conn, status=EventStatus.PENDING):
                unready = next(p for p in (ma, mb, kg) if not _provider_ready(p))
                _warn_unconfigured("council deliberation", unready)
        report.council_results = results
        report.deliberated = len(results)
        for r in results:
            if r.is_consensus and r.decree is not None:
                report.forged += 1
                report.forged_decrees.append(r.decree)
            else:
                report.divided += 1

        # 3) Checkpoint --------------------------------------------------------
        if _provider_ready(ma):
            checkpoints = checkpoint_step(conn, config, mage=ma, now=now_dt)
        else:
            checkpoints = []
            if db.list_standing_decrees(conn):
                _warn_unconfigured("checkpoint review", ma)
        report.checkpoint_rows = checkpoints
        report.checkpoints = len(checkpoints)

        # 4) Resolve -----------------------------------------------------------
        if _provider_ready(hist):
            rulings, abstained = resolve_step(
                conn, config, historian_provider=hist, now=now_iso
            )
        else:
            rulings, abstained = [], 0
            if db.list_decrees_due(conn, now_iso):
                _warn_unconfigured("Historian resolution", hist)
        report.rulings = rulings
        report.resolved = len(rulings)
        report.abstained = abstained

        # 5) Score -------------------------------------------------------------
        snapshot = scoring.compute_metrics(conn, now=now_iso)
        report.metrics_snapshot_id = snapshot.id

        # 6) Publish -----------------------------------------------------------
        report.chronicle_files = chronicle.generate(
            conn, config.chronicle_out_dir, now=now_iso
        )

        return report
    finally:
        if owns_conn:
            conn.close()


__all__ = [
    "run_daily",
    "DailyRunReport",
    "harvest_step",
    "deliberate_step",
    "checkpoint_step",
    "resolve_step",
    "build_providers",
    "build_fetchers",
    "check_judge_independence",
    "COMPONENT_CHECKPOINT",
    "CHECKPOINT_SYSTEM",
    "ENV_NEWS_FEEDS",
    "ENV_MARKET_ENDPOINT",
]
