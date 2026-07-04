"""Frozen data entities + string-enums for The Wizard King's Decree (SPEC §14, §10).

Every persisted row in the SQLite store has a matching frozen dataclass here.
All dataclasses are ``frozen=True`` (immutable, hashable) and ``kw_only=True`` so
field order mirrors SPEC §14 exactly while still allowing sensible defaults.

Status/verdict vocabularies are ``StrEnum`` subclasses: members compare equal to
their plain-string values, so they round-trip through SQLite TEXT columns without
coercion (a value read back from the DB is a plain ``str`` and still compares
equal to the corresponding enum member).
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

# ---------------------------------------------------------------------------
# String-enums (stored as TEXT; members == their string values)
# ---------------------------------------------------------------------------


class EventStatus(StrEnum):
    """Lifecycle of a harvested matter (SPEC §14 events.status)."""

    PENDING = "pending"
    DECREED = "decreed"
    DIVIDED = "divided"
    RESOLVED = "resolved"


class DecreeStatus(StrEnum):
    """Lifecycle of a forged decree (SPEC §14 decrees.status).

    Note the harsh terminal tier is spelled ``cancelled`` here (past tense)
    while the Historian's *verdict* spells it ``cancellation`` (see ``Tier``).
    Use ``TIER_TO_DECREE_STATUS`` to map between them.

    Two non-tier terminal states arise from the weekly checkpoint (SPEC §8, §16.8):
    ``WITHDRAWN`` (the council retracted the prophecy before it resolved) and
    ``SUPERSEDED`` (an amendment forged a new decree that replaces this one). Both
    are removed from the resolution sweep and never scored.
    """

    STANDING = "standing"
    VINDICATED = "vindicated"
    CLIFFNOTES = "cliffnotes"
    APOLOGY = "apology"
    CANCELLED = "cancelled"
    WITHDRAWN = "withdrawn"
    SUPERSEDED = "superseded"


class Tier(StrEnum):
    """The Ladder of Shame verdict a ruling assigns (SPEC §10).

    Also referred to as the Historian's *verdict*; ``Verdict`` is an alias.
    """

    VINDICATED = "vindicated"
    CLIFFNOTES = "cliffnotes"
    APOLOGY = "apology"
    CANCELLATION = "cancellation"


# The Historian's verdict and the ladder Tier are the same vocabulary.
Verdict = Tier


class Source(StrEnum):
    """How a matter entered the queue (SPEC §7, §14 events.source)."""

    HARVESTED = "harvested"
    FREE_PICK = "free-pick"


class Domain(StrEnum):
    """Reasoning-favored domains (SPEC §7). Sports/pure-chance are excluded."""

    POLITICS = "politics"
    ECON = "econ"
    CURRENT_EVENTS = "current-events"
    CRYPTO = "crypto"
    WORLD_NEWS = "world-news"


class CheckpointAction(StrEnum):
    """Weekly re-affirmation outcomes (SPEC §8, §14 checkpoints.action)."""

    REAFFIRM = "reaffirm"
    AMEND = "amend"
    WITHDRAW = "withdraw"


# Maps a Historian verdict (Tier) onto the resulting decree status.
TIER_TO_DECREE_STATUS: dict[Tier, DecreeStatus] = {
    Tier.VINDICATED: DecreeStatus.VINDICATED,
    Tier.CLIFFNOTES: DecreeStatus.CLIFFNOTES,
    Tier.APOLOGY: DecreeStatus.APOLOGY,
    Tier.CANCELLATION: DecreeStatus.CANCELLED,
}

# The harsh tiers require stronger corroboration (SPEC §9, §10, §16.3).
HARSH_TIERS: frozenset[Tier] = frozenset({Tier.APOLOGY, Tier.CANCELLATION})


# ---------------------------------------------------------------------------
# Entities (one per SPEC §14 table; column order preserved)
# ---------------------------------------------------------------------------


@dataclass(frozen=True, kw_only=True)
class Event:
    """A harvested matter awaiting (or having received) a decree. SPEC §14 events."""

    source: str
    title: str
    domain: str
    description: str = ""
    resolution_date: str | None = None
    resolution_criteria: str = ""
    market_implied_prob: float | None = None
    source_ref: str | None = None
    harvested_at: str | None = None
    status: str = EventStatus.PENDING
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class Decree:
    """A forged proclamation, public + hidden metadata. SPEC §4, §14 decrees."""

    event_id: int
    claim_text: str
    regal_text: str = ""
    direction: str = ""
    private_confidence: float = 0.0
    consensus_rounds: int = 0
    status: str = DecreeStatus.STANDING
    issued_at: str | None = None
    supersedes_id: int | None = None
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class Deliberation:
    """One mage's contribution in one round of council debate. SPEC §5, §14."""

    event_id: int
    round: int
    model: str
    draft_claim: str = ""
    draft_confidence: float = 0.0
    reasoning: str = ""
    created_at: str | None = None
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class Checkpoint:
    """A weekly re-affirmation of a standing decree. SPEC §8, §14 checkpoints."""

    decree_id: int
    action: str
    new_confidence: float | None = None
    notes: str = ""
    checked_at: str | None = None
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class Ruling:
    """The Court Historian's append-only judgement. SPEC §9, §14 rulings.

    ``evidence_json`` and the metrics JSON elsewhere are stored as JSON *text*;
    callers serialize/deserialize with the stdlib ``json`` module.
    """

    decree_id: int
    verdict: str
    historian_model: str = ""
    evidence_json: str = ""
    corroborating_sources: int = 0
    reasoning: str = ""
    ruled_at: str | None = None
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class Correction:
    """The published correction copy for a ruling. SPEC §10, §14 corrections."""

    ruling_id: int
    decree_id: int
    tier: str
    correction_text: str = ""
    published_at: str | None = None
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class ModelRun:
    """A single LLM call's cost/usage audit record. SPEC §14 model_runs, §16.7."""

    component: str
    model: str
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cost: float = 0.0
    latency_ms: int = 0
    created_at: str | None = None
    id: int | None = None


@dataclass(frozen=True, kw_only=True)
class MetricsSnapshot:
    """A point-in-time scoreboard snapshot. SPEC §11, §14 metrics_snapshots.

    ``metrics_json`` is JSON *text*; ``scoring.compute_metrics`` builds it.
    """

    metrics_json: str
    computed_at: str | None = None
    id: int | None = None


__all__ = [
    # enums / vocabularies
    "EventStatus",
    "DecreeStatus",
    "Tier",
    "Verdict",
    "Source",
    "Domain",
    "CheckpointAction",
    "TIER_TO_DECREE_STATUS",
    "HARSH_TIERS",
    # entities
    "Event",
    "Decree",
    "Deliberation",
    "Checkpoint",
    "Ruling",
    "Correction",
    "ModelRun",
    "MetricsSnapshot",
]
