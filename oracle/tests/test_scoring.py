"""Offline tests for wkd.scoring (SPEC §11 scoreboard metrics).

A small synthetic store with *known* outcomes is seeded in :meth:`setUp`, then
each metric section is asserted against hand-computed exact values. No network,
no API keys, no pip installs — pure stdlib + the foundation modules.

The fixture (10 ruled decrees + 1 standing + divided/pending events) is laid out
so every split has clean targets; see the table in ``_RULED`` below.
"""

import json
import unittest

from wkd import db
from wkd import scoring
from wkd.models import (
    Decree,
    DecreeStatus,
    Domain,
    Event,
    EventStatus,
    Ruling,
    Source,
    Tier,
    TIER_TO_DECREE_STATUS,
)

# Each ruled decree: (domain, source, verdict, private_confidence, market_prob)
# Designed targets:
#   hit rate          = 6/10 = 0.6
#   tiers             = vindicated 6, cliffnotes 2, apology 1, cancellation 1
#   per-domain        = econ 3/4, politics 1/3, crypto 2/3
#   by-source         = harvested 5/6, free-pick 1/4
#   market-sourced    = 6 decrees (those with a market_prob)
_RULED = [
    # econ (4): 3 vindicated
    (Domain.ECON, Source.HARVESTED, Tier.VINDICATED, 0.95, 0.6),
    (Domain.ECON, Source.HARVESTED, Tier.VINDICATED, 0.85, 0.4),
    (Domain.ECON, Source.FREE_PICK, Tier.VINDICATED, 0.75, None),
    (Domain.ECON, Source.FREE_PICK, Tier.APOLOGY, 0.65, None),
    # politics (3): 1 vindicated
    (Domain.POLITICS, Source.HARVESTED, Tier.VINDICATED, 0.55, 0.7),
    (Domain.POLITICS, Source.HARVESTED, Tier.CLIFFNOTES, 0.45, 0.5),
    (Domain.POLITICS, Source.FREE_PICK, Tier.CANCELLATION, 0.25, None),
    # crypto (3): 2 vindicated
    (Domain.CRYPTO, Source.HARVESTED, Tier.VINDICATED, 0.15, 0.3),
    (Domain.CRYPTO, Source.FREE_PICK, Tier.CLIFFNOTES, 0.05, None),
    (Domain.CRYPTO, Source.HARVESTED, Tier.VINDICATED, 0.35, 0.8),
]

FIXED_NOW = "2026-07-01T00:00:00Z"


class ScoringTestBase(unittest.TestCase):
    def setUp(self):
        self.conn = db.init_db(":memory:")
        self._seed()
        self.metrics = scoring.build_metrics(self.conn, rng_seed=0)

    def tearDown(self):
        self.conn.close()

    def _seed(self):
        # 10 resolved events, each with one ruled decree.
        for i, (domain, source, verdict, conf, mkt) in enumerate(_RULED):
            ev = db.insert_event(
                self.conn,
                Event(
                    source=source,
                    title=f"matter-{i}",
                    domain=domain,
                    resolution_date="2026-06-15T00:00:00Z",
                    resolution_criteria="objective",
                    market_implied_prob=mkt,
                    harvested_at="2026-06-01T00:00:00Z",
                    status=EventStatus.RESOLVED,
                ),
            )
            dec = db.insert_decree(
                self.conn,
                Decree(
                    event_id=ev.id,
                    claim_text=f"claim-{i}",
                    private_confidence=conf,
                    status=TIER_TO_DECREE_STATUS[verdict],
                    issued_at="2026-06-02T00:00:00Z",
                ),
            )
            db.insert_ruling(
                self.conn,
                Ruling(
                    decree_id=dec.id,
                    verdict=verdict,
                    historian_model="mock-historian",
                    corroborating_sources=3,
                    ruled_at="2026-06-16T00:00:00Z",
                ),
            )

        # 1 standing decree (event 'decreed', not yet ruled).
        ev_standing = db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="standing",
                domain=Domain.WORLD_NEWS,
                resolution_date="2026-12-01T00:00:00Z",
                status=EventStatus.DECREED,
            ),
        )
        db.insert_decree(
            self.conn,
            Decree(event_id=ev_standing.id, claim_text="future", private_confidence=0.5),
        )

        # 2 divided events (King held his tongue), 2 still pending.
        for n in range(2):
            db.insert_event(
                self.conn,
                Event(source=Source.HARVESTED, title=f"divided-{n}",
                      domain=Domain.POLITICS, status=EventStatus.DIVIDED),
            )
        for n in range(2):
            db.insert_event(
                self.conn,
                Event(source=Source.FREE_PICK, title=f"pending-{n}",
                      domain=Domain.ECON, status=EventStatus.PENDING),
            )


class CountsTest(ScoringTestBase):
    def test_counts(self):
        c = self.metrics["counts"]
        self.assertEqual(c["events_total"], 15)
        self.assertEqual(c["events_pending"], 2)
        self.assertEqual(c["events_decreed"], 1)
        self.assertEqual(c["events_divided"], 2)
        self.assertEqual(c["events_resolved"], 10)
        self.assertEqual(c["decrees_total"], 11)
        self.assertEqual(c["decrees_standing"], 1)
        self.assertEqual(c["decrees_ruled"], 10)


class HitRateTest(ScoringTestBase):
    def test_point_estimate(self):
        h = self.metrics["hit_rate"]
        self.assertEqual(h["ruled"], 10)
        self.assertEqual(h["vindicated"], 6)
        self.assertAlmostEqual(h["rate"], 0.6)

    def test_ci_brackets_the_point(self):
        h = self.metrics["hit_rate"]
        self.assertGreaterEqual(h["rate"], h["ci_low"])
        self.assertLessEqual(h["rate"], h["ci_high"])
        self.assertGreaterEqual(h["ci_low"], 0.0)
        self.assertLessEqual(h["ci_high"], 1.0)
        self.assertEqual(h["ci_method"], "bootstrap-percentile")

    def test_ci_is_deterministic_for_seed(self):
        a = scoring.build_metrics(self.conn, rng_seed=0)["hit_rate"]
        b = scoring.build_metrics(self.conn, rng_seed=0)["hit_rate"]
        self.assertEqual((a["ci_low"], a["ci_high"]), (b["ci_low"], b["ci_high"]))

    def test_different_seed_may_differ_but_stays_valid(self):
        other = scoring.build_metrics(self.conn, rng_seed=12345)["hit_rate"]
        self.assertGreaterEqual(other["ci_low"], 0.0)
        self.assertLessEqual(other["ci_high"], 1.0)
        self.assertLessEqual(other["ci_low"], other["ci_high"])


class TierDistributionTest(ScoringTestBase):
    def test_counts_and_fractions(self):
        td = self.metrics["tier_distribution"]
        self.assertEqual(td["counts"]["vindicated"], 6)
        self.assertEqual(td["counts"]["cliffnotes"], 2)
        self.assertEqual(td["counts"]["apology"], 1)
        self.assertEqual(td["counts"]["cancellation"], 1)
        self.assertEqual(sum(td["counts"].values()), 10)
        self.assertAlmostEqual(td["fractions"]["vindicated"], 0.6)
        self.assertAlmostEqual(td["fractions"]["cliffnotes"], 0.2)
        self.assertAlmostEqual(td["fractions"]["apology"], 0.1)
        self.assertAlmostEqual(td["fractions"]["cancellation"], 0.1)


class PerDomainTest(ScoringTestBase):
    def test_per_domain_accuracy(self):
        pd = self.metrics["per_domain_accuracy"]
        self.assertEqual(pd["econ"]["ruled"], 4)
        self.assertEqual(pd["econ"]["vindicated"], 3)
        self.assertAlmostEqual(pd["econ"]["hit_rate"], 0.75)
        self.assertEqual(pd["politics"]["ruled"], 3)
        self.assertAlmostEqual(pd["politics"]["hit_rate"], 1 / 3)
        self.assertEqual(pd["crypto"]["ruled"], 3)
        self.assertAlmostEqual(pd["crypto"]["hit_rate"], 2 / 3)
        # world-news only had a standing (unruled) decree -> not present.
        self.assertNotIn("world-news", pd)


class DividedTest(ScoringTestBase):
    def test_divided_rate(self):
        d = self.metrics["divided"]
        self.assertEqual(d["council_divided"], 2)
        self.assertEqual(d["decreed"], 11)  # 1 decreed + 10 resolved
        self.assertEqual(d["deliberated"], 13)
        self.assertAlmostEqual(d["divided_rate"], 2 / 13)


class CalibrationTest(ScoringTestBase):
    def test_buckets_total_and_endpoints(self):
        cal = self.metrics["calibration"]
        self.assertEqual(cal["n_buckets"], 10)
        buckets = cal["buckets"]
        self.assertEqual(len(buckets), 10)
        self.assertEqual(sum(b["n"] for b in buckets), 10)
        self.assertEqual(sum(b["vindicated"] for b in buckets), 6)
        # bucket 0 [0.0,0.1): the 0.05 cliffnotes -> miss
        self.assertEqual(buckets[0]["n"], 1)
        self.assertAlmostEqual(buckets[0]["mean_confidence"], 0.05)
        self.assertAlmostEqual(buckets[0]["hit_rate"], 0.0)
        # bucket 9 [0.9,1.0]: the 0.95 vindicated -> hit
        self.assertEqual(buckets[9]["n"], 1)
        self.assertAlmostEqual(buckets[9]["mean_confidence"], 0.95)
        self.assertAlmostEqual(buckets[9]["hit_rate"], 1.0)
        # bucket 1 [0.1,0.2): the 0.15 vindicated -> hit
        self.assertAlmostEqual(buckets[1]["hit_rate"], 1.0)


class BeatTheCrowdTest(ScoringTestBase):
    def test_brier_and_directional(self):
        b = self.metrics["beat_the_crowd"]
        self.assertEqual(b["n"], 6)
        self.assertAlmostEqual(b["council_brier"], 1.575 / 6)
        self.assertAlmostEqual(b["market_brier"], 1.39 / 6)
        self.assertFalse(b["council_beats_market_brier"])
        self.assertEqual(b["council_correct"], 4)
        self.assertEqual(b["market_correct"], 3)
        self.assertEqual(b["council_better_calls"], 2)
        self.assertEqual(b["market_better_calls"], 1)


class BaselineTest(ScoringTestBase):
    def test_status_quo_baseline(self):
        base = self.metrics["baseline"]
        self.assertEqual(base["n"], 10)
        self.assertAlmostEqual(base["council_hit_rate"], 0.6)
        self.assertAlmostEqual(base["status_quo_hit_rate"], 0.4)
        self.assertAlmostEqual(base["council_minus_baseline"], 0.2)


class BySourceTest(ScoringTestBase):
    def test_harvested_vs_free_pick(self):
        bs = self.metrics["by_source"]
        self.assertEqual(bs["harvested"]["ruled"], 6)
        self.assertEqual(bs["harvested"]["vindicated"], 5)
        self.assertAlmostEqual(bs["harvested"]["hit_rate"], 5 / 6)
        self.assertEqual(bs["free-pick"]["ruled"], 4)
        self.assertEqual(bs["free-pick"]["vindicated"], 1)
        self.assertAlmostEqual(bs["free-pick"]["hit_rate"], 0.25)


class PersistenceTest(ScoringTestBase):
    def test_compute_persists_snapshot(self):
        snap = scoring.compute_metrics(self.conn, rng_seed=0, now=FIXED_NOW)
        self.assertIsNotNone(snap.id)
        self.assertEqual(snap.computed_at, FIXED_NOW)
        latest = db.latest_metrics(self.conn)
        self.assertEqual(latest.id, snap.id)
        data = json.loads(latest.metrics_json)
        self.assertEqual(data["computed_at"], FIXED_NOW)
        self.assertAlmostEqual(data["hit_rate"]["rate"], 0.6)
        self.assertEqual(data["metrics_version"], scoring.METRICS_VERSION)

    def test_metrics_json_is_valid_and_canonical(self):
        snap = scoring.compute_metrics(self.conn, rng_seed=0, now=FIXED_NOW)
        # round-trips as JSON and was serialized with sort_keys=True
        loaded = json.loads(snap.metrics_json)
        self.assertEqual(
            snap.metrics_json, json.dumps(loaded, sort_keys=True)
        )


class EmptyStoreTest(unittest.TestCase):
    """All sections must be well-defined (and zero) on a fresh store."""

    def setUp(self):
        self.conn = db.init_db(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_no_division_by_zero(self):
        m = scoring.build_metrics(self.conn, rng_seed=0)
        self.assertEqual(m["counts"]["decrees_ruled"], 0)
        self.assertEqual(m["hit_rate"]["ruled"], 0)
        self.assertEqual(m["hit_rate"]["rate"], 0.0)
        self.assertEqual(m["hit_rate"]["ci_low"], 0.0)
        self.assertEqual(m["hit_rate"]["ci_high"], 0.0)
        self.assertEqual(m["divided"]["divided_rate"], 0.0)
        self.assertEqual(m["beat_the_crowd"]["n"], 0)
        self.assertFalse(m["beat_the_crowd"]["council_beats_market_brier"])
        self.assertEqual(m["baseline"]["council_minus_baseline"], 0.0)
        self.assertEqual(m["per_domain_accuracy"], {})
        self.assertEqual(sum(b["n"] for b in m["calibration"]["buckets"]), 0)

    def test_compute_on_empty_persists(self):
        snap = scoring.compute_metrics(self.conn, rng_seed=0, now=FIXED_NOW)
        self.assertIsNotNone(snap.id)
        self.assertEqual(db.latest_metrics(self.conn).id, snap.id)


class BootstrapCiUnitTest(unittest.TestCase):
    """Direct, seed-independent assertions on the bootstrap helper."""

    def test_all_ones(self):
        self.assertEqual(scoring.bootstrap_ci([1, 1, 1], rng_seed=0), (1.0, 1.0))

    def test_all_zeros(self):
        self.assertEqual(scoring.bootstrap_ci([0, 0, 0, 0], rng_seed=7), (0.0, 0.0))

    def test_empty(self):
        self.assertEqual(scoring.bootstrap_ci([], rng_seed=0), (0.0, 0.0))

    def test_deterministic_for_seed(self):
        data = [1, 0, 1, 1, 0, 0, 1, 0]
        self.assertEqual(
            scoring.bootstrap_ci(data, rng_seed=3, resamples=500),
            scoring.bootstrap_ci(data, rng_seed=3, resamples=500),
        )

    def test_bounds(self):
        low, high = scoring.bootstrap_ci([1, 0, 1, 0, 1], rng_seed=1)
        self.assertGreaterEqual(low, 0.0)
        self.assertLessEqual(high, 1.0)
        self.assertLessEqual(low, high)


class PercentileBrierUnitTest(unittest.TestCase):
    def test_percentile_basic(self):
        vals = [0.0, 0.25, 0.5, 0.75, 1.0]
        self.assertAlmostEqual(scoring._percentile(vals, 0.0), 0.0)
        self.assertAlmostEqual(scoring._percentile(vals, 1.0), 1.0)
        self.assertAlmostEqual(scoring._percentile(vals, 0.5), 0.5)

    def test_percentile_interpolates(self):
        # midway between 0.0 and 1.0 across two points
        self.assertAlmostEqual(scoring._percentile([0.0, 1.0], 0.5), 0.5)

    def test_brier_score(self):
        # perfect forecasts -> 0; worst -> 1
        self.assertAlmostEqual(scoring.brier_score([1.0, 0.0], [1, 0]), 0.0)
        self.assertAlmostEqual(scoring.brier_score([0.0, 1.0], [1, 0]), 1.0)
        self.assertAlmostEqual(scoring.brier_score([], []), 0.0)

    def test_bucket_index_edges(self):
        self.assertEqual(scoring._bucket_index(0.0), 0)
        self.assertEqual(scoring._bucket_index(0.05), 0)
        self.assertEqual(scoring._bucket_index(0.99), 9)
        self.assertEqual(scoring._bucket_index(1.0), 9)  # clamps into top bin


if __name__ == "__main__":
    unittest.main()
