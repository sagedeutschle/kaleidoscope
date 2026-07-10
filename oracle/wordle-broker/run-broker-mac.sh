#!/bin/zsh
# Wordgame daily-word broker (clean-room rebuild, 2026-07-09).
#
# Design constraints (do not weaken these — they are the legal posture):
#   1. NEVER contacts nytimes.com or any NYT infrastructure. The word is read
#      from public news coverage (Parade, TheGamer, word.tips, etc.) via the
#      claude CLI's WebSearch — the same act as a human reading an article.
#      A single day's answer is an uncopyrightable fact; that is why those
#      outlets publish it openly every day.
#   2. Publishes ONLY today's word. No archive is kept or served publicly, so
#      the curated list is never reproduced as a compilation.
#   3. Cross-checked: the model must cite >= 2 independent source domains and
#      the script re-validates shape + date before publishing.
#   4. The payload never uses the "Wordle" trademark (sourceName stays "Daily").
#
# Publishes to the Supabase storage object that prismet.xyz/api/wordle proxies:
#   bucket kaleidoscope-public, key wordle/daily.json
# Idempotent: exits 0 without work if today's date is already published.
# Scheduled by ~/Library/LaunchAgents/com.gtrktscrb.wordle-broker.daily.plist

set -u
export PATH="$HOME/.claude-accounts/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin"

PROJECT_REF="cmufcjysgbiqhohozkrf"
OBJECT_PATH="kaleidoscope-public/wordle/daily.json"
PUBLIC_URL="https://${PROJECT_REF}.supabase.co/storage/v1/object/public/${OBJECT_PATH}"
LOG_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$LOG_DIR/broker.log"

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

TODAY=$(TZ=America/New_York date '+%Y-%m-%d')
HUMAN_DATE=$(TZ=America/New_York date '+%B %-d, %Y')

# --- Idempotence gate -------------------------------------------------------
current=$(curl -s -m 10 "$PUBLIC_URL" 2>/dev/null)
current_date=$(print -r -- "$current" | /usr/bin/python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("date",""))
except Exception: print("")' 2>/dev/null)
if [[ "$current_date" == "$TODAY" ]]; then
  log "already published for $TODAY — nothing to do"
  exit 0
fi

# --- Ask claude (WebSearch over news coverage; never NYT) -------------------
PROMPT="Search the web for today's daily Wordle answer as published by news/games
outlets (e.g. Parade, TheGamer, word.tips, Technobezz — NOT nytimes.com).
Today is ${HUMAN_DATE} (US Eastern). Cross-check at least two independent
outlets that state the answer for exactly that date. Reply with ONLY one line
of minified JSON, no markdown, in this exact shape:
{\"answer\":\"<5 lowercase letters>\",\"date\":\"${TODAY}\",\"sources\":[\"<domain1>\",\"<domain2>\"]}
If you cannot confirm the same 5-letter answer on two independent domains for
that exact date, reply with exactly: {\"error\":\"unconfirmed\"}"

raw=$(claude -p "$PROMPT" --allowedTools "WebSearch" 2>>"$LOG")
line=$(print -r -- "$raw" | grep -E '^\{.*\}$' | tail -1)

if [[ -z "$line" ]]; then
  log "FAIL: no JSON line in claude output: ${raw:0:200}"
  exit 1
fi

# --- Validate (never trust model output blindly) ----------------------------
validated=$(/usr/bin/python3 -c '
import json, re, sys
today, line = sys.argv[1], sys.argv[2]
try:
    p = json.loads(line)
except Exception:
    sys.exit(2)
if "error" in p:
    sys.exit(3)
answer = str(p.get("answer", "")).strip().lower()
sources = p.get("sources", [])
domains = {re.sub(r"^www\.", "", str(s).lower().split("/")[0]) for s in sources if s}
if not re.fullmatch(r"[a-z]{5}", answer):
    sys.exit(4)
if p.get("date") != today:
    sys.exit(5)
if len(domains) < 2 or any("nytimes" in d for d in domains):
    sys.exit(6)
print(json.dumps({"answer": answer, "date": today, "sourceName": "Daily"}))
' "$TODAY" "$line")
rc=$?
if (( rc != 0 )) || [[ -z "$validated" ]]; then
  log "FAIL: validation rc=$rc line=$line"
  exit 1
fi

# --- Publish (service_role key via Supabase mgmt token in login keychain) ---
MGMT=$(security find-generic-password -s "Supabase CLI" -w 2>/dev/null | sed 's/^go-keyring-base64://' | base64 -d)
if [[ -z "$MGMT" ]]; then
  log "FAIL: no Supabase mgmt token in keychain"
  exit 1
fi
SERVICE_KEY=$(curl -s -m 15 -H "Authorization: Bearer $MGMT" \
  "https://api.supabase.com/v1/projects/${PROJECT_REF}/api-keys" \
  | /usr/bin/python3 -c 'import json,sys
for k in json.load(sys.stdin):
    if k.get("name") == "service_role":
        print(k.get("api_key", "")); break' 2>/dev/null)
if [[ -z "$SERVICE_KEY" ]]; then
  log "FAIL: could not fetch service_role key"
  exit 1
fi

http_status=$(print -r -- "$validated" | curl -s -m 20 -o /dev/null -w "%{http_code}" \
  -X PUT "https://${PROJECT_REF}.supabase.co/storage/v1/object/${OBJECT_PATH}" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "x-upsert: true" \
  --data-binary @-)

if [[ "$http_status" == "200" ]]; then
  log "OK: published $validated"
  exit 0
else
  log "FAIL: storage PUT returned $http_status"
  exit 1
fi
