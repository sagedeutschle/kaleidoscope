"""Offline tests for wkd.chronicle (static-site generator, SPEC §12).

No network, no API keys, no pip installs. A seeded in-memory DB is populated
with decrees in every status (standing / vindicated / cliffnotes / apology /
cancelled), a divided event, and a metrics snapshot; then ``generate`` is run
into a temp dir and the emitted HTML is asserted.
"""

import json
import tempfile
import unittest
from pathlib import Path

from wkd import chronicle, db, scoring
from wkd.models import (
    Correction,
    Decree,
    DecreeStatus,
    Deliberation,
    Domain,
    Event,
    EventStatus,
    Ruling,
    Source,
    Tier,
)

NOW = "2026-06-26 12:00 UTC"


class ChronicleTestBase(unittest.TestCase):
    """Build a representative DB, generate the chronicle into a temp dir."""

    def setUp(self):
        self.conn = db.init_db(":memory:")
        self.tmp = tempfile.TemporaryDirectory()
        self.out = Path(self.tmp.name)
        self._seed()
        self.written = chronicle.generate(self.conn, self.out, now=NOW)

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    # -- helpers ----------------------------------------------------------
    def _add_event(self, **kw) -> Event:
        base = dict(
            source=Source.HARVESTED,
            title="A matter",
            domain=Domain.ECON,
            description="",
            resolution_date="2026-07-31T00:00:00Z",
            resolution_criteria="Objective criteria here",
            harvested_at="2026-06-01T00:00:00Z",
            status=EventStatus.DECREED,
        )
        base.update(kw)
        return db.insert_event(self.conn, Event(**base))

    def _add_decree(self, event_id, **kw) -> Decree:
        base = dict(
            event_id=event_id,
            claim_text="The Fed shall cut rates by July.",
            regal_text="By the 31st of July, the Fed SHALL cut rates. Beyond doubt.",
            direction="yes",
            private_confidence=0.72,
            consensus_rounds=2,
            status=DecreeStatus.STANDING,
            issued_at="2026-06-02T00:00:00Z",
        )
        base.update(kw)
        return db.insert_decree(self.conn, Decree(**base))

    def _seed(self):
        # 1) Standing decree (no ruling yet) — reasoning must stay hidden.
        ev1 = self._add_event(
            title="Fed July decision",
            domain=Domain.ECON,
            status=EventStatus.DECREED,
        )
        self.d_standing = self._add_decree(
            ev1.id,
            claim_text="The Fed cuts in July.",
            regal_text="The Fed SHALL cut in July. This is beyond doubt.",
        )
        db.insert_deliberation(
            self.conn,
            Deliberation(
                event_id=ev1.id,
                round=1,
                model="claude-opus-4-8",
                draft_claim="Fed cuts in July",
                draft_confidence=0.7,
                reasoning="SECRET-STANDING-REASONING inflation cooling fast",
                created_at="2026-06-02T00:00:00Z",
            ),
        )

        # 2) Vindicated decree (market-sourced, so beat-the-crowd has data).
        ev2 = self._add_event(
            title="Bitcoin ATH",
            domain=Domain.CRYPTO,
            status=EventStatus.RESOLVED,
            market_implied_prob=0.6,
        )
        self.d_vind = self._add_decree(
            ev2.id,
            claim_text="Bitcoin sets a new all-time high.",
            regal_text="Bitcoin SHALL crown a new all-time high.",
            status=DecreeStatus.VINDICATED,
        )
        db.insert_deliberation(
            self.conn,
            Deliberation(
                event_id=ev2.id,
                round=1,
                model="gpt-4.1",
                draft_claim="BTC ATH",
                draft_confidence=0.66,
                reasoning="REVEALED-VIND-REASONING momentum + ETF inflows",
                created_at="2026-06-02T00:00:00Z",
            ),
        )
        r_vind = db.insert_ruling(
            self.conn,
            Ruling(
                decree_id=self.d_vind.id,
                verdict=Tier.VINDICATED,
                historian_model="gemini-2.5-pro",
                evidence_json=json.dumps(
                    [
                        {"title": "Reuters: BTC hits record", "url": "https://r.example/btc"},
                        {"title": "Bloomberg confirms ATH", "url": "https://b.example/btc"},
                    ]
                ),
                corroborating_sources=2,
                reasoning="Multiple outlets confirm the record.",
                ruled_at="2026-08-01T00:00:00Z",
            ),
        )
        db.insert_correction(
            self.conn,
            Correction(
                ruling_id=r_vind.id,
                decree_id=self.d_vind.id,
                tier=Tier.VINDICATED,
                correction_text="VICTORY-COPY The King foresaw it true.",
                published_at="2026-08-01T00:00:00Z",
            ),
        )

        # 3) Cliffnotes decree.
        ev3 = self._add_event(
            title="Rate cut timing", domain=Domain.ECON, status=EventStatus.RESOLVED
        )
        self.d_cliff = self._add_decree(
            ev3.id,
            claim_text="Rates cut in July.",
            regal_text="The cut SHALL come in July.",
            status=DecreeStatus.CLIFFNOTES,
        )
        r_cliff = db.insert_ruling(
            self.conn,
            Ruling(
                decree_id=self.d_cliff.id,
                verdict=Tier.CLIFFNOTES,
                historian_model="gemini-2.5-pro",
                evidence_json="",
                corroborating_sources=3,
                reasoning="Right direction, cut landed in September not July.",
                ruled_at="2026-09-20T00:00:00Z",
            ),
        )
        db.insert_correction(
            self.conn,
            Correction(
                ruling_id=r_cliff.id,
                decree_id=self.d_cliff.id,
                tier=Tier.CLIFFNOTES,
                correction_text="CLIFF-COPY Right in spirit, wrong on the month.",
                published_at="2026-09-20T00:00:00Z",
            ),
        )

        # 4) Apology decree (harsh tier).
        ev4 = self._add_event(
            title="Election upset",
            domain=Domain.POLITICS,
            status=EventStatus.RESOLVED,
        )
        self.d_apo = self._add_decree(
            ev4.id,
            claim_text="The incumbent loses.",
            regal_text="The incumbent SHALL fall.",
            status=DecreeStatus.APOLOGY,
        )
        r_apo = db.insert_ruling(
            self.conn,
            Ruling(
                decree_id=self.d_apo.id,
                verdict=Tier.APOLOGY,
                historian_model="gemini-2.5-pro",
                evidence_json=json.dumps(
                    {"sources": [{"title": "AP result", "url": "https://ap.example/x"}]}
                ),
                corroborating_sources=4,
                reasoning="Incumbent won decisively.",
                ruled_at="2026-11-05T00:00:00Z",
            ),
        )
        db.insert_correction(
            self.conn,
            Correction(
                ruling_id=r_apo.id,
                decree_id=self.d_apo.id,
                tier=Tier.APOLOGY,
                correction_text="APOLOGY-COPY The King grovels; the record is rewritten.",
                published_at="2026-11-05T00:00:00Z",
            ),
        )

        # 5) Cancelled decree (event never happened).
        ev5 = self._add_event(
            title="Phantom summit",
            domain=Domain.WORLD_NEWS,
            status=EventStatus.RESOLVED,
        )
        self.d_cancel = self._add_decree(
            ev5.id,
            claim_text="The summit yields a treaty.",
            regal_text="A treaty SHALL be signed at the summit.",
            status=DecreeStatus.CANCELLED,
        )
        r_cancel = db.insert_ruling(
            self.conn,
            Ruling(
                decree_id=self.d_cancel.id,
                verdict=Tier.CANCELLATION,
                historian_model="gemini-2.5-pro",
                evidence_json="",
                corroborating_sources=3,
                reasoning="The summit was cancelled; no treaty exists.",
                ruled_at="2026-10-01T00:00:00Z",
            ),
        )
        db.insert_correction(
            self.conn,
            Correction(
                ruling_id=r_cancel.id,
                decree_id=self.d_cancel.id,
                tier=Tier.CANCELLATION,
                correction_text="CANCEL-COPY The event is hereby cancelled.",
                published_at="2026-10-01T00:00:00Z",
            ),
        )

        # A divided matter (no decree).
        db.insert_event(
            self.conn,
            Event(
                source=Source.HARVESTED,
                title="DIVIDED-MATTER too close to call",
                domain=Domain.CURRENT_EVENTS,
                description="The council could not converge.",
                status=EventStatus.DIVIDED,
            ),
        )

        # The scoreboard snapshot is the GENUINE scoring output for this store, not
        # a hand-built shape — so the scoring->chronicle contract is exercised for
        # real. Given the seed (4 ruled: 1 vindicated, 1 cliffnotes, 1 apology, 1
        # cancellation; 1 standing; 1 divided event), scoring computes:
        #   hit rate           1/4 = 25.0%
        #   status-quo baseline 3/4 = 75.0%
        #   council divided     1/6 = 16.7%
        #   per-domain          crypto 100%, econ/politics/world-news 0%
        #   beat-the-crowd      n=1 (the market-sourced crypto matter)
        scoring.compute_metrics(
            self.conn, now="2026-12-01T00:00:00Z", rng_seed=0
        )

    # -- convenience ------------------------------------------------------
    def _read(self, name: str) -> str:
        return (self.out / name).read_text(encoding="utf-8")

    def _read_decree(self, decree) -> str:
        return self._read(chronicle.decree_filename(decree.id))


class FilesWrittenTest(ChronicleTestBase):
    def test_core_files_written(self):
        for name in (chronicle.INDEX_FILE, chronicle.DIVIDED_FILE, chronicle.STYLE_FILE):
            self.assertTrue((self.out / name).exists(), f"{name} missing")

    def test_one_article_per_decree(self):
        for d in (
            self.d_standing,
            self.d_vind,
            self.d_cliff,
            self.d_apo,
            self.d_cancel,
        ):
            self.assertTrue(
                (self.out / chronicle.decree_filename(d.id)).exists(),
                f"article for decree {d.id} missing",
            )

    def test_returns_written_paths(self):
        self.assertTrue(all(Path(p).exists() for p in self.written))
        names = {Path(p).name for p in self.written}
        self.assertIn(chronicle.INDEX_FILE, names)
        self.assertIn(chronicle.DIVIDED_FILE, names)
        self.assertIn(chronicle.STYLE_FILE, names)


class ScoreboardTest(ChronicleTestBase):
    def test_index_has_scoreboard_numbers(self):
        # These are the REAL scoring outputs for the seeded store; the prior buggy
        # chronicle (reading flat top-level keys scoring never emits) rendered Hit
        # Rate 'n/a' and Vindicated '0 of 0 ruled' here, so this is a red test
        # against that regression.
        idx = self._read(chronicle.INDEX_FILE)
        self.assertIn("Scoreboard", idx)
        self.assertIn("25.0%", idx)         # hit rate 1/4
        self.assertIn("1 of 4 ruled", idx)  # vindicated of ruled
        self.assertIn("75.0%", idx)         # status-quo baseline 3/4
        self.assertIn("16.7%", idx)         # council divided 1/6
        self.assertIn("Beat the Crowd", idx)  # market-sourced card (n=1)
        self.assertIn("95% CI", idx)        # bootstrap CI rendered

    def test_index_has_tier_and_domain_tables(self):
        idx = self._read(chronicle.INDEX_FILE)
        self.assertIn("Ladder of Shame", idx)
        self.assertIn("Per-Domain Accuracy", idx)
        self.assertIn("Harvested vs Free-Pick", idx)
        self.assertIn("100.0%", idx)  # crypto per-domain accuracy 1/1
        # The Ladder of Shame shows the actual per-tier counts (the prior bug
        # iterated tier_distribution's outer dict and rendered 'counts'/'fractions'
        # rows instead). Each tier is 1 in this seed.
        self.assertIn("<td>Vindicated</td><td>1</td>", idx)
        self.assertIn("<td>Cliffnotes</td><td>1</td>", idx)
        self.assertNotIn("<td>counts</td>", idx)
        self.assertNotIn("<td>fractions</td>", idx)

    def test_index_links_to_decrees_and_divided(self):
        idx = self._read(chronicle.INDEX_FILE)
        self.assertIn(chronicle.decree_filename(self.d_vind.id), idx)
        self.assertIn("divided.html", idx)
        # Each decree's headline appears in the roll.
        self.assertIn("Bitcoin SHALL crown a new all-time high.", idx)

    def test_scoreboard_empty_when_no_metrics(self):
        conn = db.init_db(":memory:")
        try:
            with tempfile.TemporaryDirectory() as tmp:
                chronicle.generate(conn, tmp, now=NOW)
                idx = (Path(tmp) / chronicle.INDEX_FILE).read_text(encoding="utf-8")
                self.assertIn("No reckonings", idx)
        finally:
            conn.close()


class CorrectionBannerTest(ChronicleTestBase):
    def test_apology_banner_stamped(self):
        page = self._read_decree(self.d_apo)
        self.assertIn("banner-apology", page)
        self.assertIn("Apology", page)
        self.assertIn("APOLOGY-COPY The King grovels", page)
        self.assertIn("4 corroborating sources", page)

    def test_cancellation_banner_stamped(self):
        page = self._read_decree(self.d_cancel)
        self.assertIn("banner-cancellation", page)
        self.assertIn("Cancellation", page)
        self.assertIn("CANCEL-COPY The event is hereby cancelled.", page)

    def test_cliffnotes_banner_stamped(self):
        page = self._read_decree(self.d_cliff)
        self.assertIn("banner-cliffnotes", page)
        self.assertIn("CLIFF-COPY", page)

    def test_vindicated_seal(self):
        page = self._read_decree(self.d_vind)
        self.assertIn("banner-vindicated", page)
        self.assertIn("Vindicated", page)
        self.assertIn("VICTORY-COPY", page)
        # cited evidence rendered as links.
        self.assertIn("https://r.example/btc", page)
        self.assertIn("Reuters: BTC hits record", page)

    def test_standing_has_no_correction_banner(self):
        page = self._read_decree(self.d_standing)
        self.assertIn("banner-standing", page)
        self.assertIn("Awaiting the reckoning", page)
        self.assertNotIn("banner-apology", page)
        self.assertNotIn("banner-vindicated", page)


class ArticleContentTest(ChronicleTestBase):
    def test_article_has_claim_and_resolution(self):
        page = self._read_decree(self.d_standing)
        self.assertIn("The Fed cuts in July.", page)  # claim_text
        self.assertIn("The Fed SHALL cut in July. This is beyond doubt.", page)  # regal
        self.assertIn("2026-07-31T00:00:00Z", page)   # resolution date
        self.assertIn("Objective criteria here", page)  # resolution criteria
        self.assertIn("econ", page)                    # domain

    def test_reasoning_hidden_until_ruled(self):
        # Standing decree: private reasoning + confidence must NOT be revealed.
        standing = self._read_decree(self.d_standing)
        self.assertNotIn("SECRET-STANDING-REASONING", standing)
        self.assertNotIn("private confidence", standing.lower())

        # Vindicated (ruled) decree: reasoning + confidence ARE revealed.
        ruled = self._read_decree(self.d_vind)
        self.assertIn("REVEALED-VIND-REASONING", ruled)
        self.assertIn("0.66", ruled)  # draft confidence
        self.assertIn("private confidence", ruled.lower())

    def test_ruled_article_shows_verdict_and_historian(self):
        page = self._read_decree(self.d_apo)
        self.assertIn("The Reckoning", page)
        self.assertIn("apology", page)          # verdict
        self.assertIn("gemini-2.5-pro", page)   # historian model
        self.assertIn("Incumbent won decisively.", page)  # historian reasoning


class DividedLedgerTest(ChronicleTestBase):
    def test_divided_page_lists_matter(self):
        page = self._read(chronicle.DIVIDED_FILE)
        self.assertIn("Divided Ledger", page)
        self.assertIn("DIVIDED-MATTER too close to call", page)
        self.assertIn("The council could not converge.", page)

    def test_decreed_event_not_on_divided_page(self):
        page = self._read(chronicle.DIVIDED_FILE)
        # A decreed matter's title should not appear in the divided ledger.
        self.assertNotIn("Fed July decision", page)


class EscapingAndPathTest(ChronicleTestBase):
    def test_html_is_escaped(self):
        ev = self._add_event(title="Tag <b>x</b>", domain=Domain.ECON)
        d = self._add_decree(
            ev.id,
            claim_text="Markets rise & <script>alert(1)</script> falls",
            regal_text="By <em>decree</em> & will, markets RISE.",
        )
        chronicle.generate(self.conn, self.out, now=NOW)
        page = self._read_decree(d)
        self.assertIn("&lt;script&gt;", page)
        self.assertNotIn("<script>alert(1)</script>", page)
        self.assertIn("&amp;", page)

    def test_accepts_db_path_not_only_connection(self):
        with tempfile.TemporaryDirectory() as tmp:
            dbpath = Path(tmp) / "wkd.db"
            conn = db.init_db(str(dbpath))
            db.insert_event(
                conn,
                Event(
                    source=Source.FREE_PICK,
                    title="Pathy matter",
                    domain=Domain.CRYPTO,
                    status=EventStatus.DIVIDED,
                    description="from a path",
                ),
            )
            conn.commit()
            conn.close()
            outdir = Path(tmp) / "site"
            written = chronicle.generate(str(dbpath), outdir, now=NOW)
            self.assertTrue((outdir / chronicle.INDEX_FILE).exists())
            self.assertIn(
                "Pathy matter",
                (outdir / chronicle.DIVIDED_FILE).read_text(encoding="utf-8"),
            )
            self.assertTrue(all(Path(p).exists() for p in written))

    def test_idempotent_regeneration(self):
        first = self._read(chronicle.INDEX_FILE)
        chronicle.generate(self.conn, self.out, now=NOW)
        second = self._read(chronicle.INDEX_FILE)
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
