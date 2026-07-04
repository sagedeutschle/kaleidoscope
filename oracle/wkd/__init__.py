"""The Wizard King's Decree — a self-grading model-council forecasting experiment.

This package implements SPEC.md. The Foundation layer (``config``, ``models``,
``db``, ``providers``) defines the frozen public API that every downstream
module (``harvester``, ``council``, ``historian``, ``scoring``, ``chronicle``,
``driver``, ``cli``) builds against.
"""

from __future__ import annotations

from .config import (
    Config,
    ModelSpec,
    load_config,
)
from .models import (
    Checkpoint,
    CheckpointAction,
    Correction,
    Decree,
    DecreeStatus,
    Deliberation,
    Domain,
    Event,
    EventStatus,
    HARSH_TIERS,
    MetricsSnapshot,
    ModelRun,
    Ruling,
    Source,
    TIER_TO_DECREE_STATUS,
    Tier,
    Verdict,
)
from .providers import (
    AnthropicProvider,
    GeminiProvider,
    LLMProvider,
    LLMResponse,
    MockProvider,
    OpenAIProvider,
    get_provider,
)

__version__ = "0.1.0"

__all__ = [
    "__version__",
    # config
    "Config",
    "ModelSpec",
    "load_config",
    # models — entities
    "Event",
    "Decree",
    "Deliberation",
    "Checkpoint",
    "Ruling",
    "Correction",
    "ModelRun",
    "MetricsSnapshot",
    # models — vocabularies
    "EventStatus",
    "DecreeStatus",
    "Tier",
    "Verdict",
    "Source",
    "Domain",
    "CheckpointAction",
    "TIER_TO_DECREE_STATUS",
    "HARSH_TIERS",
    # providers
    "LLMResponse",
    "LLMProvider",
    "AnthropicProvider",
    "OpenAIProvider",
    "GeminiProvider",
    "MockProvider",
    "get_provider",
]
