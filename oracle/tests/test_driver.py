"""End-to-end offline tests for wkd.driver — the idempotent daily orchestration.

Everything external is faked: four :class:`~wkd.providers.MockProvider`s scripted
to converge / judge, injected fake fetchers, a fixed injected ``now``, a temp
SQLite DB, and a temp Chronicle out-dir. No network, no API keys, no pip installs.

The headline test (:class:`EndToEndRunDailyTest`) seeds one already-standing decree
whose event has already passed its resolution date, then runs ``run_daily`` once at
a fixed ``now`` that is BEFORE a freshly-harvested matter's resolution date. In a
single pass this both forges a new decree (future date passes the falsifiability
gate) and resolves the seeded one (past date is due), so the assertions cover the
whole harvest -> deliberate -> resolve -> score -> publish flow.
"""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from unittest import mock

from wkd import db, driver
from wkd.config import Config, ModelSpec
from wkd.models import (
    Decree,
    DecreeStatus,
    Event,
    EventStatus,
    Source,
    Tier,
)
from wkd.providers import MockProvider

# Fixed wall-clock: AFTER the seeded decree's resolution date (2026-06-01) so it
# is due to be judged, but BEFORE the harvested matter's date (2026-12-31) so it
# passes the gate and a fresh decree is forged.
NOW = "2026-06-26T12:00:00Z"


def _draft(claim, direction, confidence, *, agree=False, reasoning="because"):
    return json.dumps(
        {
            "claim": claim,
            "direction": direction,
            "confidence": confidence,
            "reasoning": reasoning,
            "agree": agree,
        }
    )


# A market question A (future): forged into a decree this run.
_AGREED_A = "United States CPI year-over-year prints above three percent for December 2026."


class _FakeNewsFetcher:
    """Injected NewsFetcher (duck-typed ``fetch() -> list[dict]``)."""

    def __init__(self, items):
        self.items = items
        self.calls = 0

    def fetch(self):
        self.calls += 1
        return list(self.items)


def _matter_a():
    return {
        "title": "United States CPI year-over-year for December 2026",
        "domain": "econ",
        "description": "The BLS releases the December 2026 CPI report.",
        "resolution_date": "2026-12-31",
        "resolution_criteria": "Per the official BLS CPI release for December 2026.",
        "source_ref": "news://cpi-dec-2026",
    }


class _DriverTestBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.tmp.name, "wkd.db")
        self.out_dir = os.path.join(self.tmp.name, "chronicle")
        self.conn = db.init_db(db.connect(self.db_path))
        self.config = Config(
            db_path=self.db_path,
            chronicle_out_dir=self.out_dir,
            mage_a=ModelSpec("mock", "mock-a"),
            mage_b=ModelSpec("mock", "mock-b"),
            king=ModelSpec("mock", "mock-king"),
            historian=ModelSpec("mock", "mock-historian"),
        )

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def _seed_standing_decree(self):
        """A standing decree whose event already passed its resolution date."""
        event = db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="Federal Reserve June 2026 rate decision",
                domain="econ",
                description="The FOMC met in June 2026.",
                resolution_date="2026-06-01",
                resolution_criteria="Per the official FOMC statement.",
                market_implied_prob=0.6,
                source_ref="news://fomc-jun-2026",
                harvested_at="2026-05-20T12:00:00Z",
                status=EventStatus.DECREED,
            ),
        )
        decree = db.insert_decree(
            self.conn,
            Decree(
                event_id=event.id,
                claim_text="The Federal Reserve cut its policy rate at the June 2026 meeting.",
                regal_text="By royal certainty, the Fed SHALL cut in June.",
                direction="cut",
                private_confidence=0.72,
                consensus_rounds=2,
                status=DecreeStatus.STANDING,
                issued_at="2026-05-20T12:00:00Z",
            ),
        )
        return event, decree

    def _mages(self):
        """Mocks scripted to converge on matter A in round 2; defaults are safe."""
        mage_a = MockProvider(
            [
                _draft("CPI runs hot in December", "above", 0.7, agree=False),
                _draft(_AGREED_A, "above", 0.8, agree=True),
            ],
            model="claude-test",
            default=_draft("noop", "", 0.0, agree=False),
            cost=0.002,
        )
        mage_b = MockProvider(
            [
                _draft("Inflation stays above 3%", "above", 0.6, agree=False),
                _draft(_AGREED_A, "above", 0.6, agree=True),
            ],
            model="gpt-test",
            default=_draft("noop", "", 0.0, agree=False),
            cost=0.001,
        )
        king = MockProvider(
            ["By the crown's certainty, CPI SHALL exceed three percent. It is sealed."],
            model="king-test",
            default="The decree is sealed.",
            cost=0.001,
        )
        return mage_a, mage_b, king

    def _historian(self, verdict="vindicated"):
        payload = json.dumps(
            {
                "verdict": verdict,
                "reasoning": "Multiple outlets confirm the outcome.",
                "evidence": [
                    {"source": "Reuters", "url": "https://reuters.com/a", "quote": "cut", "supports": True},
                    {"source": "Associated Press", "url": "https://apnews.com/b", "quote": "rate cut", "supports": True},
                    {"source": "Bloomberg", "url": "https://bloomberg.com/c", "quote": "lowered", "supports": True},
                ],
            }
        )
        return MockProvider(default=payload, model="gemini-test", cost=0.004)


class EndToEndRunDailyTest(_DriverTestBase):
    """One run_daily pass forges a new decree AND resolves a due one."""

    def _run_once(self, now=NOW, historian_verdict="vindicated"):
        mage_a, mage_b, king = self._mages()
        hist = self._historian(historian_verdict)
        news = _FakeNewsFetcher([_matter_a()])
        report = driver.run_daily(
            self.config,
            now=now,
            conn=self.conn,
            mage_a=mage_a,
            mage_b=mage_b,
            king=king,
            historian_provider=hist,
            news_fetcher=news,
        )
        return report, (mage_a, mage_b, king, hist, news)

    def test_decree_forged(self):
        self._seed_standing_decree()
        report, _ = self._run_once()
        self.assertEqual(report.harvested, 1)
        self.assertGreaterEqual(report.forged, 1)
        self.assertEqual(report.divided, 0)
        # The harvested matter A now carries a standing decree.
        decree = report.forged_decrees[0]
        self.assertEqual(decree.claim_text, _AGREED_A)
        self.assertEqual(decree.status, DecreeStatus.STANDING)
        self.assertIn("SHALL", decree.regal_text)
        evt = db.get_event(self.conn, decree.event_id)
        self.assertEqual(evt.status, EventStatus.DECREED)

    def test_due_decree_resolves_to_a_tier(self):
        _evt_b, decree_b = self._seed_standing_decree()
        report, _ = self._run_once()
        self.assertEqual(report.resolved, 1)
        self.assertEqual(report.abstained, 0)
        rulings = db.list_rulings(self.conn, decree_b.id)
        self.assertEqual(len(rulings), 1)
        self.assertEqual(rulings[0].verdict, Tier.VINDICATED)
        # Decree + event status advanced; a correction was stamped.
        self.assertEqual(
            db.get_decree(self.conn, decree_b.id).status, DecreeStatus.VINDICATED
        )
        self.assertEqual(
            db.get_event(self.conn, decree_b.event_id).status, EventStatus.RESOLVED
        )
        self.assertEqual(len(db.list_corrections(self.conn, decree_b.id)), 1)

    def test_metrics_computed(self):
        self._seed_standing_decree()
        report, _ = self._run_once()
        self.assertIsNotNone(report.metrics_snapshot_id)
        snap = db.latest_metrics(self.conn)
        self.assertIsNotNone(snap)
        metrics = json.loads(snap.metrics_json)
        self.assertEqual(metrics["hit_rate"]["ruled"], 1)
        self.assertEqual(metrics["hit_rate"]["vindicated"], 1)
        self.assertEqual(metrics["computed_at"], NOW)

    def test_chronicle_generated(self):
        _evt_b, decree_b = self._seed_standing_decree()
        report, _ = self._run_once()
        self.assertTrue(report.chronicle_files)
        index = os.path.join(self.out_dir, "index.html")
        self.assertTrue(os.path.exists(index))
        self.assertTrue(os.path.exists(os.path.join(self.out_dir, "divided.html")))
        self.assertTrue(os.path.exists(os.path.join(self.out_dir, "style.css")))
        self.assertTrue(
            os.path.exists(os.path.join(self.out_dir, f"decree-{decree_b.id}.html"))
        )
        with open(index, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("The Wizard King", text)

    def test_audit_trail_persisted(self):
        self._seed_standing_decree()
        self._run_once()
        # Council (mage turns) + King + Historian all logged to model_runs.
        self.assertTrue(db.list_model_runs(self.conn, component="council"))
        self.assertTrue(db.list_model_runs(self.conn, component="king"))
        self.assertTrue(db.list_model_runs(self.conn, component="historian"))

    def test_idempotent_second_run(self):
        self._seed_standing_decree()
        self._run_once()
        decrees_after_first = len(db.list_decrees(self.conn))
        rulings_after_first = len(db.list_rulings(self.conn))

        # A second pass at the SAME now must add no new decrees/rulings: matter A
        # dedups on harvest, its event is no longer pending, and the seeded decree
        # is already resolved (no longer standing/due).
        report2, _ = self._run_once()
        self.assertEqual(report2.forged, 0)
        self.assertEqual(report2.harvested, 0)
        self.assertEqual(report2.resolved, 0)
        self.assertEqual(len(db.list_decrees(self.conn)), decrees_after_first)
        self.assertEqual(len(db.list_rulings(self.conn)), rulings_after_first)


class RunDailyOwnsConnectionTest(_DriverTestBase):
    """run_daily opens + closes its own connection when none is injected."""

    def test_persists_to_configured_db_file(self):
        # Close the setUp connection; run_daily should open config.db_path itself.
        self.conn.close()
        mage_a = MockProvider(
            [
                _draft("CPI hot", "above", 0.7, agree=False),
                _draft(_AGREED_A, "above", 0.8, agree=True),
            ],
            model="claude-test",
            default=_draft("noop", "", 0.0, agree=False),
        )
        mage_b = MockProvider(
            [
                _draft("Above 3%", "above", 0.6, agree=False),
                _draft(_AGREED_A, "above", 0.6, agree=True),
            ],
            model="gpt-test",
            default=_draft("noop", "", 0.0, agree=False),
        )
        king = MockProvider(["It is sealed."], model="king-test", default="sealed")
        hist = MockProvider(default="{}", model="gemini-test")
        news = _FakeNewsFetcher([_matter_a()])

        report = driver.run_daily(
            self.config,
            now=NOW,
            mage_a=mage_a,
            mage_b=mage_b,
            king=king,
            historian_provider=hist,
            news_fetcher=news,
        )
        self.assertEqual(report.forged, 1)

        # Re-open the file: the forged decree was committed and persisted.
        conn2 = db.connect(self.db_path)
        try:
            self.assertEqual(len(db.list_decrees(conn2)), 1)
            self.assertEqual(len(db.list_events(conn2, status=EventStatus.DECREED)), 1)
        finally:
            conn2.close()
        # Re-bind self.conn so tearDown's close() is harmless.
        self.conn = db.connect(self.db_path)


class DividedPathTest(_DriverTestBase):
    """When the council never agrees, the King holds his tongue (event divided)."""

    def test_event_marked_divided(self):
        mage_a = MockProvider(
            [
                _draft("CPI hot", "above", 0.7, agree=False),
                _draft("CPI hot", "above", 0.7, agree=False),
                _draft("CPI hot", "above", 0.7, agree=False),
            ],
            model="claude-test",
            default=_draft("noop", "", 0.0, agree=False),
        )
        mage_b = MockProvider(
            [
                _draft("CPI cool", "below", 0.6, agree=False),
                _draft("CPI cool", "below", 0.6, agree=False),
                _draft("CPI cool", "below", 0.6, agree=False),
            ],
            model="gpt-test",
            default=_draft("noop", "", 0.0, agree=False),
        )
        king = MockProvider(default="(should not be called)", model="king-test")
        hist = MockProvider(default="{}", model="gemini-test")
        news = _FakeNewsFetcher([_matter_a()])

        report = driver.run_daily(
            self.config,
            now=NOW,
            conn=self.conn,
            mage_a=mage_a,
            mage_b=mage_b,
            king=king,
            historian_provider=hist,
            news_fetcher=news,
        )
        self.assertEqual(report.forged, 0)
        self.assertEqual(report.divided, 1)
        self.assertEqual(king.call_count, 0)  # the King stayed silent
        events = db.list_events(self.conn, status=EventStatus.DIVIDED)
        self.assertEqual(len(events), 1)


class CheckpointStepTest(_DriverTestBase):
    """A standing, unresolved, not-yet-due decree gets re-affirmed on schedule."""

    def test_due_decree_is_checkpointed(self):
        # Event resolves in the future (not due for resolution), decree issued long
        # ago (older than checkpoint_interval_days) -> a checkpoint is due.
        event = db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="2026 US midterm control of the House",
                domain="politics",
                description="The 2026 US midterm elections.",
                resolution_date="2026-11-03",
                resolution_criteria="Per the certified results.",
                harvested_at="2026-05-01T12:00:00Z",
                status=EventStatus.DECREED,
            ),
        )
        decree = db.insert_decree(
            self.conn,
            Decree(
                event_id=event.id,
                claim_text="The opposition wins control of the House in 2026.",
                direction="flip",
                private_confidence=0.6,
                status=DecreeStatus.STANDING,
                issued_at="2026-05-01T12:00:00Z",
            ),
        )
        mage = MockProvider(
            default=json.dumps(
                {"action": "reaffirm", "confidence": 0.62, "notes": "still on track"}
            ),
            model="claude-test",
        )
        rows = driver.checkpoint_step(self.conn, self.config, mage=mage, now=NOW)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].action, "reaffirm")
        self.assertEqual(rows[0].decree_id, decree.id)
        stored = db.list_checkpoints(self.conn, decree.id)
        self.assertEqual(len(stored), 1)
        # And it is logged to the audit trail.
        self.assertTrue(
            db.list_model_runs(self.conn, component=driver.COMPONENT_CHECKPOINT)
        )

    def test_freshly_issued_decree_not_checkpointed(self):
        event = db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="2026 US midterm control of the House",
                domain="politics",
                resolution_date="2026-11-03",
                resolution_criteria="Per the certified results.",
                harvested_at=NOW,
                status=EventStatus.DECREED,
            ),
        )
        db.insert_decree(
            self.conn,
            Decree(
                event_id=event.id,
                claim_text="The opposition wins control of the House in 2026.",
                direction="flip",
                status=DecreeStatus.STANDING,
                issued_at=NOW,  # issued exactly at `now` -> not yet due
            ),
        )
        mage = MockProvider(default="{}", model="claude-test")
        rows = driver.checkpoint_step(self.conn, self.config, mage=mage, now=NOW)
        self.assertEqual(rows, [])
        self.assertEqual(mage.call_count, 0)


class CheckpointActionEnforcementTest(_DriverTestBase):
    """withdraw / amend are ENFORCED on decree state, not merely recorded (§8, §16.8)."""

    def _standing_future_decree(self, conf=0.6):
        # Resolves in the future (not due for the Historian), issued long ago (so a
        # weekly checkpoint is due).
        event = db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="2026 US midterm control of the House",
                domain="politics",
                description="The 2026 US midterm elections.",
                resolution_date="2026-11-03",
                resolution_criteria="Per the certified results.",
                harvested_at="2026-05-01T12:00:00Z",
                status=EventStatus.DECREED,
            ),
        )
        decree = db.insert_decree(
            self.conn,
            Decree(
                event_id=event.id,
                claim_text="The opposition wins control of the House in 2026.",
                regal_text="The House SHALL flip.",
                direction="flip",
                private_confidence=conf,
                consensus_rounds=2,
                status=DecreeStatus.STANDING,
                issued_at="2026-05-01T12:00:00Z",
            ),
        )
        return event, decree

    def test_withdraw_retires_decree_and_it_is_never_ruled(self):
        _event, decree = self._standing_future_decree()
        mage = MockProvider(
            default=json.dumps(
                {"action": "withdraw", "confidence": 0.2, "notes": "the news turned"}
            ),
            model="claude-test",
        )
        rows = driver.checkpoint_step(self.conn, self.config, mage=mage, now=NOW)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].action, "withdraw")

        # The decree is moved OUT of standing -> withdrawn (the prior no-op left it
        # standing, where it would still be judged and scored).
        self.assertEqual(
            db.get_decree(self.conn, decree.id).status, DecreeStatus.WITHDRAWN
        )
        self.assertEqual(db.list_standing_decrees(self.conn), [])
        # Even past its resolution date it is NOT due, and the Historian is never
        # summoned for it.
        self.assertEqual(
            db.list_decrees_due(self.conn, "2026-12-01T00:00:00Z"), []
        )
        hist = MockProvider(default="{}", model="gemini-test")
        rulings, abstained = driver.resolve_step(
            self.conn, self.config, historian_provider=hist, now="2026-12-01T00:00:00Z"
        )
        self.assertEqual(rulings, [])
        self.assertEqual(abstained, 0)
        self.assertEqual(hist.call_count, 0)

    def test_amend_supersedes_with_a_new_standing_decree(self):
        _event, decree = self._standing_future_decree(conf=0.6)
        mage = MockProvider(
            default=json.dumps(
                {"action": "amend", "confidence": 0.8, "notes": "more confident now"}
            ),
            model="claude-test",
        )
        rows = driver.checkpoint_step(self.conn, self.config, mage=mage, now=NOW)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].action, "amend")

        # The original decree is retired (superseded), never silently edited (§16.8).
        old = db.get_decree(self.conn, decree.id)
        self.assertEqual(old.status, DecreeStatus.SUPERSEDED)
        self.assertAlmostEqual(old.private_confidence, 0.6)  # original value preserved

        # Exactly one standing decree remains: the new superseding one.
        standing = db.list_standing_decrees(self.conn)
        self.assertEqual(len(standing), 1)
        new = standing[0]
        self.assertNotEqual(new.id, decree.id)
        self.assertEqual(new.supersedes_id, decree.id)
        self.assertEqual(new.claim_text, decree.claim_text)  # claim carried over
        self.assertAlmostEqual(new.private_confidence, 0.8)  # amended confidence

        # Only the superseding decree is ever judged — not both copies.
        due = db.list_decrees_due(self.conn, "2026-12-01T00:00:00Z")
        self.assertEqual([d.id for d in due], [new.id])


class JudgeIndependenceTest(unittest.TestCase):
    """The Court Historian's independence is enforced at runtime (SPEC §3, §16.1)."""

    def _cfg(self, *, historian, mage_a=None, mage_b=None):
        mage_a = mage_a or ModelSpec("anthropic", "claude-opus-4-8")
        mage_b = mage_b or ModelSpec("openai", "gpt-4.1")
        return Config(historian=historian, mage_a=mage_a, mage_b=mage_b, king=mage_a)

    def test_identical_model_to_a_mage_raises(self):
        cfg = self._cfg(historian=ModelSpec("anthropic", "claude-opus-4-8"))
        with self.assertRaises(ValueError):
            driver.check_judge_independence(cfg)
        with self.assertRaises(ValueError):
            driver.build_providers(cfg)

    def test_same_family_different_model_warns(self):
        # The documented §17.1 fallback (walled-off same-family judge) is allowed but
        # must surface a loud warning rather than pass silently.
        cfg = self._cfg(historian=ModelSpec("anthropic", "claude-haiku-fallback"))
        with self.assertWarns(UserWarning):
            driver.check_judge_independence(cfg)

    def test_independent_gemini_default_is_clean(self):
        cfg = self._cfg(historian=ModelSpec("gemini", "gemini-2.5-pro"))
        driver.check_judge_independence(cfg)  # no raise
        providers = driver.build_providers(cfg)  # offline-safe (lazy SDK imports)
        self.assertEqual(len(providers), 4)

    def test_mock_providers_are_exempt(self):
        cfg = self._cfg(
            historian=ModelSpec("mock", "m"),
            mage_a=ModelSpec("mock", "m"),
            mage_b=ModelSpec("mock", "m2"),
        )
        driver.check_judge_independence(cfg)  # test doubles never trip the guard


class UnconfiguredRunIsOfflineSafeTest(unittest.TestCase):
    """An unconfigured `run` (real providers, no keys/SDKs) must not crash.

    Regression for the default-config footgun: the free-pick leg used to fire an
    Anthropic call unconditionally, so `python3 -m wkd run` crashed offline with
    ModuleNotFoundError. Now every LLM leg is skipped (with a warning) when its
    provider isn't ready, and the non-LLM work (score + publish) still happens.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db_path = os.path.join(self.tmp.name, "wkd.db")
        self.out_dir = os.path.join(self.tmp.name, "chronicle")

    def test_default_real_provider_run_skips_llm_and_publishes(self):
        # Default cast = real Claude/GPT/Gemini; free_pick_max>0 is the footgun.
        cfg = Config(
            db_path=self.db_path, chronicle_out_dir=self.out_dir, free_pick_max=3
        )
        with mock.patch.dict(
            os.environ,
            {
                "ANTHROPIC_API_KEY": "",
                "OPENAI_API_KEY": "",
                "GEMINI_API_KEY": "",
                "WKD_NEWS_FEEDS": "",
                "WKD_MARKET_ENDPOINT": "",
            },
            clear=False,
        ):
            with self.assertWarns(UserWarning):  # free-pick skipped, not crashed
                report = driver.run_daily(cfg, now=NOW)
        self.assertEqual(report.harvested, 0)  # no sources configured
        self.assertEqual(report.forged, 0)
        self.assertEqual(report.resolved, 0)
        # Non-LLM work still ran: a chronicle was published.
        self.assertTrue(report.chronicle_files)
        self.assertTrue(os.path.exists(os.path.join(self.out_dir, "index.html")))


if __name__ == "__main__":
    unittest.main()
