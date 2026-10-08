#!/usr/bin/env python3
"""Static SQL/PLpgSQL grammar and Python AST validation; never runs a database.

Optional isolated dependency: pglast==7.7 (PostgreSQL 17 grammar).
The absence of that parser is NOT_RUN/77, not successful SQL execution.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    destination = Path(args.output).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    evidence = {
        "status": "PASS", "engine_execution": False, "rls_executed": False,
        "production_connected": False, "results": [],
    }
    try:
        from pglast import __version__, parse_plpgsql, parse_sql
    except ImportError:
        evidence.update(status="NOT_RUN", reason="pglast==7.7 is unavailable")
        (destination / "syntax_results.json").write_text(json.dumps(evidence, indent=2) + "\n")
        print("NOT_RUN: " + evidence["reason"])
        return 77
    evidence.update(parser="pglast", parser_version=__version__)
    for path in sorted(HERE.iterdir()):
        if path.suffix not in (".sql", ".py"):
            continue
        entry = {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        try:
            if path.suffix == ".sql":
                entry["sql_statement_count"] = len(parse_sql(path.read_text()))
                entry["plpgsql_parser_units"] = len(parse_plpgsql(path.read_text()))
            else:
                ast.parse(path.read_text(), filename=str(path))
            entry["status"] = "PASS"
            print("PASS syntax only: " + path.name)
        except Exception as exc:
            entry.update(status="FAIL", error=f"{type(exc).__name__}: {exc}")
            evidence["status"] = "FAIL"
            print("FAIL syntax: " + path.name + ": " + entry["error"])
        evidence["results"].append(entry)
    (destination / "syntax_results.json").write_text(json.dumps(evidence, indent=2) + "\n")
    return 0 if evidence["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
