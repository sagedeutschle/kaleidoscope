"""Command-line entrypoint for The Wizard King's Decree (SPEC §8, §15).

``python3 -m wkd <subcommand>`` (see :mod:`wkd.__main__`). Subcommands:

* ``init-db``    — create the SQLite schema (idempotent).
* ``run``        — one full idempotent daily pass (harvest → … → publish).
* ``harvest``    — harvest matters from the configured sources only.
* ``deliberate`` — deliberate pending matters into decrees only.
* ``resolve``    — summon the Historian for decrees past their resolution date.
* ``score``      — recompute + persist the metrics snapshot.
* ``publish``    — regenerate the static Chronicle.
* ``serve``      — serve the Chronicle over the tailnet (``http.server``).

Most subcommands accept ``--now ISO8601`` (an injectable clock for deterministic
or back-dated runs) and a global ``--config PATH``. API keys are read from the
environment only (never passed on the command line).
"""

from __future__ import annotations

import argparse
import functools
import json
import sys
from pathlib import Path
from typing import Sequence

from . import chronicle, db, driver, scoring
from .config import Config, load_config


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load(args: argparse.Namespace) -> Config:
    return load_config(getattr(args, "config", None))


def _open(config: Config):
    """Open the configured DB with the schema ensured."""
    conn = db.connect(config.db_path)
    db.init_db(conn)
    return conn


def _emit(obj) -> None:
    print(json.dumps(obj, indent=2, sort_keys=True))


# ---------------------------------------------------------------------------
# Subcommand handlers (return an int exit code)
# ---------------------------------------------------------------------------


def cmd_init_db(args: argparse.Namespace) -> int:
    config = _load(args)
    conn = db.init_db(db.connect(config.db_path))
    tables = db.list_tables(conn)
    conn.close()
    _emit({"db_path": config.db_path, "tables": tables})
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    config = _load(args)
    report = driver.run_daily(config, now=args.now)
    _emit(report.to_dict())
    return 0


def cmd_harvest(args: argparse.Namespace) -> int:
    config = _load(args)
    conn = _open(config)
    try:
        news, market = driver.build_fetchers(config)
        events = driver.harvest_step(
            conn, config, now=args.now, news_fetcher=news, market_client=market
        )
    finally:
        conn.close()
    _emit({"harvested": len(events), "ids": [e.id for e in events]})
    return 0


def cmd_deliberate(args: argparse.Namespace) -> int:
    config = _load(args)
    conn = _open(config)
    try:
        ma, mb, kg, _hist = driver.build_providers(config)
        results = driver.deliberate_step(
            conn, config, mage_a=ma, mage_b=mb, king=kg, now=args.now
        )
    finally:
        conn.close()
    forged = sum(1 for r in results if r.is_consensus)
    _emit(
        {
            "deliberated": len(results),
            "forged": forged,
            "divided": len(results) - forged,
        }
    )
    return 0


def cmd_resolve(args: argparse.Namespace) -> int:
    config = _load(args)
    conn = _open(config)
    try:
        _ma, _mb, _kg, hist = driver.build_providers(config)
        rulings, abstained = driver.resolve_step(
            conn, config, historian_provider=hist, now=args.now
        )
    finally:
        conn.close()
    _emit(
        {
            "resolved": len(rulings),
            "abstained": abstained,
            "verdicts": [str(r.verdict) for r in rulings],
        }
    )
    return 0


def cmd_score(args: argparse.Namespace) -> int:
    config = _load(args)
    conn = _open(config)
    try:
        snapshot = scoring.compute_metrics(conn, now=args.now)
    finally:
        conn.close()
    metrics = json.loads(snapshot.metrics_json)
    _emit(
        {
            "snapshot_id": snapshot.id,
            "computed_at": snapshot.computed_at,
            "hit_rate": metrics.get("hit_rate", {}),
            "counts": metrics.get("counts", {}),
        }
    )
    return 0


def cmd_publish(args: argparse.Namespace) -> int:
    config = _load(args)
    conn = _open(config)
    try:
        files = chronicle.generate(conn, config.chronicle_out_dir, now=args.now)
    finally:
        conn.close()
    _emit({"out_dir": config.chronicle_out_dir, "files": files})
    return 0


def cmd_serve(args: argparse.Namespace) -> int:
    config = _load(args)
    out_dir = Path(config.chronicle_out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    port = args.port if args.port is not None else config.chronicle_port

    # Imported here so a missing index doesn't matter until someone serves.
    import http.server
    import socketserver

    handler = functools.partial(
        http.server.SimpleHTTPRequestHandler, directory=str(out_dir)
    )
    print(
        f"Serving the Chronicle from {out_dir} on http://0.0.0.0:{port} "
        "(Ctrl-C to stop)",
        file=sys.stderr,
    )
    with socketserver.TCPServer(("", port), handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:  # pragma: no cover - interactive
            print("\nThe court is adjourned.", file=sys.stderr)
    return 0


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="wkd",
        description="The Wizard King's Decree — a self-grading model-council "
        "forecasting experiment (SPEC.md).",
    )
    parser.add_argument(
        "--config",
        metavar="PATH",
        default=None,
        help="path to a YAML/JSON config file (env WKD_*/keys still apply)",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    def _add(name: str, handler, *, with_now: bool = False, help_: str = "") -> argparse.ArgumentParser:
        sp = sub.add_parser(name, help=help_)
        if with_now:
            sp.add_argument(
                "--now",
                metavar="ISO8601",
                default=None,
                help="injectable wall-clock (e.g. 2026-06-26T12:00:00Z); defaults to UTC now",
            )
        sp.set_defaults(func=handler)
        return sp

    _add("init-db", cmd_init_db, help_="create the SQLite schema (idempotent)")
    _add("run", cmd_run, with_now=True, help_="one full idempotent daily pass")
    _add("harvest", cmd_harvest, with_now=True, help_="harvest matters from configured sources")
    _add("deliberate", cmd_deliberate, with_now=True, help_="deliberate pending matters into decrees")
    _add("resolve", cmd_resolve, with_now=True, help_="summon the Historian for due decrees")
    _add("score", cmd_score, with_now=True, help_="recompute + persist the metrics snapshot")
    _add("publish", cmd_publish, with_now=True, help_="regenerate the static Chronicle")
    serve_sp = _add("serve", cmd_serve, help_="serve the Chronicle over the tailnet")
    serve_sp.add_argument(
        "--port",
        type=int,
        default=None,
        help="override config.chronicle_port",
    )

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


__all__ = ["main", "build_parser"]
