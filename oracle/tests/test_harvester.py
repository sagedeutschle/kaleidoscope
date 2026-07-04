"""Offline tests for wkd.harvester.

Covers the reasoning-favored domain filter (sports / pure-chance excluded),
the falsifiability gate, dedup vs existing + within-batch matters, market
``market_implied_prob`` capture, and persistence of pending Events. The
injectable NewsFetcher / MarketQuestionClient are replaced with simple fakes;
the real feedparser/httpx-backed impls are only checked for lazy-import safety.
"""

import unittest

from wkd import db
from wkd.harvester import (
    EXCLUDED_DOMAIN_TOKENS,
    FeedparserNewsFetcher,
    HttpxMarketQuestionClient,
    MatterCandidate,
    harvest,
    is_falsifiable,
    normalize_domain,
)
from wkd.models import Domain, Event, EventStatus, Source

# A fixed "now" so the gate's future-date check is deterministic.
NOW = "2026-06-26T00:00:00Z"
FUTURE = "2026-09-01T00:00:00Z"
PAST = "2026-01-01T00:00:00Z"
GOOD_CRITERIA = "The Fed funds target range is lowered at the July FOMC meeting."


# ---------------------------------------------------------------------------
# Fakes for the injected sources (duck-typed: just need fetch()).
# ---------------------------------------------------------------------------


class FakeFetcher:
    def __init__(self, items):
        self._items = items
        self.calls = 0

    def fetch(self):
        self.calls += 1
        return list(self._items)


def _market_item(**kw):
    base = {
        "question": "Will the Fed cut rates by September 2026?",
        "domain": "econ",
        "end_date": FUTURE,
        "resolution_criteria": GOOD_CRITERIA,
        "probability": 0.62,
        "id": "mkt-1",
    }
    base.update(kw)
    return base


def _news_item(**kw):
    base = {
        "title": "US Supreme Court to rule on landmark case by September 2026",
        "domain": "politics",
        "date": FUTURE,
        "resolution_criteria": "A signed majority opinion is published on the docket.",
        "link": "https://news.example/scotus",
    }
    base.update(kw)
    return base


# ---------------------------------------------------------------------------
# Domain normalization / reasoning-favored filter
# ---------------------------------------------------------------------------


class NormalizeDomainTest(unittest.TestCase):
    def test_canonical_passthrough(self):
        for d in Domain:
            self.assertEqual(normalize_domain(d.value), d.value)

    def test_synonyms_map_to_canonical(self):
        self.assertEqual(normalize_domain("Economy"), "econ")
        self.assertEqual(normalize_domain("Finance"), "econ")
        self.assertEqual(normalize_domain("Bitcoin"), "crypto")
        self.assertEqual(normalize_domain("Election"), "politics")
        self.assertEqual(normalize_domain("International"), "world-news")
        self.assertEqual(normalize_domain("Breaking News"), "current-events")

    def test_crypto_wins_over_econ_when_both_present(self):
        # "crypto market" must land in crypto, not econ (specificity ordering)
        self.assertEqual(normalize_domain("crypto market"), "crypto")

    def test_excluded_returns_none(self):
        for raw in ["sports", "NFL", "Soccer", "lottery", "dice game", "casino"]:
            self.assertIsNone(normalize_domain(raw), raw)

    def test_unknown_and_empty_return_none(self):
        self.assertIsNone(normalize_domain("knitting"))
        self.assertIsNone(normalize_domain(""))
        self.assertIsNone(normalize_domain(None))

    def test_excluded_tokens_nonempty(self):
        self.assertIn("sports", EXCLUDED_DOMAIN_TOKENS)
        self.assertIn("lottery", EXCLUDED_DOMAIN_TOKENS)


# ---------------------------------------------------------------------------
# Falsifiability gate
# ---------------------------------------------------------------------------


class FalsifiabilityGateTest(unittest.TestCase):
    def _cand(self, **kw):
        base = dict(
            title="The Fed shall cut rates by September 2026.",
            domain="econ",
            resolution_date=FUTURE,
            resolution_criteria=GOOD_CRITERIA,
        )
        base.update(kw)
        return MatterCandidate(**base)

    def test_good_candidate_passes(self):
        ok, reason = is_falsifiable(self._cand(), now=NOW)
        self.assertTrue(ok, reason)
        self.assertEqual(reason, "ok")

    def test_missing_date_fails(self):
        ok, reason = is_falsifiable(self._cand(resolution_date=None), now=NOW)
        self.assertFalse(ok)
        self.assertIn("date", reason)

    def test_empty_date_fails(self):
        ok, _ = is_falsifiable(self._cand(resolution_date="  "), now=NOW)
        self.assertFalse(ok)

    def test_past_date_fails(self):
        ok, reason = is_falsifiable(self._cand(resolution_date=PAST), now=NOW)
        self.assertFalse(ok)
        self.assertIn("future", reason)

    def test_equal_to_now_fails(self):
        ok, _ = is_falsifiable(self._cand(resolution_date=NOW), now=NOW)
        self.assertFalse(ok)  # must be STRICTLY future

    def test_unparseable_date_fails(self):
        ok, reason = is_falsifiable(self._cand(resolution_date="next tuesday"), now=NOW)
        self.assertFalse(ok)
        self.assertIn("unparseable", reason)

    def test_missing_criteria_fails(self):
        ok, reason = is_falsifiable(self._cand(resolution_criteria=""), now=NOW)
        self.assertFalse(ok)
        self.assertIn("criteria", reason)

    def test_vague_title_fails(self):
        ok, reason = is_falsifiable(
            self._cand(title="The Fed might possibly cut rates someday soon"), now=NOW
        )
        self.assertFalse(ok)
        self.assertIn("vague", reason)

    def test_short_title_fails(self):
        ok, _ = is_falsifiable(self._cand(title="Fed cut"), now=NOW)
        self.assertFalse(ok)

    def test_month_named_may_is_not_a_hedge(self):
        # "May" the month must not trip the hedge detector.
        ok, reason = is_falsifiable(
            self._cand(title="Congress shall pass the budget by May 2026"), now=NOW
        )
        self.assertTrue(ok, reason)

    def test_date_only_resolution_accepted(self):
        ok, reason = is_falsifiable(self._cand(resolution_date="2026-09-01"), now=NOW)
        self.assertTrue(ok, reason)


# ---------------------------------------------------------------------------
# harvest() — orchestration
# ---------------------------------------------------------------------------


class HarvestTest(unittest.TestCase):
    def setUp(self):
        self.conn = db.init_db(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_persists_pending_events_from_both_sources(self):
        out = harvest(
            self.conn,
            news_fetcher=FakeFetcher([_news_item()]),
            market_client=FakeFetcher([_market_item()]),
            now=NOW,
        )
        self.assertEqual(len(out), 2)
        for ev in out:
            self.assertIsInstance(ev, Event)
            self.assertIsNotNone(ev.id)
            self.assertEqual(ev.status, EventStatus.PENDING)
            self.assertEqual(ev.harvested_at, NOW)
        # and they are actually in the DB as pending
        self.assertEqual(len(db.list_events(self.conn, status="pending")), 2)

    def test_market_implied_prob_captured(self):
        out = harvest(
            self.conn,
            market_client=FakeFetcher([_market_item(probability=62)]),  # percent form
            now=NOW,
        )
        self.assertEqual(len(out), 1)
        self.assertAlmostEqual(out[0].market_implied_prob, 0.62)
        self.assertEqual(out[0].source, Source.HARVESTED)

    def test_news_has_no_market_prob(self):
        out = harvest(self.conn, news_fetcher=FakeFetcher([_news_item()]), now=NOW)
        self.assertIsNone(out[0].market_implied_prob)

    def test_excluded_domain_dropped(self):
        out = harvest(
            self.conn,
            market_client=FakeFetcher([
                _market_item(domain="sports", question="Will the home team win the final by September?"),
                _market_item(),  # the keeper
            ]),
            now=NOW,
        )
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0].domain, "econ")

    def test_gate_failure_dropped(self):
        # one with no resolution date (not datable) -> dropped; one good -> kept
        out = harvest(
            self.conn,
            news_fetcher=FakeFetcher([
                _news_item(date=None, title="Some vague unfolding political situation continues"),
                _news_item(),
            ]),
            now=NOW,
        )
        self.assertEqual(len(out), 1)

    def test_past_date_dropped(self):
        out = harvest(
            self.conn,
            market_client=FakeFetcher([_market_item(end_date=PAST)]),
            now=NOW,
        )
        self.assertEqual(out, [])

    def test_domains_allowlist_filters(self):
        out = harvest(
            self.conn,
            news_fetcher=FakeFetcher([_news_item()]),       # politics
            market_client=FakeFetcher([_market_item()]),    # econ
            domains=["econ"],
            now=NOW,
        )
        self.assertEqual([e.domain for e in out], ["econ"])

    def test_dedup_against_existing_events(self):
        # pre-seed the identical market matter
        first = harvest(self.conn, market_client=FakeFetcher([_market_item()]), now=NOW)
        self.assertEqual(len(first), 1)
        # harvest the same matter again -> deduped, nothing new
        again = harvest(self.conn, market_client=FakeFetcher([_market_item()]), now=NOW)
        self.assertEqual(again, [])
        self.assertEqual(len(db.list_events(self.conn)), 1)

    def test_dedup_within_batch(self):
        # same matter delivered by both fetchers in one run -> only one persisted
        out = harvest(
            self.conn,
            news_fetcher=FakeFetcher([_news_item(source_ref=None)]),
            market_client=FakeFetcher([
                {
                    "question": "US Supreme Court to rule on landmark case by September 2026",
                    "domain": "politics",
                    "end_date": FUTURE,
                    "resolution_criteria": "A signed majority opinion is published on the docket.",
                }
            ]),
            now=NOW,
        )
        self.assertEqual(len(out), 1)

    def test_dedup_by_source_ref(self):
        a = harvest(self.conn, news_fetcher=FakeFetcher([_news_item(link="https://x/1")]), now=NOW)
        self.assertEqual(len(a), 1)
        # different title, SAME source_ref -> treated as duplicate
        b = harvest(
            self.conn,
            news_fetcher=FakeFetcher([
                _news_item(title="Different framing of the same docket ruling by September 2026", link="https://x/1")
            ]),
            now=NOW,
        )
        self.assertEqual(b, [])

    def test_limit_caps_new_events(self):
        items = [_market_item(question=f"Will metric {i} exceed target by September 2026?", id=f"m{i}")
                 for i in range(5)]
        out = harvest(self.conn, market_client=FakeFetcher(items), now=NOW, limit=2)
        self.assertEqual(len(out), 2)

    def test_no_sources_returns_empty(self):
        self.assertEqual(harvest(self.conn, now=NOW), [])

    def test_fetchers_are_invoked(self):
        nf = FakeFetcher([_news_item()])
        mc = FakeFetcher([_market_item()])
        harvest(self.conn, news_fetcher=nf, market_client=mc, now=NOW)
        self.assertEqual(nf.calls, 1)
        self.assertEqual(mc.calls, 1)


# ---------------------------------------------------------------------------
# Free-pick origination (SPEC §7): the King proposes his own matters
# ---------------------------------------------------------------------------


def _free_pick_payload(*titles):
    import json as _json

    return _json.dumps(
        [
            {
                "title": t,
                "domain": "econ",
                "description": "A free-pick the King chose to prophesy.",
                "resolution_date": FUTURE,
                "resolution_criteria": GOOD_CRITERIA,
            }
            for t in titles
        ]
    )


class FreePickHarvestTest(unittest.TestCase):
    def setUp(self):
        self.conn = db.init_db(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_free_pick_provider_originates_tagged_events(self):
        from wkd.harvester import COMPONENT_FREE_PICK
        from wkd.providers import MockProvider

        provider = MockProvider(
            default=_free_pick_payload(
                "The S&P 500 closes above 7000 by September 2026.",
                "US headline CPI falls below two percent by September 2026.",
            ),
            model="king-test",
        )
        out = harvest(
            self.conn,
            free_pick_provider=provider,
            free_pick_max=3,
            now=NOW,
        )
        # Both proposed matters pass the gate and are persisted, tagged free-pick
        # by ORIGIN (not by anything the model self-reports).
        self.assertEqual(len(out), 2)
        for ev in out:
            self.assertEqual(ev.source, Source.FREE_PICK)
            self.assertEqual(ev.status, EventStatus.PENDING)
        self.assertEqual(
            len(db.list_events(self.conn, source=Source.FREE_PICK)), 2
        )
        # The origination model call was audited for the cost/usage trail (§16.7).
        self.assertEqual(
            len(db.list_model_runs(self.conn, component=COMPONENT_FREE_PICK)), 1
        )

    def test_free_pick_obeys_gate_and_cap(self):
        from wkd.providers import MockProvider

        # One good matter + one ungradeable (past date) — the gate drops the bad one.
        import json as _json

        payload = _json.dumps(
            [
                {
                    "title": "Bitcoin sets a new all-time high by September 2026.",
                    "domain": "crypto",
                    "resolution_date": FUTURE,
                    "resolution_criteria": GOOD_CRITERIA,
                },
                {
                    "title": "An already-settled matter from the past.",
                    "domain": "econ",
                    "resolution_date": PAST,  # not in the future -> gate rejects
                    "resolution_criteria": GOOD_CRITERIA,
                },
            ]
        )
        provider = MockProvider(default=payload, model="king-test")
        out = harvest(self.conn, free_pick_provider=provider, free_pick_max=5, now=NOW)
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0].source, Source.FREE_PICK)

    def test_free_pick_disabled_when_max_zero(self):
        from wkd.providers import MockProvider

        provider = MockProvider(default=_free_pick_payload("ignored"), model="king-test")
        out = harvest(self.conn, free_pick_provider=provider, free_pick_max=0, now=NOW)
        self.assertEqual(out, [])
        self.assertEqual(provider.call_count, 0)  # not even called

    def test_garbled_free_pick_completion_yields_nothing(self):
        from wkd.providers import MockProvider

        provider = MockProvider(default="(not json at all)", model="king-test")
        out = harvest(self.conn, free_pick_provider=provider, free_pick_max=3, now=NOW)
        self.assertEqual(out, [])  # no crash, just no free-picks

    def test_free_pick_uses_web_search(self):
        # The King must WEB-SEARCH for matters so the live claude-cli provider
        # actually grounds its picks; MockProvider records the flag (SPEC §7).
        from wkd.providers import MockProvider

        provider = MockProvider(
            default=_free_pick_payload("The Fed shall cut rates by September 2026."),
            model="king-test",
        )
        harvest(self.conn, free_pick_provider=provider, free_pick_max=3, now=NOW)
        self.assertTrue(provider.calls)
        self.assertTrue(provider.calls[0]["search"])  # web-grounded origination

    def test_canned_upcoming_events_gated_deduped_and_persisted(self):
        # A canned JSON array of upcoming, dated events the King "found" by search:
        # two distinct keepers, a within-batch duplicate of the first, and one
        # ungradeable (no date). Only the two distinct, gradeable matters survive —
        # gated, deduped, and persisted as pending free-pick Events.
        import json as _json

        from wkd.providers import MockProvider

        payload = _json.dumps([
            {
                "title": "The S&P 500 closes above 7000 by September 2026.",
                "domain": "econ",
                "resolution_date": FUTURE,
                "resolution_criteria": GOOD_CRITERIA,
            },
            {
                "title": "Bitcoin sets a new all-time high by September 2026.",
                "domain": "crypto",
                "resolution_date": FUTURE,
                "resolution_criteria": GOOD_CRITERIA,
            },
            {  # within-batch duplicate of the first matter -> deduped away
                "title": "The S&P 500 closes above 7000 by September 2026.",
                "domain": "econ",
                "resolution_date": FUTURE,
                "resolution_criteria": GOOD_CRITERIA,
            },
            {  # ungradeable: no resolution date -> dropped by the falsifiability gate
                "title": "Some vague unfolding economic situation continues",
                "domain": "econ",
                "resolution_date": None,
                "resolution_criteria": GOOD_CRITERIA,
            },
        ])
        provider = MockProvider(default=payload, model="king-test")
        out = harvest(self.conn, free_pick_provider=provider, free_pick_max=10, now=NOW)

        self.assertEqual(len(out), 2)
        self.assertEqual({e.source for e in out}, {Source.FREE_PICK})
        self.assertTrue(all(e.status == EventStatus.PENDING for e in out))
        self.assertEqual(
            {e.title for e in out},
            {
                "The S&P 500 closes above 7000 by September 2026.",
                "Bitcoin sets a new all-time high by September 2026.",
            },
        )
        # Persisted to the DB, tagged free-pick.
        self.assertEqual(len(db.list_events(self.conn, source=Source.FREE_PICK)), 2)

    def test_free_pick_deduped_against_existing(self):
        from wkd.providers import MockProvider

        provider = MockProvider(
            default=_free_pick_payload("The S&P 500 closes above 7000 by September 2026."),
            model="king-test",
        )
        first = harvest(self.conn, free_pick_provider=provider, free_pick_max=3, now=NOW)
        self.assertEqual(len(first), 1)
        # Same matter proposed on a later run -> deduped against the existing event.
        again = harvest(self.conn, free_pick_provider=provider, free_pick_max=3, now=NOW)
        self.assertEqual(again, [])
        self.assertEqual(len(db.list_events(self.conn, source=Source.FREE_PICK)), 1)


# ---------------------------------------------------------------------------
# Real source impls — lazy-import safety only (never hit the network)
# ---------------------------------------------------------------------------


class LazyImportTest(unittest.TestCase):
    def test_construction_imports_no_sdk(self):
        # If feedparser/httpx were imported eagerly this construction (or the
        # module import) would fail in the bare test env.
        FeedparserNewsFetcher(["https://feed.example/rss"])
        HttpxMarketQuestionClient("https://api.example/markets")

    def test_news_fetch_lazy_imports_feedparser(self):
        try:
            import feedparser  # noqa: F401
            self.skipTest("feedparser installed; lazy-import path not exercised")
        except ModuleNotFoundError:
            pass
        with self.assertRaises(ModuleNotFoundError):
            FeedparserNewsFetcher(["https://feed.example/rss"]).fetch()

    def test_market_fetch_lazy_imports_httpx(self):
        try:
            import httpx  # noqa: F401
            self.skipTest("httpx installed; lazy-import path not exercised")
        except ModuleNotFoundError:
            pass
        with self.assertRaises(ModuleNotFoundError):
            HttpxMarketQuestionClient("https://api.example/markets").fetch()


class FreePickParseTest(unittest.TestCase):
    """Web-search free-pick replies wrap the JSON in a ```json fence with prose
    before it and a trailing 'Sources:' list of [text](url) links — whose brackets
    used to break the greedy array regex, yielding zero matters. Regression."""

    def test_parses_fenced_json_amid_prose_and_source_links(self):
        from wkd import harvester
        text = (
            "Based on web searches, here are three matters worthy of decree:\n\n"
            "```json\n"
            '[{"title":"June Jobs Report","resolution_date":"2026-07-02",'
            '"resolution_criteria":"BLS releases nonfarm payrolls.","domain":"econ"},'
            '{"title":"Wimbledon Final","resolution_date":"2026-07-12",'
            '"resolution_criteria":"Champions crowned.","domain":"current-events"}]\n'
            "```\n\n"
            "Sources:\n- [BLS Schedule](https://www.bls.gov/x)\n"
            "- [Wimbledon](https://wimbledon.com/y)\n"
        )
        items = harvester._parse_free_pick_items(text)
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]["title"], "June Jobs Report")
        self.assertEqual(items[1]["domain"], "current-events")


if __name__ == "__main__":
    unittest.main()
