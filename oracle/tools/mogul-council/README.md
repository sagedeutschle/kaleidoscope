# The Mogul Council — bench pipeline (v2)

Feeds **The Moguls** board (Debt Clock lens). Single-writer/public-read like the
decrees: run on the source laptop, publish to the gist, every install reads it.

## The bench

| Seat | Who | Output |
|---|---|---|
| Justice | **Opus** (`claude --model opus`) | verdict + 2-3 sentence written opinion |
| Justice | **GPT-5.5** (`codex exec -m gpt-5.5`) | verdict + written opinion |
| Jury seat | **The Sonnet Jury** — 3× `claude --model sonnet` as personas *The Skeptic / The Builder / The Ledger Clerk* | 3 verdicts + persona quips → one collective seat |
| Jury seat | **The Mini Jury** — 3× `codex exec -m gpt-5.5 -c model_reasoning_effort='"low"'` as *The Quant / The Populist / The Butler* | same |

> ChatGPT-account Codex does **not** expose `gpt-5.5-mini` (400: "not supported
> with a ChatGPT account") — low-effort gpt-5.5 is the mini tier here, and the
> published `model` field says so honestly. DeepSeek remains a future Justice
> once the account has credit.

## Voting (mirrors `MogulBench.ruling` in `ios/Sources/Core/Stats/MogulModel.swift` — keep in sync)

1. Each Justice holds one seat; each jury's collective verdict holds one seat (4 seats).
2. A jury's seat = majority of its jurors; a full 3-way split hangs the jury (→ `aight`).
3. A strict majority of seats (3+) rules.
4. Tie → Justices who agree with each other prevail. Justices split too → `aight` (officially mid).

After the votes, **Opus (as court reporter)** writes a per-mogul `consensus`
(2-4 sentences naming the dissents) plus a `voteSummary` tally line is computed.

## Flow

1. Refresh `moguls-raw.json` (research agent; schema = fields in `MogulModel.swift`
   incl. `medianWorkerPayUSD` from SEC pay-ratio disclosures).
2. `./run-council-v2.sh` — 8 voices in parallel, then `merge-bench.py --prepare`
   → consensus call → `merge-bench.py --finalize` → `moguls.json`.
3. Ship:
   ```sh
   cp moguls.json ../../../ios/Resources/moguls.json   # bundled fallback
   python3 - <<'PY'                                     # publish to the gist
   import json, subprocess
   body = json.dumps({"files": {"moguls.json": {"content": open("moguls.json").read()}}})
   subprocess.run(["gh","api","-X","PATCH","/gists/89deccae62f7fcd458d47fa464d82e0c","--input","-"],
                  input=body, text=True, check=True)
   PY
   ```

Gist `89deccae62f7fcd458d47fa464d82e0c` (raw URL hardcoded in `ios/Sources/Backend/MogulSource.swift`).
Old v1 boards (flat `council`, no `bench`) still decode in-app — new fields are optional.

## Ground rules

- **Satire discipline:** prompts forbid crime allegations/defamation — roast the
  *vibe*, PG-13. The app labels everything satire. This ships in an App Store product.
- Figures must be real public estimates with sources named per entry.
- Rerun when numbers feel stale (monthly-ish); the bench costs ~9 model calls.
