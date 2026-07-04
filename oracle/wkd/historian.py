"""The Court Historian / resolver (SPEC §9, §10, §16).

When a decree's ``resolution_date`` passes, the Historian (Gemini in production —
an *independent* model family, SPEC §3) is summoned to judge it against reality.

Hard independence rules enforced here:

* The Historian sees **only** the literal decree: ``claim_text`` plus the event's
  ``resolution_criteria`` (and the objective ``resolution_date``). It is **never**
  shown the council's deliberation, reasoning, direction, regal styling, or private
  confidence — no anchoring, no contamination (SPEC §3, §16.2).
* Judgement is **search-grounded** (``search=True``) so it rules against real
  reporting, and it must **cite evidence** (SPEC §9, §16.3).
* A verdict requires **≥2 independent corroborating sources**; the harsh tiers
  (apology, cancellation) require **stronger** corroboration still (SPEC §9, §10,
  §16.3). When corroboration is insufficient the Historian **abstains** — no ruling
  is written and the decree stays ``standing`` to be retried on a later sweep.

Persistence is **append-only**: each ruling writes a new ``rulings`` row and a new
``corrections`` row; the decree's status is advanced via
:data:`~wkd.models.TIER_TO_DECREE_STATUS` and its event is marked ``resolved``.
Every Historian call is logged to ``model_runs`` for the cost/usage audit (SPEC
§16.7) — even when the Historian abstains.

The Historian model is **injected** (any :class:`~wkd.providers.LLMProvider`); the
offline test-suite passes a :class:`~wkd.providers.MockProvider` scripting evidence
JSON, so no SDK, network, or API key is touched. The clock is injectable via
``now`` for deterministic tests.
"""

from __future__ import annotations

import json
import re
import time
from datetime import datetime, timezone
from typing import Any, Iterable
from urllib.parse import urlsplit

from .db import (
    get_event,
    insert_correction,
    insert_model_run,
    insert_ruling,
    transaction,
    update_decree_status,
    update_event_status,
)
from .models import (
    HARSH_TIERS,
    TIER_TO_DECREE_STATUS,
    Correction,
    Decree,
    EventStatus,
    ModelRun,
    Ruling,
    Tier,
)
from .providers import LLMProvider, LLMResponse

# ---------------------------------------------------------------------------
# Corroboration policy (SPEC §9, §16.3)
# ---------------------------------------------------------------------------

#: Every verdict on the merits must cite at least this many independent sources.
MIN_CORROBORATION: int = 2
#: The harsh tiers (apology, cancellation) demand stronger corroboration still.
MIN_CORROBORATION_HARSH: int = 3

#: Identifies the Historian to the cost/usage audit (``model_runs.component``).
COMPONENT = "historian"


# ---------------------------------------------------------------------------
# Prompt construction — claim + resolution criteria ONLY (no deliberation)
# ---------------------------------------------------------------------------

_SYSTEM_PROMPT = (
    "You are the Court Historian, an independent judge of royal decrees. You have "
    "no loyalty to the Crown and never saw how the decree was reached — you judge a "
    "claim ONLY against verifiable real-world reporting that you find and cite.\n\n"
    "Use web search to gather current reporting. For any verdict you MUST cite at "
    "least two INDEPENDENT corroborating sources (different outlets, not syndications "
    "of one wire story). The harsh verdicts (apology, cancellation) require stronger "
    "corroboration than that. If you cannot corroborate a finding, say so plainly "
    "rather than guess.\n\n"
    "Assign exactly one verdict on the Ladder of Shame:\n"
    "  - \"vindicated\"   : the claim came true per its resolution criteria.\n"
    "  - \"cliffnotes\"   : right direction, but the details or timing were off.\n"
    "  - \"apology\"      : the claim was substantively, clearly wrong.\n"
    "  - \"cancellation\" : the prophesied event never happened / is unresolvable / "
    "was a non-event.\n\n"
    "Respond with STRICT JSON only, no prose outside it, of the form:\n"
    "{\n"
    '  "verdict": "vindicated|cliffnotes|apology|cancellation",\n'
    '  "reasoning": "<concise justification grounded in the cited evidence>",\n'
    '  "evidence": [\n'
    '    {"source": "<outlet name>", "url": "<link>", "quote": "<relevant excerpt>", '
    '"supports": true}\n'
    "  ]\n"
    "}\n"
    "Each evidence item is one independent source. Set \"supports\" false for a "
    "source that contradicts your verdict."
)


def build_historian_prompt(claim_text: str, resolution_criteria: str,
                           resolution_date: str | None = None) -> tuple[str, str]:
    """Return ``(system, user)`` prompts exposing ONLY the literal decree.

    Deliberation, reasoning, direction, regal text and private confidence are
    deliberately absent (SPEC §16.2 — no anchoring).
    """
    lines = [
        "Judge the following royal decree against real-world reporting.",
        "",
        f"CLAIM: {claim_text}",
    ]
    if resolution_date:
        lines.append(f"RESOLUTION DATE (when reality settles it): {resolution_date}")
    lines.append(
        "RESOLUTION CRITERIA (objective conditions for right/wrong): "
        + (resolution_criteria or "(none supplied — judge the plain meaning of the claim)")
    )
    lines += [
        "",
        "Search for current reporting, cite independent corroborating sources, and "
        "return the strict JSON verdict object.",
    ]
    return _SYSTEM_PROMPT, "\n".join(lines)


# ---------------------------------------------------------------------------
# Response parsing
# ---------------------------------------------------------------------------

_VERDICT_ALIASES: dict[str, Tier] = {
    "vindicated": Tier.VINDICATED,
    "vindication": Tier.VINDICATED,
    "correct": Tier.VINDICATED,
    "true": Tier.VINDICATED,
    "cliffnotes": Tier.CLIFFNOTES,
    "cliff-notes": Tier.CLIFFNOTES,
    "cliff notes": Tier.CLIFFNOTES,
    "partial": Tier.CLIFFNOTES,
    "amendment": Tier.CLIFFNOTES,
    "apology": Tier.APOLOGY,
    "wrong": Tier.APOLOGY,
    "false": Tier.APOLOGY,
    "incorrect": Tier.APOLOGY,
    "cancellation": Tier.CANCELLATION,
    "cancelled": Tier.CANCELLATION,
    "canceled": Tier.CANCELLATION,
    "cancel": Tier.CANCELLATION,
    "non-event": Tier.CANCELLATION,
    "unresolvable": Tier.CANCELLATION,
}


def to_tier(value: Any) -> Tier | None:
    """Map a Historian verdict string onto a :class:`Tier` (None if unknown)."""
    if value is None:
        return None
    return _VERDICT_ALIASES.get(str(value).strip().lower())


def _json_candidates(text: str) -> Iterable[str]:
    """Yield progressively more permissive JSON substrings to try parsing."""
    yield text
    fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if fenced:
        yield fenced.group(1)
    i, j = text.find("{"), text.rfind("}")
    if i != -1 and j != -1 and j > i:
        yield text[i : j + 1]


def _coerce_json(text: str) -> dict | None:
    """Best-effort parse of a (possibly fenced/wrapped) JSON object."""
    if not text or not text.strip():
        return None
    for candidate in _json_candidates(text.strip()):
        try:
            obj = json.loads(candidate)
        except (json.JSONDecodeError, ValueError):
            continue
        if isinstance(obj, dict):
            return obj
    return None


def parse_historian_response(text: str) -> dict | None:
    """Parse a raw Historian completion into a normalized dict, or None.

    Returns ``{"verdict": Tier|None, "evidence": list, "reasoning": str,
    "raw": dict}``. Returns ``None`` if no JSON object can be recovered (the
    Historian then abstains rather than crash the daily driver).
    """
    obj = _coerce_json(text)
    if obj is None:
        return None
    evidence = obj.get("evidence")
    if not isinstance(evidence, list):
        evidence = []
    return {
        "verdict": to_tier(obj.get("verdict")),
        "evidence": evidence,
        "reasoning": str(obj.get("reasoning", "") or ""),
        "raw": obj,
    }


# ---------------------------------------------------------------------------
# Corroboration counting (independence)
# ---------------------------------------------------------------------------


def _supports(value: Any) -> bool:
    """Whether an evidence item is a *supporting* (corroborating) source."""
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() not in ("false", "no", "0", "n", "refutes", "contradicts")
    return True


def _source_key(item: dict) -> str | None:
    """Normalized identity of a source for independence dedup (outlet/domain)."""
    for field in ("source", "publisher", "outlet", "name", "domain"):
        v = item.get(field)
        if isinstance(v, str) and v.strip():
            return v.strip().lower()
    url = item.get("url") or item.get("link")
    if isinstance(url, str) and url.strip():
        net = urlsplit(url.strip()).netloc.lower()
        if net.startswith("www."):
            net = net[4:]
        return net or url.strip().lower()
    return None


def count_independent_sources(evidence: Iterable[Any]) -> int:
    """Count distinct, independent, *supporting* sources in cited evidence.

    Two articles from the same outlet (or the same domain) count once — that is
    the "independent" in "≥2 independent corroborating sources" (SPEC §16.3).
    """
    seen: set[str] = set()
    for item in evidence or []:
        if isinstance(item, str):
            if item.strip():
                seen.add(item.strip().lower())
            continue
        if not isinstance(item, dict):
            continue
        if not _supports(item.get("supports", True)):
            continue
        key = _source_key(item)
        if key:
            seen.add(key)
    return len(seen)


# ---------------------------------------------------------------------------
# The corroboration guard (SPEC §9, §16.3)
# ---------------------------------------------------------------------------


def required_corroboration(tier: Tier) -> int:
    """Independent-source floor for a tier (harsh tiers demand more)."""
    return MIN_CORROBORATION_HARSH if tier in HARSH_TIERS else MIN_CORROBORATION


def guarded_verdict(proposed: Tier | None, n_sources: int) -> Tier | None:
    """Clamp a proposed verdict to what the corroboration can actually support.

    * meets its own floor                       -> the proposed verdict stands.
    * a harsh tier short of the harsh floor but
      with the base ≥2 corroboration            -> downgraded to ``cliffnotes``
      (enough to note a problem, not to condemn or cancel).
    * anything below the base ≥2 floor          -> ``None`` (the Historian
      abstains; no ruling is issued and the decree stays standing).

    This is what stops a single-source "miss" from ever escalating to an apology
    or cancellation (SPEC §16.3).
    """
    if proposed is None:
        return None
    if n_sources >= required_corroboration(proposed):
        return proposed
    if proposed in HARSH_TIERS and n_sources >= MIN_CORROBORATION:
        return Tier.CLIFFNOTES
    return None


# ---------------------------------------------------------------------------
# Correction copy (SPEC §10) — stdlib f-strings only
# ---------------------------------------------------------------------------

_CORRECTION_TEMPLATES: dict[Tier, str] = {
    Tier.VINDICATED: (
        "⚜️ VINDICATED. The Crown's decree stands sealed: “{claim}”. "
        "Reality has borne out the prophecy; let it be recorded as a victory of the Council."
    ),
    Tier.CLIFFNOTES: (
        "\U0001f4cc CLIFFNOTES. The decree — “{claim}” — caught the right "
        "current but missed the particulars. The record is amended accordingly."
    ),
    Tier.APOLOGY: (
        "\U0001f647 APOLOGY. The Crown was wrong. The decree “{claim}” did not come "
        "to pass as proclaimed. The King humbles himself before the realm and the record is "
        "rewritten."
    ),
    Tier.CANCELLATION: (
        "\U0001f6ab CANCELLATION. The prophesied matter — “{claim}” — never "
        "came to be. The event is hereby cancelled and struck from the rolls."
    ),
}


def correction_copy(tier: Tier, claim_text: str, reasoning: str = "") -> str:
    """Render the published correction/seal text for a verdict (SPEC §10)."""
    base = _CORRECTION_TEMPLATES[tier].format(claim=claim_text)
    if reasoning.strip():
        base = f"{base}\n\nHistorian's finding: {reasoning.strip()}"
    return base


# ---------------------------------------------------------------------------
# Clock
# ---------------------------------------------------------------------------


def _utcnow_iso() -> str:
    """Current UTC time as a fixed-width ISO-8601 string (lexicographically sortable)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# The summons
# ---------------------------------------------------------------------------


def rule(
    decree: Decree,
    historian_provider: LLMProvider,
    db: Any,
    *,
    now: str | None = None,
    temperature: float = 0.2,
    max_tokens: int = 2048,
) -> Ruling | None:
    """Summon the Court Historian to judge ``decree`` against reality.

    ``db`` is an open :class:`sqlite3.Connection` (the database of record).
    ``historian_provider`` is any :class:`~wkd.providers.LLMProvider`; in
    production a search-grounded Gemini, in tests a scripted ``MockProvider``.

    Returns the persisted :class:`~wkd.models.Ruling` on a successful judgement,
    or ``None`` when the Historian **abstains** (response unparseable, no verdict,
    or corroboration below the ≥2 floor) — in which case nothing is written to
    ``rulings``/``corrections`` and the decree is left ``standing`` for a later
    sweep. The Historian's call is logged to ``model_runs`` either way.

    Side effects on success (append-only, SPEC §16.8):
      * a new ``rulings`` row,
      * a new ``corrections`` row,
      * the decree status advanced per :data:`TIER_TO_DECREE_STATUS`,
      * the event marked ``resolved``,
      * a ``model_runs`` audit row.
    """
    if decree.id is None:
        raise ValueError("cannot rule on an unsaved decree (decree.id is None)")
    ts = now or _utcnow_iso()

    event = get_event(db, decree.event_id)
    if event is None:
        raise ValueError(f"decree {decree.id} references missing event {decree.event_id}")

    # Build the prompt from the literal decree ONLY — never the deliberation.
    system, user = build_historian_prompt(
        claim_text=decree.claim_text,
        resolution_criteria=event.resolution_criteria,
        resolution_date=event.resolution_date,
    )

    # Search-grounded, JSON-mode judgement; time it for the cost/usage audit.
    started = time.perf_counter()
    resp: LLMResponse = historian_provider.complete(
        system,
        user,
        temperature=temperature,
        max_tokens=max_tokens,
        want_json=True,
        search=True,
    )
    latency_ms = int((time.perf_counter() - started) * 1000)

    # Audit the call regardless of whether a verdict is ultimately issued.
    insert_model_run(
        db,
        ModelRun(
            component=COMPONENT,
            model=resp.model,
            prompt_tokens=resp.prompt_tokens,
            completion_tokens=resp.completion_tokens,
            cost=resp.cost,
            latency_ms=latency_ms,
            created_at=ts,
        ),
    )

    parsed = parse_historian_response(resp.text)
    if parsed is None or parsed["verdict"] is None:
        return None  # abstain: unparseable or no recognizable verdict

    proposed: Tier = parsed["verdict"]
    evidence = parsed["evidence"]
    n_sources = count_independent_sources(evidence)

    verdict = guarded_verdict(proposed, n_sources)
    if verdict is None:
        return None  # abstain: corroboration below the ≥2 floor

    # Persist the verdict as ONE atomic transaction (SPEC §16.8): the ruling, its
    # correction, and the decree/event status advances either ALL land or NONE do.
    # A crash mid-sequence would otherwise leave a ruling+correction stamped while
    # the decree stayed ``standing`` — and the next idempotent driver sweep would
    # re-judge it and append a DUPLICATE ruling/correction. Committing atomically
    # makes the standing→resolved transition land with the ruling, so a re-run
    # never sees a half-judged decree (the decree is no longer ``standing``/due).
    evidence_record = {
        "proposed_verdict": str(proposed),
        "final_verdict": str(verdict),
        "downgraded": verdict != proposed,
        "independent_sources": n_sources,
        "required": required_corroboration(proposed),
        "evidence": evidence,
    }
    with transaction(db):
        ruling = insert_ruling(
            db,
            Ruling(
                decree_id=decree.id,
                verdict=verdict,
                historian_model=resp.model,
                evidence_json=json.dumps(evidence_record, ensure_ascii=False),
                corroborating_sources=n_sources,
                reasoning=parsed["reasoning"],
                ruled_at=ts,
            ),
            commit=False,
        )
        # The published correction/seal copy (append-only).
        insert_correction(
            db,
            Correction(
                ruling_id=ruling.id,
                decree_id=decree.id,
                tier=verdict,
                correction_text=correction_copy(verdict, decree.claim_text, parsed["reasoning"]),
                published_at=ts,
            ),
            commit=False,
        )
        # Advance decree + event status (the decree is superseded in spirit, never edited).
        update_decree_status(db, decree.id, TIER_TO_DECREE_STATUS[verdict], commit=False)
        update_event_status(db, decree.event_id, EventStatus.RESOLVED, commit=False)

    return ruling


__all__ = [
    "rule",
    "build_historian_prompt",
    "parse_historian_response",
    "to_tier",
    "count_independent_sources",
    "guarded_verdict",
    "required_corroboration",
    "correction_copy",
    "MIN_CORROBORATION",
    "MIN_CORROBORATION_HARSH",
    "COMPONENT",
]
