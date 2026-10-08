#!/usr/bin/env python3
"""Read-only BIL-02 ownership/frozen-contract verification against real Git BASE."""

import hashlib
import json
import subprocess
from pathlib import Path

BASE = "1744788e6bfbdffc3a168bbaf36b3abf3e2c698a"
BASE_TREE = "8f140791e1c2adcb21122ce64a65cb168bbe90d7"
ROOT = Path(__file__).resolve().parents[3]
OWNED_FILE = "lib/features/intelligence_center/presentation/intelligence_vision_flow.dart"
OWNED_DIRS = (
    "lib/features/intelligence_center/media_bridge/",
    "test/parallel/bil02/",
    "docs/qa_parallel/bil02/",
    "tool/qa_parallel/bil02/",
)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def main():
    head = git("rev-parse", "HEAD").decode().strip()
    tree = git("rev-parse", BASE + "^{tree}").decode().strip()
    tracked = git("diff", "--name-only", BASE, "--").decode().splitlines()
    new = git("ls-files", "--others", "--exclude-standard").decode().splitlines()
    changed = sorted(set(tracked + new))
    violations = [
        path for path in changed
        if path != OWNED_FILE and not path.startswith(OWNED_DIRS)
    ]
    frozen = git(
        "diff", "--name-only", BASE, "--",
        "lib/features/intelligence_center/domain/food_v2/",
        "pubspec.yaml", "pubspec.lock", "analysis_options.yaml",
    ).decode().splitlines()
    files = []
    digest = hashlib.sha256()
    for path in changed:
        target = ROOT / path
        sha = hashlib.sha256(target.read_bytes()).hexdigest() if target.is_file() else None
        files.append({"path": path, "sha256": sha})
        digest.update((path + "\0" + str(sha) + "\n").encode())
    passed = head == BASE and tree == BASE_TREE and not violations and not frozen
    print(json.dumps({
        "status": "PASS" if passed else "FAIL",
        "head": head,
        "base_tree": tree,
        "ownership_violations": violations,
        "frozen_changes": frozen,
        "changed_files": files,
        "changed_source_digest": digest.hexdigest(),
    }, ensure_ascii=False, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
