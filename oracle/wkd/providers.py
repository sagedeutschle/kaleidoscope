"""LLM provider abstraction (SPEC §13, §16.7).

A thin, swappable seam over the three live SDKs plus a deterministic
:class:`MockProvider` used by the entire offline test-suite. Real SDKs are
imported **lazily** inside :meth:`complete` so importing this module — and
constructing any provider — never requires the SDKs to be installed and never
touches the network.

The factory :func:`get_provider` maps a :class:`~wkd.config.ModelSpec` (or a bare
provider name) onto a concrete provider, returning a :class:`MockProvider` when
the provider is ``"mock"``.
"""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, Callable, Union

# ---------------------------------------------------------------------------
# Pricing (USD per 1,000,000 tokens). Update as provider pricing changes; an
# unknown model simply costs 0.0 (cost is "pennies by nature" per SPEC §18).
# ---------------------------------------------------------------------------

_PRICE_PER_MTOK: dict[str, tuple[float, float]] = {
    # model: (input_per_mtok, output_per_mtok)
    "claude-opus-4-8": (5.0, 25.0),
    "gpt-4.1": (2.0, 8.0),
    "gemini-2.5-pro": (1.25, 10.0),
}


def estimate_cost(model: str, prompt_tokens: int, completion_tokens: int) -> float:
    """Rough USD cost for a call, from the local price table (0.0 if unknown)."""
    pin, pout = _PRICE_PER_MTOK.get(model, (0.0, 0.0))
    return (prompt_tokens / 1_000_000) * pin + (completion_tokens / 1_000_000) * pout


def _sdk_available(module: str) -> bool:
    """True if ``module`` can be located without actually importing it."""
    try:
        return importlib.util.find_spec(module) is not None
    except (ImportError, ValueError):
        return False


@dataclass
class LLMResponse:
    """Normalized result of a single completion across all providers."""

    text: str
    model: str
    prompt_tokens: int
    completion_tokens: int
    cost: float
    raw: dict | None = None


class LLMProvider(ABC):
    """Common interface for every model backend.

    ``search=True`` requests web-grounded generation; only providers that
    support it (Gemini, for the Historian) honor it — others ignore it.
    ``want_json=True`` requests strict JSON output where the SDK supports it.
    """

    name: str = "abstract"

    @abstractmethod
    def complete(
        self,
        system: str,
        user: str,
        *,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        want_json: bool = False,
        search: bool = False,
    ) -> LLMResponse:
        ...

    def is_ready(self) -> bool:
        """Whether a live call can succeed now (API key present + SDK importable).

        Base default ``True`` (mock / injected test doubles are always ready);
        the live providers override this so the driver can gracefully *skip* LLM
        legs when the project is unconfigured (no keys / SDKs installed) instead
        of crashing mid-run.
        """
        return True


# ---------------------------------------------------------------------------
# Live providers (SDKs imported lazily inside complete())
# ---------------------------------------------------------------------------


class AnthropicProvider(LLMProvider):
    """Claude via the ``anthropic`` SDK (council mage / King styling pass)."""

    name = "anthropic"

    def __init__(self, model: str, api_key: str | None = None):
        self.model = model
        self._api_key = api_key

    def complete(
        self,
        system: str,
        user: str,
        *,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        want_json: bool = False,
        search: bool = False,
    ) -> LLMResponse:
        from anthropic import Anthropic  # lazy import (live path only)

        client = Anthropic(api_key=self._api_key or os.environ.get("ANTHROPIC_API_KEY"))
        # NOTE: the Messages API has no strict JSON mode; callers append a
        # "respond with JSON only" instruction to `system`/`user` when needed.
        # `search` is not supported here (only Gemini grounds the Historian).
        resp = client.messages.create(
            model=self.model,
            max_tokens=max_tokens,
            temperature=temperature,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        text = resp.content[0].text
        pin = int(resp.usage.input_tokens)
        pout = int(resp.usage.output_tokens)
        return LLMResponse(
            text=text,
            model=self.model,
            prompt_tokens=pin,
            completion_tokens=pout,
            cost=estimate_cost(self.model, pin, pout),
        )

    def is_ready(self) -> bool:
        key = self._api_key or os.environ.get("ANTHROPIC_API_KEY")
        return bool(key) and _sdk_available("anthropic")


class OpenAIProvider(LLMProvider):
    """GPT via the ``openai`` SDK (council mage / King styling pass)."""

    name = "openai"

    def __init__(self, model: str, api_key: str | None = None):
        self.model = model
        self._api_key = api_key

    def complete(
        self,
        system: str,
        user: str,
        *,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        want_json: bool = False,
        search: bool = False,
    ) -> LLMResponse:
        from openai import OpenAI  # lazy import (live path only)

        client = OpenAI(api_key=self._api_key or os.environ.get("OPENAI_API_KEY"))
        kwargs: dict[str, Any] = {
            "model": self.model,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        }
        if want_json:
            kwargs["response_format"] = {"type": "json_object"}
        resp = client.chat.completions.create(**kwargs)
        text = resp.choices[0].message.content or ""
        pin = int(resp.usage.prompt_tokens)
        pout = int(resp.usage.completion_tokens)
        return LLMResponse(
            text=text,
            model=self.model,
            prompt_tokens=pin,
            completion_tokens=pout,
            cost=estimate_cost(self.model, pin, pout),
        )

    def is_ready(self) -> bool:
        key = self._api_key or os.environ.get("OPENAI_API_KEY")
        return bool(key) and _sdk_available("openai")


class GeminiProvider(LLMProvider):
    """Gemini via ``google-genai`` — the independent, search-grounded Historian.

    When ``search=True`` the Google Search grounding tool is enabled so the
    Historian judges against real reporting (SPEC §3, §9, §16.3).
    """

    name = "gemini"

    def __init__(self, model: str, api_key: str | None = None):
        self.model = model
        self._api_key = api_key

    def complete(
        self,
        system: str,
        user: str,
        *,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        want_json: bool = False,
        search: bool = False,
    ) -> LLMResponse:
        from google import genai  # lazy import (live path only)
        from google.genai import types

        client = genai.Client(api_key=self._api_key or os.environ.get("GEMINI_API_KEY"))
        cfg_kwargs: dict[str, Any] = {
            "temperature": temperature,
            "max_output_tokens": max_tokens,
        }
        if system:
            cfg_kwargs["system_instruction"] = system
        if search:
            cfg_kwargs["tools"] = [types.Tool(google_search=types.GoogleSearch())]
        if want_json and not search:
            # JSON mime-type and grounding are mutually exclusive in the API.
            cfg_kwargs["response_mime_type"] = "application/json"
        resp = client.models.generate_content(
            model=self.model,
            contents=user,
            config=types.GenerateContentConfig(**cfg_kwargs),
        )
        text = resp.text or ""
        usage = getattr(resp, "usage_metadata", None)
        pin = int(getattr(usage, "prompt_token_count", 0) or 0)
        pout = int(getattr(usage, "candidates_token_count", 0) or 0)
        return LLMResponse(
            text=text,
            model=self.model,
            prompt_tokens=pin,
            completion_tokens=pout,
            cost=estimate_cost(self.model, pin, pout),
        )

    def is_ready(self) -> bool:
        key = self._api_key or os.environ.get("GEMINI_API_KEY")
        return bool(key) and _sdk_available("google.genai")


class ClaudeCliProvider(LLMProvider):
    """Claude via the local ``claude`` CLI in print mode — uses the Max
    **subscription**, no API key (SPEC §17.1 fallback path).

    Web grounding (for the Court Historian when no independent Gemini key is
    available) is enabled with ``search=True``, which allows the ``WebSearch``
    tool; otherwise tools are disabled so the council predicts from pure
    reasoning. The CLI exposes no ``temperature``/``max_tokens`` knobs, so those
    are accepted and ignored.

    Each call carries Claude Code's full system prompt (~150k cached tokens), so
    the subscription path is heavier per call than the raw API — fine for a light
    cadence, but prefer the API providers for volume.
    """

    name = "claude-cli"

    def __init__(
        self,
        model: str,
        *,
        binary: str = "claude",
        runner: Callable[[list[str]], tuple[int, str, str]] | None = None,
        search_tools: tuple[str, ...] = ("WebSearch", "WebFetch"),
    ):
        self.model = model
        self._binary = binary
        self._runner = runner  # injectable: (args) -> (returncode, stdout, stderr)
        self._search_tools = list(search_tools)

    def _invoke(self, args: list[str]) -> tuple[int, str, str]:
        if self._runner is not None:
            return self._runner(args)
        proc = subprocess.run(args, capture_output=True, text=True)
        return proc.returncode, proc.stdout, proc.stderr

    def complete(
        self,
        system: str,
        user: str,
        *,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        want_json: bool = False,
        search: bool = False,
    ) -> LLMResponse:
        args = [self._binary, "-p", user, "--output-format", "json", "--model", self.model]
        if system:
            args += ["--append-system-prompt", system]
        if search:
            args += ["--allowedTools", *self._search_tools]
        else:
            args += ["--disallowedTools", "WebSearch", "WebFetch", "Bash"]
        rc, out, err = self._invoke(args)
        if rc != 0:
            raise RuntimeError(f"claude CLI exited {rc}: {(err or out)[:500]}")
        try:
            data = json.loads(out)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"claude CLI returned non-JSON output: {out[:300]}") from exc
        if data.get("is_error"):
            raise RuntimeError(f"claude CLI error: {str(data.get('result', ''))[:500]}")
        usage = data.get("usage") or {}
        return LLMResponse(
            text=str(data.get("result", "") or ""),
            model=self.model,
            prompt_tokens=int(usage.get("input_tokens", 0) or 0),
            completion_tokens=int(usage.get("output_tokens", 0) or 0),
            cost=float(data.get("total_cost_usd", 0.0) or 0.0),
            raw=data,
        )

    def is_ready(self) -> bool:
        # Subscription-based: needs the CLI on PATH, not an API key.
        return shutil.which(self._binary) is not None


# ---------------------------------------------------------------------------
# MockProvider — deterministic, scriptable, offline
# ---------------------------------------------------------------------------

# A single scripted response may be given as plain text, a full LLMResponse, or
# a dict of LLMResponse kwargs (must contain "text").
ResponseSpec = Union[str, LLMResponse, dict]
# The whole script is either an ordered list (returned per call) or a dict that
# routes by substring of the (system+user) prompt to a spec or list of specs.
Script = Union[list, dict, None]


class MockProvider(LLMProvider):
    """Deterministic provider for tests — scripts council/King/Historian turns.

    Construct with ``responses`` as either:

    * a **list** of specs returned in call order (e.g. a mage's round-1, round-2,
      round-3 drafts as the council converges or diverges), or
    * a **dict** mapping a prompt *substring* → a spec (or a list of specs cycled
      in order for repeated matches) — useful for one provider that answers
      different prompts, e.g. a Historian keyed by claim text per tier.

    ``default`` is returned when a list is exhausted or no dict key matches.
    Every call is recorded in :attr:`calls` (and the user text in :attr:`prompts`)
    so tests can assert what the council/Historian actually asked.
    """

    name = "mock"

    def __init__(
        self,
        responses: Script = None,
        *,
        name: str = "mock",
        model: str = "mock-model",
        default: ResponseSpec | None = None,
        cost: float = 0.0,
    ):
        self.name = name
        self.model = model
        self._responses = responses
        self._default = default
        self._cost = cost
        self.call_count = 0
        self.calls: list[dict[str, Any]] = []
        self.prompts: list[str] = []
        self._key_idx: dict[str, int] = {}

    # -- public helpers ----------------------------------------------------

    @property
    def last_prompt(self) -> str | None:
        return self.prompts[-1] if self.prompts else None

    def reset(self) -> None:
        """Forget recorded calls and restart the script from the top."""
        self.call_count = 0
        self.calls.clear()
        self.prompts.clear()
        self._key_idx.clear()

    # -- LLMProvider -------------------------------------------------------

    def complete(
        self,
        system: str,
        user: str,
        *,
        temperature: float = 0.7,
        max_tokens: int = 2048,
        want_json: bool = False,
        search: bool = False,
    ) -> LLMResponse:
        self.call_count += 1
        self.calls.append(
            {
                "system": system,
                "user": user,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "want_json": want_json,
                "search": search,
            }
        )
        self.prompts.append(user)
        spec = self._select(system or "", user or "")
        return self._coerce(spec, system or "", user or "")

    # -- internals ---------------------------------------------------------

    def _select(self, system: str, user: str) -> ResponseSpec:
        responses = self._responses
        if isinstance(responses, dict):
            prompt = f"{system}\n{user}"
            for key, val in responses.items():
                if key in prompt:
                    if isinstance(val, list):
                        idx = self._key_idx.get(key, 0)
                        if idx >= len(val):
                            raise AssertionError(
                                f"MockProvider script for key {key!r} exhausted "
                                f"after {idx} call(s)"
                            )
                        self._key_idx[key] = idx + 1
                        return val[idx]
                    return val
            return self._require_default(f"no MockProvider key matched prompt: {user!r}")
        if isinstance(responses, list):
            idx = self.call_count - 1
            if idx < len(responses):
                return responses[idx]
            return self._require_default(
                f"MockProvider list script exhausted after {len(responses)} call(s)"
            )
        return self._require_default("MockProvider has no scripted responses")

    def _require_default(self, msg: str) -> ResponseSpec:
        if self._default is not None:
            return self._default
        raise AssertionError(msg)

    def _coerce(self, spec: ResponseSpec, system: str, user: str) -> LLMResponse:
        if isinstance(spec, LLMResponse):
            return spec
        if isinstance(spec, dict):
            data = dict(spec)
            if "text" not in data:
                raise AssertionError("MockProvider dict response needs a 'text' key")
            data.setdefault("model", self.model)
            text = str(data["text"])
            data.setdefault("prompt_tokens", _approx_tokens(system) + _approx_tokens(user))
            data.setdefault("completion_tokens", _approx_tokens(text))
            data.setdefault("cost", self._cost)
            return LLMResponse(**data)
        # plain string
        text = str(spec)
        return LLMResponse(
            text=text,
            model=self.model,
            prompt_tokens=_approx_tokens(system) + _approx_tokens(user),
            completion_tokens=_approx_tokens(text),
            cost=self._cost,
        )


def _approx_tokens(text: str) -> int:
    """Crude deterministic token estimate (~4 chars/token) for mock usage."""
    return max(1, len(text) // 4) if text else 0


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

_LIVE_PROVIDERS: dict[str, Callable[[str, str | None], LLMProvider]] = {
    "anthropic": lambda model, key: AnthropicProvider(model, api_key=key),
    "openai": lambda model, key: OpenAIProvider(model, api_key=key),
    "gemini": lambda model, key: GeminiProvider(model, api_key=key),
}


def get_provider(spec_or_name: Any, config: Any | None = None) -> LLMProvider:
    """Build a provider from a :class:`ModelSpec`-like object or a provider name.

    ``spec_or_name`` may be anything exposing ``.provider`` and ``.model``
    (e.g. ``config.mage_a``) or a bare string such as ``"mock"`` / ``"anthropic"``.
    Returns a (default-scripted) :class:`MockProvider` when the provider is
    ``"mock"``. API keys are pulled from ``config.key_for(provider)`` when a
    config is supplied; otherwise live providers fall back to env vars.
    """
    if hasattr(spec_or_name, "provider") and hasattr(spec_or_name, "model"):
        provider = str(spec_or_name.provider).lower()
        model = str(spec_or_name.model)
    elif isinstance(spec_or_name, str):
        provider = spec_or_name.lower()
        model = ""
    else:
        raise TypeError(f"cannot resolve provider from {spec_or_name!r}")

    if provider == "mock":
        return MockProvider(default="(mock response)", model=model or "mock-model")

    if provider == "claude-cli":
        return ClaudeCliProvider(model or "haiku")

    factory = _LIVE_PROVIDERS.get(provider)
    if factory is None:
        raise ValueError(f"unknown provider {provider!r}")

    key = None
    if config is not None and hasattr(config, "key_for"):
        key = config.key_for(provider)
    return factory(model, key)


__all__ = [
    "LLMResponse",
    "LLMProvider",
    "AnthropicProvider",
    "OpenAIProvider",
    "GeminiProvider",
    "ClaudeCliProvider",
    "MockProvider",
    "get_provider",
    "estimate_cost",
]
