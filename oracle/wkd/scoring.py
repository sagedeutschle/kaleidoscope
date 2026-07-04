"""Scoring / scoreboard metrics for The Wizard King's Decree (SPEC §11).

:func:`compute_metrics` reads the whole store and produces — then persists — a
:class:`~wkd.models.MetricsSnapshot` covering every metric the Verdict needs:

* **Hit rate** (vindicated / ruled) with a seeded bootstrap confidence interval.
* **Tier distribution** across the Ladder of Shame.
* **Per-domain accuracy** (econ vs politics vs ...).
* **Council-divided rate** (how often the future was too uncertain to decree).
* **Calibration** of ``private_confidence`` in ten buckets.
* **Beat-the-crowd** vs ``market_implied_prob`` (Brier + directional), markets
  harvested for their *questions* only — never traded (SPEC §2, §11).
* **Status-quo / no-change baseline** the council must clear.
* **Harvested vs free-pick** split, so easy free-picks cannot juice the score.

Design rules that keep this deterministic and offline-testable:

* A "hit" means exactly **verdict == VINDICATED** everywhere (hit rate,
  calibration, beat-the-crowd, baseline) — cliffnotes/apology/cancellation all
  score as "the prophesied change did not (fully) come to pass" (``y = 0``).
* The only randomness — the bootstrap resampling — is driven by an injected
  ``rng_seed`` so two runs on the same data are identical.
* The clock is injectable (``now=...``); tests pass a fixed timestamp.

The foundation ``db`` module is imported here as ``_store`` so the public first
argument can keep the frozen name ``db`` (a :class:`sqlite3.Connection`).
"""

from __future__ import annotations

import json
import math
import random
import sqlite3
from collections import Counter, namedtuple
from datetime import datetime, timezone
from typing import Iterable, Sequence

from wkd import db as _store
from wkd.models import (
    DecreeStatus,
    MetricsSnapshot,
    Tier,
)

# Bumped if the metrics_json shape changes (scoreboard history is long-lived).
METRICS_VERSION = 1
CALIBRATION_BUCKETS = 10

# One resolved decree paired with its event + the Historian's latest verdict.
RuledRecord = namedtuple("RuledRecord", "decree event verdict y")


# ---------------------------------------------------------------------------
# Small numeric helpers (pure, deterministic)
# ---------------------------------------------------------------------------


def _rate(num: float, den: float) -> float:
    """Safe ratio: ``num / den`` or ``0.0`` when ``den`` is zero/empty."""
    return float(num) / float(den) if den else 0.0


def _bucket_index(confidence: float, buckets: int = CALIBRATION_BUCKETS) -> int:
    """Map a 0–1 confidence onto ``[0, buckets-1]`` (1.0 lands in the top bin)."""
    idx = int(confidence * buckets)
    if idx < 0:
        return 0
    if idx >= buckets:
        return buckets - 1
    return idx


def _percentile(sorted_vals: Sequence[float], q: float) -> float:
    """Linear-interpolation percentile of an *already sorted* sequence.

    ``q`` is in ``[0, 1]``. Matches the common "linear" method so a degenerate
    sample (all values equal) returns that value for any ``q``.
    """
    n = len(sorted_vals)
    if n == 0:
        return 0.0
    if n == 1:
        return float(sorted_vals[0])
    pos = q * (n - 1)
    lo = math.floor(pos)
    hi = math.ceil(pos)
    if lo == hi:
        return float(sorted_vals[int(pos)])
    frac = pos - lo
    return float(sorted_vals[lo] * (1.0 - frac) + sorted_vals[hi] * frac)


def bootstrap_ci(
    outcomes: Iterable[int],
    *,
    rng_seed: int = 0,
    resamples: int = 1000,
    ci_level: float = 0.95,
) -> tuple[float, float]:
    """Seeded percentile bootstrap CI for the mean of binary ``outcomes``.

    Deterministic for a fixed ``rng_seed``. Empty input -> ``(0.0, 0.0)``; a
    degenerate sample (all 0s or all 1s) collapses to ``(v, v)``.
    """
    data = list(outcomes)
    n = len(data)
    if n == 0:
        return (0.0, 0.0)
    rng = random.Random(rng_seed)
    means = [sum(rng.choices(data, k=n)) / n for _ in range(resamples)]
    means.sort()
    alpha = (1.0 - ci_level) / 2.0
    return (_percentile(means, alpha), _percentile(means, 1.0 - alpha))


def brier_score(probs: Sequence[float], outcomes: Sequence[int]) -> float:
    """Mean squared error of probabilistic forecasts (lower is better)."""
    n = len(probs)
    if n == 0:
        return 0.0
    return sum((p - y) ** 2 for p, y in zip(probs, outcomes)) / n


# ---------------------------------------------------------------------------
# Reading the store into scorable records
# ---------------------------------------------------------------------------


def _load_ruled(db: sqlite3.Connection) -> list[RuledRecord]:
    """Every decree that has a ruling, paired with its event + latest verdict.

    Rulings are append-only; the *latest* ruling per decree wins (``list_rulings``
    returns them id-ascending, so the last seen for a decree id is newest).
    """
    latest: dict[int, object] = {}
    for ruling in _store.list_rulings(db):
        latest[ruling.decree_id] = ruling

    ruled: list[RuledRecord] = []
    for decree_id, ruling in latest.items():
        decree = _store.get_decree(db, decree_id)
        if decree is None:
            continue
        event = _store.get_event(db, decree.event_id)
        if event is None:
            continue
        verdict = str(ruling.verdict)
        y = 1 if verdict == Tier.VINDICATED else 0
        ruled.append(RuledRecord(decree=decree, event=event, verdict=verdict, y=y))
    return ruled


# ---------------------------------------------------------------------------
# Metric sections
# ---------------------------------------------------------------------------


def _counts(events, decrees, ruled) -> dict:
    status = Counter(str(e.status) for e in events)
    standing = sum(1 for d in decrees if str(d.status) == DecreeStatus.STANDING)
    return {
        "events_total": len(events),
        "events_pending": status.get("pending", 0),
        "events_decreed": status.get("decreed", 0),
        "events_divided": status.get("divided", 0),
        "events_resolved": status.get("resolved", 0),
        "decrees_total": len(decrees),
        "decrees_standing": standing,
        "decrees_ruled": len(ruled),
    }


def _hit_rate(ruled, *, rng_seed: int, resamples: int, ci_level: float) -> dict:
    outcomes = [r.y for r in ruled]
    n = len(outcomes)
    vindicated = sum(outcomes)
    low, high = bootstrap_ci(
        outcomes, rng_seed=rng_seed, resamples=resamples, ci_level=ci_level
    )
    return {
        "ruled": n,
        "vindicated": vindicated,
        "rate": _rate(vindicated, n),
        "ci_low": low,
        "ci_high": high,
        "ci_level": ci_level,
        "ci_method": "bootstrap-percentile",
        "bootstrap_resamples": resamples,
        "rng_seed": rng_seed,
    }


def _tier_distribution(ruled) -> dict:
    n = len(ruled)
    counts = Counter(r.verdict for r in ruled)
    counts_out = {t.value: counts.get(t.value, 0) for t in Tier}
    fractions = {k: _rate(v, n) for k, v in counts_out.items()}
    return {"counts": counts_out, "fractions": fractions, "ruled": n}


def _grouped_accuracy(ruled, key) -> dict:
    out: dict[str, dict] = {}
    for group in sorted({key(r) for r in ruled}):
        recs = [r for r in ruled if key(r) == group]
        v = sum(r.y for r in recs)
        out[group] = {
            "ruled": len(recs),
            "vindicated": v,
            "hit_rate": _rate(v, len(recs)),
        }
    return out


def _divided(events) -> dict:
    status = Counter(str(e.status) for e in events)
    divided = status.get("divided", 0)
    # An event reached a decree iff it is 'decreed' (standing) or 'resolved'.
    decreed = status.get("decreed", 0) + status.get("resolved", 0)
    deliberated = divided + decreed
    return {
        "council_divided": divided,
        "decreed": decreed,
        "deliberated": deliberated,
        "divided_rate": _rate(divided, deliberated),
    }


def _calibration(ruled, buckets: int = CALIBRATION_BUCKETS) -> dict:
    out = []
    for i in range(buckets):
        recs = [
            r for r in ruled if _bucket_index(r.decree.private_confidence, buckets) == i
        ]
        n = len(recs)
        conf_sum = sum(r.decree.private_confidence for r in recs)
        v = sum(r.y for r in recs)
        out.append(
            {
                "lo": round(i / buckets, 4),
                "hi": round((i + 1) / buckets, 4),
                "n": n,
                "mean_confidence": (conf_sum / n) if n else 0.0,
                "vindicated": v,
                "hit_rate": _rate(v, n),
            }
        )
    return {"n_buckets": buckets, "buckets": out}


def _beat_the_crowd(ruled) -> dict:
    market = [r for r in ruled if r.event.market_implied_prob is not None]
    n = len(market)
    council_probs = [r.decree.private_confidence for r in market]
    market_probs = [r.event.market_implied_prob for r in market]
    outcomes = [r.y for r in market]

    council_correct = market_correct = 0
    council_better = market_better = 0
    for cp, mp, y in zip(council_probs, market_probs, outcomes):
        c_ok = (cp >= 0.5) == (y == 1)
        m_ok = (mp >= 0.5) == (y == 1)
        council_correct += int(c_ok)
        market_correct += int(m_ok)
        if c_ok and not m_ok:
            council_better += 1
        if m_ok and not c_ok:
            market_better += 1

    council_brier = brier_score(council_probs, outcomes)
    market_brier = brier_score(market_probs, outcomes)
    return {
        "n": n,
        "council_brier": council_brier,
        "market_brier": market_brier,
        "council_beats_market_brier": bool(n) and council_brier < market_brier,
        "council_correct": council_correct,
        "market_correct": market_correct,
        "council_better_calls": council_better,
        "market_better_calls": market_better,
    }


def _baseline(ruled) -> dict:
    """Status-quo / no-change predictor: it bets every prophecy fails (y == 0)."""
    n = len(ruled)
    vindicated = sum(r.y for r in ruled)
    council = _rate(vindicated, n)
    status_quo = _rate(n - vindicated, n)
    return {
        "n": n,
        "council_hit_rate": council,
        "status_quo_hit_rate": status_quo,
        "council_minus_baseline": council - status_quo,
    }


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def build_metrics(
    db: sqlite3.Connection,
    *,
    rng_seed: int = 0,
    resamples: int = 1000,
    ci_level: float = 0.95,
) -> dict:
    """Compute the full metrics dict from the store (no clock, no persistence)."""
    events = _store.list_events(db)
    decrees = _store.list_decrees(db)
    ruled = _load_ruled(db)

    return {
        "metrics_version": METRICS_VERSION,
        "counts": _counts(events, decrees, ruled),
        "hit_rate": _hit_rate(
            ruled, rng_seed=rng_seed, resamples=resamples, ci_level=ci_level
        ),
        "tier_distribution": _tier_distribution(ruled),
        "per_domain_accuracy": _grouped_accuracy(ruled, lambda r: str(r.event.domain)),
        "divided": _divided(events),
        "calibration": _calibration(ruled),
        "beat_the_crowd": _beat_the_crowd(ruled),
        "baseline": _baseline(ruled),
        "by_source": _grouped_accuracy(ruled, lambda r: str(r.event.source)),
    }


def _utc_now_iso() -> str:
    """Current UTC time as an ISO-8601 ``...Z`` string (the store's convention)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compute_metrics(
    db: sqlite3.Connection,
    *,
    rng_seed: int = 0,
    now: str | None = None,
    resamples: int = 1000,
    ci_level: float = 0.95,
) -> MetricsSnapshot:
    """Compute, persist, and return a :class:`MetricsSnapshot` (SPEC §11, §14).

    ``db`` is an open :class:`sqlite3.Connection`. ``rng_seed`` makes the
    bootstrap CI reproducible; ``now`` (injectable clock) stamps ``computed_at``
    and defaults to the current UTC time. The snapshot's ``metrics_json`` is the
    canonical (``sort_keys=True``) serialization of :func:`build_metrics`.
    """
    metrics = build_metrics(
        db, rng_seed=rng_seed, resamples=resamples, ci_level=ci_level
    )
    computed_at = now or _utc_now_iso()
    metrics["computed_at"] = computed_at
    snapshot = MetricsSnapshot(
        metrics_json=json.dumps(metrics, sort_keys=True),
        computed_at=computed_at,
    )
    return _store.insert_metrics_snapshot(db, snapshot)


__all__ = [
    "compute_metrics",
    "build_metrics",
    "bootstrap_ci",
    "brier_score",
    "RuledRecord",
    "METRICS_VERSION",
    "CALIBRATION_BUCKETS",
]
