"""Offline tests for wkd.historian (the Court Historian / resolver, SPEC §9, §10, §16).

All tests run fully offline with no API keys: the Historian is a scripted
:class:`MockProvider` returning canned evidence JSON. They assert each of the four
Ladder-of-Shame tiers, the ≥2-independent-source corroboration guard (a
single-source "miss" must NOT escalate to apology/cancellation), source-independence
dedup, the no-anchoring rule (deliberation never reaches the Historian), append-only
persistence, status transitions, and the model-run audit.
"""

import json
import unittest

from wkd import db
from wkd.historian import (
    MIN_CORROBORATION,
    MIN_CORROBORATION_HARSH,
    build_historian_prompt,
    correction_copy,
    count_independent_sources,
    guarded_verdict,
    parse_historian_response,
    required_corroboration,
    rule,
    to_tier,
)
from wkd.models import (
    Decree,
    DecreeStatus,
    Deliberation,
    Domain,
    Event,
    EventStatus,
    Source,
    Tier,
)
from wkd.providers import MockProvider


def _evidence(*sources):
    """Build a list of supporting evidence dicts from (name, url) pairs."""
    out = []
    for name, url in sources:
        out.append({"source": name, "url": url, "quote": "...", "supports": True})
    return out


def _hist_json(verdict, evidence, reasoning="because the record says so"):
    return json.dumps({"verdict": verdict, "reasoning": reasoning, "evidence": evidence})


class _Fixture(unittest.TestCase):
    """Common in-memory DB with one standing decree on one pending event."""

    NOW = "2026-08-01T00:00:00Z"

    def setUp(self):
        self.conn = db.init_db(":memory:")
        self.event = db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="Fed July decision",
                domain=Domain.ECON,
                description="FOMC July meeting",
                resolution_date="2026-07-31T00:00:00Z",
                resolution_criteria="A federal funds target-rate cut is announced by 2026-07-31.",
                status=EventStatus.DECREED,
            ),
        )
        # A SECRET deliberation reasoning that the Historian must never see.
        self.secret = "MAGE-SECRET-REASONING-do-not-leak-7f3a"
        db.insert_deliberation(
            self.conn,
            Deliberation(
                event_id=self.event.id,
                round=1,
                model="anthropic/claude-opus-4-8",
                draft_claim="The Fed will cut rates",
                reasoning=self.secret,
            ),
        )
        self.decree = db.insert_decree(
            self.conn,
            Decree(
                event_id=self.event.id,
                claim_text="The Fed shall cut rates by the 31st of July.",
                regal_text="By the 31st of July, the Fed SHALL cut. This is beyond doubt.",
                direction="cut",
                private_confidence=0.72,
                consensus_rounds=2,
                status=DecreeStatus.STANDING,
                issued_at="2026-07-01T00:00:00Z",
            ),
        )

    def tearDown(self):
        self.conn.close()

    def _rule(self, hist_text):
        provider = MockProvider([hist_text])
        result = rule(self.decree, provider, self.conn, now=self.NOW)
        return result, provider


# ---------------------------------------------------------------------------
# The four tiers
# ---------------------------------------------------------------------------


class TierTest(_Fixture):
    def test_vindicated(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        ruling, _ = self._rule(_hist_json("vindicated", ev))
        self.assertIsNotNone(ruling)
        self.assertEqual(ruling.verdict, Tier.VINDICATED)
        self.assertEqual(ruling.corroborating_sources, 2)
        # decree + event status advanced
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.VINDICATED)
        self.assertEqual(db.get_event(self.conn, self.event.id).status, EventStatus.RESOLVED)
        # correction (victory seal) persisted
        corrs = db.list_corrections(self.conn, self.decree.id)
        self.assertEqual(len(corrs), 1)
        self.assertEqual(corrs[0].tier, Tier.VINDICATED)
        self.assertIn("VINDICATED", corrs[0].correction_text)

    def test_cliffnotes(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        ruling, _ = self._rule(_hist_json("cliffnotes", ev))
        self.assertEqual(ruling.verdict, Tier.CLIFFNOTES)
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.CLIFFNOTES)

    def test_apology_with_strong_corroboration(self):
        ev = _evidence(
            ("Reuters", "https://reuters.com/a"),
            ("AP", "https://apnews.com/b"),
            ("Bloomberg", "https://bloomberg.com/c"),
        )
        ruling, _ = self._rule(_hist_json("apology", ev))
        self.assertEqual(ruling.verdict, Tier.APOLOGY)
        self.assertEqual(ruling.corroborating_sources, 3)
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.APOLOGY)
        corr = db.list_corrections(self.conn, self.decree.id)[0]
        self.assertEqual(corr.tier, Tier.APOLOGY)
        self.assertIn("APOLOGY", corr.correction_text)

    def test_cancellation_with_strong_corroboration(self):
        ev = _evidence(
            ("Reuters", "https://reuters.com/a"),
            ("AP", "https://apnews.com/b"),
            ("BBC", "https://bbc.com/c"),
        )
        ruling, _ = self._rule(_hist_json("cancellation", ev))
        self.assertEqual(ruling.verdict, Tier.CANCELLATION)
        # Tier.CANCELLATION maps to DecreeStatus.CANCELLED (past tense).
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.CANCELLED)


# ---------------------------------------------------------------------------
# The corroboration guard (the heart of integrity safeguard §16.3)
# ---------------------------------------------------------------------------


class CorroborationGuardTest(_Fixture):
    def test_single_source_miss_does_not_escalate_to_apology(self):
        # A claimed "apology" backed by ONE source must NOT produce apology/cancellation.
        ev = _evidence(("Reuters", "https://reuters.com/only"))
        ruling, _ = self._rule(_hist_json("apology", ev))
        self.assertIsNone(ruling)  # Historian abstains
        # nothing written, decree stays standing
        self.assertEqual(db.list_rulings(self.conn), [])
        self.assertEqual(db.list_corrections(self.conn), [])
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.STANDING)
        self.assertEqual(db.get_event(self.conn, self.event.id).status, EventStatus.DECREED)

    def test_single_source_cancellation_abstains(self):
        ev = _evidence(("Reuters", "https://reuters.com/only"))
        ruling, _ = self._rule(_hist_json("cancellation", ev))
        self.assertIsNone(ruling)
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.STANDING)

    def test_two_source_apology_downgrades_to_cliffnotes(self):
        # Enough to note a problem (≥2) but short of the harsh floor (3): cliffnotes.
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        ruling, _ = self._rule(_hist_json("apology", ev))
        self.assertIsNotNone(ruling)
        self.assertEqual(ruling.verdict, Tier.CLIFFNOTES)  # NOT apology
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.CLIFFNOTES)
        # audit trail records the downgrade
        record = json.loads(ruling.evidence_json)
        self.assertEqual(record["proposed_verdict"], "apology")
        self.assertEqual(record["final_verdict"], "cliffnotes")
        self.assertTrue(record["downgraded"])

    def test_single_source_vindicated_abstains(self):
        # Even a positive verdict needs ≥2 independent sources (SPEC §16.3).
        ev = _evidence(("Reuters", "https://reuters.com/only"))
        ruling, _ = self._rule(_hist_json("vindicated", ev))
        self.assertIsNone(ruling)
        self.assertEqual(db.get_decree(self.conn, self.decree.id).status, DecreeStatus.STANDING)

    def test_same_outlet_twice_counts_once(self):
        # Two Reuters articles are NOT independent -> only 1 source -> abstain.
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("Reuters", "https://reuters.com/b"))
        self.assertEqual(count_independent_sources(ev), 1)
        ruling, _ = self._rule(_hist_json("vindicated", ev))
        self.assertIsNone(ruling)

    def test_same_domain_different_path_counts_once(self):
        # Independence by domain when only urls are given.
        ev = [
            {"url": "https://www.reuters.com/markets/x"},
            {"url": "https://reuters.com/markets/y"},
        ]
        self.assertEqual(count_independent_sources(ev), 1)


# ---------------------------------------------------------------------------
# Independence / no-anchoring (SPEC §16.2) + grounding
# ---------------------------------------------------------------------------


class IndependenceTest(_Fixture):
    def test_prompt_contains_claim_and_criteria(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        _, provider = self._rule(_hist_json("vindicated", ev))
        call = provider.calls[0]
        prompt = call["system"] + "\n" + call["user"]
        self.assertIn(self.decree.claim_text, prompt)
        self.assertIn(self.event.resolution_criteria, prompt)

    def test_prompt_never_leaks_deliberation(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        _, provider = self._rule(_hist_json("vindicated", ev))
        call = provider.calls[0]
        prompt = call["system"] + "\n" + call["user"]
        # the council's secret reasoning, regal text, direction, and confidence
        # must never reach the Historian (no anchoring).
        self.assertNotIn(self.secret, prompt)
        self.assertNotIn(self.decree.regal_text, prompt)
        self.assertNotIn("0.72", prompt)

    def test_historian_call_is_search_grounded_json(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        _, provider = self._rule(_hist_json("vindicated", ev))
        call = provider.calls[0]
        self.assertTrue(call["search"])     # SPEC §9 search-grounded
        self.assertTrue(call["want_json"])  # strict JSON verdict


# ---------------------------------------------------------------------------
# Persistence: append-only + audit
# ---------------------------------------------------------------------------


class PersistenceTest(_Fixture):
    def test_model_run_audited(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        self._rule(_hist_json("vindicated", ev))
        runs = db.list_model_runs(self.conn, component="historian")
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0].component, "historian")

    def test_model_run_audited_even_on_abstain(self):
        # Abstaining still cost a call; it must be logged for the audit (§16.7).
        ev = _evidence(("Reuters", "https://reuters.com/only"))
        ruling, _ = self._rule(_hist_json("apology", ev))
        self.assertIsNone(ruling)
        self.assertEqual(len(db.list_model_runs(self.conn, component="historian")), 1)

    def test_rulings_are_append_only(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        provider = MockProvider(
            [_hist_json("vindicated", ev), _hist_json("cliffnotes", ev)]
        )
        r1 = rule(self.decree, provider, self.conn, now=self.NOW)
        r2 = rule(self.decree, provider, self.conn, now="2026-08-02T00:00:00Z")
        self.assertIsNotNone(r1)
        self.assertIsNotNone(r2)
        rulings = db.list_rulings(self.conn, self.decree.id)
        self.assertEqual(len(rulings), 2)  # nothing overwritten
        self.assertEqual(len(db.list_corrections(self.conn, self.decree.id)), 2)

    def test_evidence_json_roundtrips(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        ruling, _ = self._rule(_hist_json("vindicated", ev))
        record = json.loads(ruling.evidence_json)
        self.assertEqual(record["independent_sources"], 2)
        self.assertEqual(len(record["evidence"]), 2)


# ---------------------------------------------------------------------------
# Atomicity (SPEC §16.8): a crash mid-resolution must not half-write a ruling
# ---------------------------------------------------------------------------


class AtomicityTest(_Fixture):
    def test_crash_mid_resolution_rolls_back_and_retry_does_not_duplicate(self):
        import wkd.historian as H

        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        provider = MockProvider(
            [_hist_json("vindicated", ev), _hist_json("vindicated", ev)]
        )

        # Force a crash DURING the decree-status advance — i.e. AFTER the ruling +
        # correction rows were inserted inside the atomic transaction.
        orig = H.update_decree_status

        def boom(*a, **k):
            raise RuntimeError("crash mid-resolution")

        H.update_decree_status = boom
        try:
            with self.assertRaises(RuntimeError):
                rule(self.decree, provider, self.conn, now=self.NOW)
        finally:
            H.update_decree_status = orig

        # The whole verdict rolled back: NO ruling, NO correction; the decree is
        # still standing and its event still decreed (so the driver re-judges it).
        self.assertEqual(db.list_rulings(self.conn, self.decree.id), [])
        self.assertEqual(db.list_corrections(self.conn, self.decree.id), [])
        self.assertEqual(
            db.get_decree(self.conn, self.decree.id).status, DecreeStatus.STANDING
        )
        self.assertEqual(
            db.get_event(self.conn, self.event.id).status, EventStatus.DECREED
        )
        # The model-call audit (committed before the transaction) survived (§16.7).
        self.assertEqual(len(db.list_model_runs(self.conn, component="historian")), 1)

        # The idempotent re-run lands exactly ONE ruling + correction — no duplicate
        # from the interrupted attempt.
        ruling = rule(self.decree, provider, self.conn, now="2026-08-02T00:00:00Z")
        self.assertIsNotNone(ruling)
        self.assertEqual(len(db.list_rulings(self.conn, self.decree.id)), 1)
        self.assertEqual(len(db.list_corrections(self.conn, self.decree.id)), 1)
        self.assertEqual(
            db.get_decree(self.conn, self.decree.id).status, DecreeStatus.VINDICATED
        )


# ---------------------------------------------------------------------------
# Parsing robustness / abstention
# ---------------------------------------------------------------------------


class ParsingTest(_Fixture):
    def test_unparseable_response_abstains(self):
        ruling, _ = self._rule("the Fed did something, I think, no JSON here")
        self.assertIsNone(ruling)
        self.assertEqual(db.list_rulings(self.conn), [])
        # but the call is still audited
        self.assertEqual(len(db.list_model_runs(self.conn, component="historian")), 1)

    def test_unknown_verdict_abstains(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        ruling, _ = self._rule(_hist_json("maybe-sort-of", ev))
        self.assertIsNone(ruling)

    def test_fenced_json_is_parsed(self):
        ev = _evidence(("Reuters", "https://reuters.com/a"), ("AP", "https://apnews.com/b"))
        fenced = "Here is my verdict:\n```json\n" + _hist_json("vindicated", ev) + "\n```\nDone."
        ruling, _ = self._rule(fenced)
        self.assertIsNotNone(ruling)
        self.assertEqual(ruling.verdict, Tier.VINDICATED)

    def test_unsaved_decree_raises(self):
        ghost = Decree(event_id=self.event.id, claim_text="x")  # id is None
        with self.assertRaises(ValueError):
            rule(ghost, MockProvider(["{}"]), self.conn, now=self.NOW)


# ---------------------------------------------------------------------------
# Pure helpers (no DB)
# ---------------------------------------------------------------------------


class HelperTest(unittest.TestCase):
    def test_to_tier(self):
        self.assertEqual(to_tier("vindicated"), Tier.VINDICATED)
        self.assertEqual(to_tier("CANCELLED"), Tier.CANCELLATION)
        self.assertEqual(to_tier(" Apology "), Tier.APOLOGY)
        self.assertIsNone(to_tier("nonsense"))
        self.assertIsNone(to_tier(None))

    def test_required_corroboration(self):
        self.assertEqual(required_corroboration(Tier.VINDICATED), MIN_CORROBORATION)
        self.assertEqual(required_corroboration(Tier.CLIFFNOTES), MIN_CORROBORATION)
        self.assertEqual(required_corroboration(Tier.APOLOGY), MIN_CORROBORATION_HARSH)
        self.assertEqual(required_corroboration(Tier.CANCELLATION), MIN_CORROBORATION_HARSH)

    def test_guarded_verdict(self):
        self.assertEqual(guarded_verdict(Tier.VINDICATED, 2), Tier.VINDICATED)
        self.assertIsNone(guarded_verdict(Tier.VINDICATED, 1))
        self.assertEqual(guarded_verdict(Tier.APOLOGY, 3), Tier.APOLOGY)
        self.assertEqual(guarded_verdict(Tier.APOLOGY, 2), Tier.CLIFFNOTES)
        self.assertIsNone(guarded_verdict(Tier.APOLOGY, 1))
        self.assertEqual(guarded_verdict(Tier.CANCELLATION, 2), Tier.CLIFFNOTES)
        self.assertIsNone(guarded_verdict(None, 5))

    def test_count_independent_sources_skips_contradicting(self):
        ev = [
            {"source": "Reuters", "supports": True},
            {"source": "AP", "supports": False},  # contradicts -> not counted
        ]
        self.assertEqual(count_independent_sources(ev), 1)

    def test_count_independent_sources_accepts_plain_strings(self):
        self.assertEqual(count_independent_sources(["Reuters", "AP", "Reuters"]), 2)

    def test_correction_copy_per_tier(self):
        for tier in (Tier.VINDICATED, Tier.CLIFFNOTES, Tier.APOLOGY, Tier.CANCELLATION):
            text = correction_copy(tier, "the Fed shall cut")
            self.assertIn("the Fed shall cut", text)
            self.assertTrue(text.strip())

    def test_parse_historian_response_none_on_garbage(self):
        self.assertIsNone(parse_historian_response("no json"))
        self.assertIsNone(parse_historian_response(""))

    def test_build_prompt_excludes_optional_date(self):
        system, user = build_historian_prompt("claim X", "criteria Y")
        self.assertIn("claim X", user)
        self.assertIn("criteria Y", user)
        self.assertNotIn("RESOLUTION DATE", user)
        system, user = build_historian_prompt("claim X", "criteria Y", "2026-07-31T00:00:00Z")
        self.assertIn("RESOLUTION DATE", user)


if __name__ == "__main__":
    unittest.main()
