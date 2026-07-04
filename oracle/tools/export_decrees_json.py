#!/usr/bin/env python3
"""Export a wkd DB (e.g. fun.db) to a flat decrees.json for the ChessHotSwap Oracle tab.

Usage: python3 export_decrees_json.py <db_path> <out_path>
Re-run anytime to refresh the bundled snapshot the app reads.
"""
import datetime
import json
import sqlite3
import sys

db = sys.argv[1] if len(sys.argv) > 1 else "fun.db"
out = sys.argv[2] if len(sys.argv) > 2 else "decrees.json"

c = sqlite3.connect(db)
c.row_factory = sqlite3.Row


def _looks_like_refusal(text):
    """The King (esp. a small model) sometimes refuses to proclaim certainty.
    Detect that so we can fall back to the plain claim instead of shipping a
    refusal as a 'royal proclamation'."""
    t = (text or "").strip().lower()
    starts = ("i appreciate", "i can't", "i cannot", "i'm not able", "i am not able",
              "i won't", "i will not", "as an ai", "i'm unable", "i am unable", "i must decline")
    return t.startswith(starts) or "can't proclaim" in t or "cannot proclaim" in t

# Map DecreeStatus / Tier strings onto the fixed record keys the Swift model expects.
STMAP = {
    "standing": "standing", "vindicated": "vindicated", "cliffnotes": "cliffnotes",
    "apology": "apology", "cancelled": "cancellation", "cancellation": "cancellation",
}
rec = {k: 0 for k in
       ["total", "standing", "vindicated", "cliffnotes", "apology", "cancellation", "divided", "ruled"]}

decrees = []
rows = c.execute(
    "SELECT d.id, d.claim_text, d.regal_text, d.status, d.private_confidence, "
    "       e.title, e.domain, e.resolution_date, e.resolution_criteria, e.source "
    "FROM decrees d JOIN events e ON e.id = d.event_id "
    "WHERE d.status NOT IN ('superseded','withdrawn') "
    "ORDER BY e.resolution_date").fetchall()
for r in rows:
    did = r["id"]
    ru = c.execute("SELECT verdict FROM rulings WHERE decree_id=? ORDER BY id DESC LIMIT 1", (did,)).fetchone()
    co = c.execute("SELECT correction_text FROM corrections WHERE decree_id=? ORDER BY id DESC LIMIT 1", (did,)).fetchone()
    verdict = ru["verdict"] if ru else None
    regal = r["regal_text"] or ""
    if _looks_like_refusal(regal):
        regal = r["claim_text"] or ""   # never ship a refusal as a proclamation
    decrees.append({
        "id": did, "title": r["title"], "regal": regal,
        "claim": r["claim_text"] or "", "status": r["status"],
        "confidence": r["private_confidence"] or 0.0,
        "resolves": r["resolution_date"] or "", "domain": r["domain"] or "",
        "criteria": r["resolution_criteria"] or "", "source": r["source"] or "",
        "verdict": verdict, "correction": (co["correction_text"] if co else None),
    })
    rec["total"] += 1
    k = STMAP.get(r["status"])
    if k:
        rec[k] += 1
    if verdict:
        rec["ruled"] += 1

divided = [{"title": x["title"], "resolves": x["resolution_date"] or ""}
           for x in c.execute("SELECT title, resolution_date FROM events WHERE status='divided'").fetchall()]
rec["divided"] = len(divided)

obj = {"generated": datetime.date.today().isoformat(), "record": rec,
       "decrees": decrees, "divided": divided}
with open(out, "w") as f:
    json.dump(obj, f, indent=2)
print(f"wrote {len(decrees)} decrees, {len(divided)} divided -> {out}")
