#!/usr/bin/env python3
"""Create, test and stop a disposable PostgreSQL cluster bound to 127.0.0.1.

No DSN/host/database argument is accepted. Never reads project .env files.
Set BIL07_POSTGRES_BIN to a directory containing initdb, pg_ctl and psql.
Exit 77 means NOT_RUN (missing runtime), not PASS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import pwd
import shutil
import socket
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, help="Absolute scratch evidence directory")
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    commands: list[dict] = []
    result = {
        "status": "NOT_RUN", "production_connected": False,
        "production_deployed": False, "host": "127.0.0.1",
        "started_at_epoch": time.time(),
    }
    directories: list[Path] = []
    if os.environ.get("BIL07_POSTGRES_BIN"):
        directories.append(Path(os.environ["BIL07_POSTGRES_BIN"]).resolve())
    psql = shutil.which("psql")
    if psql:
        directories.append(Path(psql).resolve().parent)
    directories += sorted(Path("/usr/lib/postgresql").glob("*/bin"), reverse=True)
    directories += sorted(Path("/opt").glob("postgres*/bin"), reverse=True)
    binary_dir = next(
        (d for d in directories if all((d / n).is_file() for n in ("psql", "initdb", "pg_ctl"))),
        None,
    )

    def save() -> None:
        result["finished_at_epoch"] = time.time()
        result["source_sha256"] = {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(HERE.iterdir()) if p.is_file()
        }
        (output / "runner_results.json").write_text(json.dumps(result, indent=2) + "\n")
        (output / "runner_commands.json").write_text(json.dumps(commands, indent=2) + "\n")

    if binary_dir is None:
        result["reason"] = "initdb, pg_ctl and psql were not found; no remote fallback is permitted."
        save()
        print("NOT_RUN: " + result["reason"])
        return 77
    prefix: list[str] = []
    account = None
    if os.geteuid() == 0:
        requested_account = os.environ.get("BIL07_PG_OS_USER")
        candidates = [requested_account] if requested_account else ["postgres", "nobody"]
        for name in candidates:
            try:
                candidate = pwd.getpwnam(name)
                if candidate.pw_uid != 0:
                    account = candidate
                    break
            except KeyError:
                continue
        if account is None:
            result["reason"] = "initdb refuses root; an existing unprivileged local account is unavailable."
            save()
            print("NOT_RUN: " + result["reason"])
            return 77
        uid_map_path = Path("/proc/self/uid_map")
        gid_map_path = Path("/proc/self/gid_map")
        if uid_map_path.is_file() and gid_map_path.is_file():
            def mapped(path: Path, value: int) -> bool:
                ranges = [tuple(map(int, line.split())) for line in path.read_text().splitlines()]
                return any(start <= value < start + count for start, _outside, count in ranges)
            if not mapped(uid_map_path, account.pw_uid) or not mapped(gid_map_path, account.pw_gid):
                result.update(
                    reason="The executor maps only restricted UID/GIDs; its unprivileged account is unmapped. "
                           "PostgreSQL refuses root. No identity/access-control bypass is attempted.",
                    uid_map=uid_map_path.read_text().strip(),
                    gid_map=gid_map_path.read_text().strip(),
                )
                save()
                print("NOT_RUN: " + result["reason"])
                return 77
        runuser = shutil.which("runuser")
        if runuser is None:
            result["reason"] = "Running as root without runuser; no escalation or remote fallback."
            save()
            print("NOT_RUN: " + result["reason"])
            return 77
        prefix = [runuser, "-u", account.pw_name, "--"]
        result["local_os_user"] = account.pw_name

    env = {k: v for k, v in os.environ.items() if not k.startswith("PG")}
    env.update(PGHOST="127.0.0.1", PGHOSTADDR="127.0.0.1", PGUSER="postgres",
               PGSSLMODE="disable", PGCONNECT_TIMEOUT="5")
    cluster = Path(tempfile.mkdtemp(prefix="bil07-local-pg-"))
    data = cluster / "data"
    server_log = cluster / "postgres.log"
    if account is not None:
        try:
            os.chown(cluster, account.pw_uid, account.pw_gid)
        except OSError as exc:
            result.update(status="NOT_RUN", reason=f"Cannot assign disposable cluster to an unprivileged owner: {exc}")
            shutil.rmtree(cluster)
            save()
            print("NOT_RUN: " + result["reason"])
            return 77
    port_socket = socket.socket()
    port_socket.bind(("127.0.0.1", 0))
    port = port_socket.getsockname()[1]
    port_socket.close()
    dbname = "bil07_local_" + os.urandom(6).hex()
    env.update(PGPORT=str(port), PGDATABASE=dbname)
    started = False
    result.update(postgres_bin=str(binary_dir), port=port, database=dbname)

    def command(argv: list[str], timeout: int = 30, check: bool = True,
                input_text: str | None = None) -> subprocess.CompletedProcess:
        start = time.monotonic()
        completed = subprocess.run(
            argv, input=input_text, text=True, capture_output=True,
            env=env, timeout=timeout, check=False,
        )
        commands.append({
            "command": argv, "exit_code": completed.returncode,
            "stdout": completed.stdout, "stderr": completed.stderr,
            "elapsed_seconds": round(time.monotonic() - start, 4),
        })
        if check and completed.returncode:
            raise RuntimeError(completed.stderr or completed.stdout)
        return completed

    try:
        version = command([str(binary_dir / "psql"), "--version"]).stdout.strip()
        result["psql_version"] = version
        command(prefix + [
            str(binary_dir / "initdb"), "-D", str(data),
            "--auth=trust", "--username=postgres", "--encoding=UTF8",
            "--no-locale",
        ])
        # TCP listens only on loopback. A unique local socket path prevents
        # accidental connections to an existing database cluster.
        command(prefix + [
            str(binary_dir / "pg_ctl"), "-D", str(data), "-l", str(server_log),
            "-w", "-t", "15", "start", "-o",
            f"-h 127.0.0.1 -p {port} -k {cluster} -c max_connections=20 "
            "-c shared_buffers=32MB -c fsync=on -c jit=off -c log_min_messages=warning",
        ])
        started = True
        command([
            str(binary_dir / "psql"), "-X", "-qAt", "-v", "ON_ERROR_STOP=1",
            "-h", "127.0.0.1", "-p", str(port), "-U", "postgres", "-d", "postgres",
            "-c", f"create database {dbname};",
        ])
        child_env = {
            **env, "BIL07_PSQL": str(binary_dir / "psql"),
            "BIL07_SQL_OUTPUT_DIR": str(output),
        }
        # Process lifetime is outside any application fake clock.
        start = time.monotonic()
        completed = subprocess.run(
            [sys.executable, str(HERE / "integration_tests.py")],
            env=child_env, text=True, capture_output=True, timeout=180,
            check=False,
        )
        (output / "sql_stdout.log").write_text(completed.stdout)
        (output / "sql_stderr.log").write_text(completed.stderr)
        commands.append({
            "command": [sys.executable, str(HERE / "integration_tests.py")],
            "exit_code": completed.returncode,
            "elapsed_seconds": round(time.monotonic() - start, 4),
            "stdout_log": str(output / "sql_stdout.log"),
            "stderr_log": str(output / "sql_stderr.log"),
        })
        print(completed.stdout, end="")
        if completed.stderr:
            print(completed.stderr, file=sys.stderr, end="")
        result["status"] = "PASS" if completed.returncode == 0 else "FAIL"
        result["exit_code"] = completed.returncode
    except Exception as exc:
        result.update(status="FAIL", reason=f"{type(exc).__name__}: {exc}", exit_code=1)
        print(result["reason"], file=sys.stderr)
    finally:
        if started:
            try:
                stop = command(prefix + [
                    str(binary_dir / "pg_ctl"), "-D", str(data),
                    "-m", "immediate", "-w", "-t", "15", "stop",
                ], check=False)
                result["cluster_stopped"] = stop.returncode == 0
            except Exception as exc:
                result["cluster_stop_error"] = str(exc)
        if server_log.is_file():
            shutil.copyfile(server_log, output / "postgres.log")
        # Delete only the exact fresh directory allocated by this run.
        if not started or result.get("cluster_stopped"):
            shutil.rmtree(cluster)
        else:
            result["cleanup_pending"] = str(cluster)
        save()
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
