# The Mogul Council — pipeline

Feeds **The Moguls** board (Debt Clock lens, both apps eventually). Same
single-writer/public-read pattern as the decrees: run on the source laptop,
publish to a gist, every install reads the same board.

## Flow

1. **Research** — produce/refresh `moguls-raw.json` in this directory: the top
   ~15 billionaires (Forbes Real-Time) + ~10 highest-paid CEOs (Equilar/proxy
   filings), with `netWorthUSD`, `annualCompUSD`, `compYear`,
   `medianWorkerPayUSD` (Dodd-Frank pay-ratio disclosures), `knownFor`,
   `source`. Easiest: hand the schema to a web-search agent (see the field
   list in `ios/Sources/Core/Stats/MogulModel.swift`).
2. **Council** — `./run-council.sh` puts the roster in front of the bots in
   parallel: **Claude** (Max-sub CLI), **Codex** (CLI), **DeepSeek** (API; key
   read from `~/.zshrc` at runtime — never committed). Each returns
   verdict + quip per mogul: `fraud` / `aight` / `gaming`.
   - DeepSeek seat is skipped automatically if the API fails (e.g. no credit —
     that was the state on 2026-07-04; top up at platform.deepseek.com).
3. **Merge** — `python3 merge-council.py` → `moguls.json`. Majority rules;
   ties (or a 3-way split) land on `aight`. Mirrors `Mogul.majority(of:)` in
   the app — keep both in sync.
4. **Ship** —
   ```sh
   cp moguls.json ../../../ios/Resources/moguls.json   # bundled fallback
   python3 - <<'PY'                                     # publish to the gist
   import json, subprocess
   body = json.dumps({"files": {"moguls.json": {"content": open("moguls.json").read()}}})
   subprocess.run(["gh","api","-X","PATCH","/gists/89deccae62f7fcd458d47fa464d82e0c","--input","-"],
                  input=body, text=True, check=True)
   PY
   ```

Gist: `89deccae62f7fcd458d47fa464d82e0c` (raw URL is hardcoded in
`ios/Sources/Backend/MogulSource.swift`).

## Ground rules

- **Satire discipline:** the prompt forbids real crime allegations/defamation —
  verdicts roast the *vibe*, PG-13. The app labels everything as satire. Keep it
  that way; this ships in an App Store product.
- Figures must be real public estimates (Forbes/Bloomberg/SEC proxies) with the
  source named per entry.
- Cadence: rerun whenever the numbers feel stale (monthly-ish is plenty);
  wire into `run-daily-mac.sh` only if Sage wants it automatic.
