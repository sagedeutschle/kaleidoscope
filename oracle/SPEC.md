# 👑 The Wizard King's Decree — Design Spec

| | |
|---|---|
| **Status** | Approved design (pre-implementation) |
| **Date** | 2026-06-26 |
| **Home** | `ai-tools/wizard-kings-decree/` |
| **Runtime host** | archbox (Arch Linux, Tailscale `100.108.54.108`, user `saged`) |
| **Author** | sage + Claude (brainstormed) |

---

## 1. Premise & Hypothesis

A council of chat models is forced to commit to **absolute, no-hedge prophecies** about upcoming news. An *independent* Court Historian judges each prophecy against reality and, when the council is wrong, forces a public correction on an escalating ladder of shame. Over months, the accumulating record of decrees and apologies answers one question:

> **Can chat models actually call the future of the news — and how often do they have to grovel?**

The theatrical framing (a Wizard King, his council of mages, a Court Historian) is the *delivery*. Underneath it is a rigorous, auditable, self-grading forecasting experiment. Both halves are real: **rigor in robes.**

## 2. Goals / Non-Goals

**Goals**
- Measure, over a long horizon, whether a model council can predict news outcomes better than chance / status-quo.
- Force falsifiable, no-hedge commitments so every call is undeniably right or wrong.
- Keep the judge honest and independent of the predictors, with zero human in the loop.
- Produce a browsable, theatrical chronicle of the King's record.

**Non-Goals**
- **No betting, no money, no market positions.** Prediction markets appear only as a *source of falsifiable questions* and as an optional accuracy benchmark — never as something we trade.
- No human-in-the-loop judging (fully automated Court Historian).
- No probability-calibration UI in v1 (private confidence is logged for later analysis; the King speaks only in certainties).

## 3. The Cast (models & independence)

| Role | Model(s) | Notes |
|------|----------|-------|
| **The Council of Mages** | Claude **Opus 4.8** + OpenAI **GPT** | Deliberate; must reach consensus to issue a decree. |
| **The Wizard King** | (rendering pass) | The single regal voice that proclaims the council's agreed prophecy as absolute fact. Can be one of the council models in a pure styling role. |
| **The Court Historian** | **Gemini** (independent) | Judges decrees against real news. **Must not be a council member.** Uses Gemini's native Google Search grounding for ground truth. |

**Independence rule:** the Historian is a *different model family* than both council members, and it sees **only** the literal decree (claim + resolution criteria) plus the real-world evidence it fetches — **never** the council's private deliberation or reasoning. No anchoring, no contamination.

## 4. Core Object: The Decree

Every decree is a public proclamation backed by hidden structured metadata:

| Field | Meaning |
|-------|---------|
| `claim_text` | The falsifiable claim in plain language. |
| `regal_text` | The King's theatrical proclamation ("By the 31st of July, the Fed shall cut rates. This is beyond doubt."). |
| `resolution_date` | When reality settles it. **Must be in the future** relative to issuance. |
| `resolution_criteria` | Objective, checkable conditions for right/wrong. |
| `domain` | politics / econ / current-events / crypto / world-news. |
| `private_confidence` | The council's *true* internal probability (0–1), logged for calibration analysis. **The public decree is always absolute regardless of this number.** |
| `source` | `harvested` or `free-pick`. |
| `market_implied_prob` | If harvested from a market, the crowd's implied answer (for the beat-the-crowd benchmark). Nullable. |

## 5. Deliberation Protocol (council → consensus / divided)

1. **Independent drafts** — each mage privately drafts a claim + direction + private confidence + reasoning, *without seeing the other's*.
2. **Exchange & revise** — they see each other's drafts and reasoning, then revise.
3. **Converge** — repeat up to **3 rounds** seeking agreement on (a) direction and (b) claim wording.
4. **Outcome:**
   - **Consensus** → a decree is forged (council's agreed claim + merged, e.g. averaged, private confidence).
   - **Divided** (no agreement after the cap) → **the King holds his tongue.** No decree. The event is logged as `council-divided` — a meaningful measurement of genuine uncertainty, not a failure.

The full deliberation transcript (every round, both models, reasoning, tokens) is persisted for audit.

## 6. Falsifiability Gate

Before any decree is accepted, it must pass an automated gate:
- Has a concrete `resolution_date` strictly in the future.
- Has objective `resolution_criteria` checkable from public reporting.
- Is not vague, tautological, or unverifiable.

Candidates failing the gate are reworded by the council or dropped. The gate applies equally to harvested and free-pick decrees — this is what keeps a fully-automated, no-human-backstop pipeline from rotting into ungradeable mush.

## 7. Decree Sourcing (hybrid)

A **harvester** assembles a queue of "matters" for the King:
- **Datable upcoming events** from news / events calendars (scheduled releases, votes, meetings, deadlines).
- **Prediction-market & forecasting questions** (e.g. Polymarket/Metaculus) as ready-made falsifiable claims with resolution criteria and dates — harvested for their *questions*, never traded. These also supply `market_implied_prob` for the beat-the-crowd benchmark.
- **Free-pick**: the King also surveys live headlines and may decree on matters of his own choosing (subject to the falsifiability gate).

**Domains (reasoning-favored):** politics, economics, current events, crypto, world news. **Excluded:** pure-chance and sports.

## 8. Cadence

A single **idempotent daily driver** runs on archbox and decides what is due (robust to missed days — it catches up):
- **Harvest** new matters every run.
- **Deliberate** on fresh matters → issue decrees (or mark divided).
- **Re-affirm checkpoints (weekly):** for standing decrees whose event hasn't resolved, the council may *re-affirm, amend, or withdraw* as news develops (hybrid cadence). Logged as decree updates; the original decree is never silently edited.
- **Resolution sweep:** for standing decrees past their `resolution_date`, summon the Court Historian.
- **Score & publish:** recompute metrics, regenerate the chronicle.

## 9. The Court Historian (resolution)

When a decree's `resolution_date` passes:
1. The Historian (Gemini, search-grounded) is given **only** the claim + resolution criteria.
2. It fetches real-world reporting, **cites its sources**, and must find **≥2 independent corroborating sources** before issuing a non-trivial verdict (the harsh tiers — apology, cancellation — require strong corroboration).
3. It rules one tier of the ladder (§10), generating the verdict + evidence + reasoning.
4. The corresponding correction copy is generated and stamped onto the chronicle. Rulings are **append-only**.

## 10. The Ladder of Shame (tiers & triggers)

| Tier | Trigger | Output |
|------|---------|--------|
| ⚜️ **Vindicated** | Decree came true per criteria. | Victory proclamation; the decree stands sealed. |
| 📌 **Cliffnotes** | Right direction, wrong details or timing. | Terse amendment appended. |
| 🙇 **Apology + Correction** | Substantively, clearly wrong. | Groveling royal apology + rewritten record. |
| 🚫 **Cancellation** | The prophesied event never happened / is unresolvable / was a non-event. | Formal retraction: "the event is hereby cancelled." |

## 11. Metrics & The Verdict

Computed over the accumulating record:
- **Hit rate** (vindicated ÷ ruled) over time, with bootstrap confidence intervals.
- **Tier distribution** (how often each rung of shame fires).
- **Per-domain accuracy** (is the council better at econ than politics?).
- **Council-divided rate** (how often the future was too uncertain to decree).
- **Calibration of private confidence** (did high-confidence decrees actually land more often?).
- **Beat-the-crowd** (for market-harvested decrees: did the council's call beat `market_implied_prob` against the eventual outcome? — the original "beat the market" question, answered as analysis, not betting).
- **Baseline floor:** a naive **status-quo / no-change** predictor run on the same matters, to prove the council clears a trivial bar.
- Harvested vs free-pick tracked separately (so the council can't juice the score by cherry-picking easy free-picks).

## 12. The Chronicle (the artifact)

A browsable site generated from the database and served from archbox over the tailnet:
- **Decree articles** — illuminated proclamations with claim, resolution date, domain, and (revealed after ruling) the council's reasoning.
- **Correction banners** — cliffnotes / apology / cancellation stamped over wrong decrees.
- **The Scoreboard** — the council's accuracy, tier counts, per-domain breakdown, divided rate, and beat-the-crowd record over time.
- **The Divided Ledger** — matters the King declined to prophesy.

## 13. Architecture & Data Flow

```
            ┌──────────────┐
   news ───▶│  Harvester   │──▶ events (pending, gated)
 markets ──▶└──────────────┘
                  │
                  ▼
            ┌──────────────┐   deliberations (transcript)
            │   Council    │──▶ decrees (standing)  |  events→divided
            │ Claude + GPT │
            └──────────────┘
                  │ (weekly) checkpoints
                  ▼
            ┌──────────────┐
            │   Resolver   │  for decrees past resolution_date
            │  = Historian │──▶ rulings ──▶ corrections
            │   (Gemini)   │
            └──────────────┘
                  │
                  ▼
            ┌──────────────┐
            │   Scoring    │──▶ metrics_snapshots
            └──────────────┘
                  │
                  ▼
            ┌──────────────┐
            │  Chronicle   │──▶ static site (tailnet)
            │  generator   │
            └──────────────┘
```

All components are independent modules behind clear interfaces (harvester, council, historian, scoring, chronicle), each testable in isolation. Model access sits behind a thin provider abstraction so the council/historian model assignment is swappable.

## 14. Data Model (SQLite)

- **`events`** — `id, source, source_ref, title, domain, description, resolution_date, resolution_criteria, market_implied_prob, harvested_at, status` (pending / decreed / divided / resolved).
- **`decrees`** — `id, event_id, issued_at, claim_text, regal_text, direction, private_confidence, consensus_rounds, status (standing/vindicated/cliffnotes/apology/cancelled), supersedes_id`.
- **`deliberations`** — `id, event_id, round, model, draft_claim, draft_confidence, reasoning, created_at`.
- **`checkpoints`** — `id, decree_id, checked_at, action (reaffirm/amend/withdraw), new_confidence, notes`.
- **`rulings`** — `id, decree_id, ruled_at, verdict, historian_model, evidence_json, corroborating_sources, reasoning`.
- **`corrections`** — `id, ruling_id, decree_id, tier, correction_text, published_at`.
- **`model_runs`** — `id, component, model, prompt_tokens, completion_tokens, cost, latency_ms, created_at` (cost/usage audit).
- **`metrics_snapshots`** — `id, computed_at, metrics_json` (scoreboard history).

## 15. Infrastructure & Deployment

- **Host:** archbox. Python **3.11+** in a project venv at `ai-tools/wizard-kings-decree/`.
- **Store:** SQLite (single file, append-only rulings, easy to inspect over SSH).
- **Scheduler:** one **cron** entry → idempotent daily driver (internal due-logic handles harvest/deliberate/checkpoint/resolve/score/publish + catch-up).
- **Chronicle serving:** generate static HTML (Jinja2) → serve on a tailnet port (`python -m http.server` or existing nginx/caddy).
- **Deploy protocol:** deployment to archbox **must follow the Agent Startup Protocol** in `archbox-dev/Archbox Development.md` (SSH in, post a status report, review pending tasks, append to Edit History on any persistent change).

## 16. Integrity Safeguards (consolidated)

1. **Independent judge** — Historian is a different model family (Gemini) than the council.
2. **No anchoring** — Historian sees only the decree + fetched evidence, never the deliberation.
3. **Grounded & cited** — every verdict cites ≥2 independent sources; the harsh tiers (apology, cancellation) require stronger corroboration still.
4. **Lookahead control** — only future-resolving events; `resolution_date > issued_at`; issuance time logged vs model cutoff for audit.
5. **Falsifiability gate** — no ungradeable decrees enter the record.
6. **Honest certainty** — private confidence logged; public decree absolute → calibration measurable without softening the test.
7. **Full audit trail** — every prompt, transcript, token, and cost persisted.
8. **Non-destructive** — append-only rulings; idempotent driver; decrees never silently edited (amendments supersede).

## 17. Dependencies & Open Items

1. **API keys** (on archbox): `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`.
   - ⚠️ **Gemini access on archbox is currently incomplete** (Archbox Known Issue #4 — blocked on an OpenCode/Google OAuth flow). The Historian needs a **proper Gemini API key**, independent of that OAuth. **Fallback if unavailable:** a walled-off Claude/GPT Historian with mandatory citations + corroboration (less ideal — weaker independence).
2. **Harvester source** — Gemini-grounded search and/or RSS/news feeds and/or market-question APIs (Polymarket/Metaculus). Pluggable; finalize in planning.
3. **archbox Python env** — confirm 3.11+ and create venv.
4. **Daily decree volume cap** — propose start at ~3–8 decrees/day to control cost and protect quality; tune later.

## 18. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Historian misjudges with no human backstop | Independent model + citations + corroboration; evidence logged for spot-audit; divided/cancellation reduce forced-wrong calls. |
| Vague/unfalsifiable decrees | Falsifiability gate rejects them. |
| Knowledge-cutoff contamination | Only future-resolving events; audit issuance vs cutoff. |
| News source unreliable / paywalled | Pluggable sources; corroboration; Gemini grounding. |
| archbox unreachable / asleep | Already hardened no-sleep (Known Issue #2); idempotent catch-up driver; Tailscale always-on. |
| Free-picks cherry-picked to juice score | Harvested vs free-pick tracked & reported separately. |
| Model cost drift | Token/cost logged per run + volume cap (cost is pennies by nature). |

## 19. Build Phases

1. **Foundation** — project scaffold, config, secrets loading, SQLite schema, provider abstraction.
2. **Harvester + falsifiability gate** — pull datable events + market questions; gate; dedup → `events`.
3. **Council deliberation engine** — independent drafts → exchange → converge/divided; private confidence; regal rendering.
4. **Court Historian / resolver** — search-grounded judging, citation + corroboration, tier assignment, correction generation.
5. **Scoring** — hit rate, tiers, per-domain, divided rate, calibration, beat-the-crowd, baseline, CIs.
6. **The Chronicle** — static-site generator + tailnet serving.
7. **Orchestration & deploy** — idempotent daily driver, cron on archbox (following the Agent Startup Protocol), logging, durability.
