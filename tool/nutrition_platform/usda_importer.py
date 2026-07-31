#!/usr/bin/env python3
"""BIL USDA resumable raw/master staging importer.

Streams FoodData Central CSV members directly from ZIP archives into a SQLite
staging database. It is intentionally source-neutral at the application boundary
and does not build a mobile catalog or integrate with Flutter.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import signal
import sqlite3
import sys
import time
import tracemalloc
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Iterable, Iterator, Sequence

SCHEMA_VERSION = 1
IMPORTER_VERSION = "1.0.1"
DEFAULT_BATCH_SIZE = 2_000

STAGE_ORDER: tuple[str, ...] = (
    "foundation",
    "legacy",
    "branded",
    "foods",
    "nutrients",
    "portions",
    "relationships",
    "indexes",
)

DATASET_HINTS = {
    "foundation": "foundation",
    "sr_legacy": "legacy",
    "branded": "branded",
}

FOOD_MEMBERS = {"food.csv", "foundation_food.csv", "sr_legacy_food.csv", "branded_food.csv"}
NUTRIENT_MEMBERS = {
    "nutrient.csv",
    "food_nutrient.csv",
    "food_nutrient_source.csv",
    "food_nutrient_derivation.csv",
    "lab_method_nutrient.csv",
}
PORTION_MEMBERS = {"food_portion.csv", "measure_unit.csv"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest()


def detect_dataset(path: Path) -> str:
    name = path.name.lower()
    for marker, dataset in DATASET_HINTS.items():
        if marker in name:
            return dataset
    raise ValueError(f"Unable to classify USDA archive: {path.name}")


def member_basename(member: str) -> str:
    return member.rsplit("/", 1)[-1]


def classify_member(dataset: str, member: str) -> str:
    base = member_basename(member).lower()
    if not base.endswith(".csv"):
        return "ignore"
    if dataset == "foundation" and base in {"foundation_food.csv", "sample_food.csv", "sub_sample_food.csv"}:
        return "foundation"
    if dataset == "legacy" and base == "sr_legacy_food.csv":
        return "legacy"
    if dataset == "branded" and base == "branded_food.csv":
        return "branded"
    if base in FOOD_MEMBERS:
        return "foods"
    if base in NUTRIENT_MEMBERS:
        return "nutrients"
    if base in PORTION_MEMBERS:
        return "portions"
    return "relationships"


@dataclass(frozen=True)
class SourceArchive:
    dataset: str
    path: Path
    sha256: str
    size_bytes: int


@dataclass
class MemberProgress:
    dataset: str
    member: str
    stage: str
    rows_read: int = 0
    rows_accepted: int = 0
    rows_rejected: int = 0
    resumed_from_row: int = 0
    elapsed_seconds: float = 0.0
    peak_memory_bytes: int = 0

    @property
    def rows_per_second(self) -> float:
        return self.rows_read / self.elapsed_seconds if self.elapsed_seconds else 0.0


class StopController:
    def __init__(self) -> None:
        self.requested = False
        self._previous: dict[int, object] = {}

    def install(self) -> None:
        for signum in (signal.SIGINT, signal.SIGTERM):
            try:
                self._previous[signum] = signal.getsignal(signum)
                signal.signal(signum, self._handler)
            except (ValueError, OSError):
                pass

    def restore(self) -> None:
        for signum, handler in self._previous.items():
            try:
                signal.signal(signum, handler)
            except (ValueError, OSError):
                pass

    def _handler(self, _signum: int, _frame: object) -> None:
        self.requested = True


class StagingDatabase:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._closed = False
        self.conn = sqlite3.connect(path)
        self.conn.execute("PRAGMA foreign_keys = ON")
        self.conn.execute("PRAGMA journal_mode = WAL")
        self.conn.execute("PRAGMA synchronous = NORMAL")
        self.conn.execute("PRAGMA temp_store = MEMORY")
        self.initialize()

    def initialize(self) -> None:
        self.conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS build_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS source_archive (
                dataset TEXT PRIMARY KEY,
                path TEXT NOT NULL,
                sha256 TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                registered_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS import_stage (
                stage TEXT PRIMARY KEY,
                ordinal INTEGER NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('pending','running','completed','failed','interrupted')),
                started_at TEXT,
                completed_at TEXT,
                error_message TEXT
            );
            CREATE TABLE IF NOT EXISTS import_checkpoint (
                dataset TEXT NOT NULL,
                member_name TEXT NOT NULL,
                stage TEXT NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('pending','running','completed','failed','interrupted')),
                header_json TEXT,
                last_row_number INTEGER NOT NULL DEFAULT 0,
                rows_read INTEGER NOT NULL DEFAULT 0,
                rows_accepted INTEGER NOT NULL DEFAULT 0,
                rows_rejected INTEGER NOT NULL DEFAULT 0,
                elapsed_seconds REAL NOT NULL DEFAULT 0,
                peak_memory_bytes INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL,
                error_message TEXT,
                PRIMARY KEY(dataset, member_name)
            );
            CREATE TABLE IF NOT EXISTS raw_record (
                dataset TEXT NOT NULL,
                member_name TEXT NOT NULL,
                source_row_number INTEGER NOT NULL,
                stage TEXT NOT NULL,
                source_id TEXT,
                payload_json TEXT NOT NULL,
                imported_at TEXT NOT NULL,
                PRIMARY KEY(dataset, member_name, source_row_number)
            );
            """
        )
        self.conn.execute(
            "INSERT OR REPLACE INTO build_metadata(key,value) VALUES('schema_version',?)",
            (str(SCHEMA_VERSION),),
        )
        self.conn.execute(
            "INSERT OR REPLACE INTO build_metadata(key,value) VALUES('importer_version',?)",
            (IMPORTER_VERSION,),
        )
        for ordinal, stage in enumerate(STAGE_ORDER):
            self.conn.execute(
                "INSERT OR IGNORE INTO import_stage(stage,ordinal,status) VALUES(?,?, 'pending')",
                (stage, ordinal),
            )
        self.conn.commit()

    def register_source(self, source: SourceArchive) -> None:
        existing = self.conn.execute(
            "SELECT sha256 FROM source_archive WHERE dataset=?", (source.dataset,)
        ).fetchone()
        if existing and existing[0] != source.sha256:
            completed = self.conn.execute(
                "SELECT COUNT(*) FROM import_checkpoint WHERE dataset=? AND last_row_number>0",
                (source.dataset,),
            ).fetchone()[0]
            if completed:
                raise RuntimeError(
                    f"Source archive changed for {source.dataset}; use a new staging database or reset that dataset"
                )
        self.conn.execute(
            """INSERT INTO source_archive(dataset,path,sha256,size_bytes,registered_at)
               VALUES(?,?,?,?,?)
               ON CONFLICT(dataset) DO UPDATE SET path=excluded.path,size_bytes=excluded.size_bytes""",
            (source.dataset, str(source.path), source.sha256, source.size_bytes, utc_now()),
        )
        self.conn.commit()

    def checkpoint(self, dataset: str, member: str) -> sqlite3.Row | None:
        self.conn.row_factory = sqlite3.Row
        row = self.conn.execute(
            "SELECT * FROM import_checkpoint WHERE dataset=? AND member_name=?",
            (dataset, member),
        ).fetchone()
        self.conn.row_factory = None
        return row

    def start_member(self, dataset: str, member: str, stage: str, header: Sequence[str], resume_row: int) -> None:
        now = utc_now()
        self.conn.execute(
            "UPDATE import_stage SET status='running', started_at=COALESCE(started_at,?), error_message=NULL WHERE stage=?",
            (now, stage),
        )
        self.conn.execute(
            """INSERT INTO import_checkpoint(
                   dataset,member_name,stage,status,header_json,last_row_number,updated_at)
               VALUES(?,?,?,'running',?,?,?)
               ON CONFLICT(dataset,member_name) DO UPDATE SET
                   stage=excluded.stage,status='running',header_json=excluded.header_json,
                   updated_at=excluded.updated_at,error_message=NULL""",
            (dataset, member, stage, json.dumps(list(header), ensure_ascii=False), resume_row, now),
        )
        self.conn.commit()

    def save_batch(self, rows: Sequence[tuple[str, str, int, str, str | None, str, str]], progress: MemberProgress) -> None:
        with self.conn:
            self.conn.executemany(
                """INSERT OR IGNORE INTO raw_record(
                       dataset,member_name,source_row_number,stage,source_id,payload_json,imported_at)
                   VALUES(?,?,?,?,?,?,?)""",
                rows,
            )
            self.conn.execute(
                """UPDATE import_checkpoint SET status='running',last_row_number=?,rows_read=?,
                   rows_accepted=?,rows_rejected=?,elapsed_seconds=?,peak_memory_bytes=?,updated_at=?
                   WHERE dataset=? AND member_name=?""",
                (
                    progress.rows_read,
                    progress.rows_read,
                    progress.rows_accepted,
                    progress.rows_rejected,
                    progress.elapsed_seconds,
                    progress.peak_memory_bytes,
                    utc_now(),
                    progress.dataset,
                    progress.member,
                ),
            )

    def finish_member(self, progress: MemberProgress, status: str, error: str | None = None) -> None:
        with self.conn:
            self.conn.execute(
                """UPDATE import_checkpoint SET status=?,last_row_number=?,rows_read=?,rows_accepted=?,
                   rows_rejected=?,elapsed_seconds=?,peak_memory_bytes=?,updated_at=?,error_message=?
                   WHERE dataset=? AND member_name=?""",
                (
                    status,
                    progress.rows_read,
                    progress.rows_read,
                    progress.rows_accepted,
                    progress.rows_rejected,
                    progress.elapsed_seconds,
                    progress.peak_memory_bytes,
                    utc_now(),
                    error,
                    progress.dataset,
                    progress.member,
                ),
            )

    def refresh_stage_statuses(self) -> None:
        with self.conn:
            for stage in STAGE_ORDER[:-1]:
                stats = self.conn.execute(
                    "SELECT COUNT(*), SUM(status='completed') FROM import_checkpoint WHERE stage=?",
                    (stage,),
                ).fetchone()
                total, complete = stats[0], stats[1] or 0
                if total and total == complete:
                    self.conn.execute(
                        "UPDATE import_stage SET status='completed', completed_at=?, error_message=NULL WHERE stage=?",
                        (utc_now(), stage),
                    )

    def build_indexes(self) -> None:
        self.conn.execute(
            "UPDATE import_stage SET status='running',started_at=COALESCE(started_at,?) WHERE stage='indexes'",
            (utc_now(),),
        )
        self.conn.executescript(
            """
            CREATE INDEX IF NOT EXISTS idx_raw_record_stage ON raw_record(stage);
            CREATE INDEX IF NOT EXISTS idx_raw_record_source_id ON raw_record(dataset, source_id);
            CREATE INDEX IF NOT EXISTS idx_checkpoint_status ON import_checkpoint(status);
            """
        )
        self.conn.execute(
            "UPDATE import_stage SET status='completed',completed_at=? WHERE stage='indexes'",
            (utc_now(),),
        )
        self.conn.commit()

    def write_report(self, report_path: Path, result: dict[str, object]) -> None:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")

    def verify_integrity(self) -> dict[str, object]:
        integrity = self.conn.execute("PRAGMA integrity_check").fetchone()[0]
        foreign_keys = self.conn.execute("PRAGMA foreign_key_check").fetchall()
        counts = {
            row[0]: row[1]
            for row in self.conn.execute("SELECT dataset,COUNT(*) FROM raw_record GROUP BY dataset")
        }
        incomplete = self.conn.execute(
            "SELECT dataset,member_name,status FROM import_checkpoint WHERE status!='completed'"
        ).fetchall()
        return {
            "integrity_check": integrity,
            "foreign_key_violations": len(foreign_keys),
            "raw_record_counts": counts,
            "incomplete_members": [list(row) for row in incomplete],
        }

    def close(self) -> None:
        if self._closed:
            return
        try:
            self.conn.commit()
            # Ensure WAL/SHM state is flushed before Windows test cleanup removes
            # the temporary database directory. This is safe even when WAL has
            # no pending frames.
            self.conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchall()
        finally:
            self.conn.close()
            self._closed = True

    def __enter__(self) -> "StagingDatabase":
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.close()


def row_source_id(row: dict[str, str]) -> str | None:
    for key in ("fdc_id", "id", "gtin_upc", "ndb_number"):
        value = row.get(key)
        if value:
            return value.strip()
    return None


def archive_members(source: SourceArchive) -> list[str]:
    with zipfile.ZipFile(source.path) as archive:
        return sorted(
            info.filename
            for info in archive.infolist()
            if not info.is_dir() and info.filename.lower().endswith(".csv")
        )


def inspect_archives(paths: Sequence[Path]) -> dict[str, object]:
    datasets: dict[str, object] = {}
    for path in paths:
        dataset = detect_dataset(path)
        digest = sha256_file(path)
        members: list[dict[str, object]] = []
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                if info.is_dir() or not info.filename.lower().endswith(".csv"):
                    continue
                with archive.open(info) as raw:
                    text = io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")
                    reader = csv.reader(text)
                    header = next(reader, [])
                members.append(
                    {
                        "member": info.filename,
                        "stage": classify_member(dataset, info.filename),
                        "uncompressed_bytes": info.file_size,
                        "columns": header,
                    }
                )
        datasets[dataset] = {
            "path": str(path),
            "sha256": digest,
            "size_bytes": path.stat().st_size,
            "members": members,
        }
    return {
        "generated_at": utc_now(),
        "importer_version": IMPORTER_VERSION,
        "datasets": datasets,
    }


def import_member(
    db: StagingDatabase,
    source: SourceArchive,
    member: str,
    batch_size: int,
    stop: StopController,
    progress_callback: Callable[[MemberProgress], None] | None = None,
    stop_after_rows: int | None = None,
) -> MemberProgress:
    stage = classify_member(source.dataset, member)
    checkpoint = db.checkpoint(source.dataset, member)
    if checkpoint and checkpoint["status"] == "completed":
        return MemberProgress(
            dataset=source.dataset,
            member=member,
            stage=stage,
            rows_read=checkpoint["rows_read"],
            rows_accepted=checkpoint["rows_accepted"],
            rows_rejected=checkpoint["rows_rejected"],
            resumed_from_row=checkpoint["last_row_number"],
            elapsed_seconds=checkpoint["elapsed_seconds"],
            peak_memory_bytes=checkpoint["peak_memory_bytes"],
        )
    resume_row = int(checkpoint["last_row_number"]) if checkpoint else 0
    progress = MemberProgress(source.dataset, member, stage, resumed_from_row=resume_row)
    progress.rows_read = resume_row
    if checkpoint:
        progress.rows_accepted = int(checkpoint["rows_accepted"])
        progress.rows_rejected = int(checkpoint["rows_rejected"])
        progress.elapsed_seconds = float(checkpoint["elapsed_seconds"])
        progress.peak_memory_bytes = int(checkpoint["peak_memory_bytes"])

    started = time.monotonic()
    tracemalloc.start()
    batch: list[tuple[str, str, int, str, str | None, str, str]] = []
    try:
        with zipfile.ZipFile(source.path) as archive, archive.open(member) as raw:
            text = io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")
            reader = csv.DictReader(text)
            if not reader.fieldnames:
                raise RuntimeError(f"CSV header missing: {member}")
            db.start_member(source.dataset, member, stage, reader.fieldnames, resume_row)
            for row_number, row in enumerate(reader, start=1):
                if row_number <= resume_row:
                    continue
                if stop.requested:
                    raise KeyboardInterrupt
                progress.rows_read = row_number
                try:
                    payload = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
                    batch.append(
                        (
                            source.dataset,
                            member,
                            row_number,
                            stage,
                            row_source_id(row),
                            payload,
                            utc_now(),
                        )
                    )
                    progress.rows_accepted += 1
                except (TypeError, ValueError):
                    progress.rows_rejected += 1
                if len(batch) >= batch_size:
                    current, peak = tracemalloc.get_traced_memory()
                    progress.peak_memory_bytes = max(progress.peak_memory_bytes, peak)
                    progress.elapsed_seconds += time.monotonic() - started
                    db.save_batch(batch, progress)
                    batch.clear()
                    started = time.monotonic()
                    if progress_callback:
                        progress_callback(progress)
                if stop_after_rows is not None and progress.rows_read >= stop_after_rows:
                    stop.requested = True
            if batch:
                current, peak = tracemalloc.get_traced_memory()
                progress.peak_memory_bytes = max(progress.peak_memory_bytes, peak)
                progress.elapsed_seconds += time.monotonic() - started
                db.save_batch(batch, progress)
                batch.clear()
            db.finish_member(progress, "completed")
            if progress_callback:
                progress_callback(progress)
            return progress
    except KeyboardInterrupt:
        if batch:
            current, peak = tracemalloc.get_traced_memory()
            progress.peak_memory_bytes = max(progress.peak_memory_bytes, peak)
            progress.elapsed_seconds += time.monotonic() - started
            db.save_batch(batch, progress)
        db.finish_member(progress, "interrupted", "KeyboardInterrupt")
        raise
    except Exception as exc:
        db.finish_member(progress, "failed", str(exc))
        raise
    finally:
        tracemalloc.stop()


def run_import(
    archive_paths: Sequence[Path],
    database_path: Path,
    report_path: Path,
    batch_size: int = DEFAULT_BATCH_SIZE,
    selected_stages: set[str] | None = None,
    stop_after_rows: int | None = None,
) -> dict[str, object]:
    database_path.parent.mkdir(parents=True, exist_ok=True)
    sources = [
        SourceArchive(detect_dataset(path), path.resolve(), sha256_file(path), path.stat().st_size)
        for path in archive_paths
    ]
    stop = StopController()
    stop.install()
    results: list[dict[str, object]] = []
    result: dict[str, object] | None = None

    def log(progress: MemberProgress) -> None:
        print(
            f"[{progress.dataset}/{member_basename(progress.member)}] "
            f"stage={progress.stage} rows={progress.rows_read} accepted={progress.rows_accepted} "
            f"rejected={progress.rows_rejected} rate={progress.rows_per_second:.1f}/s "
            f"peak_memory={progress.peak_memory_bytes / (1024 * 1024):.1f} MiB checkpoint={progress.rows_read}",
            flush=True,
        )

    db = StagingDatabase(database_path)
    try:
        for source in sources:
            db.register_source(source)
        for stage in STAGE_ORDER[:-1]:
            if selected_stages and stage not in selected_stages:
                continue
            for source in sources:
                for member in archive_members(source):
                    if classify_member(source.dataset, member) != stage:
                        continue
                    try:
                        progress = import_member(
                            db,
                            source,
                            member,
                            batch_size,
                            stop,
                            progress_callback=log,
                            stop_after_rows=stop_after_rows,
                        )
                        results.append(progress.__dict__ | {"rows_per_second": progress.rows_per_second})
                    except KeyboardInterrupt:
                        result = {
                            "status": "interrupted",
                            "generated_at": utc_now(),
                            "database": str(database_path),
                            "database_sha256": None,
                            "members": results,
                            "verification": db.verify_integrity(),
                        }
                        print(
                            f"Import interrupted safely. Checkpoint saved. Report: {report_path}",
                            file=sys.stderr,
                        )
                        break
                if result is not None:
                    break
            if result is not None:
                break

        if result is None:
            db.refresh_stage_statuses()
            db.build_indexes()
            verification = db.verify_integrity()
            status = "completed" if not verification["incomplete_members"] else "partial"
            result = {
                "status": status,
                "generated_at": utc_now(),
                "database": str(database_path),
                "database_sha256": None,
                "members": results,
                "verification": verification,
            }
    finally:
        stop.restore()
        db.close()

    # Hash and report are intentionally produced only after SQLite is fully
    # closed, so callers can immediately move or delete the database on Windows.
    result["database_sha256"] = sha256_file(database_path)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return result

def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    inspect_parser = sub.add_parser("inspect", help="Inspect archive schemas without importing all rows")
    inspect_parser.add_argument("archives", nargs="+", type=Path)
    inspect_parser.add_argument("--report", required=True, type=Path)

    import_parser = sub.add_parser("import", help="Run or resume the staging import")
    import_parser.add_argument("archives", nargs="+", type=Path)
    import_parser.add_argument("--database", required=True, type=Path)
    import_parser.add_argument("--report", required=True, type=Path)
    import_parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    import_parser.add_argument("--stages", nargs="*", choices=STAGE_ORDER[:-1])

    verify_parser = sub.add_parser("verify", help="Verify an existing staging database")
    verify_parser.add_argument("--database", required=True, type=Path)
    verify_parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if args.command == "inspect":
        result = inspect_archives(args.archives)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Inspection report written: {args.report}")
        return 0
    if args.command == "import":
        if args.batch_size <= 0:
            raise ValueError("--batch-size must be positive")
        result = run_import(
            args.archives,
            args.database,
            args.report,
            batch_size=args.batch_size,
            selected_stages=set(args.stages) if args.stages else None,
        )
        print(json.dumps({"status": result["status"], "report": str(args.report)}, ensure_ascii=False))
        return 0 if result["status"] in {"completed", "partial", "interrupted"} else 1
    if args.command == "verify":
        db = StagingDatabase(args.database)
        result = db.verify_integrity()
        db.close()
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0 if result["integrity_check"] == "ok" and result["foreign_key_violations"] == 0 else 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
