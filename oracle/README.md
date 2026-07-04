# The Wizard King's Decree

A council of chat models is forced to commit to absolute, no-hedge prophecies
about upcoming news. An independent Court Historian judges each prophecy against
reality and, when the council is wrong, forces a public correction on an
escalating ladder of shame. Over months the record answers one question: can
chat models actually call the future of the news, and how often do they have to
grovel?

The theatrical framing (a Wizard King, his Council of Mages, a Court Historian)
is the delivery. Underneath it is an auditable, self-grading forecasting
experiment. Rigor in robes. The full design is in [SPEC.md](./SPEC.md), which is
authoritative.

## The cast

- **Council of Mages** — Claude Opus 4.8 + an OpenAI GPT. They deliberate
  independently, then exchange and revise up to three rounds. A decree is forged
  only on consensus; otherwise the matter is logged `divided` and the King holds
  his tongue.
- **The Wizard King** — a styling pass that proclaims the agreed prophecy as
  absolute fact.
- **The Court Historian** — Gemini, search-grounded and independent. It sees
  only the literal decree (claim + resolution criteria), never the
  deliberation, and must cite at least two independent corroborating sources
  before any verdict (more for the harsh tiers).

## Layout

```
wkd/
  config.py      Config + ModelSpec; env-sourced keys (never serialized)
  models.py      frozen entities + StrEnum vocabularies (SPEC §14, §10)
  db.py          SQLite layer; append-only rulings/corrections
  providers.py   LLM seam (Anthropic/OpenAI/Gemini, lazy SDKs) + MockProvider
  harvester.py   pull + falsifiability-gate + dedup matters -> events
  council.py     deliberation protocol -> decree or divided
  historian.py   resolution: search-grounded, cited, corroborated verdicts
  scoring.py     hit rate (+bootstrap CI), tiers, calibration, beat-the-crowd
  chronicle.py   static-site generator (stdlib templating only)
  driver.py      run_daily(): idempotent harvest->...->publish, catches up
  cli.py         argparse entrypoint (python3 -m wkd ...)
tests/           stdlib unittest, fully offline (no keys, no network, no pip)
```

## Running the tests (offline, no keys, no installs)

The entire suite runs on the standard library. Every SDK, network call, clock
read, and DB path is behind an injectable dependency, and the tests pass fakes
(`MockProvider`, fake fetchers, a temp DB, a fixed `now`).

```sh
cd ai-tools/wizard-kings-decree
python3 -m unittest discover -s tests -t . -v
```

You need Python 3.11+ (3.14 is fine). You do **not** need `anthropic`,
`openai`, `google-genai`, `feedparser`, `httpx`, or `PyYAML` to run the tests.

## Using the CLI

```sh
python3 -m wkd init-db                       # create the SQLite schema
python3 -m wkd run --now 2026-06-26T12:00:00Z  # one full daily pass
python3 -m wkd harvest                       # harvest configured sources only
python3 -m wkd deliberate                    # deliberate pending matters
python3 -m wkd resolve                       # summon the Historian for due decrees
python3 -m wkd score                         # recompute the metrics snapshot
python3 -m wkd publish                       # regenerate the Chronicle
python3 -m wkd serve --port 8787             # serve the Chronicle over the tailnet
```

A global `--config path/to/config.{yaml,json}` applies to every subcommand;
`--now ISO8601` injects the clock where it matters. With no `--config`, built-in
defaults plus `WKD_*` env overrides are used.

**Offline-safe by default.** With no API keys or SDKs installed, `run` still does
its non-LLM work (harvest from any configured sources, score, publish a — likely
empty — Chronicle) and *skips* each model leg (council, free-pick, checkpoint,
Historian), emitting a warning rather than crashing. Set the keys (below) and
`pip install -r requirements.txt` to light up the model legs.

## Going live

1. **Set keys** (environment only — see [.env.example](./.env.example)):
   `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`. Then
   `pip install -r requirements.txt` in the project venv.
2. **Configure harvest sources** (optional) via environment, not the config
   file: `WKD_NEWS_FEEDS` (comma-separated RSS/Atom URLs) and
   `WKD_MARKET_ENDPOINT` (a prediction-market questions JSON endpoint —
   harvested for the questions only, never traded). With neither set,
   harvesting is a clean no-op.
3. **Pick models** in a config file (see [config.example.yaml](./config.example.yaml));
   model ids live in config, not buried in logic, so they are easy to bump.

### Gemini caveat (archbox Known Issue #4)

The Court Historian needs a proper Gemini API key, independent of the archbox
OpenCode/Google OAuth flow, which is currently incomplete (Archbox Known Issue
#4). If a real Gemini key is unavailable, the fallback is a walled-off
Claude/GPT Historian with the same mandatory citation + corroboration rules —
weaker independence, so prefer the real key.

### Deploying to archbox

archbox (Arch Linux, Tailscale `100.108.54.108`, user `saged`) is the runtime
host. Deployment **must follow the Agent Startup Protocol** in
`archbox-dev/Archbox Development.md` (SSH in, post a status report, review
pending tasks, append to the Edit History on any persistent change).

One cron entry drives the whole thing — the daily driver is idempotent and
catches up if days were missed:

```cron
# The Wizard King holds court once a day at 13:00 UTC.
0 13 * * *  cd /home/saged/wizard-kings-decree && \
  . .venv/bin/activate && . ./.env && \
  python3 -m wkd run --config config.yaml >> logs/wkd.log 2>&1
```

Serve the Chronicle over the tailnet separately (a long-running
`python3 -m wkd serve`, an nginx/caddy static mount, or a systemd unit pointed
at `chronicle/`).

## Design guarantees

- **Independent judge, no anchoring** — the Historian is a different model
  family and never sees the deliberation.
- **Falsifiability gate** — no ungradeable decree enters the record; resolution
  dates must be in the future at issuance.
- **Append-only + idempotent** — rulings and corrections are never edited;
  decrees are superseded, never silently rewritten; re-running the driver is
  safe.
- **Full audit trail** — every prompt, transcript, token, and cost is persisted
  to SQLite.
