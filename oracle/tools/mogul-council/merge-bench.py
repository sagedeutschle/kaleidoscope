#!/usr/bin/env python3
"""Council v2 merge — bench voting + consensus assembly.

Voting (mirrors Mogul.benchRuling in MogulModel.swift — keep in sync):
  Seats = each present Justice (1 each) + each jury's collective verdict (1 each).
  Jury verdict = majority of its jurors; full split -> "aight" (hung).
  Ruling: strict majority of seats (3+ of 4) wins; on a tie, unanimous present
  Justices prevail; otherwise "aight".

--prepare : parse the 8 voices, compute rulings, write bench-work.json +
            consensus-request.txt (for the Opus court reporter).
--finalize: attach consensus lines, emit final moguls.json.
"""
import json, re, sys, pathlib

SCRATCH = pathlib.Path(__file__).parent
VALID = {"fraud", "aight", "gaming"}
STAMP = {"fraud": "FRAUD!", "aight": "Aight...", "gaming": "GAMING!!!!"}

def parse(path, want_opinion=False):
    """Leniently parse a bot reply: find the JSON array, validate entries."""
    try:
        text = (SCRATCH / path).read_text()
    except FileNotFoundError:
        return {}
    match = re.search(r"\[.*\]", text, re.DOTALL)
    if not match:
        return {}
    try:
        entries = json.loads(match.group(0))
    except json.JSONDecodeError:
        return {}
    out = {}
    key = "opinion" if want_opinion else "quip"
    for entry in entries:
        verdict = str(entry.get("verdict", "")).lower().strip()
        line = str(entry.get(key, "")).strip()
        mid = entry.get("id")
        if mid and verdict in VALID and line:
            out[mid] = {"verdict": verdict, key: line[:600 if want_opinion else 200]}
    return out

def jury_verdict(votes):
    """2-of-3 (or majority of present) wins; tie/split -> hung -> aight."""
    if not votes:
        return "aight"
    tally = {}
    for v in votes:
        tally[v["verdict"]] = tally.get(v["verdict"], 0) + 1
    top = max(tally.values())
    leaders = [k for k in VALID if tally.get(k) == top]
    return leaders[0] if len(leaders) == 1 and top * 2 > len(votes) else "aight"

def bench_ruling(justice_verdicts, jury_verdicts):
    seats = justice_verdicts + jury_verdicts
    tally = {}
    for v in seats:
        tally[v] = tally.get(v, 0) + 1
    top = max(tally.values())
    leaders = [k for k in VALID if tally.get(k) == top]
    if len(leaders) == 1 and top * 2 > len(seats):        # strict majority
        return leaders[0]
    if justice_verdicts and len(set(justice_verdicts)) == 1:  # justices agree
        return justice_verdicts[0]
    return "aight"

JUSTICES = [("Opus", "claude-opus", "justice-opus.out"),
            ("GPT-5.5", "gpt-5.5", "justice-codex.out")]
JURIES = [("The Sonnet Jury", "claude-sonnet",
           [("The Skeptic", "sonnet-juror-1.out"),
            ("The Builder", "sonnet-juror-2.out"),
            ("The Ledger Clerk", "sonnet-juror-3.out")]),
          ("The Mini Jury", "gpt-5.5 (low effort)",
           [("The Quant", "mini-juror-1.out"),
            ("The Populist", "mini-juror-2.out"),
            ("The Butler", "mini-juror-3.out")])]

def build_bench():
    raw = json.load(open(SCRATCH / "moguls-raw.json"))
    justice_tables = [(n, m, parse(p, want_opinion=True)) for n, m, p in JUSTICES]
    jury_tables = [(n, m, [(pn, parse(pf)) for pn, pf in jurors]) for n, m, jurors in JURIES]

    for name, _, table in justice_tables:
        print(f"Justice {name}: {len(table)} opinions", file=sys.stderr)
    for name, _, jurors in jury_tables:
        print(f"{name}: " + ", ".join(f"{pn}={len(t)}" for pn, t in jurors), file=sys.stderr)

    moguls = []
    for entry in raw:
        mid = entry["id"]
        justices = [{"councilor": n, "model": m, "verdict": t[mid]["verdict"],
                     "opinion": t[mid]["opinion"]}
                    for n, m, t in justice_tables if mid in t]
        juries = []
        for jname, jmodel, jurors in jury_tables:
            votes = [{"persona": pn, "verdict": t[mid]["verdict"], "quip": t[mid]["quip"]}
                     for pn, t in jurors if mid in t]
            if votes:
                juries.append({"name": jname, "model": jmodel, "jurors": votes,
                               "juryVerdict": jury_verdict(votes)})
        ruling = bench_ruling([j["verdict"] for j in justices],
                              [j["juryVerdict"] for j in juries])
        seat_tally = {}
        for v in [j["verdict"] for j in justices] + [j["juryVerdict"] for j in juries]:
            seat_tally[v] = seat_tally.get(v, 0) + 1
        parts = [f"SEATS " + "–".join(str(c) for c in sorted(seat_tally.values(), reverse=True))]
        for j in juries:
            jt = {}
            for v in j["jurors"]:
                jt[v["verdict"]] = jt.get(v["verdict"], 0) + 1
            if len(jt) == len(j["jurors"]):
                parts.append(f"{j['name'].replace('The ', '')} hung")
            else:
                parts.append(f"{j['name'].replace('The ', '')} {max(jt.values())}–{len(j['jurors']) - max(jt.values())} {j['juryVerdict']}")
        vote_summary = " · ".join(parts)

        # Backward-compatible flat council (old builds render this list).
        flat = [{"councilor": f"{j['councilor']}, J.", "model": j["model"],
                 "verdict": j["verdict"], "quip": j["opinion"][:200]} for j in justices]
        for j in juries:
            for v in j["jurors"]:
                flat.append({"councilor": f"{j['name']} — {v['persona']}", "model": j["model"],
                             "verdict": v["verdict"], "quip": v["quip"]})

        moguls.append({**{k: entry.get(k) for k in
                          ("id", "name", "title", "category", "netWorthUSD", "annualCompUSD",
                           "compYear", "medianWorkerPayUSD", "knownFor", "source")},
                       "council": flat,
                       "bench": {"justices": justices, "juries": juries},
                       "voteSummary": vote_summary,
                       "finalVerdict": ruling})
    return moguls

if "--prepare" in sys.argv:
    moguls = build_bench()
    (SCRATCH / "bench-work.json").write_text(json.dumps(moguls, indent=0))
    req = ["""You are the COURT REPORTER for THE COUNCIL, a satirical comedy bench that vibe-checks
billionaires in a games app. For EACH case below you get the bench's votes (2 justices with
opinions, 2 juries of 3 personas) and the computed RULING. Write a CONSENSUS: 2-4 sentences
summarizing the bench's discourse — what convinced the majority, who dissented and WHY,
in dry court-reporter comedy. Reference jurors/justices by name. SATIRE ONLY: never allege
actual crimes or anything defamatory; PG-13. Do not contradict the computed ruling.
Reply with ONLY a JSON array: [{"id":"...","consensus":"2-4 sentences"}] — every id once.

THE CASES:"""]
    for m in moguls:
        case = {"id": m["id"], "name": m["name"], "ruling": STAMP[m["finalVerdict"]],
                "voteSummary": m["voteSummary"],
                "justices": [{j["councilor"]: f"{STAMP[j['verdict']]} — {j['opinion']}"}
                             for j in m["bench"]["justices"]],
                "juries": [{j["name"]: [f"{v['persona']}: {STAMP[v['verdict']]} — {v['quip']}"
                                        for v in j["jurors"]]} for j in m["bench"]["juries"]]}
        req.append(json.dumps(case))
    (SCRATCH / "consensus-request.txt").write_text("\n".join(req))
    print("prepared: bench-work.json + consensus-request.txt", file=sys.stderr)

elif "--finalize" in sys.argv:
    moguls = json.loads((SCRATCH / "bench-work.json").read_text())
    cons = parse("consensus.out")  # reuse lenient array parser (verdict absent) — parse manually instead
    text = (SCRATCH / "consensus.out").read_text()
    match = re.search(r"\[.*\]", text, re.DOTALL)
    table = {}
    if match:
        try:
            for e in json.loads(match.group(0)):
                if e.get("id") and str(e.get("consensus", "")).strip():
                    table[e["id"]] = str(e["consensus"]).strip()[:900]
        except json.JSONDecodeError:
            pass
    print(f"consensus lines: {len(table)}", file=sys.stderr)
    for m in moguls:
        m["consensus"] = table.get(m["id"])
    ledger = {"asOf": "2026-07-04", "moguls": moguls}
    (SCRATCH / "moguls.json").write_text(json.dumps(ledger, indent=1))
    tally = {}
    for m in moguls:
        tally[m["finalVerdict"]] = tally.get(m["finalVerdict"], 0) + 1
    print(f"wrote {len(moguls)} moguls; rulings {tally}; "
          f"missing consensus: {[m['id'] for m in moguls if not m.get('consensus')]}",
          file=sys.stderr)
else:
    print("usage: merge-bench.py --prepare | --finalize", file=sys.stderr)
    sys.exit(2)
