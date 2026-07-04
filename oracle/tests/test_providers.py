"""Offline tests for wkd.providers (LLMResponse, MockProvider, factory, lazy SDKs)."""

import importlib.util
import json
import os
import unittest
from unittest import mock

from wkd.config import ModelSpec
from wkd.providers import (
    AnthropicProvider,
    ClaudeCliProvider,
    GeminiProvider,
    LLMProvider,
    LLMResponse,
    MockProvider,
    OpenAIProvider,
    estimate_cost,
    get_provider,
)


class LLMResponseTest(unittest.TestCase):
    def test_fields(self):
        r = LLMResponse(text="hi", model="m", prompt_tokens=3, completion_tokens=1, cost=0.0)
        self.assertEqual(r.text, "hi")
        self.assertIsNone(r.raw)

    def test_estimate_cost(self):
        # known model priced; unknown model is free
        self.assertGreater(estimate_cost("claude-opus-4-8", 1_000_000, 0), 0)
        self.assertEqual(estimate_cost("unknown-model", 1000, 1000), 0.0)


class MockListModeTest(unittest.TestCase):
    def test_returns_in_call_order(self):
        # scripts a mage's three converging rounds
        m = MockProvider(["round1", "round2", "agree"], model="mage-a")
        self.assertEqual(m.complete("sys", "p1").text, "round1")
        self.assertEqual(m.complete("sys", "p2").text, "round2")
        self.assertEqual(m.complete("sys", "p3").text, "agree")
        self.assertEqual(m.call_count, 3)
        self.assertEqual(m.prompts, ["p1", "p2", "p3"])
        self.assertEqual(m.last_prompt, "p3")

    def test_response_carries_provider_model(self):
        m = MockProvider(["x"], model="mage-a")
        self.assertEqual(m.complete("s", "u").model, "mage-a")

    def test_exhausted_list_without_default_raises(self):
        m = MockProvider(["only"])
        m.complete("s", "u")
        with self.assertRaises(AssertionError):
            m.complete("s", "u")

    def test_default_used_when_list_exhausted(self):
        m = MockProvider(["only"], default="fallback")
        m.complete("s", "u")
        self.assertEqual(m.complete("s", "u").text, "fallback")

    def test_reset(self):
        m = MockProvider(["a", "b"])
        m.complete("s", "u")
        m.reset()
        self.assertEqual(m.call_count, 0)
        self.assertEqual(m.complete("s", "u").text, "a")


class MockDictModeTest(unittest.TestCase):
    def test_routes_by_substring(self):
        # one Historian provider answering different decree claims per tier
        hist = MockProvider(
            {
                "rate cut": '{"verdict":"vindicated"}',
                "election": '{"verdict":"apology"}',
            }
        )
        self.assertIn("vindicated", hist.complete("sys", "Did the rate cut happen?").text)
        self.assertIn("apology", hist.complete("sys", "Who won the election?").text)

    def test_matches_against_system_too(self):
        m = MockProvider({"HISTORIAN": "ok"})
        self.assertEqual(m.complete("You are the HISTORIAN.", "judge this").text, "ok")

    def test_list_value_cycles_per_key(self):
        m = MockProvider({"draft": ["d1", "d2"]})
        self.assertEqual(m.complete("s", "please draft").text, "d1")
        self.assertEqual(m.complete("s", "redraft now").text, "d2")

    def test_no_match_raises_without_default(self):
        m = MockProvider({"foo": "bar"})
        with self.assertRaises(AssertionError):
            m.complete("s", "nothing relevant")

    def test_no_match_uses_default(self):
        m = MockProvider({"foo": "bar"}, default="def")
        self.assertEqual(m.complete("s", "unrelated").text, "def")


class MockCoercionTest(unittest.TestCase):
    def test_passthrough_llmresponse(self):
        canned = LLMResponse(text="t", model="x", prompt_tokens=10, completion_tokens=5, cost=0.01)
        m = MockProvider([canned])
        out = m.complete("s", "u")
        self.assertIs(out, canned)

    def test_dict_spec_builds_response(self):
        # script exact token counts for a King styling pass
        m = MockProvider([{"text": "By royal decree!", "prompt_tokens": 42, "completion_tokens": 7}])
        out = m.complete("s", "u")
        self.assertEqual(out.text, "By royal decree!")
        self.assertEqual(out.prompt_tokens, 42)
        self.assertEqual(out.completion_tokens, 7)
        self.assertEqual(out.model, "mock-model")  # defaulted

    def test_dict_spec_requires_text(self):
        m = MockProvider([{"prompt_tokens": 1}])
        with self.assertRaises(AssertionError):
            m.complete("s", "u")


class MockRecordingTest(unittest.TestCase):
    def test_records_call_kwargs(self):
        m = MockProvider(["ok"])
        m.complete("system", "user", temperature=0.2, max_tokens=99, want_json=True, search=True)
        call = m.calls[0]
        self.assertEqual(call["system"], "system")
        self.assertEqual(call["temperature"], 0.2)
        self.assertEqual(call["max_tokens"], 99)
        self.assertTrue(call["want_json"])
        self.assertTrue(call["search"])

    def test_is_llmprovider(self):
        self.assertIsInstance(MockProvider(["x"]), LLMProvider)


class FactoryTest(unittest.TestCase):
    def test_mock_by_name(self):
        p = get_provider("mock")
        self.assertIsInstance(p, MockProvider)
        # has a default so it never raises even unscripted
        self.assertEqual(p.complete("s", "u").text, "(mock response)")

    def test_mock_by_modelspec(self):
        p = get_provider(ModelSpec("mock", "mock-judge"))
        self.assertIsInstance(p, MockProvider)
        self.assertEqual(p.model, "mock-judge")

    def test_live_specs_resolve_without_sdk(self):
        # Constructing live providers must NOT import any SDK.
        self.assertIsInstance(get_provider(ModelSpec("anthropic", "claude-opus-4-8")), AnthropicProvider)
        self.assertIsInstance(get_provider(ModelSpec("openai", "gpt-4.1")), OpenAIProvider)
        self.assertIsInstance(get_provider(ModelSpec("gemini", "gemini-2.5-pro")), GeminiProvider)

    def test_unknown_provider_raises(self):
        with self.assertRaises(ValueError):
            get_provider(ModelSpec("llama", "whatever"))

    def test_bad_type_raises(self):
        with self.assertRaises(TypeError):
            get_provider(123)

    def test_key_pulled_from_config(self):
        class FakeCfg:
            def key_for(self, provider):
                return "KEY-" + provider

        p = get_provider(ModelSpec("anthropic", "claude-opus-4-8"), FakeCfg())
        self.assertEqual(p._api_key, "KEY-anthropic")


class LazyImportTest(unittest.TestCase):
    def test_construction_does_not_import_sdk(self):
        # If these imports were eager, importing wkd.providers would already
        # have failed (the SDKs aren't installed in the test env).
        AnthropicProvider("claude-opus-4-8")
        OpenAIProvider("gpt-4.1")
        GeminiProvider("gemini-2.5-pro")

    def test_complete_attempts_lazy_import(self):
        # Calling complete() with no SDK installed surfaces the import error,
        # proving the SDK is only touched inside complete().
        try:
            import anthropic  # noqa: F401
            self.skipTest("anthropic SDK is installed; lazy-import path not exercised")
        except ModuleNotFoundError:
            pass
        with self.assertRaises(ModuleNotFoundError):
            AnthropicProvider("claude-opus-4-8").complete("s", "u")


class IsReadyTest(unittest.TestCase):
    """is_ready() lets the driver skip unconfigured LLM legs (SPEC §17)."""

    def test_mock_is_always_ready(self):
        self.assertTrue(MockProvider().is_ready())
        self.assertTrue(get_provider("mock").is_ready())

    def test_live_providers_not_ready_without_key(self):
        # Blank the keys so readiness is False regardless of whether the SDKs
        # happen to be installed on the host.
        with mock.patch.dict(
            os.environ,
            {"ANTHROPIC_API_KEY": "", "OPENAI_API_KEY": "", "GEMINI_API_KEY": ""},
            clear=False,
        ):
            self.assertFalse(AnthropicProvider("claude-opus-4-8").is_ready())
            self.assertFalse(OpenAIProvider("gpt-4.1").is_ready())
            self.assertFalse(GeminiProvider("gemini-2.5-pro").is_ready())

    def test_key_present_but_sdk_missing_is_not_ready(self):
        # In the offline test env the SDK is absent, so a key alone isn't enough.
        if importlib.util.find_spec("anthropic") is not None:
            self.skipTest("anthropic SDK installed; readiness then depends on key only")
        self.assertFalse(
            AnthropicProvider("claude-opus-4-8", api_key="sk-test").is_ready()
        )


class ClaudeCliProviderTest(unittest.TestCase):
    """Subscription path via the `claude` CLI — parsed with an injected runner."""

    @staticmethod
    def _ok_json(text="PONG", cost=0.087, pin=52, pout=1259):
        return json.dumps(
            {
                "is_error": False,
                "result": text,
                "total_cost_usd": cost,
                "usage": {"input_tokens": pin, "output_tokens": pout},
            }
        )

    def test_parses_cli_json_and_disables_web_by_default(self):
        seen = {}

        def runner(args):
            seen["args"] = args
            return (0, self._ok_json(), "")

        r = ClaudeCliProvider("haiku", runner=runner).complete("be terse", "say pong")
        self.assertEqual(r.text, "PONG")
        self.assertEqual((r.prompt_tokens, r.completion_tokens), (52, 1259))
        self.assertAlmostEqual(r.cost, 0.087)
        self.assertEqual(r.model, "haiku")
        # council calls must NOT have web access
        self.assertIn("--disallowedTools", seen["args"])
        self.assertNotIn("--allowedTools", seen["args"])
        self.assertIn("--append-system-prompt", seen["args"])
        self.assertIn("haiku", seen["args"])

    def test_search_enables_websearch(self):
        seen = {}

        def runner(args):
            seen["args"] = args
            return (0, self._ok_json(text="verdict"), "")

        ClaudeCliProvider("sonnet", runner=runner).complete(
            "judge", "did it happen?", search=True
        )
        self.assertIn("--allowedTools", seen["args"])
        self.assertIn("WebSearch", seen["args"])
        self.assertNotIn("--disallowedTools", seen["args"])

    def test_nonzero_exit_raises(self):
        p = ClaudeCliProvider("haiku", runner=lambda args: (1, "", "boom"))
        with self.assertRaises(RuntimeError):
            p.complete("s", "u")

    def test_is_ready_false_when_binary_absent(self):
        self.assertFalse(
            ClaudeCliProvider("haiku", binary="definitely-not-a-real-binary-xyz").is_ready()
        )

    def test_factory_builds_claude_cli(self):
        p = get_provider(ModelSpec("claude-cli", "haiku"))
        self.assertIsInstance(p, ClaudeCliProvider)
        self.assertEqual(p.model, "haiku")


if __name__ == "__main__":
    unittest.main()
