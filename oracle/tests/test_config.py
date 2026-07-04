"""Offline tests for wkd.config (defaults, env, JSON file, secret handling)."""

import json
import os
import tempfile
import unittest
from pathlib import Path

from wkd.config import (
    DEFAULT_HISTORIAN,
    DEFAULT_MAGE_A,
    Config,
    ModelSpec,
    load_config,
)
from wkd.models import Domain

_KEYS = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY")
_WKD = (
    "WKD_DB_PATH",
    "WKD_CHRONICLE_DIR",
    "WKD_CHRONICLE_PORT",
    "WKD_DAILY_DECREE_CAP",
    "WKD_DELIBERATION_MAX_ROUNDS",
    "WKD_CHECKPOINT_INTERVAL_DAYS",
    "WKD_FREE_PICK_MAX",
)


class ConfigTest(unittest.TestCase):
    def setUp(self):
        # Snapshot and clear all env vars this module touches.
        self._saved = {k: os.environ.get(k) for k in (*_KEYS, *_WKD)}
        for k in (*_KEYS, *_WKD):
            os.environ.pop(k, None)

    def tearDown(self):
        for k, v in self._saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def test_defaults(self):
        cfg = load_config()
        self.assertEqual(cfg.daily_decree_cap, 6)
        self.assertEqual(cfg.deliberation_max_rounds, 3)
        self.assertEqual(cfg.checkpoint_interval_days, 7)
        self.assertEqual(cfg.free_pick_max, 3)  # SPEC §7 free-pick leg (active)
        self.assertEqual(cfg.chronicle_port, 8787)
        self.assertEqual(cfg.mage_a, DEFAULT_MAGE_A)
        self.assertEqual(cfg.historian.provider, "gemini")
        # domains default to the full reasoning-favored set
        self.assertEqual(cfg.domains, [d.value for d in Domain])
        self.assertIn("current-events", cfg.domains)

    def test_keys_from_env_only(self):
        os.environ["ANTHROPIC_API_KEY"] = "sk-ant-xyz"
        os.environ["OPENAI_API_KEY"] = "sk-oai-xyz"
        os.environ["GEMINI_API_KEY"] = "g-xyz"
        cfg = load_config()
        self.assertEqual(cfg.anthropic_api_key, "sk-ant-xyz")
        self.assertEqual(cfg.openai_api_key, "sk-oai-xyz")
        self.assertEqual(cfg.gemini_api_key, "g-xyz")
        self.assertEqual(cfg.key_for("anthropic"), "sk-ant-xyz")
        self.assertEqual(cfg.key_for("gemini"), "g-xyz")

    def test_to_dict_strips_secrets(self):
        os.environ["ANTHROPIC_API_KEY"] = "sk-ant-secret"
        cfg = load_config()
        d = cfg.to_dict()
        flat = json.dumps(d)
        self.assertNotIn("sk-ant-secret", flat)
        self.assertNotIn("api_key", flat)
        # structural fields are present
        self.assertEqual(d["daily_decree_cap"], 6)
        self.assertEqual(d["models"]["historian"]["provider"], "gemini")

    def test_repr_and_str_never_leak_secrets(self):
        # The default dataclass repr/str must NOT reproduce any key, so a stray
        # print/log/f-string or a config captured in a traceback can't leak them.
        os.environ["ANTHROPIC_API_KEY"] = "ant-SECRET-aaa"
        os.environ["OPENAI_API_KEY"] = "oai-SECRET-bbb"
        os.environ["GEMINI_API_KEY"] = "gem-SECRET-ccc"
        cfg = load_config()
        # sanity: the keys really are loaded (so this isn't vacuously true)
        self.assertEqual(cfg.gemini_api_key, "gem-SECRET-ccc")
        for rendered in (repr(cfg), str(cfg), f"{cfg}", "%s" % (cfg,)):
            self.assertNotIn("SECRET", rendered)
            self.assertNotIn("ant-SECRET-aaa", rendered)
            self.assertNotIn("oai-SECRET-bbb", rendered)
            self.assertNotIn("gem-SECRET-ccc", rendered)
        # the non-secret structure is still visible for debugging
        self.assertIn("daily_decree_cap", repr(cfg))

    def test_json_file_overrides(self):
        payload = {
            "db_path": "/tmp/wkd-test.db",
            "chronicle_port": 9001,
            "daily_decree_cap": 4,
            "domains": ["politics", "econ"],
            "models": {
                "mage_b": {"provider": "openai", "model": "gpt-5-mini"},
                "historian": {"provider": "gemini", "model": "gemini-3-pro"},
            },
        }
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "cfg.json"
            p.write_text(json.dumps(payload), encoding="utf-8")
            cfg = load_config(p)
        self.assertEqual(cfg.db_path, "/tmp/wkd-test.db")
        self.assertEqual(cfg.chronicle_port, 9001)
        self.assertEqual(cfg.daily_decree_cap, 4)
        self.assertEqual(cfg.domains, ["politics", "econ"])
        self.assertEqual(cfg.mage_b, ModelSpec("openai", "gpt-5-mini"))
        self.assertEqual(cfg.historian, ModelSpec("gemini", "gemini-3-pro"))
        # unset roles keep their defaults
        self.assertEqual(cfg.mage_a, DEFAULT_MAGE_A)

    def test_env_overrides_file(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "cfg.json"
            p.write_text(json.dumps({"daily_decree_cap": 4}), encoding="utf-8")
            os.environ["WKD_DAILY_DECREE_CAP"] = "8"
            os.environ["WKD_CHRONICLE_PORT"] = "7000"
            cfg = load_config(p)
        self.assertEqual(cfg.daily_decree_cap, 8)
        self.assertEqual(cfg.chronicle_port, 7000)

    def test_free_pick_max_file_and_env(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "cfg.json"
            p.write_text(json.dumps({"free_pick_max": 5}), encoding="utf-8")
            cfg = load_config(p)
            self.assertEqual(cfg.free_pick_max, 5)
            self.assertEqual(cfg.to_dict()["free_pick_max"], 5)
            os.environ["WKD_FREE_PICK_MAX"] = "0"
            cfg = load_config(p)
        self.assertEqual(cfg.free_pick_max, 0)  # env disables free-pick

    def test_unknown_extension_raises(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "cfg.toml"
            p.write_text("x = 1", encoding="utf-8")
            with self.assertRaises(ValueError):
                load_config(p)

    def test_missing_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            load_config("/no/such/path/cfg.json")

    def test_yaml_lazy_behaviour(self):
        # YAML support is optional and imported lazily. If PyYAML is absent
        # (the offline default), loading a .yaml must raise a helpful error;
        # if it happens to be installed, loading must succeed.
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "cfg.yaml"
            p.write_text("daily_decree_cap: 5\n", encoding="utf-8")
            try:
                import yaml  # noqa: F401
                have_yaml = True
            except ModuleNotFoundError:
                have_yaml = False
            if have_yaml:
                cfg = load_config(p)
                self.assertEqual(cfg.daily_decree_cap, 5)
            else:
                with self.assertRaises(RuntimeError):
                    load_config(p)


if __name__ == "__main__":
    unittest.main()
