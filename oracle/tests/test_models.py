"""Offline tests for wkd.models (vocabularies + frozen entities)."""

import dataclasses
import unittest

from wkd.models import (
    HARSH_TIERS,
    TIER_TO_DECREE_STATUS,
    CheckpointAction,
    Decree,
    DecreeStatus,
    Domain,
    Event,
    EventStatus,
    Ruling,
    Source,
    Tier,
    Verdict,
)


class VocabularyTest(unittest.TestCase):
    def test_event_status_values(self):
        self.assertEqual(
            [s.value for s in EventStatus],
            ["pending", "decreed", "divided", "resolved"],
        )

    def test_decree_status_values(self):
        self.assertEqual(
            [s.value for s in DecreeStatus],
            [
                "standing",
                "vindicated",
                "cliffnotes",
                "apology",
                "cancelled",
                # Non-tier terminal states from the weekly checkpoint (SPEC §8, §16.8).
                "withdrawn",
                "superseded",
            ],
        )

    def test_tier_is_verdict_alias(self):
        self.assertIs(Verdict, Tier)
        self.assertEqual(
            [t.value for t in Tier],
            ["vindicated", "cliffnotes", "apology", "cancellation"],
        )

    def test_strenum_compares_to_plain_str(self):
        # values round-trip through the DB as plain strings
        self.assertEqual(EventStatus.PENDING, "pending")
        self.assertTrue("pending" == EventStatus.PENDING)
        self.assertEqual(str(Domain.CURRENT_EVENTS), "current-events")

    def test_source_values(self):
        self.assertEqual(Source.HARVESTED, "harvested")
        self.assertEqual(Source.FREE_PICK, "free-pick")

    def test_domain_hyphenated_values(self):
        vals = [d.value for d in Domain]
        self.assertIn("current-events", vals)
        self.assertIn("world-news", vals)
        self.assertNotIn("sports", vals)

    def test_checkpoint_actions(self):
        self.assertEqual(
            [a.value for a in CheckpointAction],
            ["reaffirm", "amend", "withdraw"],
        )

    def test_tier_to_decree_status_mapping(self):
        self.assertEqual(TIER_TO_DECREE_STATUS[Tier.VINDICATED], DecreeStatus.VINDICATED)
        self.assertEqual(TIER_TO_DECREE_STATUS[Tier.CLIFFNOTES], DecreeStatus.CLIFFNOTES)
        self.assertEqual(TIER_TO_DECREE_STATUS[Tier.APOLOGY], DecreeStatus.APOLOGY)
        # cancellation verdict -> cancelled decree status
        self.assertEqual(TIER_TO_DECREE_STATUS[Tier.CANCELLATION], DecreeStatus.CANCELLED)

    def test_harsh_tiers(self):
        self.assertEqual(HARSH_TIERS, frozenset({Tier.APOLOGY, Tier.CANCELLATION}))


class EntityTest(unittest.TestCase):
    def test_event_construction_and_defaults(self):
        e = Event(source=Source.HARVESTED, title="Fed meeting", domain=Domain.ECON)
        self.assertEqual(e.status, EventStatus.PENDING)
        self.assertIsNone(e.id)
        self.assertIsNone(e.market_implied_prob)
        self.assertEqual(e.description, "")

    def test_entities_are_frozen(self):
        e = Event(source="harvested", title="t", domain="econ")
        with self.assertRaises(dataclasses.FrozenInstanceError):
            e.title = "mutated"  # type: ignore[misc]

    def test_replace_sets_id(self):
        e = Event(source="harvested", title="t", domain="econ")
        e2 = dataclasses.replace(e, id=7)
        self.assertIsNone(e.id)
        self.assertEqual(e2.id, 7)
        self.assertEqual(e2.title, "t")

    def test_decree_defaults(self):
        d = Decree(event_id=1, claim_text="X will happen")
        self.assertEqual(d.status, DecreeStatus.STANDING)
        self.assertEqual(d.private_confidence, 0.0)
        self.assertEqual(d.consensus_rounds, 0)
        self.assertIsNone(d.supersedes_id)

    def test_ruling_required_fields(self):
        r = Ruling(decree_id=3, verdict=Tier.VINDICATED)
        self.assertEqual(r.verdict, "vindicated")
        self.assertEqual(r.corroborating_sources, 0)
        self.assertEqual(r.evidence_json, "")

    def test_entities_hashable(self):
        # frozen dataclasses are hashable; usable in sets/dict keys
        a = Event(source="harvested", title="t", domain="econ")
        b = Event(source="harvested", title="t", domain="econ")
        self.assertEqual(a, b)
        self.assertEqual(len({a, b}), 1)


if __name__ == "__main__":
    unittest.main()
