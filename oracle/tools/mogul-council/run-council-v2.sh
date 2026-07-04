#!/bin/zsh
# The Council of Bots v2 — a real bench:
#   JUSTICES (1 seat each): Claude Opus, Codex GPT-5.5 — detailed written opinions.
#   JURIES (1 collective seat each): Sonnet Jury (3× claude sonnet), Mini Jury (3× gpt-5.5-mini)
#     — each juror has a persona; jury seat = 2-of-3 majority (3-way split = hung -> aight).
# RULING: 3+ of 4 seats wins; 2-2 -> agreeing Justices prevail; Justices split -> aight.
# Then Opus (as court reporter) writes a per-mogul CONSENSUS naming the dissents.
set -uo pipefail
SCRATCH="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRATCH"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
CODEX=/Applications/Codex.app/Contents/Resources/codex

RULES='
RULES:
- SATIRE / comedy roast. NEVER allege actual crimes, legal fraud, or anything defamatory.
  Roast the VIBE (comp structure, aura, PR energy, yacht count) — never assert wrongdoing.
  No slurs, PG-13.
- Verdicts: "gaming" = GAMING!!!! passes the vibe check, built something real;
  "aight" = Aight... mid, the shrug of the century; "fraud" = FRAUD! comedic bust,
  vibes are OFF (rent-seeking energy, "my salary is a rounding error of my grant" energy).
- Vote honestly from YOUR OWN judgment/persona. Disagreement across the bench is expected
  and desired. Do NOT give everyone the same verdict.
- Reply with ONLY a JSON array, no markdown fences, no prose. Include every id exactly once.'

# --- Prompt: justices (detailed opinions) ---
cat > justice-prompt.txt <<EOF
You are a JUSTICE on THE COUNCIL — the comedy audit bench in a games app's satirical
wealth board. Below: real billionaires/top-paid CEOs with public figures (net worth,
annual comp, their company's median worker pay).

For EACH person deliver your verdict plus a WRITTEN OPINION: 2-3 sentences of genuinely
funny, specific reasoning that cites their actual numbers or record (e.g. the pay ratio,
the one-time mega-grant, the \$1 salary flex). This is your considered judicial take,
not a one-liner.
$RULES
Shape: [{"id":"...","verdict":"gaming|aight|fraud","opinion":"2-3 sentences"}]

THE ROSTER:
EOF
cat roster-slim.json >> justice-prompt.txt

# --- Prompt template: jurors (persona quips) ---
make_juror_prompt() {  # $1 = persona name, $2 = persona brief
  cat <<EOF
You are juror "$1" on a 3-person jury inside THE COUNCIL — the comedy audit bench in a
games app's satirical wealth board. Your persona: $2 Stay in persona.

For EACH person below: your verdict + ONE quip (under 140 chars) from your persona's angle.
$RULES
Shape: [{"id":"...","verdict":"gaming|aight|fraud","quip":"..."}]

THE ROSTER:
$(cat roster-slim.json)
EOF
}

echo "=== bench convening $(date '+%H:%M:%S') ==="

# Justices
( claude --model opus -p --output-format text < justice-prompt.txt > justice-opus.out 2> justice-opus.err; \
  echo "justice-opus rc=$? bytes=$(wc -c < justice-opus.out | tr -d ' ')" ) &
( "$CODEX" exec -m gpt-5.5 --sandbox read-only --skip-git-repo-check -C "$SCRATCH" \
    -o justice-codex.out - < justice-prompt.txt > justice-codex.log 2>&1; \
  echo "justice-codex rc=$? bytes=$(wc -c < justice-codex.out 2>/dev/null | tr -d ' ')" ) &

# Sonnet Jury (3 personas)
make_juror_prompt "The Skeptic" "you assume every PR story is spin and check what was actually built." > sj1.txt
make_juror_prompt "The Builder" "you respect shipped products and founders who still write code; allergic to committee energy." > sj2.txt
make_juror_prompt "The Ledger Clerk" "you only care about the comp math — ratios, grants, footnotes. Numbers do not lie." > sj3.txt
for i in 1 2 3; do
  ( claude --model sonnet -p --output-format text < "sj$i.txt" > "sonnet-juror-$i.out" 2> "sonnet-juror-$i.err"; \
    echo "sonnet-juror-$i rc=$? bytes=$(wc -c < sonnet-juror-$i.out | tr -d ' ')" ) &
done

# Mini Jury (3 personas) — staggered so codex doesn't rate-trip
make_juror_prompt "The Quant" "you speak in basis points and think charisma is a rounding error." > mj1.txt
make_juror_prompt "The Populist" "you channel what the average person yells at the TV about these people." > mj2.txt
make_juror_prompt "The Butler" "you have served old money for 40 years and find new money exhausting." > mj3.txt
for i in 1 2 3; do
  ( "$CODEX" exec -m gpt-5.5 -c model_reasoning_effort='"low"' --sandbox read-only --skip-git-repo-check -C "$SCRATCH" \
      -o "mini-juror-$i.out" - < "mj$i.txt" > "mini-juror-$i.log" 2>&1; \
    echo "mini-juror-$i rc=$? bytes=$(wc -c < mini-juror-$i.out 2>/dev/null | tr -d ' ')" ) &
  sleep 5
done

wait
echo "=== votes in $(date '+%H:%M:%S') — computing rulings ==="

python3 merge-bench.py --prepare || exit 1

echo "=== consensus writer (Opus, court reporter) ==="
claude --model opus -p --output-format text < consensus-request.txt > consensus.out 2> consensus.err
echo "consensus rc=$? bytes=$(wc -c < consensus.out | tr -d ' ')"

python3 merge-bench.py --finalize || exit 1
echo "=== bench adjourned $(date '+%H:%M:%S') ==="
