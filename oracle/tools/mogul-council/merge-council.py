#!/usr/bin/env python3
"""Merge the Council of Bots' verdicts with the researched roster -> moguls.json.

Mirrors the Swift reference logic in MogulModel.swift: majority rules; any tie
(including a full split or an empty council) lands on "aight".
"""
import json, re, sys, pathlib

SCRATCH = pathlib.Path(__file__).parent
VALID = {"fraud", "aight", "gaming"}

def parse_bot(path, councilor, model):
    """Leniently parse a bot's reply: strip fences/prose, find the JSON array."""
    try:
        text = (SCRATCH / path).read_text()
    except FileNotFoundError:
        return {}
    if not text.strip():
        return {}
    match = re.search(r"\[.*\]", text, re.DOTALL)
    if not match:
        return {}
    try:
        entries = json.loads(match.group(0))
    except json.JSONDecodeError:
        return {}
    out = {}
    for entry in entries:
        verdict = str(entry.get("verdict", "")).lower().strip()
        quip = str(entry.get("quip", "")).strip()
        mid = entry.get("id")
        if mid and verdict in VALID and quip:
            out[mid] = {"councilor": councilor, "model": model,
                        "verdict": verdict, "quip": quip[:200]}
    return out

def majority(opinions):
    if not opinions:
        return "aight"
    tally = {}
    for op in opinions:
        tally[op["verdict"]] = tally.get(op["verdict"], 0) + 1
    top = max(tally.values())
    leaders = [v for v in VALID if tally.get(v) == top]
    return leaders[0] if len(leaders) == 1 else "aight"

raw = json.load(open(SCRATCH / "moguls-raw.json"))
bots = [
    parse_bot("claude.out", "Claude", "claude-cli (Max)"),
    parse_bot("codex.last", "Codex", "codex-cli"),
    parse_bot("deepseek.out", "DeepSeek", "deepseek-chat"),
]
for name, table in zip(("Claude", "Codex", "DeepSeek"), bots):
    print(f"{name}: {len(table)} verdicts", file=sys.stderr)

moguls = []
for entry in raw:
    council = [table[entry["id"]] for table in bots if entry["id"] in table]
    moguls.append({
        "id": entry["id"],
        "name": entry["name"],
        "title": entry["title"],
        "category": entry["category"],
        "netWorthUSD": entry.get("netWorthUSD"),
        "annualCompUSD": entry.get("annualCompUSD"),
        "compYear": entry.get("compYear"),
        "medianWorkerPayUSD": entry.get("medianWorkerPayUSD"),
        "knownFor": entry["knownFor"],
        "source": entry["source"],
        "council": council,
        "finalVerdict": majority(council),
    })

ledger = {"asOf": "2026-07-04", "moguls": moguls}
out = SCRATCH / "moguls.json"
out.write_text(json.dumps(ledger, indent=1))
tally = {}
for m in moguls:
    tally[m["finalVerdict"]] = tally.get(m["finalVerdict"], 0) + 1
print(f"wrote {len(moguls)} moguls -> {out}", file=sys.stderr)
print(f"final verdicts: {tally}", file=sys.stderr)
missing = [m["id"] for m in moguls if len(m["council"]) < 2]
if missing:
    print(f"WARNING: thin council (<2 opinions) for: {missing}", file=sys.stderr)
