"""Offline tests for wkd.council — the deliberation protocol (SPEC §5, §6).

All providers are :class:`~wkd.providers.MockProvider`s scripted to converge
(forge a decree) or diverge (mark the event divided, King silent). No network,
no keys, no pip installs. The clock is injected via ``now=`` for determinism.
"""

import json
import unittest
from datetime import datetime, timezone

from wkd import council, db
from wkd.council import (
    STATUS_CONSENSUS,
    STATUS_DIVIDED,
    STATUS_GATE_FAILED,
    deliberate,
)
from wkd.models import DecreeStatus, EventStatus, Event
from wkd.providers import MockProvider

# A fixed wall-clock so every stored timestamp is deterministic and the matter's
# resolution_date (2026-07-31) is unambiguously in the future.
NOW = datetime(2026, 6, 26, 12, 0, 0, tzinfo=timezone.utc)


def _draft(claim, direction, confidence, *, agree=False, reasoning="because") -> str:
    """Serialize a mage's JSON draft exactly as a real mage would emit it."""
    return json.dumps(
        {
            "claim": claim,
            "direction": direction,
            "confidence": confidence,
            "reasoning": reasoning,
            "agree": agree,
        }
    )


class _CouncilTestBase(unittest.TestCase):
    def setUp(self):
        # In-memory DB kept alive by holding the returned connection.
        self.conn = db.init_db(":memory:")
        self.event = db.insert_event(
            self.conn,
            Event(
                source="harvested",
                title="July FOMC rate decision",
                domain="econ",
                description="The Fed meets on 2026-07-30.",
                resolution_date="2026-07-31",
                resolution_criteria="Per the official FOMC statement on 2026-07-30.",
                market_implied_prob=0.55,
                harvested_at=NOW.isoformat(),
            ),
        )

    def tearDown(self):
        self.conn.close()


class ConvergenceTest(_CouncilTestBase):
    """Both mages converge in round 2 → a decree is forged (SPEC §5)."""

    def _run(self):
        agreed = "The Fed will hold its policy rate unchanged at the July 2026 meeting."
        self.mage_a = MockProvider(
            [
                _draft("Fed holds in July", "hold", 0.7, agree=False),
                _draft(agreed, "hold", 0.8, agree=True),
            ],
            model="claude-test",
            cost=0.002,
        )
        self.mage_b = MockProvider(
            [
                _draft("Likely a hold", "hold", 0.5, agree=False),
                _draft(agreed, "hold", 0.6, agree=True),
            ],
            model="gpt-test",
            cost=0.001,
        )
        self.king = MockProvider(
            ["By the crown's certainty, the Fed SHALL hold in July. It is sealed."],
            model="king-test",
            cost=0.003,
        )
        self.agreed = agreed
        return deliberate(
            self.event,
            self.mage_a,
            self.mage_b,
            self.king,
            self.conn,
            max_rounds=3,
            now=NOW,
        )

    def test_status_and_decree_forged(self):
        res = self._run()
        self.assertEqual(res.status, STATUS_CONSENSUS)
        self.assertTrue(res.is_consensus)
        self.assertFalse(res.is_divided)
        self.assertIsNotNone(res.decree)
        self.assertEqual(res.rounds, 2)  # earliest consensus is after one exchange

    def test_decree_contents(self):
        res = self._run()
        d = res.decree
        self.assertEqual(d.claim_text, self.agreed)
        self.assertEqual(d.direction, "hold")
        # averaged private confidence from the FINAL-round drafts: (0.8+0.6)/2
        self.assertAlmostEqual(d.private_confidence, 0.7, places=6)
        self.assertEqual(d.consensus_rounds, 2)
        self.assertEqual(d.status, DecreeStatus.STANDING)
        self.assertEqual(d.issued_at, NOW.isoformat())
        self.assertIn("SHALL hold", d.regal_text)  # King's styling pass landed

    def test_decree_persisted_and_standing(self):
        res = self._run()
        fetched = db.get_decree(self.conn, res.decree.id)
        self.assertIsNotNone(fetched)
        self.assertEqual(fetched.claim_text, self.agreed)
        standing = db.list_standing_decrees(self.conn)
        self.assertEqual([d.id for d in standing], [res.decree.id])

    def test_event_marked_decreed(self):
        self._run()
        ev = db.get_event(self.conn, self.event.id)
        self.assertEqual(ev.status, EventStatus.DECREED)

    def test_king_called_exactly_once(self):
        self._run()
        self.assertEqual(self.king.call_count, 1)
        self.assertEqual(self.mage_a.call_count, 2)
        self.assertEqual(self.mage_b.call_count, 2)

    def test_transcript_persisted(self):
        res = self._run()
        delibs = db.list_deliberations(self.conn, self.event.id)
        self.assertEqual(len(delibs), 4)  # 2 rounds x 2 mages
        self.assertEqual(res.deliberations, delibs)
        self.assertEqual([d.round for d in delibs], [1, 1, 2, 2])
        models = {d.model for d in delibs}
        self.assertEqual(models, {"claude-test", "gpt-test"})
        for d in delibs:
            self.assertEqual(d.created_at, NOW.isoformat())

    def test_model_runs_recorded_with_cost(self):
        self._run()
        runs = db.list_model_runs(self.conn)
        self.assertEqual(len(runs), 5)  # 4 mage calls + 1 king
        council_runs = db.list_model_runs(self.conn, component=council.COMPONENT_COUNCIL)
        king_runs = db.list_model_runs(self.conn, component=council.COMPONENT_KING)
        self.assertEqual(len(council_runs), 4)
        self.assertEqual(len(king_runs), 1)
        # cost flows through from the scripted providers' per-call cost
        self.assertEqual(king_runs[0].cost, 0.003)
        self.assertEqual({r.cost for r in council_runs}, {0.002, 0.001})


class IndependenceAndProtocolTest(_CouncilTestBase):
    """Round 1 is independent; round 2 is the exchange; mages get want_json."""

    def test_round_one_independent_round_two_exchange(self):
        other_a_claim = "MAGE-A-SECRET-CLAIM holds in July"
        other_b_claim = "MAGE-B-SECRET-CLAIM holds in July"
        agreed = "The Fed will hold its policy rate unchanged in July 2026 (joint)."
        mage_a = MockProvider(
            [
                _draft(other_a_claim, "hold", 0.7, agree=False),
                _draft(agreed, "hold", 0.8, agree=True),
            ]
        )
        mage_b = MockProvider(
            [
                _draft(other_b_claim, "hold", 0.5, agree=False),
                _draft(agreed, "hold", 0.6, agree=True),
            ]
        )
        king = MockProvider(["Proclaimed."])
        deliberate(self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW)

        # Round 1 (call index 0) is independent: neither mage sees the other.
        self.assertNotIn(other_b_claim, mage_a.calls[0]["user"])
        self.assertNotIn(other_a_claim, mage_b.calls[0]["user"])
        # Round 2 (call index 1) is the exchange: each sees the OTHER's draft.
        self.assertIn(other_b_claim, mage_a.calls[1]["user"])
        self.assertIn(other_a_claim, mage_b.calls[1]["user"])

    def test_mages_requested_json_king_not(self):
        agreed = "The Fed will hold its policy rate unchanged in July 2026 here."
        mage_a = MockProvider([_draft("x holds rates", "hold", 0.7),
                               _draft(agreed, "hold", 0.8, agree=True)])
        mage_b = MockProvider([_draft("y holds rates", "hold", 0.5),
                               _draft(agreed, "hold", 0.6, agree=True)])
        king = MockProvider(["Proclaimed."])
        deliberate(self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW)
        self.assertTrue(all(c["want_json"] for c in mage_a.calls))
        self.assertTrue(all(c["want_json"] for c in mage_b.calls))
        self.assertFalse(king.calls[0]["want_json"])


class DivisionTest(_CouncilTestBase):
    """The mages never agree → divided; the King holds his tongue (SPEC §5)."""

    def _run(self, max_rounds=3):
        # mage_a always "hold", mage_b always "cut", never agreeing.
        self.mage_a = MockProvider(
            [_draft("Fed holds", "hold", 0.6, agree=False) for _ in range(max_rounds)],
            model="claude-test",
        )
        self.mage_b = MockProvider(
            [_draft("Fed cuts", "cut", 0.6, agree=False) for _ in range(max_rounds)],
            model="gpt-test",
        )
        # An empty, default-less King: if it is ever called the test fails loudly.
        self.king = MockProvider([])
        return deliberate(
            self.event,
            self.mage_a,
            self.mage_b,
            self.king,
            self.conn,
            max_rounds=max_rounds,
            now=NOW,
        )

    def test_status_divided_no_decree(self):
        res = self._run()
        self.assertEqual(res.status, STATUS_DIVIDED)
        self.assertTrue(res.is_divided)
        self.assertFalse(res.is_consensus)
        self.assertIsNone(res.decree)
        self.assertEqual(res.rounds, 3)

    def test_king_silent_and_no_decrees(self):
        self._run()
        self.assertEqual(self.king.call_count, 0)
        self.assertEqual(db.list_decrees(self.conn), [])

    def test_event_marked_divided(self):
        self._run()
        ev = db.get_event(self.conn, self.event.id)
        self.assertEqual(ev.status, EventStatus.DIVIDED)

    def test_full_transcript_still_persisted(self):
        self._run()
        delibs = db.list_deliberations(self.conn, self.event.id)
        self.assertEqual(len(delibs), 6)  # 3 rounds x 2 mages
        runs = db.list_model_runs(self.conn)
        self.assertEqual(len(runs), 6)  # no King run
        self.assertEqual(self.mage_a.call_count, 3)
        self.assertEqual(self.mage_b.call_count, 3)

    def test_agreement_on_direction_only_is_not_enough(self):
        # Same direction but explicit agree=False must NOT forge a decree:
        # the protocol requires an explicit joint endorsement.
        mage_a = MockProvider([_draft("Fed holds", "hold", 0.6, agree=False) for _ in range(3)])
        mage_b = MockProvider([_draft("Fed holds", "hold", 0.6, agree=False) for _ in range(3)])
        king = MockProvider([])
        res = deliberate(self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW)
        self.assertEqual(res.status, STATUS_DIVIDED)
        self.assertEqual(king.call_count, 0)

    def test_single_round_cap_cannot_reach_consensus(self):
        # max_rounds=1 means no exchange round, so consensus is impossible.
        res = self._run(max_rounds=1)
        self.assertEqual(res.status, STATUS_DIVIDED)
        self.assertEqual(res.rounds, 1)
        self.assertEqual(len(db.list_deliberations(self.conn, self.event.id)), 2)


class FalsifiabilityGateTest(_CouncilTestBase):
    """Even on consensus, an ungradeable claim is rejected (SPEC §6)."""

    def _converging_mages(self, claim):
        mage_a = MockProvider([_draft("draft a", "yes", 0.7),
                              _draft(claim, "yes", 0.8, agree=True)])
        mage_b = MockProvider([_draft("draft b", "yes", 0.6),
                              _draft(claim, "yes", 0.7, agree=True)])
        return mage_a, mage_b

    def test_past_resolution_date_rejected(self):
        # Force the resolution_date into the past by advancing the injected clock.
        claim = "The Fed will hold its policy rate unchanged at the meeting."
        mage_a, mage_b = self._converging_mages(claim)
        king = MockProvider([])
        future_now = datetime(2030, 1, 1, tzinfo=timezone.utc)
        res = deliberate(
            self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=future_now
        )
        self.assertEqual(res.status, STATUS_GATE_FAILED)
        self.assertIsNone(res.decree)
        self.assertEqual(king.call_count, 0)  # King still holds his tongue
        self.assertIn("future", res.reason)
        ev = db.get_event(self.conn, self.event.id)
        self.assertEqual(ev.status, EventStatus.DIVIDED)
        self.assertEqual(db.list_decrees(self.conn), [])

    def test_hedged_claim_rejected(self):
        # Mages "agree" but on a hedged, unfalsifiable claim.
        claim = "The Fed might possibly hold rates, but it is unclear and uncertain."
        mage_a, mage_b = self._converging_mages(claim)
        king = MockProvider([])
        res = deliberate(
            self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW
        )
        self.assertEqual(res.status, STATUS_GATE_FAILED)
        self.assertEqual(king.call_count, 0)
        self.assertIn("falsifiability", res.reason)

    def test_injected_gate_override_is_used(self):
        claim = "The Fed will hold its policy rate unchanged at the meeting."
        mage_a, mage_b = self._converging_mages(claim)
        king = MockProvider(["Decreed."])
        calls = {}

        def always_fail(claim_text, event, now_dt):
            calls["claim"] = claim_text
            return False, "custom rejection"

        res = deliberate(
            self.event,
            mage_a,
            mage_b,
            king,
            self.conn,
            max_rounds=3,
            now=NOW,
            falsifiability_gate=always_fail,
        )
        self.assertEqual(res.status, STATUS_GATE_FAILED)
        self.assertIn("custom rejection", res.reason)
        self.assertEqual(calls["claim"], claim)  # gate saw the agreed claim
        self.assertEqual(king.call_count, 0)


class MiscTest(_CouncilTestBase):
    def test_unpersisted_event_rejected(self):
        ghost = Event(source="free-pick", title="t", domain="econ",
                      resolution_date="2026-07-31", resolution_criteria="c")
        with self.assertRaises(ValueError):
            deliberate(ghost, MockProvider(["x"]), MockProvider(["y"]),
                       MockProvider(["z"]), self.conn, now=NOW)

    def test_now_accepts_iso_string(self):
        agreed = "The Fed will hold its policy rate unchanged in July 2026 (iso)."
        mage_a = MockProvider([_draft("a holds", "hold", 0.7),
                              _draft(agreed, "hold", 0.8, agree=True)])
        mage_b = MockProvider([_draft("b holds", "hold", 0.5),
                              _draft(agreed, "hold", 0.6, agree=True)])
        king = MockProvider(["Proclaimed."])
        res = deliberate(self.event, mage_a, mage_b, king, self.conn,
                         max_rounds=3, now="2026-06-26T12:00:00+00:00")
        self.assertEqual(res.decree.issued_at, "2026-06-26T12:00:00+00:00")


class OutcomeAgreementTest(_CouncilTestBase):
    """Loosened consensus (cheap-model robustness): mutual `agree` on the same
    OUTCOME forges a decree even when the mages' direction labels differ verbatim.
    Regression for the World Cup light test, where two Haiku mages both predicted
    the same winner but their exact-string directions didn't match."""

    def test_agree_with_differing_direction_labels_forges(self):
        mage_a = MockProvider(
            [
                _draft("Fed holds in July", "hold", 0.7, agree=False),
                _draft("The Fed keeps its policy rate unchanged in July 2026", "hold rates", 0.78, agree=True),
            ],
            model="claude-test",
        )
        mage_b = MockProvider(
            [
                _draft("Likely a hold", "no change", 0.6, agree=False),
                _draft("The Fed leaves the policy rate flat at the July meeting", "no hike no cut", 0.72, agree=True),
            ],
            model="gpt-test",
        )
        king = MockProvider(["By the crown, the Fed SHALL hold. It is sealed."], model="king-test")
        res = deliberate(self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW)
        # Different direction labels ("hold rates" vs "no hike no cut") used to divide;
        # now the mutual agree on the same outcome forges a decree.
        self.assertEqual(res.status, STATUS_CONSENSUS)
        self.assertTrue(res.is_consensus)
        self.assertIsNotNone(res.decree)


class KingRefusalTest(_CouncilTestBase):
    """The King (Haiku) sometimes refuses to proclaim certainty about a real
    event. That refusal text must NEVER become the stored ``regal_text``: the
    engine retries once with a firmer, theatrical framing and finally falls back
    to a deterministic templated decree, so ``regal_text`` is never a refusal and
    never empty."""

    AGREED = "The Fed will hold its policy rate unchanged at the July 2026 meeting."

    def _converging_mages(self):
        mage_a = MockProvider(
            [
                _draft("Fed holds in July", "hold", 0.7, agree=False),
                _draft(self.AGREED, "hold", 0.8, agree=True),
            ],
            model="claude-test",
        )
        mage_b = MockProvider(
            [
                _draft("Likely a hold", "hold", 0.5, agree=False),
                _draft(self.AGREED, "hold", 0.6, agree=True),
            ],
            model="gpt-test",
        )
        return mage_a, mage_b

    def test_refusal_then_retry_recovers(self):
        mage_a, mage_b = self._converging_mages()
        # First King render is a refusal; the firmer theatrical retry complies.
        king = MockProvider(
            [
                "I appreciate the creative exercise, but I can't proclaim "
                "certainty about real-world financial outcomes.",
                "By the throne, the Fed SHALL hold its rate in July. It is sealed.",
            ],
            model="king-test",
            cost=0.003,
        )
        res = deliberate(
            self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW
        )
        self.assertEqual(res.status, STATUS_CONSENSUS)
        self.assertIsNotNone(res.decree)
        regal = res.decree.regal_text
        self.assertTrue(regal.strip())  # never empty
        self.assertFalse(council._looks_like_refusal(regal))  # never a refusal
        self.assertIn("SHALL hold", regal)  # used the retry, not the refusal text
        self.assertEqual(king.call_count, 2)  # first render + one retry
        # Honest accounting: BOTH King calls are logged as model_runs rows.
        king_runs = db.list_model_runs(self.conn, component=council.COMPONENT_KING)
        self.assertEqual(len(king_runs), 2)

    def test_persistent_refusal_falls_back_to_template(self):
        mage_a, mage_b = self._converging_mages()
        # The King refuses on BOTH attempts → deterministic templated decree.
        king = MockProvider(
            [
                "I cannot proclaim this as absolute fact about the future.",
                "I'm not able to guarantee a real-world financial outcome.",
            ],
            model="king-test",
        )
        res = deliberate(
            self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW
        )
        self.assertEqual(res.status, STATUS_CONSENSUS)
        regal = res.decree.regal_text
        self.assertTrue(regal.strip())
        self.assertFalse(council._looks_like_refusal(regal))
        self.assertIn("Thus it is sealed", regal)
        # The fallback decree is forged from the agreed claim.
        self.assertIn(self.AGREED.rstrip("."), regal)
        self.assertEqual(king.call_count, 2)

    def test_empty_render_falls_back_to_template(self):
        mage_a, mage_b = self._converging_mages()
        # An empty render (not a refusal, but unusable) also falls back.
        king = MockProvider(["", ""], model="king-test")
        res = deliberate(
            self.event, mage_a, mage_b, king, self.conn, max_rounds=3, now=NOW
        )
        self.assertEqual(res.status, STATUS_CONSENSUS)
        regal = res.decree.regal_text
        self.assertTrue(regal.strip())  # never empty
        self.assertIn("Thus it is sealed", regal)


if __name__ == "__main__":
    unittest.main()
