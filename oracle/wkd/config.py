"""Runtime configuration for The Wizard King's Decree.

A :class:`Config` is assembled from three layers (lowest precedence first):

1. Built-in defaults.
2. An optional YAML or JSON file (``load_config(path)``).
3. Environment-variable overrides (``WKD_*`` for structural settings).

API keys (``ANTHROPIC_API_KEY``, ``OPENAI_API_KEY``, ``GEMINI_API_KEY``) are read
from the environment *only* and are **never** persisted: :meth:`Config.to_dict`
deliberately omits them, so a serialized config can be logged safely (SPEC §16).

YAML support is optional and imported lazily — the offline test-suite only ever
uses JSON, so PyYAML is not required to run the tests.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Any

from .models import Domain

# Environment variable names for the secret keys (read, never written).
ENV_ANTHROPIC = "ANTHROPIC_API_KEY"
ENV_OPENAI = "OPENAI_API_KEY"
ENV_GEMINI = "GEMINI_API_KEY"


@dataclass(frozen=True)
class ModelSpec:
    """A provider + model-id pair for one role in the cast (SPEC §3).

    ``provider`` is one of ``anthropic`` / ``openai`` / ``gemini`` / ``mock``.
    Model ids live here (not buried in logic) so they are easy to bump.
    """

    provider: str
    model: str

    @classmethod
    def from_obj(cls, obj: Any) -> "ModelSpec":
        """Build a ModelSpec from a dict ``{provider, model}`` or pass-through."""
        if isinstance(obj, ModelSpec):
            return obj
        if isinstance(obj, dict):
            return cls(provider=str(obj["provider"]), model=str(obj["model"]))
        raise TypeError(f"cannot build ModelSpec from {obj!r}")

    def to_dict(self) -> dict[str, str]:
        return {"provider": self.provider, "model": self.model}


# ---------------------------------------------------------------------------
# Defaults. Bump the model ids here as preferred models change.
# ---------------------------------------------------------------------------

# Council of Mages (SPEC §3): Claude Opus + OpenAI GPT.
DEFAULT_MAGE_A = ModelSpec("anthropic", "claude-opus-4-8")  # Claude Opus 4.8
DEFAULT_MAGE_B = ModelSpec("openai", "gpt-4.1")             # set to current GPT
# The Wizard King is a pure styling pass and may reuse a council model (SPEC §3).
DEFAULT_KING = ModelSpec("anthropic", "claude-opus-4-8")
# The Court Historian MUST be an independent family (Gemini) (SPEC §3, §16.1).
DEFAULT_HISTORIAN = ModelSpec("gemini", "gemini-2.5-pro")   # search-grounded

DEFAULT_DOMAINS: list[str] = [d.value for d in Domain]


@dataclass
class Config:
    """All runtime knobs for the daily driver and its subsystems.

    Secrets are *not* stored in any file this config is serialized to; the
    ``*_api_key`` fields are populated from the environment at load time and
    excluded from :meth:`to_dict`.
    """

    db_path: str = "wkd.db"
    chronicle_out_dir: str = "chronicle"
    chronicle_port: int = 8787

    mage_a: ModelSpec = field(default_factory=lambda: DEFAULT_MAGE_A)
    mage_b: ModelSpec = field(default_factory=lambda: DEFAULT_MAGE_B)
    king: ModelSpec = field(default_factory=lambda: DEFAULT_KING)
    historian: ModelSpec = field(default_factory=lambda: DEFAULT_HISTORIAN)

    domains: list[str] = field(default_factory=lambda: list(DEFAULT_DOMAINS))
    daily_decree_cap: int = 6          # SPEC §17.4: start ~3-8/day
    deliberation_max_rounds: int = 3   # SPEC §5
    checkpoint_interval_days: int = 7  # SPEC §8 (weekly)
    # SPEC §7 free-pick leg: how many matters of his own choosing the King may
    # originate per run from live headlines (0 disables; the King reuses the
    # styling-pass model). Kept small for cost; tracked separately from harvested.
    free_pick_max: int = 3

    # Secrets — env-sourced, never serialized AND never reproduced in the
    # dataclass repr/str (repr=False), so a stray ``print(config)``,
    # ``f"{config}"``, ``logging.info("%s", config)``, or a config captured in a
    # traceback frame can never leak the keys (SPEC §16). ``to_dict`` omits them
    # too; ``key_for`` is the only sanctioned read path.
    anthropic_api_key: str | None = field(default=None, repr=False)
    openai_api_key: str | None = field(default=None, repr=False)
    gemini_api_key: str | None = field(default=None, repr=False)

    def key_for(self, provider: str) -> str | None:
        """Return the API key for a provider name (or ``None`` if unset)."""
        return {
            "anthropic": self.anthropic_api_key,
            "openai": self.openai_api_key,
            "gemini": self.gemini_api_key,
        }.get(provider.lower())

    def to_dict(self) -> dict[str, Any]:
        """Serializable view with **secrets stripped** (safe to log/persist)."""
        return {
            "db_path": self.db_path,
            "chronicle_out_dir": self.chronicle_out_dir,
            "chronicle_port": self.chronicle_port,
            "models": {
                "mage_a": self.mage_a.to_dict(),
                "mage_b": self.mage_b.to_dict(),
                "king": self.king.to_dict(),
                "historian": self.historian.to_dict(),
            },
            "domains": list(self.domains),
            "daily_decree_cap": self.daily_decree_cap,
            "deliberation_max_rounds": self.deliberation_max_rounds,
            "checkpoint_interval_days": self.checkpoint_interval_days,
            "free_pick_max": self.free_pick_max,
        }


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------


def _load_file(path: str | Path) -> dict[str, Any]:
    """Read a YAML/JSON config file into a dict (YAML imported lazily)."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"config file not found: {p}")
    text = p.read_text(encoding="utf-8")
    suffix = p.suffix.lower()
    if suffix == ".json":
        data = json.loads(text)
    elif suffix in (".yaml", ".yml"):
        try:
            import yaml  # lazy: only needed for YAML configs
        except ModuleNotFoundError as exc:  # pragma: no cover - env dependent
            raise RuntimeError(
                "PyYAML is required to read .yaml/.yml config files "
                "(pip install pyyaml), or use a .json config instead."
            ) from exc
        data = yaml.safe_load(text)
    else:
        raise ValueError(f"unsupported config extension {suffix!r} (use .json/.yaml)")
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise ValueError(f"config file {p} must contain a mapping at top level")
    return data


def _env(name: str) -> str | None:
    val = os.environ.get(name)
    return val if val else None


def load_config(path: str | Path | None = None) -> Config:
    """Assemble a :class:`Config` from defaults, an optional file, and the env.

    Precedence (low → high): defaults < file < ``WKD_*`` env overrides.
    Secrets come exclusively from ``ANTHROPIC_API_KEY`` / ``OPENAI_API_KEY`` /
    ``GEMINI_API_KEY`` and are not affected by the file.
    """
    cfg = Config()

    if path is not None:
        data = _load_file(path)
        models = data.get("models", {}) or {}
        cfg = replace(
            cfg,
            db_path=data.get("db_path", cfg.db_path),
            chronicle_out_dir=data.get("chronicle_out_dir", cfg.chronicle_out_dir),
            chronicle_port=int(data.get("chronicle_port", cfg.chronicle_port)),
            mage_a=ModelSpec.from_obj(models["mage_a"]) if "mage_a" in models else cfg.mage_a,
            mage_b=ModelSpec.from_obj(models["mage_b"]) if "mage_b" in models else cfg.mage_b,
            king=ModelSpec.from_obj(models["king"]) if "king" in models else cfg.king,
            historian=(
                ModelSpec.from_obj(models["historian"])
                if "historian" in models
                else cfg.historian
            ),
            domains=list(data.get("domains", cfg.domains)),
            daily_decree_cap=int(data.get("daily_decree_cap", cfg.daily_decree_cap)),
            deliberation_max_rounds=int(
                data.get("deliberation_max_rounds", cfg.deliberation_max_rounds)
            ),
            checkpoint_interval_days=int(
                data.get("checkpoint_interval_days", cfg.checkpoint_interval_days)
            ),
            free_pick_max=int(data.get("free_pick_max", cfg.free_pick_max)),
        )

    # Structural env overrides (WKD_*), highest precedence.
    if (v := _env("WKD_DB_PATH")) is not None:
        cfg.db_path = v
    if (v := _env("WKD_CHRONICLE_DIR")) is not None:
        cfg.chronicle_out_dir = v
    if (v := _env("WKD_CHRONICLE_PORT")) is not None:
        cfg.chronicle_port = int(v)
    if (v := _env("WKD_DAILY_DECREE_CAP")) is not None:
        cfg.daily_decree_cap = int(v)
    if (v := _env("WKD_DELIBERATION_MAX_ROUNDS")) is not None:
        cfg.deliberation_max_rounds = int(v)
    if (v := _env("WKD_CHECKPOINT_INTERVAL_DAYS")) is not None:
        cfg.checkpoint_interval_days = int(v)
    if (v := _env("WKD_FREE_PICK_MAX")) is not None:
        cfg.free_pick_max = int(v)

    # Secrets: env only, never from file.
    cfg.anthropic_api_key = _env(ENV_ANTHROPIC)
    cfg.openai_api_key = _env(ENV_OPENAI)
    cfg.gemini_api_key = _env(ENV_GEMINI)

    return cfg


__all__ = [
    "Config",
    "ModelSpec",
    "load_config",
    "DEFAULT_MAGE_A",
    "DEFAULT_MAGE_B",
    "DEFAULT_KING",
    "DEFAULT_HISTORIAN",
    "DEFAULT_DOMAINS",
    "ENV_ANTHROPIC",
    "ENV_OPENAI",
    "ENV_GEMINI",
]
