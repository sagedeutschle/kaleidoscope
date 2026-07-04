"""SQLite persistence layer (SPEC §14).

Eight tables, one per entity in :mod:`wkd.models`, with columns matching SPEC §14
exactly. Rulings and corrections are **append-only** (no update/delete helpers);
decrees are *superseded* (a new row with ``supersedes_id``) rather than edited
(SPEC §16.8). All timestamps are caller-supplied ISO-8601 UTC strings.

Connections are configured with ``sqlite3.Row`` and ``PRAGMA foreign_keys=ON``.

Insert helpers accept a frozen entity (with ``id=None``) and return a *new*
frozen entity with ``id`` populated from ``lastrowid``.
"""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from dataclasses import replace
from pathlib import Path
from typing import Iterator, Union

from .models import (
    Checkpoint,
    Correction,
    Decree,
    DecreeStatus,
    Deliberation,
    Event,
    EventStatus,
    MetricsSnapshot,
    ModelRun,
    Ruling,
)

ConnOrPath = Union[str, Path, sqlite3.Connection]

# ---------------------------------------------------------------------------
# Schema (SPEC §14 columns, verbatim)
# ---------------------------------------------------------------------------

_SCHEMA: tuple[str, ...] = (
    """
    CREATE TABLE IF NOT EXISTS events (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        source               TEXT NOT NULL,
        source_ref           TEXT,
        title                TEXT NOT NULL,
        domain               TEXT NOT NULL,
        description          TEXT,
        resolution_date      TEXT,
        resolution_criteria  TEXT,
        market_implied_prob  REAL,
        harvested_at         TEXT,
        status               TEXT NOT NULL DEFAULT 'pending'
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS decrees (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id           INTEGER NOT NULL REFERENCES events(id),
        issued_at          TEXT,
        claim_text         TEXT NOT NULL,
        regal_text         TEXT,
        direction          TEXT,
        private_confidence REAL,
        consensus_rounds   INTEGER,
        status             TEXT NOT NULL DEFAULT 'standing',
        supersedes_id      INTEGER REFERENCES decrees(id)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS deliberations (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id         INTEGER NOT NULL REFERENCES events(id),
        round            INTEGER NOT NULL,
        model            TEXT NOT NULL,
        draft_claim      TEXT,
        draft_confidence REAL,
        reasoning        TEXT,
        created_at       TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS checkpoints (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        decree_id      INTEGER NOT NULL REFERENCES decrees(id),
        checked_at     TEXT,
        action         TEXT NOT NULL,
        new_confidence REAL,
        notes          TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS rulings (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        decree_id            INTEGER NOT NULL REFERENCES decrees(id),
        ruled_at             TEXT,
        verdict              TEXT NOT NULL,
        historian_model      TEXT,
        evidence_json        TEXT,
        corroborating_sources INTEGER,
        reasoning            TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS corrections (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        ruling_id       INTEGER NOT NULL REFERENCES rulings(id),
        decree_id       INTEGER NOT NULL REFERENCES decrees(id),
        tier            TEXT NOT NULL,
        correction_text TEXT,
        published_at    TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS model_runs (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        component         TEXT NOT NULL,
        model             TEXT NOT NULL,
        prompt_tokens     INTEGER,
        completion_tokens INTEGER,
        cost              REAL,
        latency_ms        INTEGER,
        created_at        TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS metrics_snapshots (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        computed_at  TEXT,
        metrics_json TEXT NOT NULL
    )
    """,
)


# ---------------------------------------------------------------------------
# Connection / schema
# ---------------------------------------------------------------------------


def connect(path: str | Path) -> sqlite3.Connection:
    """Open a connection with row access by name and foreign keys enabled."""
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(target: ConnOrPath) -> sqlite3.Connection:
    """Create all tables (idempotent) and return an open connection.

    ``target`` may be a path (a new connection is opened and returned — use this
    with ``":memory:"`` to keep the schema alive for the test's lifetime) or an
    existing :class:`sqlite3.Connection` (schema is created on it in place).
    """
    conn = target if isinstance(target, sqlite3.Connection) else connect(target)
    for stmt in _SCHEMA:
        conn.execute(stmt)
    conn.commit()
    return conn


@contextmanager
def transaction(conn: sqlite3.Connection) -> Iterator[sqlite3.Connection]:
    """Group several writes into ONE atomic commit (SPEC §16.8 non-destructive).

    Call the insert/update helpers with ``commit=False`` inside the ``with`` block;
    the single commit happens on clean exit and a rollback happens on any
    exception, so a crash mid-sequence leaves the store untouched rather than
    half-written (e.g. a ruling with no matching decree-status advance). Any
    per-call ``commit=True`` write inside the block would defeat the atomicity, so
    keep every write inside ``commit=False``.
    """
    try:
        yield conn
        conn.commit()
    except BaseException:
        conn.rollback()
        raise


# ---------------------------------------------------------------------------
# Row -> entity mappers
# ---------------------------------------------------------------------------


def _row_to_event(r: sqlite3.Row) -> Event:
    return Event(
        id=r["id"],
        source=r["source"],
        source_ref=r["source_ref"],
        title=r["title"],
        domain=r["domain"],
        description=r["description"] or "",
        resolution_date=r["resolution_date"],
        resolution_criteria=r["resolution_criteria"] or "",
        market_implied_prob=r["market_implied_prob"],
        harvested_at=r["harvested_at"],
        status=r["status"],
    )


def _row_to_decree(r: sqlite3.Row) -> Decree:
    return Decree(
        id=r["id"],
        event_id=r["event_id"],
        issued_at=r["issued_at"],
        claim_text=r["claim_text"],
        regal_text=r["regal_text"] or "",
        direction=r["direction"] or "",
        private_confidence=r["private_confidence"] if r["private_confidence"] is not None else 0.0,
        consensus_rounds=r["consensus_rounds"] if r["consensus_rounds"] is not None else 0,
        status=r["status"],
        supersedes_id=r["supersedes_id"],
    )


def _row_to_deliberation(r: sqlite3.Row) -> Deliberation:
    return Deliberation(
        id=r["id"],
        event_id=r["event_id"],
        round=r["round"],
        model=r["model"],
        draft_claim=r["draft_claim"] or "",
        draft_confidence=r["draft_confidence"] if r["draft_confidence"] is not None else 0.0,
        reasoning=r["reasoning"] or "",
        created_at=r["created_at"],
    )


def _row_to_checkpoint(r: sqlite3.Row) -> Checkpoint:
    return Checkpoint(
        id=r["id"],
        decree_id=r["decree_id"],
        checked_at=r["checked_at"],
        action=r["action"],
        new_confidence=r["new_confidence"],
        notes=r["notes"] or "",
    )


def _row_to_ruling(r: sqlite3.Row) -> Ruling:
    return Ruling(
        id=r["id"],
        decree_id=r["decree_id"],
        ruled_at=r["ruled_at"],
        verdict=r["verdict"],
        historian_model=r["historian_model"] or "",
        evidence_json=r["evidence_json"] or "",
        corroborating_sources=r["corroborating_sources"] if r["corroborating_sources"] is not None else 0,
        reasoning=r["reasoning"] or "",
    )


def _row_to_correction(r: sqlite3.Row) -> Correction:
    return Correction(
        id=r["id"],
        ruling_id=r["ruling_id"],
        decree_id=r["decree_id"],
        tier=r["tier"],
        correction_text=r["correction_text"] or "",
        published_at=r["published_at"],
    )


def _row_to_model_run(r: sqlite3.Row) -> ModelRun:
    return ModelRun(
        id=r["id"],
        component=r["component"],
        model=r["model"],
        prompt_tokens=r["prompt_tokens"] if r["prompt_tokens"] is not None else 0,
        completion_tokens=r["completion_tokens"] if r["completion_tokens"] is not None else 0,
        cost=r["cost"] if r["cost"] is not None else 0.0,
        latency_ms=r["latency_ms"] if r["latency_ms"] is not None else 0,
        created_at=r["created_at"],
    )


def _row_to_metrics(r: sqlite3.Row) -> MetricsSnapshot:
    return MetricsSnapshot(
        id=r["id"],
        computed_at=r["computed_at"],
        metrics_json=r["metrics_json"],
    )


# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------


def insert_event(conn: sqlite3.Connection, event: Event) -> Event:
    cur = conn.execute(
        """INSERT INTO events
           (source, source_ref, title, domain, description, resolution_date,
            resolution_criteria, market_implied_prob, harvested_at, status)
           VALUES (?,?,?,?,?,?,?,?,?,?)""",
        (
            str(event.source),
            event.source_ref,
            event.title,
            str(event.domain),
            event.description,
            event.resolution_date,
            event.resolution_criteria,
            event.market_implied_prob,
            event.harvested_at,
            str(event.status),
        ),
    )
    conn.commit()
    return replace(event, id=cur.lastrowid)


def get_event(conn: sqlite3.Connection, event_id: int) -> Event | None:
    r = conn.execute("SELECT * FROM events WHERE id=?", (event_id,)).fetchone()
    return _row_to_event(r) if r else None


def list_events(
    conn: sqlite3.Connection,
    status: str | None = None,
    source: str | None = None,
) -> list[Event]:
    sql = "SELECT * FROM events"
    clauses: list[str] = []
    params: list[object] = []
    if status is not None:
        clauses.append("status=?")
        params.append(str(status))
    if source is not None:
        clauses.append("source=?")
        params.append(str(source))
    if clauses:
        sql += " WHERE " + " AND ".join(clauses)
    sql += " ORDER BY id"
    return [_row_to_event(r) for r in conn.execute(sql, params).fetchall()]


def update_event_status(
    conn: sqlite3.Connection, event_id: int, status: str, *, commit: bool = True
) -> None:
    conn.execute("UPDATE events SET status=? WHERE id=?", (str(status), event_id))
    if commit:
        conn.commit()


# ---------------------------------------------------------------------------
# decrees
# ---------------------------------------------------------------------------


def insert_decree(conn: sqlite3.Connection, decree: Decree, *, commit: bool = True) -> Decree:
    cur = conn.execute(
        """INSERT INTO decrees
           (event_id, issued_at, claim_text, regal_text, direction,
            private_confidence, consensus_rounds, status, supersedes_id)
           VALUES (?,?,?,?,?,?,?,?,?)""",
        (
            decree.event_id,
            decree.issued_at,
            decree.claim_text,
            decree.regal_text,
            decree.direction,
            decree.private_confidence,
            decree.consensus_rounds,
            str(decree.status),
            decree.supersedes_id,
        ),
    )
    if commit:
        conn.commit()
    return replace(decree, id=cur.lastrowid)


def get_decree(conn: sqlite3.Connection, decree_id: int) -> Decree | None:
    r = conn.execute("SELECT * FROM decrees WHERE id=?", (decree_id,)).fetchone()
    return _row_to_decree(r) if r else None


def list_decrees(conn: sqlite3.Connection, status: str | None = None) -> list[Decree]:
    sql = "SELECT * FROM decrees"
    params: list[object] = []
    if status is not None:
        sql += " WHERE status=?"
        params.append(str(status))
    sql += " ORDER BY id"
    return [_row_to_decree(r) for r in conn.execute(sql, params).fetchall()]


def list_standing_decrees(conn: sqlite3.Connection) -> list[Decree]:
    return list_decrees(conn, status=DecreeStatus.STANDING)


def list_decrees_due(conn: sqlite3.Connection, now: str) -> list[Decree]:
    """Standing decrees whose event's ``resolution_date`` has passed (<= now).

    ``now`` is an ISO-8601 UTC string; comparison is lexicographic, which is
    correct for fixed-format ISO-8601 timestamps.
    """
    rows = conn.execute(
        """SELECT d.* FROM decrees d
           JOIN events e ON e.id = d.event_id
           WHERE d.status=? AND e.resolution_date IS NOT NULL
             AND e.resolution_date <= ?
           ORDER BY e.resolution_date, d.id""",
        (str(DecreeStatus.STANDING), now),
    ).fetchall()
    return [_row_to_decree(r) for r in rows]


def update_decree_status(
    conn: sqlite3.Connection, decree_id: int, status: str, *, commit: bool = True
) -> None:
    conn.execute("UPDATE decrees SET status=? WHERE id=?", (str(status), decree_id))
    if commit:
        conn.commit()


# ---------------------------------------------------------------------------
# deliberations
# ---------------------------------------------------------------------------


def insert_deliberation(conn: sqlite3.Connection, d: Deliberation) -> Deliberation:
    cur = conn.execute(
        """INSERT INTO deliberations
           (event_id, round, model, draft_claim, draft_confidence, reasoning, created_at)
           VALUES (?,?,?,?,?,?,?)""",
        (
            d.event_id,
            d.round,
            d.model,
            d.draft_claim,
            d.draft_confidence,
            d.reasoning,
            d.created_at,
        ),
    )
    conn.commit()
    return replace(d, id=cur.lastrowid)


def list_deliberations(conn: sqlite3.Connection, event_id: int) -> list[Deliberation]:
    rows = conn.execute(
        "SELECT * FROM deliberations WHERE event_id=? ORDER BY round, id",
        (event_id,),
    ).fetchall()
    return [_row_to_deliberation(r) for r in rows]


# ---------------------------------------------------------------------------
# checkpoints
# ---------------------------------------------------------------------------


def insert_checkpoint(
    conn: sqlite3.Connection, c: Checkpoint, *, commit: bool = True
) -> Checkpoint:
    cur = conn.execute(
        """INSERT INTO checkpoints
           (decree_id, checked_at, action, new_confidence, notes)
           VALUES (?,?,?,?,?)""",
        (c.decree_id, c.checked_at, str(c.action), c.new_confidence, c.notes),
    )
    if commit:
        conn.commit()
    return replace(c, id=cur.lastrowid)


def list_checkpoints(conn: sqlite3.Connection, decree_id: int) -> list[Checkpoint]:
    rows = conn.execute(
        "SELECT * FROM checkpoints WHERE decree_id=? ORDER BY checked_at, id",
        (decree_id,),
    ).fetchall()
    return [_row_to_checkpoint(r) for r in rows]


def last_checkpoint(conn: sqlite3.Connection, decree_id: int) -> Checkpoint | None:
    r = conn.execute(
        "SELECT * FROM checkpoints WHERE decree_id=? ORDER BY checked_at DESC, id DESC LIMIT 1",
        (decree_id,),
    ).fetchone()
    return _row_to_checkpoint(r) if r else None


# ---------------------------------------------------------------------------
# rulings (append-only)
# ---------------------------------------------------------------------------


def insert_ruling(conn: sqlite3.Connection, r: Ruling, *, commit: bool = True) -> Ruling:
    cur = conn.execute(
        """INSERT INTO rulings
           (decree_id, ruled_at, verdict, historian_model, evidence_json,
            corroborating_sources, reasoning)
           VALUES (?,?,?,?,?,?,?)""",
        (
            r.decree_id,
            r.ruled_at,
            str(r.verdict),
            r.historian_model,
            r.evidence_json,
            r.corroborating_sources,
            r.reasoning,
        ),
    )
    if commit:
        conn.commit()
    return replace(r, id=cur.lastrowid)


def get_ruling(conn: sqlite3.Connection, ruling_id: int) -> Ruling | None:
    row = conn.execute("SELECT * FROM rulings WHERE id=?", (ruling_id,)).fetchone()
    return _row_to_ruling(row) if row else None


def list_rulings(conn: sqlite3.Connection, decree_id: int | None = None) -> list[Ruling]:
    sql = "SELECT * FROM rulings"
    params: list[object] = []
    if decree_id is not None:
        sql += " WHERE decree_id=?"
        params.append(decree_id)
    sql += " ORDER BY id"
    return [_row_to_ruling(r) for r in conn.execute(sql, params).fetchall()]


# ---------------------------------------------------------------------------
# corrections (append-only)
# ---------------------------------------------------------------------------


def insert_correction(
    conn: sqlite3.Connection, c: Correction, *, commit: bool = True
) -> Correction:
    cur = conn.execute(
        """INSERT INTO corrections
           (ruling_id, decree_id, tier, correction_text, published_at)
           VALUES (?,?,?,?,?)""",
        (c.ruling_id, c.decree_id, str(c.tier), c.correction_text, c.published_at),
    )
    if commit:
        conn.commit()
    return replace(c, id=cur.lastrowid)


def list_corrections(conn: sqlite3.Connection, decree_id: int | None = None) -> list[Correction]:
    sql = "SELECT * FROM corrections"
    params: list[object] = []
    if decree_id is not None:
        sql += " WHERE decree_id=?"
        params.append(decree_id)
    sql += " ORDER BY id"
    return [_row_to_correction(r) for r in conn.execute(sql, params).fetchall()]


# ---------------------------------------------------------------------------
# model_runs (cost/usage audit)
# ---------------------------------------------------------------------------


def insert_model_run(conn: sqlite3.Connection, m: ModelRun) -> ModelRun:
    cur = conn.execute(
        """INSERT INTO model_runs
           (component, model, prompt_tokens, completion_tokens, cost, latency_ms, created_at)
           VALUES (?,?,?,?,?,?,?)""",
        (
            m.component,
            m.model,
            m.prompt_tokens,
            m.completion_tokens,
            m.cost,
            m.latency_ms,
            m.created_at,
        ),
    )
    conn.commit()
    return replace(m, id=cur.lastrowid)


def list_model_runs(conn: sqlite3.Connection, component: str | None = None) -> list[ModelRun]:
    sql = "SELECT * FROM model_runs"
    params: list[object] = []
    if component is not None:
        sql += " WHERE component=?"
        params.append(component)
    sql += " ORDER BY id"
    return [_row_to_model_run(r) for r in conn.execute(sql, params).fetchall()]


# ---------------------------------------------------------------------------
# metrics_snapshots
# ---------------------------------------------------------------------------


def insert_metrics_snapshot(conn: sqlite3.Connection, m: MetricsSnapshot) -> MetricsSnapshot:
    cur = conn.execute(
        "INSERT INTO metrics_snapshots (computed_at, metrics_json) VALUES (?,?)",
        (m.computed_at, m.metrics_json),
    )
    conn.commit()
    return replace(m, id=cur.lastrowid)


def latest_metrics(conn: sqlite3.Connection) -> MetricsSnapshot | None:
    r = conn.execute(
        "SELECT * FROM metrics_snapshots ORDER BY computed_at DESC, id DESC LIMIT 1"
    ).fetchone()
    return _row_to_metrics(r) if r else None


def list_tables(conn: sqlite3.Connection) -> list[str]:
    """Return user table names (handy for tests / introspection)."""
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    ).fetchall()
    return [r["name"] for r in rows]


__all__ = [
    "connect",
    "init_db",
    "transaction",
    "list_tables",
    "insert_event",
    "get_event",
    "list_events",
    "update_event_status",
    "insert_decree",
    "get_decree",
    "list_decrees",
    "list_standing_decrees",
    "list_decrees_due",
    "update_decree_status",
    "insert_deliberation",
    "list_deliberations",
    "insert_checkpoint",
    "list_checkpoints",
    "last_checkpoint",
    "insert_ruling",
    "get_ruling",
    "list_rulings",
    "insert_correction",
    "list_corrections",
    "insert_model_run",
    "list_model_runs",
    "insert_metrics_snapshot",
    "latest_metrics",
]
