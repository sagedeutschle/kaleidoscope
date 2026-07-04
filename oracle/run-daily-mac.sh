#!/bin/zsh
# Wizard King's Decree — daily council run + publish (interim host: Sage's laptop).
#
# One idempotent pass: forge up to ~5 new decrees (daily_decree_cap) and summon the
# Court Historian for EVERY decree now past its resolution date (vindicate / correct).
# Then export the flat chronicle and publish it to the public gist that BOTH
# Kaleidoscope apps read. Single writer = this laptop; public read = everyone.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"   # claude + gh + python3

GIST_ID="$(cat .gist-id 2>/dev/null)"
LOG="daily.log"
TS="$(date -u +%FT%TZ)"
echo "===== $TS  wkd daily run =====" >> "$LOG"

python3 -m wkd --config config.fun.json init-db >> "$LOG" 2>&1   # idempotent; creates schema on first run
python3 -m wkd --config config.fun.json run >> "$LOG" 2>&1
echo "[$TS] wkd run rc=$?" >> "$LOG"

python3 tools/export_decrees_json.py fun.db decrees.json >> "$LOG" 2>&1
echo "[$TS] export rc=$? bytes=$(wc -c < decrees.json 2>/dev/null | tr -d ' ')" >> "$LOG"

if [[ -n "$GIST_ID" && -s decrees.json ]]; then
  python3 - "$GIST_ID" decrees.json >> "$LOG" 2>&1 <<'PY'
import json, subprocess, sys
gist_id, path = sys.argv[1], sys.argv[2]
content = open(path, encoding="utf-8").read()
body = json.dumps({"files": {"decrees.json": {"content": content}}})
subprocess.run(["gh", "api", "-X", "PATCH", f"/gists/{gist_id}", "--input", "-"],
               input=body, text=True, check=True, stdout=subprocess.DEVNULL)
print("published", len(content), "bytes to gist", gist_id)
PY
  echo "[$TS] publish rc=$?" >> "$LOG"
else
  echo "[$TS] SKIP publish (missing .gist-id or empty decrees.json)" >> "$LOG"
fi
echo "===== $TS  done =====" >> "$LOG"
