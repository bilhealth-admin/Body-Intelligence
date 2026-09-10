"""Scan current tracked/untracked source, excluding ignored files and media.

The source snapshot is local audit evidence, never uploaded. Gitleaks redacts
all credential candidates in both its log and machine-readable report.
"""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path
import shutil
import subprocess

from audit_repository import TEXT
from run_gate import EVIDENCE, ROOT, run_gate


def is_source(path: Path) -> bool:
    return (path.suffix.lower() in TEXT or path.name.startswith(".env")
            or path.name in {".gitignore", ".gitattributes", ".npmrc", ".yarnrc",
                             "Podfile", "Gemfile", "Dockerfile", "gradlew"})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gitleaks", type=Path)
    args = parser.parse_args()
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    snapshot = EVIDENCE / f"secret_source_snapshot_{stamp}"
    snapshot.mkdir(parents=True, exist_ok=False)
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
    ).decode("utf-8").split("\0")
    count = 0
    for relative in sorted(set(paths) - {""}):
        source = ROOT / relative
        if not source.is_file() or not is_source(source):
            continue
        target = snapshot / relative
        if not target.resolve().is_relative_to(snapshot.resolve()):
            raise ValueError("Git returned an out-of-scope source path")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        count += 1
    print(f"Source files scanned: {count}; media and ignored paths not copied", flush=True)
    return run_gate("gitleaks_current_source", [
        str(args.gitleaks), "dir", "--redact=100", "--ignore-gitleaks-allow",
        "--no-banner", "--no-color", "--report-format=json",
        f"--report-path={EVIDENCE / ('gitleaks_current_' + stamp + '.json')}",
        str(snapshot),
    ])


if __name__ == "__main__":
    raise SystemExit(main())
