#!/bin/zsh
# The Council of Bots — Claude + Codex + DeepSeek each vibe-check the mogul roster.
# Outputs: claude.out / codex.last / deepseek.out (raw), then merge-council.py builds moguls.json.
set -uo pipefail
SCRATCH="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRATCH"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Slim roster for the prompt (keep tokens tight).
python3 - <<'PY'
import json
raw = json.load(open("moguls-raw.json"))
slim = [{k: m[k] for k in ("id","name","title","netWorthUSD","annualCompUSD","knownFor")} for m in raw]
open("roster-slim.json","w").write(json.dumps(slim, indent=0))
PY

cat > council-prompt.txt <<'EOF'
You are one of three bots on THE COUNCIL — the comedy audit panel in a games app's
satirical wealth board. Below is a roster of real billionaires and top-paid CEOs with
their public net worth / compensation figures.

For EACH person, deliver your ruling as a vibe check on their wealth and success:
- "gaming"  = GAMING!!!! — passes the vibe check; built something real; respect.
- "aight"   = Aight... — mid; fine; whatever; the shrug of the century.
- "fraud"   = FRAUD! — comedic bust; the vibes are OFF (rent-seeking energy, board-room
              dark arts, "my salary is a rounding error of my grant" energy).

RULES:
- This is SATIRE / a comedy roast. NEVER allege actual crimes, fraud in the legal sense,
  or anything defamatory. Roast the VIBE (comp structure, aura, PR energy, yacht count),
  never assert wrongdoing. No slurs, keep it PG-13.
- One quip per person, under 140 characters, punchy, funny, specific to who they are.
- Judge honestly and independently — do NOT give everyone the same verdict. Spread it.
- Reply with ONLY a JSON array (no markdown fences, no prose):
  [{"id":"<their id>","verdict":"gaming|aight|fraud","quip":"..."}]
  Include every id exactly once.

THE ROSTER:
EOF
cat roster-slim.json >> council-prompt.txt

echo "=== council convening $(date '+%H:%M:%S') ==="

# --- Claude (Max-sub CLI) ---
( claude -p --output-format text < council-prompt.txt > claude.out 2> claude.err; \
  echo "claude rc=$? bytes=$(wc -c < claude.out | tr -d ' ')" ) &
CLAUDE_PID=$!

# --- Codex (CLI; may hit usage limits — council survives with 2 bots) ---
( /Applications/Codex.app/Contents/Resources/codex exec \
    --sandbox read-only --skip-git-repo-check -C "$SCRATCH" \
    -o codex.last - < council-prompt.txt > codex.log 2>&1; \
  echo "codex rc=$? bytes=$(wc -c < codex.last 2>/dev/null | tr -d ' ')" ) &
CODEX_PID=$!

# --- DeepSeek (API; key from ~/.zshrc) ---
export DEEPSEEK_API_KEY="$(grep -o 'DEEPSEEK_API_KEY="[^"]*"' ~/.zshrc | cut -d'"' -f2)"
( python3 - <<'PY' > deepseek.out 2> deepseek.err
import json, os, subprocess, sys
prompt = open("council-prompt.txt").read()
key = os.environ["DEEPSEEK_API_KEY"]
body = json.dumps({
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": prompt}],
    "temperature": 1.1,
    "max_tokens": 4000,
})
out = subprocess.run(
    ["curl", "-sS", "--max-time", "240", "https://api.deepseek.com/chat/completions",
     "-H", "Content-Type: application/json", "-H", f"Authorization: Bearer {key}",
     "-d", body],
    capture_output=True, text=True)
resp = json.loads(out.stdout)
print(resp["choices"][0]["message"]["content"])
PY
  echo "deepseek rc=$? bytes=$(wc -c < deepseek.out | tr -d ' ')" ) &
DEEPSEEK_PID=$!

wait $CLAUDE_PID $CODEX_PID $DEEPSEEK_PID
echo "=== council adjourned $(date '+%H:%M:%S') ==="
ls -la claude.out codex.last deepseek.out 2>&1
