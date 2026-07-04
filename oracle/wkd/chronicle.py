"""The Chronicle — static-site generator for The Wizard King's Decree (SPEC §12).

``generate(db, out_dir)`` renders a small, browsable, self-contained static site
from the SQLite store:

* ``index.html``      — the Scoreboard + an illuminated list of every decree.
* ``decree-<id>.html``— one article per decree, with a correction banner stamped
  on the wrong ones (cliffnotes / apology / cancellation) and a victory seal on
  the vindicated ones. The council's private reasoning + confidence are revealed
  **only after a ruling** (SPEC §12).
* ``divided.html``    — the Divided Ledger: matters the King declined to prophesy.
* ``style.css``       — themed stylesheet (royal purple + gold).

The generator is **read-only** with respect to the database and fully
**idempotent**: every run overwrites the output files from the current DB state,
so it is safe to call after each daily driver pass.

Templating uses the **standard library only** (``string.Template`` for the page
shell + f-strings for fragments) — no jinja2. All dynamic content is escaped
with :func:`html.escape`. The scoreboard reads ``scoring.compute_metrics``'s
``metrics_json`` defensively (it tolerates missing keys and alternate names) so
the chronicle never crashes on a partially-populated DB.
"""

from __future__ import annotations

import html
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from string import Template
from typing import Any, Union

from . import db as _db
from .models import DecreeStatus, EventStatus, Tier

ConnOrPath = Union[str, Path, sqlite3.Connection]

# Output file names (stable so the driver / serve command can rely on them).
INDEX_FILE = "index.html"
DIVIDED_FILE = "divided.html"
STYLE_FILE = "style.css"


def decree_filename(decree_id: int | None) -> str:
    """Article file name for a decree id (e.g. ``decree-7.html``)."""
    return f"decree-{decree_id}.html"


# ---------------------------------------------------------------------------
# Tier / status presentation
# ---------------------------------------------------------------------------

# glyph, human label, css class — keyed by the Historian's Tier vocabulary.
_TIER_DISPLAY: dict[str, tuple[str, str, str]] = {
    Tier.VINDICATED.value: ("⚜️", "Vindicated", "banner-vindicated"),
    Tier.CLIFFNOTES.value: ("\U0001f4cc", "Cliffnotes", "banner-cliffnotes"),
    Tier.APOLOGY.value: ("\U0001f647", "Apology & Correction", "banner-apology"),
    Tier.CANCELLATION.value: ("\U0001f6ab", "Cancellation", "banner-cancellation"),
}

# Decree status -> the Tier vocabulary used for banner styling. The decree's
# terminal "cancelled" status maps onto the Historian's "cancellation" tier.
_STATUS_TO_TIER: dict[str, str] = {
    DecreeStatus.VINDICATED.value: Tier.VINDICATED.value,
    DecreeStatus.CLIFFNOTES.value: Tier.CLIFFNOTES.value,
    DecreeStatus.APOLOGY.value: Tier.APOLOGY.value,
    DecreeStatus.CANCELLED.value: Tier.CANCELLATION.value,
}

# Non-tier terminal decree states from the weekly checkpoint (SPEC §8, §16.8):
# glyph, human label, css suffix. These never carry a Historian ruling.
_EXTRA_STATUS_DISPLAY: dict[str, tuple[str, str, str]] = {
    DecreeStatus.WITHDRAWN.value: ("✖", "Withdrawn", "withdrawn"),
    DecreeStatus.SUPERSEDED.value: ("↻", "Superseded", "superseded"),
}

# Default banner copy when the Historian left no explicit correction text.
_DEFAULT_BANNER_TEXT: dict[str, str] = {
    Tier.VINDICATED.value: "The prophecy came to pass. The decree stands sealed.",
    Tier.CLIFFNOTES.value: "Right in spirit, astray in detail. An amendment is appended.",
    Tier.APOLOGY.value: "The King was wrong. A groveling correction is recorded.",
    Tier.CANCELLATION.value: "The prophesied event never came. The decree is hereby cancelled.",
}


# ---------------------------------------------------------------------------
# Page shell (string.Template — stdlib only)
# ---------------------------------------------------------------------------

_PAGE = Template(
    """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<link rel="stylesheet" href="$css_href">
</head>
<body>
<header class="royal-header">
  <div class="crown" aria-hidden="true">\U0001f451</div>
  <h1><a href="index.html">The Wizard King's Decree</a></h1>
  <p class="subtitle">$subtitle</p>
  <nav class="royal-nav">
    <a href="index.html">The Scoreboard</a>
    <a href="divided.html">The Divided Ledger</a>
  </nav>
</header>
<main>
$body
</main>
<footer class="royal-footer">
  <p>Rigor in robes &mdash; the auditable chronicle of the King's record.</p>
  <p class="stamp">Sealed $generated_at.</p>
</footer>
</body>
</html>
"""
)


def _esc(value: Any) -> str:
    """HTML-escape any value (``None`` becomes an empty string)."""
    return html.escape("" if value is None else str(value))


def _page(title: str, subtitle: str, body: str, generated_at: str) -> str:
    """Wrap a body fragment in the themed page shell.

    ``safe_substitute`` is used so stray ``$`` in dynamic content (e.g. "$100")
    never raises; placeholders are filled from the mapping only, and values are
    inserted verbatim (Template does not re-scan substituted values).
    """
    return _PAGE.safe_substitute(
        title=_esc(title),
        subtitle=_esc(subtitle),
        css_href=STYLE_FILE,
        body=body,
        generated_at=_esc(generated_at),
    )


# ---------------------------------------------------------------------------
# Metrics helpers (defensive: scoring may name keys differently)
# ---------------------------------------------------------------------------


def _pct(value: Any) -> str:
    """Format a 0..1 rate as a one-decimal percentage; ``"n/a"`` if not numeric."""
    try:
        return f"{float(value) * 100:.1f}%"
    except (TypeError, ValueError):
        return "n/a"


def _as_rate(value: Any) -> float | None:
    """Coerce a metric (number, or dict carrying hit_rate/accuracy) to a rate."""
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, dict):
        for k in ("hit_rate", "accuracy", "rate", "value"):
            if isinstance(value.get(k), (int, float)):
                return float(value[k])
    return None


def _metric(metrics: dict, *keys: str, default: Any = None) -> Any:
    """First present value among ``keys`` (tolerates scoring's naming variants)."""
    for k in keys:
        if k in metrics and metrics[k] is not None:
            return metrics[k]
    return default


def _scalar(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _hit_rate_block(metrics: dict) -> tuple[Any, Any, Any, tuple | None]:
    """Pull ``(ruled, vindicated, rate, ci)`` from scoring's nested ``hit_rate``.

    scoring.build_metrics emits ``hit_rate={ruled, vindicated, rate, ci_low,
    ci_high}``; this reads that contract directly (the prior code looked for flat
    top-level keys that scoring never emits, blanking the whole scoreboard). A flat
    ``{hit_rate: 0.4, ...}`` shape is still tolerated as a fallback.
    """
    hr = metrics.get("hit_rate")
    if isinstance(hr, dict):
        ruled = hr.get("ruled", 0)
        vindicated = hr.get("vindicated", 0)
        rate = hr.get("rate")
        ci = None
        if _scalar(hr.get("ci_low")) and _scalar(hr.get("ci_high")):
            ci = (hr["ci_low"], hr["ci_high"])
        return ruled, vindicated, rate, ci
    # flat fallback (legacy / partial snapshots)
    ruled = _metric(metrics, "ruled", "ruled_count", "n_ruled", default=0)
    vindicated = _metric(metrics, "vindicated", "vindicated_count", default=0)
    rate = _metric(metrics, "hit_rate", "accuracy")
    ci_flat = _metric(metrics, "hit_rate_ci", "ci", "bootstrap_ci")
    ci = tuple(ci_flat) if isinstance(ci_flat, (list, tuple)) and len(ci_flat) == 2 else None
    return ruled, vindicated, rate, ci


def _nested_rate(metrics: dict, key: str, field_name: str, *flat: str) -> Any:
    """Read ``metrics[key][field_name]`` (scoring's nested shape), else a flat key."""
    obj = metrics.get(key)
    if isinstance(obj, dict) and _scalar(obj.get(field_name)):
        return obj[field_name]
    return _metric(metrics, *flat)


def _tier_counts(metrics: dict) -> dict | None:
    """Per-tier counts from scoring's ``tier_distribution['counts']`` (or a flat map).

    scoring emits ``tier_distribution={counts:{tier:n}, fractions:{...}, ruled:N}``;
    iterating ``tier_distribution`` directly (the prior bug) yielded the rows
    ``counts``/``fractions``/``ruled`` instead of per-tier counts. We reach into
    ``counts`` first, then tolerate a flat ``{tier: n}`` shape.
    """
    td = metrics.get("tier_distribution")
    if isinstance(td, dict):
        counts = td.get("counts")
        if isinstance(counts, dict) and counts:
            return counts
        if td and all(_scalar(v) for v in td.values()):
            return td
    for k in ("tiers", "tier_counts"):
        v = metrics.get(k)
        if isinstance(v, dict) and v and all(_scalar(x) for x in v.values()):
            return v
    return None


def _beat_the_crowd_card(metrics: dict) -> tuple[str, str] | None:
    """A displayable Beat-the-Crowd card from scoring's nested ``beat_the_crowd``.

    scoring emits ``beat_the_crowd={n, council_brier, market_brier,
    council_beats_market_brier, council_correct, market_correct, ...}`` — with no
    ``rate`` field, which is why ``_as_rate`` silently dropped the card. We surface
    the council's directional accuracy on market-sourced matters (council_correct /
    n) plus a Brier comparison against the crowd. Omitted entirely when there are
    no market-sourced rulings (``n == 0``).
    """
    beat = metrics.get("beat_the_crowd")
    if isinstance(beat, dict):
        n = beat.get("n", 0)
        if not n:
            return None
        cc = beat.get("council_correct")
        if _scalar(cc):
            value = _pct(_safe_div(cc, n))
        else:
            rate = _as_rate(beat)
            value = _pct(rate) if rate is not None else "n/a"
        cb, mb = beat.get("council_brier"), beat.get("market_brier")
        if _scalar(cb) and _scalar(mb):
            verb = "beats" if beat.get("council_beats_market_brier") else "trails"
            note = (
                f' <span class="ci">Brier {cb:.3f} {verb} crowd {mb:.3f} '
                f"(n={_esc(n)})</span>"
            )
            value = f"{value}{note}"
        return ("Beat the Crowd", value)
    # flat fallback (legacy)
    rate = _as_rate(beat)
    return ("Beat the Crowd", _pct(rate)) if rate is not None else None


def _safe_div(num: Any, den: Any) -> float | None:
    try:
        return float(num) / float(den) if den else 0.0
    except (TypeError, ValueError, ZeroDivisionError):
        return None


def _render_scoreboard(metrics: dict | None) -> str:
    """Render the Scoreboard section from scoring's metrics_json (SPEC §11, §12)."""
    if not metrics:
        return (
            '<section class="scoreboard">\n'
            "  <h2>The Scoreboard</h2>\n"
            '  <p class="muted">No reckonings have been tallied yet. '
            "The Court Historian has not yet ruled.</p>\n"
            "</section>"
        )

    ruled, vindicated, hit_rate, ci = _hit_rate_block(metrics)
    baseline = _nested_rate(
        metrics, "baseline", "status_quo_hit_rate",
        "baseline_hit_rate", "baseline", "status_quo_hit_rate",
    )
    divided_rate = _nested_rate(
        metrics, "divided", "divided_rate", "divided_rate", "council_divided_rate"
    )

    ci_str = ""
    if isinstance(ci, (list, tuple)) and len(ci) == 2:
        ci_str = f' <span class="ci">95% CI [{_pct(ci[0])}, {_pct(ci[1])}]</span>'

    cards = [
        ("Hit Rate", f"{_pct(hit_rate)}{ci_str}"),
        ("Vindicated", f"{_esc(vindicated)} of {_esc(ruled)} ruled"),
        ("Status-Quo Baseline", _pct(baseline)),
        ("Council Divided", _pct(divided_rate)),
    ]
    beat_card = _beat_the_crowd_card(metrics)
    if beat_card is not None:
        cards.append(beat_card)

    cards_html = "\n".join(
        f'    <div class="stat"><span class="stat-label">{_esc(label)}</span>'
        f'<span class="stat-value">{val}</span></div>'
        for label, val in cards
    )

    parts = [
        '<section class="scoreboard">',
        "  <h2>The Scoreboard</h2>",
        '  <div class="stat-grid">',
        cards_html,
        "  </div>",
    ]

    # Tier distribution table (the actual per-tier counts).
    tier_counts = _tier_counts(metrics)
    if isinstance(tier_counts, dict) and tier_counts:
        rows = "\n".join(
            f"      <tr><td>{_esc(_TIER_DISPLAY.get(str(t), ('', str(t), ''))[1])}</td>"
            f"<td>{_esc(n)}</td></tr>"
            for t, n in tier_counts.items()
        )
        parts += [
            '  <h3>The Ladder of Shame</h3>',
            '  <table class="metrics-table tier-table">',
            "    <thead><tr><th>Tier</th><th>Count</th></tr></thead>",
            f"    <tbody>\n{rows}\n    </tbody>",
            "  </table>",
        ]

    # Per-domain accuracy table.
    per_domain = _metric(metrics, "per_domain_accuracy", "per_domain", "domain_accuracy")
    if isinstance(per_domain, dict) and per_domain:
        rows = "\n".join(
            f"      <tr><td>{_esc(dom)}</td><td>{_pct(_as_rate(acc))}</td></tr>"
            for dom, acc in per_domain.items()
        )
        parts += [
            "  <h3>Per-Domain Accuracy</h3>",
            '  <table class="metrics-table domain-table">',
            "    <thead><tr><th>Domain</th><th>Hit Rate</th></tr></thead>",
            f"    <tbody>\n{rows}\n    </tbody>",
            "  </table>",
        ]

    # Harvested vs free-pick, tracked separately (SPEC §11).
    by_source = _metric(metrics, "by_source", "source_breakdown")
    if isinstance(by_source, dict) and by_source:
        rows = "\n".join(
            f"      <tr><td>{_esc(src)}</td><td>{_pct(_as_rate(val))}</td></tr>"
            for src, val in by_source.items()
        )
        parts += [
            "  <h3>Harvested vs Free-Pick</h3>",
            '  <table class="metrics-table source-table">',
            "    <thead><tr><th>Source</th><th>Hit Rate</th></tr></thead>",
            f"    <tbody>\n{rows}\n    </tbody>",
            "  </table>",
        ]

    # Raw snapshot, collapsed — nothing scoring emits is ever lost.
    raw = _esc(json.dumps(metrics, indent=2, sort_keys=True))
    parts += [
        "  <details class=\"raw-metrics\">",
        "    <summary>Raw metrics snapshot</summary>",
        f"    <pre>{raw}</pre>",
        "  </details>",
        "</section>",
    ]
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Evidence / citations
# ---------------------------------------------------------------------------


def _render_evidence(evidence_json: str) -> str:
    """Render the Historian's cited evidence (best-effort, JSON-tolerant)."""
    if not evidence_json:
        return ""
    try:
        data = json.loads(evidence_json)
    except (ValueError, TypeError):
        return f'<p class="evidence-raw">{_esc(evidence_json)}</p>'

    items = data
    if isinstance(data, dict):
        # common shapes: {"sources": [...]} / {"citations": [...]}
        for k in ("sources", "citations", "evidence"):
            if isinstance(data.get(k), list):
                items = data[k]
                break
        else:
            items = [data]
    if not isinstance(items, list) or not items:
        return ""

    lis = []
    for it in items:
        if isinstance(it, dict):
            title = it.get("title") or it.get("name") or it.get("source") or it.get("url") or "source"
            url = it.get("url") or it.get("link")
            if url:
                lis.append(
                    f'<li><a href="{_esc(url)}" rel="noopener noreferrer">{_esc(title)}</a></li>'
                )
            else:
                lis.append(f"<li>{_esc(title)}</li>")
        else:
            lis.append(f"<li>{_esc(it)}</li>")
    return (
        '<div class="evidence">\n  <h4>Cited Evidence</h4>\n  <ul>\n    '
        + "\n    ".join(lis)
        + "\n  </ul>\n</div>"
    )


# ---------------------------------------------------------------------------
# Decree banner + article
# ---------------------------------------------------------------------------


def _status_chip(status: str) -> str:
    if status == DecreeStatus.STANDING.value:
        return '<span class="chip chip-standing">Standing</span>'
    if status in _EXTRA_STATUS_DISPLAY:
        _glyph, label, css = _EXTRA_STATUS_DISPLAY[status]
        return f'<span class="chip chip-{_esc(css)}">{_esc(label)}</span>'
    cls = _STATUS_TO_TIER.get(status, "standing")
    label = _TIER_DISPLAY.get(_STATUS_TO_TIER.get(status, ""), ("", status, ""))[1]
    return f'<span class="chip chip-{_esc(cls)}">{_esc(label)}</span>'


def _render_banner(decree, corrections, ruling) -> str:
    """The correction / victory banner stamped onto a ruled decree."""
    status = str(decree.status)
    if status == DecreeStatus.STANDING.value:
        return (
            '<div class="banner banner-standing">'
            "<strong>Awaiting the reckoning.</strong> "
            "Reality has not yet settled this prophecy.</div>"
        )
    if status == DecreeStatus.WITHDRAWN.value:
        return (
            '<div class="banner banner-withdrawn">'
            '<span class="banner-glyph" aria-hidden="true">✖</span> '
            '<span class="banner-tier">Withdrawn</span>'
            '<p class="banner-text">The council retracted this prophecy before '
            "reality could judge it. It does not count for or against the King.</p>"
            "</div>"
        )
    if status == DecreeStatus.SUPERSEDED.value:
        return (
            '<div class="banner banner-superseded">'
            '<span class="banner-glyph" aria-hidden="true">↻</span> '
            '<span class="banner-tier">Superseded</span>'
            '<p class="banner-text">A later, amended decree has superseded this '
            "proclamation. The original record stands unedited.</p>"
            "</div>"
        )

    # Prefer the Historian's published correction copy; fall back to the tier
    # implied by the decree status.
    tier = None
    text = ""
    if corrections:
        latest = corrections[-1]
        tier = str(latest.tier)
        text = latest.correction_text or ""
    if tier is None:
        tier = _STATUS_TO_TIER.get(status, Tier.CLIFFNOTES.value)
    if not text:
        text = _DEFAULT_BANNER_TEXT.get(tier, "")

    glyph, label, css = _TIER_DISPLAY.get(
        tier, ("", tier, "banner-cliffnotes")
    )
    corroboration = ""
    if ruling is not None:
        corroboration = (
            f'<span class="corroboration">{_esc(ruling.corroborating_sources)} '
            "corroborating sources</span>"
        )
    return (
        f'<div class="banner {_esc(css)}">'
        f'<span class="banner-glyph" aria-hidden="true">{glyph}</span> '
        f'<span class="banner-tier">{_esc(label)}</span>'
        f'<p class="banner-text">{_esc(text)}</p>'
        f"{corroboration}"
        "</div>"
    )


def _render_reasoning(deliberations) -> str:
    """The council's private reasoning, revealed only after a ruling."""
    if not deliberations:
        return ""
    rows = []
    for d in deliberations:
        rows.append(
            '<div class="delib">'
            f'<div class="delib-head"><span class="delib-model">{_esc(d.model)}</span>'
            f'<span class="delib-round">round {_esc(d.round)}</span>'
            f'<span class="delib-conf">confidence {_esc(d.draft_confidence)}</span></div>'
            f'<p class="delib-claim">{_esc(d.draft_claim)}</p>'
            f'<p class="delib-reasoning">{_esc(d.reasoning)}</p>'
            "</div>"
        )
    return (
        '<section class="council-reasoning">\n'
        "  <h3>The Council's Reasoning <span class=\"muted\">(revealed after ruling)</span></h3>\n  "
        + "\n  ".join(rows)
        + "\n</section>"
    )


def _render_decree_article(
    decree, event, corrections, rulings, deliberations, generated_at: str
) -> str:
    """Full HTML for one decree's article page."""
    status = str(decree.status)
    ruling = rulings[-1] if rulings else None
    # Reveal the council's private reasoning + confidence ONLY after a real
    # Historian ruling (SPEC §12). Terminal-but-unjudged states (withdrawn /
    # superseded) carry no ruling, so they reveal nothing.
    is_ruled = ruling is not None

    headline = decree.regal_text or decree.claim_text
    domain = event.domain if event else ""
    res_date = (event.resolution_date if event else None) or "an appointed hour"
    res_criteria = (event.resolution_criteria if event else "") or ""

    banner = _render_banner(decree, corrections, ruling)

    reckoning = ""
    if is_ruled and ruling is not None:
        reckoning = (
            '<section class="reckoning">\n'
            "  <h3>The Reckoning</h3>\n"
            f'  <p class="verdict">Verdict: <strong>{_esc(ruling.verdict)}</strong>'
            f' &mdash; judged by {_esc(ruling.historian_model)}.</p>\n'
            f'  <p class="historian-reasoning">{_esc(ruling.reasoning)}</p>\n'
            f"  {_render_evidence(ruling.evidence_json)}\n"
            "</section>"
        )

    # Council reasoning + private confidence revealed only after a ruling.
    reasoning = ""
    if is_ruled:
        reasoning = _render_reasoning(deliberations)

    confidence_block = ""
    if is_ruled:
        confidence_block = (
            f'<p class="private-confidence">The council\'s private confidence was '
            f'<strong>{_esc(decree.private_confidence)}</strong>, reached over '
            f'{_esc(decree.consensus_rounds)} round(s) of deliberation.</p>'
        )

    body = f"""<article class="decree decree-{_esc(status)}">
  <div class="decree-meta">
    <span class="chip chip-domain">{_esc(domain)}</span>
    {_status_chip(status)}
  </div>
  <blockquote class="regal">{_esc(headline)}</blockquote>
  {banner}
  <section class="claim">
    <h3>The Claim</h3>
    <p>{_esc(decree.claim_text)}</p>
    <p class="resolution">Reality settles this by <strong>{_esc(res_date)}</strong>.</p>
    <p class="criteria"><em>Resolution criteria:</em> {_esc(res_criteria)}</p>
  </section>
  {reckoning}
  {confidence_block}
  {reasoning}
  <p class="back"><a href="index.html">&larr; Back to the Scoreboard</a></p>
</article>"""

    subtitle = f"Decree #{_esc(decree.id)} — {_esc(domain)}"
    return _page(f"Decree #{decree.id}", subtitle, body, generated_at)


def _render_decree_card(decree, event, corrections) -> str:
    """A compact entry for the index list."""
    status = str(decree.status)
    headline = decree.regal_text or decree.claim_text
    domain = event.domain if event else ""
    href = decree_filename(decree.id)

    flag = ""
    if status != DecreeStatus.STANDING.value and corrections:
        tier = str(corrections[-1].tier)
        glyph, label, _css = _TIER_DISPLAY.get(tier, ("", tier, ""))
        flag = f'<span class="card-flag">{glyph} {_esc(label)}</span>'
    elif status in _EXTRA_STATUS_DISPLAY:
        glyph, label, _css = _EXTRA_STATUS_DISPLAY[status]
        flag = f'<span class="card-flag">{glyph} {_esc(label)}</span>'
    elif status != DecreeStatus.STANDING.value:
        tier = _STATUS_TO_TIER.get(status, "")
        glyph, label, _css = _TIER_DISPLAY.get(tier, ("", status, ""))
        flag = f'<span class="card-flag">{glyph} {_esc(label)}</span>'

    return (
        f'<li class="decree-card decree-{_esc(status)}">\n'
        f'  <div class="card-meta"><span class="chip chip-domain">{_esc(domain)}</span>'
        f"{_status_chip(status)}{flag}</div>\n"
        f'  <a class="card-headline" href="{_esc(href)}">{_esc(headline)}</a>\n'
        "</li>"
    )


# ---------------------------------------------------------------------------
# Index + Divided Ledger pages
# ---------------------------------------------------------------------------


def _render_index(decrees_ctx, metrics, divided_count, generated_at: str) -> str:
    scoreboard = _render_scoreboard(metrics)

    if decrees_ctx:
        cards = "\n".join(
            _render_decree_card(d, ev, corr) for (d, ev, corr) in decrees_ctx
        )
        decrees_section = (
            '<section class="decree-roll">\n'
            "  <h2>The Roll of Decrees</h2>\n"
            f'  <ul class="decree-list">\n{cards}\n  </ul>\n'
            "</section>"
        )
    else:
        decrees_section = (
            '<section class="decree-roll">\n'
            "  <h2>The Roll of Decrees</h2>\n"
            '  <p class="muted">The King has issued no decrees yet.</p>\n'
            "</section>"
        )

    divided_link = (
        f'<section class="divided-teaser">\n'
        f'  <p><a href="divided.html">The Divided Ledger</a> &mdash; '
        f"{_esc(divided_count)} matter(s) the King declined to prophesy.</p>\n"
        "</section>"
    )

    body = f"{scoreboard}\n{decrees_section}\n{divided_link}"
    return _page(
        "The Wizard King's Decree",
        "A council of mages, forced to prophesy. An independent Historian, keeping score.",
        body,
        generated_at,
    )


def _render_divided(events, generated_at: str) -> str:
    if events:
        items = "\n".join(
            (
                '  <li class="divided-item">\n'
                f'    <div class="card-meta"><span class="chip chip-domain">{_esc(ev.domain)}</span></div>\n'
                f'    <h3>{_esc(ev.title)}</h3>\n'
                f'    <p>{_esc(ev.description)}</p>\n'
                "  </li>"
            )
            for ev in events
        )
        body = (
            '<section class="divided">\n'
            "  <h2>The Divided Ledger</h2>\n"
            "  <p>Matters on which the Council could not converge. The King held his "
            "tongue &mdash; a measurement of genuine uncertainty, not a failure.</p>\n"
            f'  <ul class="divided-list">\n{items}\n  </ul>\n'
            "</section>"
        )
    else:
        body = (
            '<section class="divided">\n'
            "  <h2>The Divided Ledger</h2>\n"
            '  <p class="muted">The Council has converged on every matter so far. '
            "The ledger is empty.</p>\n"
            "</section>"
        )
    return _page(
        "The Divided Ledger",
        "Matters the King declined to prophesy.",
        body,
        generated_at,
    )


# ---------------------------------------------------------------------------
# Stylesheet (stdlib string constant)
# ---------------------------------------------------------------------------

_STYLE = """\
:root{
  --royal:#2a1a4a; --royal-deep:#1a0f33; --gold:#d4af37; --parchment:#f6f1e3;
  --ink:#241c14; --muted:#7a6f60;
  --vindicated:#2e7d4f; --cliffnotes:#b8860b; --apology:#b5532b; --cancellation:#8a2230;
}
*{box-sizing:border-box}
body{margin:0;font-family:Georgia,'Times New Roman',serif;background:var(--parchment);
  color:var(--ink);line-height:1.6}
a{color:var(--royal);text-decoration:none}
a:hover{text-decoration:underline}
.royal-header{background:linear-gradient(160deg,var(--royal),var(--royal-deep));
  color:var(--parchment);text-align:center;padding:2rem 1rem;border-bottom:4px solid var(--gold)}
.royal-header h1 a{color:var(--gold);font-size:2.2rem;letter-spacing:1px}
.crown{font-size:2.5rem}
.subtitle{font-style:italic;color:#d9cfe6;margin:.3rem 0 0}
.royal-nav{margin-top:1rem}
.royal-nav a{color:var(--parchment);margin:0 .8rem;border-bottom:1px solid var(--gold)}
main{max-width:880px;margin:0 auto;padding:1.5rem 1.25rem}
h2{color:var(--royal);border-bottom:2px solid var(--gold);padding-bottom:.3rem}
.muted,.muted *{color:var(--muted)}
.stat-grid{display:flex;flex-wrap:wrap;gap:1rem;margin:1rem 0}
.stat{flex:1 1 160px;background:#fff;border:1px solid #e3dcc8;border-left:4px solid var(--gold);
  border-radius:4px;padding:.8rem 1rem}
.stat-label{display:block;font-size:.8rem;text-transform:uppercase;letter-spacing:1px;color:var(--muted)}
.stat-value{display:block;font-size:1.5rem;font-weight:bold;color:var(--royal)}
.ci{font-size:.8rem;font-weight:normal;color:var(--muted)}
.metrics-table{width:100%;border-collapse:collapse;margin:.5rem 0 1.5rem}
.metrics-table th,.metrics-table td{border:1px solid #e3dcc8;padding:.4rem .7rem;text-align:left}
.metrics-table thead{background:var(--royal);color:var(--parchment)}
.raw-metrics{margin-top:1rem}
.raw-metrics pre{background:#1a0f33;color:#e8e0cf;padding:1rem;overflow:auto;border-radius:4px}
.decree-list,.divided-list{list-style:none;padding:0}
.decree-card,.divided-item{background:#fff;border:1px solid #e3dcc8;border-radius:5px;
  padding:1rem;margin:.8rem 0}
.card-meta,.decree-meta{display:flex;gap:.5rem;align-items:center;flex-wrap:wrap;margin-bottom:.4rem}
.card-headline{font-size:1.15rem;font-weight:bold}
.card-flag{margin-left:auto;font-weight:bold}
.chip{font-size:.72rem;text-transform:uppercase;letter-spacing:.5px;padding:.15rem .5rem;
  border-radius:999px;background:#ece6d6;color:var(--ink);border:1px solid #d8cfb8}
.chip-domain{background:var(--royal);color:var(--parchment);border-color:var(--royal)}
.chip-standing{background:#ece6d6}
.chip-vindicated{background:var(--vindicated);color:#fff;border-color:var(--vindicated)}
.chip-cliffnotes{background:var(--cliffnotes);color:#fff;border-color:var(--cliffnotes)}
.chip-apology{background:var(--apology);color:#fff;border-color:var(--apology)}
.chip-cancellation{background:var(--cancellation);color:#fff;border-color:var(--cancellation)}
.chip-withdrawn{background:#5a5147;color:#fff;border-color:#5a5147}
.chip-superseded{background:#4a4a6a;color:#fff;border-color:#4a4a6a}
.regal{font-size:1.5rem;font-style:italic;color:var(--royal-deep);border-left:4px solid var(--gold);
  margin:1rem 0;padding:.6rem 1rem;background:#fffdf7}
.banner{border-radius:5px;padding:1rem;margin:1rem 0;color:#fff}
.banner-standing{background:#ece6d6;color:var(--ink);border:1px dashed var(--muted)}
.banner-vindicated{background:var(--vindicated)}
.banner-cliffnotes{background:var(--cliffnotes)}
.banner-apology{background:var(--apology)}
.banner-cancellation{background:var(--cancellation)}
.banner-withdrawn{background:#5a5147}
.banner-superseded{background:#4a4a6a}
.banner-tier{font-weight:bold;text-transform:uppercase;letter-spacing:1px}
.banner-glyph{font-size:1.3rem}
.corroboration{font-size:.8rem;opacity:.9}
.reckoning,.council-reasoning,.claim{background:#fff;border:1px solid #e3dcc8;border-radius:5px;
  padding:1rem 1.25rem;margin:1rem 0}
.delib{border-top:1px solid #eee;padding:.6rem 0}
.delib-head{display:flex;gap:.8rem;font-size:.85rem;color:var(--muted)}
.evidence ul{margin:.3rem 0}
.back{margin-top:1.5rem}
.royal-footer{text-align:center;color:var(--muted);padding:2rem 1rem;border-top:1px solid #e3dcc8;
  margin-top:2rem;font-size:.9rem}
.stamp{font-style:italic}
"""


# ---------------------------------------------------------------------------
# Public entrypoint
# ---------------------------------------------------------------------------


def generate(db: ConnOrPath, out_dir: str | Path, *, now: str | None = None) -> list[str]:
    """Render the full static chronicle into ``out_dir``; return written paths.

    ``db`` may be an open :class:`sqlite3.Connection` (preferred — the driver
    passes the live connection) or a path/``":memory:"`` string (a read-only
    connection is opened and closed internally). The function is read-only and
    idempotent: it overwrites the output files from the current DB state.

    ``now`` is an injectable ISO-8601 stamp for the footer (deterministic tests);
    when omitted, the current UTC time is used.
    """
    generated_at = now or datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    opened = not isinstance(db, sqlite3.Connection)
    conn = _db.connect(str(db)) if opened else db
    try:
        out = Path(out_dir)
        out.mkdir(parents=True, exist_ok=True)
        written: list[str] = []

        # --- gather scoreboard metrics (defensive) -------------------------
        snapshot = _db.latest_metrics(conn)
        metrics: dict | None = None
        if snapshot is not None and snapshot.metrics_json:
            try:
                loaded = json.loads(snapshot.metrics_json)
                metrics = loaded if isinstance(loaded, dict) else {"value": loaded}
            except (ValueError, TypeError):
                metrics = None

        # --- decrees + per-decree articles ---------------------------------
        decrees = _db.list_decrees(conn)
        # Newest first on the index roll.
        decrees_sorted = sorted(decrees, key=lambda d: (d.id or 0), reverse=True)

        index_ctx: list[tuple[Any, Any, list]] = []
        for decree in decrees_sorted:
            event = _db.get_event(conn, decree.event_id)
            corrections = _db.list_corrections(conn, decree_id=decree.id)
            rulings = _db.list_rulings(conn, decree_id=decree.id)
            deliberations = (
                _db.list_deliberations(conn, decree.event_id) if event else []
            )
            index_ctx.append((decree, event, corrections))

            article = _render_decree_article(
                decree, event, corrections, rulings, deliberations, generated_at
            )
            path = out / decree_filename(decree.id)
            path.write_text(article, encoding="utf-8")
            written.append(str(path))

        # --- divided ledger ------------------------------------------------
        divided_events = _db.list_events(conn, status=EventStatus.DIVIDED)
        divided_path = out / DIVIDED_FILE
        divided_path.write_text(
            _render_divided(divided_events, generated_at), encoding="utf-8"
        )
        written.append(str(divided_path))

        # --- index / scoreboard --------------------------------------------
        index_path = out / INDEX_FILE
        index_path.write_text(
            _render_index(index_ctx, metrics, len(divided_events), generated_at),
            encoding="utf-8",
        )
        written.append(str(index_path))

        # --- stylesheet ----------------------------------------------------
        style_path = out / STYLE_FILE
        style_path.write_text(_STYLE, encoding="utf-8")
        written.append(str(style_path))

        return written
    finally:
        if opened:
            conn.close()


__all__ = ["generate", "decree_filename", "INDEX_FILE", "DIVIDED_FILE", "STYLE_FILE"]
