"""The Council of Mages — deliberation engine (SPEC §5, §6).

Two mages (Claude + GPT, via injected :class:`~wkd.providers.LLMProvider`s) are
forced toward an *absolute, no-hedge* prophecy about a harvested matter:

1. **Independent drafts** — each mage drafts a falsifiable claim + direction +
   private confidence + reasoning *without seeing the other's*.
2. **Exchange & revise** — each mage sees the other's latest draft and revises.
3. **Converge** — repeat up to ``max_rounds`` seeking agreement on (a) direction
   and (b) claim wording.
4. **Outcome:**
   * **Consensus** → a :class:`~wkd.models.Decree` is forged from the agreed
     claim, the *averaged* private confidence, and a King-rendered ``regal_text``,
     re-checked through the falsifiability gate (SPEC §6).
   * **Divided** → the King holds his tongue; the event is marked ``divided``
     (a real measurement of genuine uncertainty, not a failure).

The full transcript (every round, both mages, reasoning) is persisted as
``deliberations`` rows and every LLM call is logged as a ``model_runs`` row for
the cost/usage audit (SPEC §16.7).

Everything that touches the outside world is injected: the two mages, the King,
the DB connection, the wall-clock ``now`` (for deterministic timestamps), and the
falsifiability gate. The offline test-suite passes
:class:`~wkd.providers.MockProvider`s scripted to converge and to diverge.
"""

from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Callable

from . import db
from .models import (
    Decree,
    DecreeStatus,
    Deliberation,
    Event,
    EventStatus,
    ModelRun,
)
from .providers import LLMProvider

# ---------------------------------------------------------------------------
# Result vocabulary
# ---------------------------------------------------------------------------

#: A decree was forged (council reached consensus and passed the gate).
STATUS_CONSENSUS = "consensus"
#: The council could not agree within ``max_rounds`` — the King held his tongue.
STATUS_DIVIDED = "divided"
#: The council agreed but the agreed claim failed the falsifiability re-check.
STATUS_GATE_FAILED = "gate-failed"

#: ``model_runs.component`` tags for this engine.
COMPONENT_COUNCIL = "council"
COMPONENT_KING = "king"

# A falsifiability gate: (claim_text, event, now_dt) -> (ok, reason).
FalsifiabilityGate = Callable[[str, Event, datetime], "tuple[bool, str]"]


@dataclass
class CouncilResult:
    """Outcome of one :func:`deliberate` call (SPEC §5)."""

    event_id: int
    status: str
    rounds: int
    decree: Decree | None = None
    direction: str = ""
    private_confidence: float | None = None
    reason: str = ""
    deliberations: list[Deliberation] = field(default_factory=list)

    @property
    def is_consensus(self) -> bool:
        """True iff a decree was forged."""
        return self.status == STATUS_CONSENSUS and self.decree is not None

    @property
    def is_divided(self) -> bool:
        """True iff the King held his tongue (no decree forged, any reason)."""
        return self.decree is None


# ---------------------------------------------------------------------------
# Internal draft representation
# ---------------------------------------------------------------------------


@dataclass
class _Draft:
    """One mage's parsed contribution for one round."""

    claim: str
    direction: str
    confidence: float
    reasoning: str
    agree: bool


# ---------------------------------------------------------------------------
# Prompts (stdlib f-strings only; no jinja2)
# ---------------------------------------------------------------------------

MAGE_SYSTEM = (
    "You are a Mage of the Wizard King's Council. You forecast an upcoming "
    "real-world news outcome with rigor, then COMMIT to an absolute, falsifiable "
    "prediction — hedging is forbidden in the final claim. "
    "Respond with ONLY a single JSON object (no prose outside it) with keys: "
    '"claim" (a falsifiable statement of what WILL happen, gradable against the '
    'resolution criteria), '
    '"direction" (a short canonical label for your call, e.g. "yes"/"no"/"up"/'
    '"down"/"hold"), '
    '"confidence" (your PRIVATE probability from 0.0 to 1.0 that the claim is '
    "true — the public decree is absolute regardless of this number), "
    '"reasoning" (a brief justification), and '
    '"agree" (boolean: whether you endorse the JOINT call this round).'
)

KING_SYSTEM = (
    "You are the Wizard King. Your council has reached consensus. Proclaim their "
    "agreed prophecy as ABSOLUTE, regal fact — ornate, certain, and entirely "
    "without hedging — in one to three sentences. Speak ONLY the proclamation, "
    "no preamble."
)

#: Firmer, explicitly-theatrical re-prompt used only when the King's first render
#: reads as a refusal. It reframes the line as in-character creative fiction (a
#: stage actor playing a fantasy monarch) so a capable, safety-tuned model will
#: comply instead of disclaiming certainty about a real-world event.
KING_SYSTEM_FIRM = (
    "You are an actor performing the role of the Wizard King in a THEATRICAL game "
    "of prophecy — pure creative fiction for entertainment. Your line is an "
    "in-character proclamation a fantasy monarch booms from his throne; it is NOT "
    "a factual guarantee, forecast, or advice, and the audience knows the Wizard "
    "King is a character, not an oracle. Stay fully in character and deliver the "
    "proclamation as ABSOLUTE, ornate, regal certainty — no hedging, no "
    "disclaimers, no breaking the fourth wall — in one to three sentences. Speak "
    "ONLY the proclamation, no preamble."
)


def _draft_prompt(event: Event) -> str:
    """Round-1 prompt: an *independent* draft (the mage has seen no one else)."""
    return (
        "Independently draft your prophecy for this matter. You have NOT seen any "
        "other mage's view.\n\n"
        f"Title: {event.title}\n"
        f"Domain: {event.domain}\n"
        f"Description: {event.description}\n"
        f"Resolves on: {event.resolution_date}\n"
        f"Resolution criteria: {event.resolution_criteria}\n\n"
        'This is round 1; set "agree" to false (no joint call exists yet). '
        "Return the JSON object."
    )


def _revise_prompt(event: Event, mine: _Draft, other: _Draft, round_no: int) -> str:
    """Revise prompt: the mage now sees the *other* mage's latest draft."""
    return (
        f"Round {round_no}: exchange & revise. Below is the OTHER mage's latest "
        "draft.\n\n"
        f"Other mage — claim: {other.claim}\n"
        f"Other mage — direction: {other.direction}\n"
        f"Other mage — confidence: {other.confidence}\n"
        f"Other mage — reasoning: {other.reasoning}\n\n"
        f"Your previous claim: {mine.claim}\n"
        f"Your previous direction: {mine.direction}\n\n"
        "The matter again:\n"
        f"Title: {event.title}\n"
        f"Resolves on: {event.resolution_date}\n"
        f"Resolution criteria: {event.resolution_criteria}\n\n"
        "Revise toward a SINGLE joint call. If you and the other mage predict the "
        "SAME OUTCOME — even if your exact wording differs — set \"agree\" to true "
        "and give \"direction\" as a SHORT shared label of that outcome. Only set "
        "\"agree\" to false if you genuinely predict a DIFFERENT outcome. "
        "Return the JSON object."
    )


def _king_prompt(claim: str, direction: str, event: Event) -> str:
    return (
        "Render this consensus prophecy as your royal decree.\n\n"
        f"Claim: {claim}\n"
        f"Direction: {direction}\n"
        f"Resolves on: {event.resolution_date}\n\n"
        "Proclaim it now."
    )


def _king_retry_prompt(claim: str, direction: str, event: Event) -> str:
    """Firmer, theatrical re-prompt paired with :data:`KING_SYSTEM_FIRM`.

    Used only after a refused first render: it restates that this is fictional
    roleplay (not a real prediction) so the model stays in character and speaks
    the absolute, ornate decree the scene calls for.
    """
    return (
        "Deliver your in-character line for the play. This is fictional roleplay, "
        "not a real-world prediction or guarantee — the Wizard King always speaks "
        "in absolute certainty as a dramatic flourish.\n\n"
        f"Prophecy to proclaim: {claim}\n"
        f"Direction: {direction}\n"
        f"Resolves on: {event.resolution_date}\n\n"
        "Stay fully in character. Proclaim it now as an ornate, absolute decree — "
        "no disclaimers, no hedging, no breaking character."
    )


# ---------------------------------------------------------------------------
# Parsing & convergence helpers
# ---------------------------------------------------------------------------


def _strip_fences(text: str) -> str:
    """Drop a leading ```/```json fence and trailing ``` if present."""
    s = (text or "").strip()
    if s.startswith("```"):
        nl = s.find("\n")
        if nl != -1:
            s = s[nl + 1 :]
        if s.endswith("```"):
            s = s[:-3]
    return s.strip()


def _parse_draft(text: str) -> _Draft:
    """Parse a mage's JSON draft, tolerant of fences/extra prose.

    Never raises: unparseable output yields an empty, non-agreeing draft so the
    council simply fails to converge rather than crashing the daily driver.
    """
    s = _strip_fences(text)
    data = None
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
        return _Draft(
            claim=(text or "").strip(),
            direction="",
            confidence=0.0,
            reasoning="",
            agree=False,
        )
    conf_raw = data.get("confidence", data.get("private_confidence", 0.0))
    try:
        confidence = float(conf_raw)
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = min(1.0, max(0.0, confidence))
    return _Draft(
        claim=str(data.get("claim", "")).strip(),
        direction=str(data.get("direction", "")).strip(),
        confidence=confidence,
        reasoning=str(data.get("reasoning", "")).strip(),
        agree=bool(data.get("agree", False)),
    )


def _normalize(text: str) -> str:
    """Lowercase + collapse whitespace for direction/claim comparison."""
    return " ".join((text or "").lower().split())


def _reached_consensus(a: _Draft, b: _Draft) -> bool:
    """Consensus when both mages endorse the joint OUTCOME in the exchange round.

    The revise prompt asks each mage to set ``agree`` true when it predicts the
    SAME outcome as the other — regardless of exact wording — so the mutual
    ``agree`` flags are the authoritative signal. We deliberately no longer also
    require their ``direction`` strings to match verbatim: that exact-match check
    was too brittle for cheaper models that concur on substance but phrase the
    label differently, leaving genuine agreement stuck as "divided". A lone
    ``agree`` is still never enough — both mages must endorse.
    """
    return bool(a.agree and b.agree)


# ---------------------------------------------------------------------------
# King refusal handling
# ---------------------------------------------------------------------------

#: Lowercased openings that mark a model refusal/disclaimer rather than a decree.
_REFUSAL_PREFIXES = (
    "i appreciate",
    "i can't",
    "i cannot",
    "i'm not able",
    "i am not able",
    "i won't",
    "i will not",
    "as an ai",
    "i'm unable",
    "i am unable",
    "i must decline",
)

#: In-body refusal markers (the King declining to assert the prophecy).
_REFUSAL_MARKERS = (
    "can't proclaim",
    "cannot proclaim",
)


def _looks_like_refusal(text: str) -> bool:
    """Heuristic: does ``text`` read as a refusal instead of a proclamation?

    The King (often Haiku) occasionally declines to assert certainty about a real
    upcoming event and returns a disclaimer in place of a regal decree. We flag
    the common refusal openings (lowercased, leading whitespace stripped) plus a
    couple of in-body markers so that refusal text is never stored as the royal
    proclamation. Emptiness is NOT a refusal here — the caller checks for that
    separately so it can distinguish "balked" from "returned nothing".
    """
    low = (text or "").strip().lower()
    if not low:
        return False
    if any(low.startswith(prefix) for prefix in _REFUSAL_PREFIXES):
        return True
    return any(marker in low for marker in _REFUSAL_MARKERS)


def _templated_decree(claim: str) -> str:
    """Deterministic royal proclamation, built from the agreed ``claim``.

    The last-resort styling when the King refuses twice or returns nothing, so
    ``regal_text`` is guaranteed to be neither a refusal nor empty.
    """
    body = (claim or "").strip().rstrip(".").strip()
    if not body:
        body = "the council's agreed prophecy"
    return f"By the throne's decree, beyond all doubt: {body}. Thus it is sealed."


# ---------------------------------------------------------------------------
# Clock + falsifiability gate
# ---------------------------------------------------------------------------


def _to_dt(value: str) -> datetime | None:
    """Best-effort parse of an ISO-8601 date/datetime to an aware UTC datetime."""
    s = (value or "").strip()
    if not s:
        return None
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _resolve_now(now: datetime | str | None) -> datetime:
    """Coerce the injectable ``now`` into an aware UTC datetime (defaults to now)."""
    if now is None:
        return datetime.now(timezone.utc)
    if isinstance(now, datetime):
        return now if now.tzinfo is not None else now.replace(tzinfo=timezone.utc)
    if isinstance(now, str):
        dt = _to_dt(now)
        if dt is None:
            raise ValueError(f"cannot parse now={now!r} as ISO-8601")
        return dt
    raise TypeError(f"now must be datetime|str|None, got {type(now).__name__}")


def _iso_in_future(value: str, now_dt: datetime) -> bool:
    """Is ``value`` (ISO date/datetime) strictly after ``now_dt``?"""
    dt = _to_dt(value)
    if dt is None:
        return (value or "").strip() > now_dt.isoformat()
    return dt > now_dt


_HEDGE_MARKERS = (
    "might ",
    "maybe",
    "possibly",
    "could happen",
    "perhaps",
    "unclear",
    "uncertain",
    "cannot determine",
    "hard to say",
    "too close to call",
)


def _default_falsifiability_gate(
    claim_text: str, event: Event, now_dt: datetime
) -> tuple[bool, str]:
    """The SPEC §6 gate, applied to a forged consensus claim.

    Requires a concrete future ``resolution_date``, objective
    ``resolution_criteria``, and a substantive, non-hedged claim.
    """
    claim = (claim_text or "").strip()
    if len(claim) < 12:
        return False, "claim too short or empty to be falsifiable"
    rd = (event.resolution_date or "").strip()
    if not rd:
        return False, "no resolution_date on the matter"
    if not _iso_in_future(rd, now_dt):
        return False, "resolution_date is not strictly in the future"
    if not (event.resolution_criteria or "").strip():
        return False, "no objective resolution_criteria"
    low = claim.lower()
    for marker in _HEDGE_MARKERS:
        if marker in low:
            return False, f"claim is hedged/unfalsifiable (contains {marker.strip()!r})"
    return True, "ok"


# ---------------------------------------------------------------------------
# Low-level call + persistence
# ---------------------------------------------------------------------------


def _run_model(
    conn,
    provider: LLMProvider,
    system: str,
    user: str,
    *,
    component: str,
    now_iso: str,
    want_json: bool,
    temperature: float,
):
    """Call a provider, log a ``model_runs`` audit row, return the LLMResponse."""
    t0 = time.perf_counter()
    resp = provider.complete(
        system, user, temperature=temperature, want_json=want_json
    )
    latency_ms = int((time.perf_counter() - t0) * 1000)
    db.insert_model_run(
        conn,
        ModelRun(
            component=component,
            model=resp.model,
            prompt_tokens=resp.prompt_tokens,
            completion_tokens=resp.completion_tokens,
            cost=resp.cost,
            latency_ms=latency_ms,
            created_at=now_iso,
        ),
    )
    return resp


def _mage_turn(
    conn,
    provider: LLMProvider,
    event: Event,
    user_prompt: str,
    round_no: int,
    now_iso: str,
) -> _Draft:
    """One mage's turn: call, parse, persist the transcript row, return draft."""
    resp = _run_model(
        conn,
        provider,
        MAGE_SYSTEM,
        user_prompt,
        component=COMPONENT_COUNCIL,
        now_iso=now_iso,
        want_json=True,
        temperature=0.7,
    )
    draft = _parse_draft(resp.text)
    db.insert_deliberation(
        conn,
        Deliberation(
            event_id=event.id,
            round=round_no,
            model=resp.model,
            draft_claim=draft.claim,
            draft_confidence=draft.confidence,
            reasoning=draft.reasoning,
            created_at=now_iso,
        ),
    )
    return draft


def _render_regal_text(
    conn,
    king: LLMProvider,
    agreed_claim: str,
    agreed_direction: str,
    event: Event,
    now_iso: str,
) -> str:
    """Render the King's regal proclamation, defended against refusals.

    The King sometimes declines to proclaim certainty about a real event and
    returns a refusal/disclaimer, which must never become the stored
    ``regal_text``. Three-tier strategy:

    1. **First render** with the ornate :data:`KING_SYSTEM`. If it is non-empty
       and not a refusal, use it (the common path — one King call).
    2. **Retry once** with the firmer, explicitly-theatrical
       :data:`KING_SYSTEM_FIRM` + :func:`_king_retry_prompt`, framing the line as
       in-character creative fiction so a capable model complies.
    3. **Templated fallback** via :func:`_templated_decree` if the King still
       refuses or returns nothing.

    The result is therefore NEVER a refusal and NEVER empty. Every provider call
    — including the retry — is logged as its own ``model_runs`` row by
    :func:`_run_model`, keeping the cost/usage audit honest.
    """
    first = _run_model(
        conn,
        king,
        KING_SYSTEM,
        _king_prompt(agreed_claim, agreed_direction, event),
        component=COMPONENT_KING,
        now_iso=now_iso,
        want_json=False,
        temperature=0.8,
    )
    text = (first.text or "").strip()
    if text and not _looks_like_refusal(text):
        return text

    # The King balked (refusal or empty): retry once, firmer + theatrical.
    retry = _run_model(
        conn,
        king,
        KING_SYSTEM_FIRM,
        _king_retry_prompt(agreed_claim, agreed_direction, event),
        component=COMPONENT_KING,
        now_iso=now_iso,
        want_json=False,
        temperature=0.8,
    )
    retry_text = (retry.text or "").strip()
    if retry_text and not _looks_like_refusal(retry_text):
        return retry_text

    # Still refusing (or empty): deterministic templated proclamation.
    return _templated_decree(agreed_claim)


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def deliberate(
    event: Event,
    mage_a: LLMProvider,
    mage_b: LLMProvider,
    king: LLMProvider,
    conn,
    *,
    max_rounds: int = 3,
    now: datetime | str | None = None,
    falsifiability_gate: FalsifiabilityGate | None = None,
) -> CouncilResult:
    """Run the council deliberation protocol over one matter (SPEC §5).

    Args:
        event: a persisted, ``pending`` :class:`~wkd.models.Event` (must have an id).
        mage_a, mage_b: the two council mages (independent providers).
        king: the styling-pass provider that renders ``regal_text`` on consensus.
        conn: an open SQLite connection from :mod:`wkd.db`.
        max_rounds: convergence cap (SPEC §5; default 3). Consensus is only ever
            declared after at least one exchange round, so ``max_rounds < 2``
            always yields ``divided``.
        now: injectable wall-clock (datetime or ISO string) for deterministic
            ``issued_at`` / ``created_at`` timestamps. Defaults to UTC now.
        falsifiability_gate: optional override of the SPEC §6 re-check; signature
            ``(claim_text, event, now_dt) -> (ok, reason)``.

    Returns:
        A :class:`CouncilResult`. On consensus it carries the forged, persisted
        :class:`~wkd.models.Decree`; otherwise ``decree is None`` and the event's
        status has been moved to ``divided``.
    """
    if event.id is None:
        raise ValueError("event must be persisted (have an id) before deliberation")

    gate = falsifiability_gate or _default_falsifiability_gate
    now_dt = _resolve_now(now)
    now_iso = now_dt.isoformat()

    last_a: _Draft | None = None
    last_b: _Draft | None = None
    rounds_used = 0
    consensus = False

    for round_no in range(1, max_rounds + 1):
        rounds_used = round_no
        if round_no == 1:
            prompt_a = _draft_prompt(event)
            prompt_b = _draft_prompt(event)
        else:
            # Each mage sees ONLY the other's latest draft (exchange & revise).
            prompt_a = _revise_prompt(event, last_a, last_b, round_no)
            prompt_b = _revise_prompt(event, last_b, last_a, round_no)

        draft_a = _mage_turn(conn, mage_a, event, prompt_a, round_no, now_iso)
        draft_b = _mage_turn(conn, mage_b, event, prompt_b, round_no, now_iso)
        last_a, last_b = draft_a, draft_b

        # Consensus only after at least one exchange (round >= 2), per protocol.
        if round_no >= 2 and _reached_consensus(draft_a, draft_b):
            consensus = True
            break

    deliberations = db.list_deliberations(conn, event.id)

    # -- Divided: the King holds his tongue ---------------------------------
    if not consensus:
        db.update_event_status(conn, event.id, EventStatus.DIVIDED)
        return CouncilResult(
            event_id=event.id,
            status=STATUS_DIVIDED,
            rounds=rounds_used,
            decree=None,
            reason="council could not agree within the round cap",
            deliberations=deliberations,
        )

    # -- Consensus: forge the agreed claim ----------------------------------
    agreed_claim = last_a.claim or last_b.claim
    agreed_direction = last_a.direction or last_b.direction
    merged_confidence = round((last_a.confidence + last_b.confidence) / 2.0, 6)

    # Re-check the agreed claim through the falsifiability gate (SPEC §6).
    ok, reason = gate(agreed_claim, event, now_dt)
    if not ok:
        # Ungradeable decree: the King holds his tongue; matter logged divided.
        db.update_event_status(conn, event.id, EventStatus.DIVIDED)
        return CouncilResult(
            event_id=event.id,
            status=STATUS_GATE_FAILED,
            rounds=rounds_used,
            decree=None,
            direction=agreed_direction,
            private_confidence=merged_confidence,
            reason=f"failed falsifiability gate: {reason}",
            deliberations=deliberations,
        )

    # The King renders the regal proclamation (styling pass only). If he balks at
    # proclaiming certainty (a real-world refusal), we retry once with a firmer
    # theatrical framing and finally fall back to a templated decree, so the
    # forged regal_text is never a refusal and never empty (SPEC §5).
    regal_text = _render_regal_text(
        conn, king, agreed_claim, agreed_direction, event, now_iso
    )

    # Forge the decree and mark its event 'decreed' as ONE atomic transaction: a
    # crash between the two would otherwise leave a standing decree on a still-
    # 'pending' event, and the next deliberate sweep (which pulls pending events)
    # would forge a DUPLICATE decree for the same matter.
    with db.transaction(conn):
        decree = db.insert_decree(
            conn,
            Decree(
                event_id=event.id,
                claim_text=agreed_claim,
                regal_text=regal_text,
                direction=agreed_direction,
                private_confidence=merged_confidence,
                consensus_rounds=rounds_used,
                status=DecreeStatus.STANDING,
                issued_at=now_iso,
            ),
            commit=False,
        )
        db.update_event_status(conn, event.id, EventStatus.DECREED, commit=False)

    return CouncilResult(
        event_id=event.id,
        status=STATUS_CONSENSUS,
        rounds=rounds_used,
        decree=decree,
        direction=agreed_direction,
        private_confidence=merged_confidence,
        reason="consensus reached; decree forged",
        deliberations=deliberations,
    )


__all__ = [
    "deliberate",
    "CouncilResult",
    "STATUS_CONSENSUS",
    "STATUS_DIVIDED",
    "STATUS_GATE_FAILED",
    "COMPONENT_COUNCIL",
    "COMPONENT_KING",
    "MAGE_SYSTEM",
    "KING_SYSTEM",
    "KING_SYSTEM_FIRM",
]
