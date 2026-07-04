"""Offline tests for wkd.db (schema + typed CRUD helpers)."""

import json
import unittest

from wkd import db
from wkd.models import (
    Checkpoint,
    CheckpointAction,
    Correction,
    Decree,
    DecreeStatus,
    Deliberation,
    Domain,
    Event,
    EventStatus,
    MetricsSnapshot,
    ModelRun,
    Ruling,
    Source,
    Tier,
)

EXPECTED_TABLES = {
    "events",
    "decrees",
    "deliberations",
    "checkpoints",
    "rulings",
    "corrections",
    "model_runs",
    "metrics_snapshots",
}


class DbTestBase(unittest.TestCase):
    def setUp(self):
        # In-memory DB; init_db keeps the connection open for the test's life.
        self.conn = db.init_db(":memory:")

    def tearDown(self):
        self.conn.close()

    def _event(self, **kw) -> Event:
        base = dict(
            source=Source.HARVESTED,
            title="Fed decision",
            domain=Domain.ECON,
            resolution_date="2026-07-31T00:00:00Z",
            resolution_criteria="Fed funds target lowered",
            harvested_at="2026-06-26T00:00:00Z",
        )
        base.update(kw)
        return Event(**base)


class SchemaTest(DbTestBase):
    def test_all_tables_created(self):
        self.assertEqual(set(db.list_tables(self.conn)), EXPECTED_TABLES)

    def test_init_db_idempotent(self):
        db.init_db(self.conn)  # second call must not error
        self.assertEqual(set(db.list_tables(self.conn)), EXPECTED_TABLES)


class EventTest(DbTestBase):
    def test_insert_sets_id_and_roundtrips(self):
        e = db.insert_event(self.conn, self._event())
        self.assertEqual(e.id, 1)
        got = db.get_event(self.conn, 1)
        self.assertEqual(got.title, "Fed decision")
        self.assertEqual(got.domain, "econ")
        self.assertEqual(got.status, "pending")

    def test_market_implied_prob_nullable(self):
        e = db.insert_event(self.conn, self._event(market_implied_prob=0.62))
        self.assertAlmostEqual(db.get_event(self.conn, e.id).market_implied_prob, 0.62)
        e2 = db.insert_event(self.conn, self._event(market_implied_prob=None))
        self.assertIsNone(db.get_event(self.conn, e2.id).market_implied_prob)

    def test_list_and_update_status(self):
        a = db.insert_event(self.conn, self._event(title="A"))
        db.insert_event(self.conn, self._event(title="B"))
        self.assertEqual(len(db.list_events(self.conn, status=EventStatus.PENDING)), 2)
        db.update_event_status(self.conn, a.id, EventStatus.DIVIDED)
        self.assertEqual(len(db.list_events(self.conn, status="pending")), 1)
        self.assertEqual(len(db.list_events(self.conn, status="divided")), 1)

    def test_list_by_source(self):
        db.insert_event(self.conn, self._event(source=Source.HARVESTED))
        db.insert_event(self.conn, self._event(source=Source.FREE_PICK))
        self.assertEqual(len(db.list_events(self.conn, source="free-pick")), 1)


class DecreeTest(DbTestBase):
    def _seed_event(self, **kw) -> Event:
        return db.insert_event(self.conn, self._event(**kw))

    def test_insert_and_get(self):
        ev = self._seed_event()
        d = db.insert_decree(
            self.conn,
            Decree(
                event_id=ev.id,
                claim_text="The Fed shall cut.",
                regal_text="By the 31st of July, the Fed shall cut rates.",
                direction="cut",
                private_confidence=0.71,
                consensus_rounds=2,
                issued_at="2026-06-26T00:00:00Z",
            ),
        )
        self.assertEqual(d.id, 1)
        got = db.get_decree(self.conn, 1)
        self.assertEqual(got.status, "standing")
        self.assertAlmostEqual(got.private_confidence, 0.71)
        self.assertEqual(got.consensus_rounds, 2)

    def test_standing_filter_and_status_update(self):
        ev = self._seed_event()
        d = db.insert_decree(self.conn, Decree(event_id=ev.id, claim_text="c"))
        self.assertEqual(len(db.list_standing_decrees(self.conn)), 1)
        db.update_decree_status(self.conn, d.id, DecreeStatus.VINDICATED)
        self.assertEqual(len(db.list_standing_decrees(self.conn)), 0)
        self.assertEqual(len(db.list_decrees(self.conn, status="vindicated")), 1)

    def test_supersedes_chain(self):
        ev = self._seed_event()
        d1 = db.insert_decree(self.conn, Decree(event_id=ev.id, claim_text="orig"))
        d2 = db.insert_decree(
            self.conn,
            Decree(event_id=ev.id, claim_text="amended", supersedes_id=d1.id),
        )
        self.assertEqual(db.get_decree(self.conn, d2.id).supersedes_id, d1.id)

    def test_list_decrees_due(self):
        past = self._seed_event(title="past", resolution_date="2026-06-01T00:00:00Z")
        future = self._seed_event(title="future", resolution_date="2026-12-01T00:00:00Z")
        d_past = db.insert_decree(self.conn, Decree(event_id=past.id, claim_text="p"))
        db.insert_decree(self.conn, Decree(event_id=future.id, claim_text="f"))
        due = db.list_decrees_due(self.conn, "2026-06-26T00:00:00Z")
        self.assertEqual([d.id for d in due], [d_past.id])

    def test_due_excludes_non_standing(self):
        past = self._seed_event(resolution_date="2026-06-01T00:00:00Z")
        d = db.insert_decree(self.conn, Decree(event_id=past.id, claim_text="p"))
        db.update_decree_status(self.conn, d.id, DecreeStatus.VINDICATED)
        self.assertEqual(db.list_decrees_due(self.conn, "2026-06-26T00:00:00Z"), [])


class DeliberationTest(DbTestBase):
    def test_transcript_roundtrip(self):
        ev = db.insert_event(self.conn, self._event())
        db.insert_deliberation(
            self.conn,
            Deliberation(
                event_id=ev.id, round=1, model="claude-opus-4-8",
                draft_claim="cut", draft_confidence=0.7, reasoning="dovish",
                created_at="2026-06-26T00:00:00Z",
            ),
        )
        db.insert_deliberation(
            self.conn,
            Deliberation(
                event_id=ev.id, round=1, model="gpt-4.1",
                draft_claim="hold", draft_confidence=0.55, reasoning="sticky",
                created_at="2026-06-26T00:00:01Z",
            ),
        )
        rows = db.list_deliberations(self.conn, ev.id)
        self.assertEqual(len(rows), 2)
        self.assertEqual({r.model for r in rows}, {"claude-opus-4-8", "gpt-4.1"})


class CheckpointTest(DbTestBase):
    def test_last_checkpoint_returns_latest(self):
        ev = db.insert_event(self.conn, self._event())
        d = db.insert_decree(self.conn, Decree(event_id=ev.id, claim_text="c"))
        db.insert_checkpoint(
            self.conn,
            Checkpoint(decree_id=d.id, action=CheckpointAction.REAFFIRM,
                       new_confidence=0.7, checked_at="2026-07-03T00:00:00Z"),
        )
        db.insert_checkpoint(
            self.conn,
            Checkpoint(decree_id=d.id, action=CheckpointAction.AMEND,
                       new_confidence=0.6, checked_at="2026-07-10T00:00:00Z"),
        )
        last = db.last_checkpoint(self.conn, d.id)
        self.assertEqual(last.action, "amend")
        self.assertAlmostEqual(last.new_confidence, 0.6)
        self.assertEqual(len(db.list_checkpoints(self.conn, d.id)), 2)

    def test_last_checkpoint_none_when_absent(self):
        ev = db.insert_event(self.conn, self._event())
        d = db.insert_decree(self.conn, Decree(event_id=ev.id, claim_text="c"))
        self.assertIsNone(db.last_checkpoint(self.conn, d.id))


class RulingCorrectionTest(DbTestBase):
    def _decree(self) -> Decree:
        ev = db.insert_event(self.conn, self._event())
        return db.insert_decree(self.conn, Decree(event_id=ev.id, claim_text="c"))

    def test_rulings_append_only(self):
        d = self._decree()
        ev_json = json.dumps({"sources": ["a.com", "b.com"]})
        db.insert_ruling(
            self.conn,
            Ruling(decree_id=d.id, verdict=Tier.CLIFFNOTES, historian_model="gemini-2.5-pro",
                   evidence_json=ev_json, corroborating_sources=2, reasoning="close",
                   ruled_at="2026-08-01T00:00:00Z"),
        )
        db.insert_ruling(
            self.conn,
            Ruling(decree_id=d.id, verdict=Tier.APOLOGY, historian_model="gemini-2.5-pro",
                   evidence_json=ev_json, corroborating_sources=3, reasoning="reversed",
                   ruled_at="2026-08-08T00:00:00Z"),
        )
        rulings = db.list_rulings(self.conn, d.id)
        self.assertEqual(len(rulings), 2)  # both retained, nothing overwritten
        self.assertEqual([r.verdict for r in rulings], ["cliffnotes", "apology"])
        self.assertEqual(json.loads(rulings[0].evidence_json)["sources"], ["a.com", "b.com"])

    def test_correction_links_ruling_and_decree(self):
        d = self._decree()
        r = db.insert_ruling(self.conn, Ruling(decree_id=d.id, verdict=Tier.CANCELLATION,
                                               corroborating_sources=3))
        c = db.insert_correction(
            self.conn,
            Correction(ruling_id=r.id, decree_id=d.id, tier=Tier.CANCELLATION,
                       correction_text="the event is hereby cancelled.",
                       published_at="2026-08-02T00:00:00Z"),
        )
        self.assertEqual(c.id, 1)
        rows = db.list_corrections(self.conn, d.id)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].tier, "cancellation")
        self.assertEqual(rows[0].ruling_id, r.id)


class ModelRunMetricsTest(DbTestBase):
    def test_model_run_audit(self):
        db.insert_model_run(
            self.conn,
            ModelRun(component="council", model="claude-opus-4-8",
                     prompt_tokens=1200, completion_tokens=300, cost=0.013,
                     latency_ms=4200, created_at="2026-06-26T00:00:00Z"),
        )
        runs = db.list_model_runs(self.conn, component="council")
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0].prompt_tokens, 1200)
        self.assertAlmostEqual(runs[0].cost, 0.013)

    def test_latest_metrics(self):
        db.insert_metrics_snapshot(
            self.conn,
            MetricsSnapshot(metrics_json=json.dumps({"hit_rate": 0.5}),
                            computed_at="2026-07-01T00:00:00Z"),
        )
        db.insert_metrics_snapshot(
            self.conn,
            MetricsSnapshot(metrics_json=json.dumps({"hit_rate": 0.6}),
                            computed_at="2026-07-08T00:00:00Z"),
        )
        latest = db.latest_metrics(self.conn)
        self.assertEqual(json.loads(latest.metrics_json)["hit_rate"], 0.6)

    def test_latest_metrics_none_when_empty(self):
        self.assertIsNone(db.latest_metrics(self.conn))


class ForeignKeyTest(DbTestBase):
    def test_foreign_keys_enforced(self):
        import sqlite3
        # decree referencing a non-existent event must be rejected
        with self.assertRaises(sqlite3.IntegrityError):
            db.insert_decree(self.conn, Decree(event_id=999, claim_text="orphan"))


class TransactionTest(DbTestBase):
    """db.transaction groups commit=False writes into one atomic unit (SPEC §16.8)."""

    def _event_decree(self):
        ev = db.insert_event(self.conn, self._event())
        dec = db.insert_decree(
            self.conn,
            Decree(event_id=ev.id, claim_text="c", status=DecreeStatus.STANDING),
        )
        return ev, dec

    def test_commits_all_on_clean_exit(self):
        ev, dec = self._event_decree()
        with db.transaction(self.conn):
            db.insert_ruling(
                self.conn,
                Ruling(decree_id=dec.id, verdict=Tier.VINDICATED, corroborating_sources=2),
                commit=False,
            )
            db.update_decree_status(
                self.conn, dec.id, DecreeStatus.VINDICATED, commit=False
            )
        self.assertEqual(len(db.list_rulings(self.conn, dec.id)), 1)
        self.assertEqual(db.get_decree(self.conn, dec.id).status, DecreeStatus.VINDICATED)

    def test_rolls_back_all_on_exception(self):
        # A crash mid-sequence must leave NEITHER the ruling NOR the status change —
        # otherwise a re-run would re-judge the still-standing decree and duplicate.
        ev, dec = self._event_decree()

        class Boom(RuntimeError):
            pass

        with self.assertRaises(Boom):
            with db.transaction(self.conn):
                db.insert_ruling(
                    self.conn,
                    Ruling(decree_id=dec.id, verdict=Tier.VINDICATED, corroborating_sources=2),
                    commit=False,
                )
                db.update_decree_status(
                    self.conn, dec.id, DecreeStatus.VINDICATED, commit=False
                )
                raise Boom("interrupted before commit")

        # Nothing landed: append-only history stays clean, decree still standing.
        self.assertEqual(db.list_rulings(self.conn, dec.id), [])
        self.assertEqual(db.get_decree(self.conn, dec.id).status, DecreeStatus.STANDING)


if __name__ == "__main__":
    unittest.main()
