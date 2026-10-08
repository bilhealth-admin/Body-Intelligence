#!/usr/bin/env python3
"""Verify the proposed optional-PNG registration without weakening BASE gates.

Run in the validation overlay. This calls BASE's discovery gate; it does not run
the full portable suite or change test classifications at runtime.
"""

import ast
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys


BASE_SHA = "1744788e6bfbdffc3a168bbaf36b3abf3e2c698a"
POLICY = "tool/prebuild/run_code_tests.py"
CAPTURE = "test/parallel/bil07/community_channels_capture_widget_test.dart"


def main() -> None:
    root = Path.cwd()
    original = subprocess.check_output(
        ["git", "show", f"{BASE_SHA}:{POLICY}"], cwd=root,
        env={**os.environ, "GIT_NO_LAZY_FETCH": "1"},
    )
    baseline = {}
    for statement in ast.parse(original).body:
        if isinstance(statement, ast.Assign):
            for target in statement.targets:
                if isinstance(target, ast.Name):
                    try:
                        baseline[target.id] = ast.literal_eval(statement.value)
                    except (ValueError, TypeError):
                        pass
    sys.path.insert(0, str(root / "tool/prebuild"))
    spec = importlib.util.spec_from_file_location("bil07_capture_policy", root / POLICY)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load the actual capture policy")
    policy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(policy)
    discovered, ordinary = policy.discover()
    protected = (
        "NOT_RUN", "MIXED_NAMES", "CAPTURE_GUARDED",
        "ENV_CAPTURE_GUARDED", "NON_VISUAL_BYTE_TESTS",
    )
    for key in protected:
        if getattr(policy, key) != baseline[key]:
            raise AssertionError(f"Existing test partition changed: {key}")
    expected = dict(baseline["ENV_CAPTURE_DIRECTORIES"])
    expected[CAPTURE] = "BIL07_CAPTURE_DIR"
    if policy.ENV_CAPTURE_DIRECTORIES != expected:
        raise AssertionError("The optional PNG registration is not exact")
    bil07 = [name for name in discovered if name.startswith("test/parallel/bil07/")]
    if CAPTURE not in bil07 or not set(bil07).issubset(ordinary):
        raise AssertionError("Every BIL-07 test file must remain in ordinary discovery")
    print(json.dumps({
        "status": "PASS",
        "base_sha": BASE_SHA,
        "baseline_policy_sha256": hashlib.sha256(original).hexdigest(),
        "overlay_policy_sha256": hashlib.sha256((root / POLICY).read_bytes()).hexdigest(),
        "discovered_test_files": len(discovered),
        "ordinary_test_files": len(ordinary),
        "bil07_files_in_ordinary": bil07,
        "legacy_exclusions_and_filters_unchanged": True,
        "optional_png_environment": "BIL07_CAPTURE_DIR",
        "full_portable_suite_run": False,
    }, indent=2))


if __name__ == "__main__":
    main()
