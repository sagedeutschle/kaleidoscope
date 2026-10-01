"""Offline tests for the Wordgame Daily broker.

Run from oracle/wordle-broker:  python3 -m unittest discover -s tests -v
Fixtures are minimal synthetic snippets shaped like each source page.
"""
import argparse
import json
import os
import sys
import tempfile
import unittest
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import wordle_broker as wb  # noqa: E402

wb.log = lambda msg: None  # keep test output readable

DAY = date(2026, 10, 1)
NUM = 1930

WORDTIPS = (
    '<script>{type:"data",data:{solutions:[{date:"2026-10-01",number:1930,answer:"RITZY",'
    'difficulty:2},{date:"2026-09-30",number:1929,answer:"RIVER",difficulty:2}]}}</script>'
)
WORDFINDER = (
    'todayData:{date:"261001",index:1930,answer:"RITZY"},pastData:[{month:"2609",answers:'
    '[{date:"260930",index:1929,answer:"RIVER"}]}]'
)
TECHRADAR = (
    "<h2>Today's Wordle answer (game #1930)</h2><p>My start word: SANER</p>"
    "<p>Today's Wordle answer (game #1930) is&hellip; <strong>RITZY</strong>.</p>"
)
TOMSGUIDE = (
    "<h2>Today's Wordle answer</h2><p>So, what is today's Wordle answer for game #1,930? "
    "Drumroll, please &mdash; it's <strong>RITZY</strong>.</p>"
)
RPS = (
    "<h2>What is today's Wordle answer on October 1?</h2><p>It's time to reveal the answer "
    "to today's Wordle for 1/10. The word is...</p> <p><strong>RITZY</strong>.</p>"
)
PAGES = {
    "https://word.tips/todays-wordle-answer/": WORDTIPS,
    "https://wordfinder.yourdictionary.com/wordle/answers/": WORDFINDER,
    "https://www.techradar.com/news/wordle-today": TECHRADAR,
    "https://www.tomsguide.com/news/what-is-todays-wordle-answer": TOMSGUIDE,
    "https://www.rockpapershotgun.com/wordle-hint-and-answer-today-01-10-26": RPS,
}


def args(**kw):
    base = dict(dry_run=False, force=False, date=None, no_llm=True,
                key_file="/nonexistent", state_dir="/nonexistent", verify_delay=0)
    base.update(kw)
    return argparse.Namespace(**base)


class PuzzleNumberTests(unittest.TestCase):
    def test_known_anchors(self):
        self.assertEqual(wb.puzzle_number(date(2026, 7, 9)), 1846)
        self.assertEqual(wb.puzzle_number(DAY), NUM)

    def test_eastern_rollover(self):
        # 03:59 UTC on Oct 2 is still Oct 1 in New York (EDT, UTC-4).
        self.assertEqual(wb.today_eastern(datetime.fromisoformat("2026-10-02T03:59:00+00:00")), DAY)
        self.assertEqual(wb.today_eastern(datetime.fromisoformat("2026-10-02T04:01:00+00:00")),
                         date(2026, 10, 2))


class ParserTests(unittest.TestCase):
    def test_each_parser_reads_its_page(self):
        for src in wb.SOURCES:
            with self.subTest(src.name):
                self.assertEqual(src.parse(PAGES[src.url(DAY)], DAY, NUM), "ritzy")

    def test_parsers_ignore_other_days(self):
        tomorrow, num = date(2026, 10, 2), NUM + 1
        for src in wb.SOURCES:
            with self.subTest(src.name):
                self.assertIsNone(src.parse(PAGES[src.url(DAY)], tomorrow, num))

    def test_parsers_tolerate_garbage(self):
        for src in wb.SOURCES:
            with self.subTest(src.name):
                self.assertIsNone(src.parse("<html>Access denied</html>", DAY, NUM))

    def test_wordfinder_reads_past_entry_by_date(self):
        self.assertEqual(wb.parse_wordfinder(WORDFINDER, date(2026, 9, 30), 1929), "river")

    def test_rps_url_is_per_day(self):
        rps = next(s for s in wb.SOURCES if s.name == "rockpapershotgun.com")
        self.assertTrue(rps.url(DAY).endswith("-01-10-26"))

    def test_text_parsers_skip_words_before_the_anchor(self):
        # TECHRADAR mentions SANER (a start word) before the answer line.
        self.assertEqual(wb.parse_techradar(TECHRADAR, DAY, NUM), "ritzy")
        self.assertIsNone(wb.parse_techradar("<p>answer (game #1930) is ritzy-ish</p>", DAY, NUM))


class ConsensusTests(unittest.TestCase):
    def v(self, publisher, answer):
        return wb.Vote(publisher, publisher, answer)

    def test_majority_with_dissent(self):
        d = wb.decide([self.v("a", "ritzy"), self.v("b", "ritzy"), self.v("c", "papal")])
        self.assertEqual(d.answer, "ritzy")
        self.assertEqual(d.support["papal"], ["c"])

    def test_single_publisher_is_not_enough(self):
        self.assertIsNone(wb.decide([self.v("a", "ritzy")]).answer)

    def test_same_publisher_counts_once(self):
        votes = [wb.Vote("techradar", "future", "ritzy"), wb.Vote("tomsguide", "future", "ritzy")]
        self.assertIsNone(wb.decide(votes).answer)

    def test_self_contradicting_publisher_abstains(self):
        votes = [wb.Vote("techradar", "future", "ritzy"), wb.Vote("tomsguide", "future", "papal"),
                 self.v("a", "ritzy")]
        self.assertIsNone(wb.decide(votes).answer)

    def test_tie_is_refused(self):
        d = wb.decide([self.v("a", "ritzy"), self.v("b", "ritzy"),
                       self.v("c", "papal"), self.v("d", "papal")])
        self.assertIsNone(d.answer)
        self.assertIn("tie", d.reason)

    def test_errors_do_not_vote(self):
        votes = [wb.Vote("x", "x", None, "timeout"), self.v("a", "ritzy"), self.v("b", "ritzy")]
        self.assertEqual(wb.decide(votes).answer, "ritzy")


class SafetyTests(unittest.TestCase):
    def test_nyt_hosts_are_refused(self):
        for url in ("https://www.nytimes.com/svc/wordle/v2/2026-10-01.json",
                    "https://nytimes.com/games/wordle", "https://static01.nyt.com/x"):
            with self.subTest(url):
                with self.assertRaises(wb.BrokerError):
                    wb.http_get(url)

    def test_redirects_to_nyt_are_refused_before_following(self):
        req = wb.urllib.request.Request("https://word.tips/todays-wordle-answer/")
        with self.assertRaises(wb.BrokerError):
            wb.NoNytRedirects().redirect_request(
                req, None, 302, "Found", {}, "https://www.nytimes.com/games/wordle")

    def test_no_source_points_at_nyt(self):
        for src in wb.SOURCES:
            self.assertFalse(wb.is_forbidden_host(src.url(DAY)), src.name)

    def test_payload_shape(self):
        self.assertEqual(wb.build_payload("RITZY", DAY),
                         {"answer": "ritzy", "date": "2026-10-01", "sourceName": "Daily"})
        with self.assertRaises(wb.BrokerError):
            wb.build_payload("ritz", DAY)

    def test_key_file_must_be_private(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp) / "k"
            key.write_text("sb_secret_x\n")
            os.chmod(key, 0o644)
            with self.assertRaises(wb.BrokerError):
                wb.load_key(key)
            os.chmod(key, 0o600)
            self.assertEqual(wb.load_key(key), "sb_secret_x")


class LlmVoteTests(unittest.TestCase):
    def test_reply_validation(self):
        good = '{"answer":"ritzy","date":"2026-10-01","sources":["tomsguide.com","parade.com"]}'
        self.assertEqual(wb.parse_llm_reply("thinking...\n" + good, DAY), "ritzy")
        self.assertIsNone(wb.parse_llm_reply('{"error":"unconfirmed"}', DAY))
        self.assertIsNone(wb.parse_llm_reply(good.replace("parade.com", "www.tomsguide.com"), DAY))
        self.assertIsNone(wb.parse_llm_reply(good.replace("parade.com", "nytimes.com"), DAY))
        self.assertIsNone(wb.parse_llm_reply(good.replace("2026-10-01", "2026-09-30"), DAY))

    def test_daily_attempt_budget(self):
        good = '{"answer":"ritzy","date":"2026-10-01","sources":["a.com","b.com"]}'
        calls = []
        with tempfile.TemporaryDirectory() as tmp:
            for _ in range(wb.MAX_LLM_ATTEMPTS_PER_DAY + 2):
                wb.llm_vote(DAY, Path(tmp), runner=lambda p: calls.append(p) or good)
        self.assertEqual(len(calls), wb.MAX_LLM_ATTEMPTS_PER_DAY)


class RunTests(unittest.TestCase):
    def setUp(self):
        self.published = []
        self.tmp = tempfile.TemporaryDirectory()
        self.key = Path(self.tmp.name) / "key"
        self.key.write_text("sb_secret_test")
        os.chmod(self.key, 0o600)
        self.store = {}

    def tearDown(self):
        self.tmp.cleanup()

    def publish(self, payload, key):
        self.published.append((payload, key))
        self.store = dict(payload)
        return 200

    def go(self, **kw):
        a = args(date=DAY.isoformat(), force=True, key_file=str(self.key), **kw)
        return wb.run(a, fetch=PAGES.__getitem__, read_current=lambda: self.store or None,
                      publish=self.publish, proxy_check=lambda p: True)

    def test_publishes_consensus_payload(self):
        self.assertEqual(self.go(), 0)
        self.assertEqual(self.published,
                         [({"answer": "ritzy", "date": "2026-10-01", "sourceName": "Daily"},
                           "sb_secret_test")])

    def test_idempotent_when_already_current(self):
        self.store = {"answer": "ritzy", "date": DAY.isoformat(), "sourceName": "Daily"}
        a = args(date=DAY.isoformat(), key_file=str(self.key))
        rc = wb.run(a, fetch=lambda u: self.fail("must not fetch sources"),
                    read_current=lambda: self.store, publish=self.publish)
        self.assertEqual(rc, 0)
        self.assertEqual(self.published, [])

    def test_dry_run_publishes_nothing(self):
        self.assertEqual(self.go(dry_run=True), 0)
        self.assertEqual(self.published, [])

    def test_no_consensus_fails_without_publishing(self):
        def fetch(url):
            if "word.tips" in url:
                return WORDTIPS
            raise OSError("blocked")
        a = args(date=DAY.isoformat(), force=True, key_file=str(self.key))
        rc = wb.run(a, fetch=fetch, read_current=lambda: None, publish=self.publish)
        self.assertEqual(rc, 1)
        self.assertEqual(self.published, [])

    def test_llm_vote_can_complete_consensus(self):
        def fetch(url):
            if "word.tips" in url:
                return WORDTIPS
            raise OSError("blocked")
        llm = lambda day, state: wb.Vote("codex-web-search", "llm:codex", "ritzy")
        a = args(date=DAY.isoformat(), force=True, no_llm=False, key_file=str(self.key))
        rc = wb.run(a, fetch=fetch, read_current=lambda: self.store or None,
                    publish=self.publish, llm=llm, proxy_check=lambda p: True)
        self.assertEqual(rc, 0)
        self.assertEqual(self.published[0][0]["answer"], "ritzy")

    def test_refuses_other_dates_without_force(self):
        real = wb.today_eastern
        wb.today_eastern = lambda now=None: date(2026, 10, 2)
        try:
            a = args(date=DAY.isoformat(), key_file=str(self.key))
            rc = wb.run(a, fetch=PAGES.__getitem__, read_current=lambda: None,
                        publish=self.publish)
        finally:
            wb.today_eastern = real
        self.assertEqual(rc, 2)
        self.assertEqual(self.published, [])

    def test_upload_that_does_not_read_back_is_an_error(self):
        a = args(date=DAY.isoformat(), force=True, key_file=str(self.key))
        rc = wb.run(a, fetch=PAGES.__getitem__, read_current=lambda: None,
                    publish=lambda p, k: 200, proxy_check=lambda p: True)
        self.assertEqual(rc, 1)

    def test_slow_proxy_is_a_warning_not_a_failure(self):
        a = args(date=DAY.isoformat(), force=True, key_file=str(self.key))
        rc = wb.run(a, fetch=PAGES.__getitem__, read_current=lambda: self.store or None,
                    publish=self.publish, proxy_check=lambda p: False)
        self.assertEqual(rc, 0)

    def test_fresh_url_is_unique(self):
        self.assertNotEqual(wb.fresh_url(wb.PUBLIC_URL), wb.fresh_url(wb.PUBLIC_URL))

    def test_failed_upload_is_an_error(self):
        a = args(date=DAY.isoformat(), force=True, key_file=str(self.key))
        rc = wb.run(a, fetch=PAGES.__getitem__, read_current=lambda: None,
                    publish=lambda p, k: 403)
        self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
