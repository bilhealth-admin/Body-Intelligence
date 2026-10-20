#!/usr/bin/env python3
"""Record exact committed and working native/test input bytes before/after CI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

INPUT_ROOTS = ("android", "ios", "lib", "integration_test", "test_driver", "test", ".github/scripts",
               "pubspec.yaml", "pubspec.lock", ".github/workflows/bil_codeql_security_extended.yml")
CONTROLLER_PATH = ".github/workflows/bil_frozen_native_security_20261020.yml"


def collect(args, *, run=subprocess.run):
    if args.phase not in ("before", "after") or args.language not in ("java-kotlin", "swift"):
        raise ValueError("Only native before/after receipt phases are permitted")
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_head) or not re.fullmatch(r"[0-9a-f]{40}", args.source_tree):
        raise ValueError("Frozen source HEAD and tree are required")
    control = os.environ["GITHUB_SHA"]
    run_id = os.environ["GITHUB_RUN_ID"]
    if not re.fullmatch(r"[0-9a-f]{40}", control) or not re.fullmatch(r"[0-9]+", run_id):
        raise ValueError("Actual controller SHA and run ID are required")

    def git(*argv):
        result = run(["git", *argv], capture_output=True, check=False)
        if result.returncode:
            raise ValueError("Source command failed: " + argv[0])
        return result.stdout

    if git("rev-parse", "HEAD").decode().strip() != args.source_head or git("rev-parse", "HEAD^{tree}").decode().strip() != args.source_tree:
        raise ValueError("Actual checked-out source HEAD/tree mismatch")
    # Native repairs may create ignored build overlays. Tracked app, native,
    # dependency, driver and test bytes must still match the frozen commit.
    git("diff", "--exit-code", "HEAD", "--", *INPUT_ROOTS)
    inputs = []
    for entry in git("ls-tree", "-r", "-z", "HEAD", "--", *INPUT_ROOTS).split(b"\0"):
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, kind, blob = metadata.decode().split()
        path = raw_path.decode("utf-8")
        if kind != "blob" or mode == "120000":
            raise ValueError("Only regular tracked native/test input blobs are permitted")
        actual = Path(path)
        if not actual.is_file() or actual.is_symlink():
            raise ValueError("Tracked native/test input missing or symlinked")
        inputs.append({"path": path, "git_blob_sha": blob, "working_sha256": hashlib.sha256(actual.read_bytes()).hexdigest()})
    if not inputs:
        raise ValueError("Native source input inventory cannot be empty")
    inputs.sort(key=lambda row: row["path"])
    result = {"schema": "bil.qa.frozen-native-source.v1", "phase": args.phase,
              "repository": "bilhealth-admin/Body-Intelligence", "application_source_sha": args.source_head,
              "application_source_tree": args.source_tree, "controller_sha": control, "run_id": run_id,
              "workflow_path": CONTROLLER_PATH, "language": args.language, "tracked_native_inputs_clean": True,
              "input_roots": list(INPUT_ROOTS), "inputs": inputs,
              "working_inputs_fingerprint": hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
              "claim": "Actual checkout and native/test input bytes only; GitHub job/step results determine test success"}
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    if args.phase == "after":
        before = json.loads((output / "native-source-before.json").read_text())
        for field in ("repository", "application_source_sha", "application_source_tree", "controller_sha", "run_id",
                      "workflow_path", "language", "input_roots", "inputs", "working_inputs_fingerprint"):
            if before.get(field) != result[field]:
                raise ValueError("Native/test inputs changed during execution: " + field)
        result["before_after_inputs_identical"] = True
    (output / ("native-source-" + args.phase + ".json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"phase": args.phase, "source_head": args.source_head, "language": args.language,
                      "native_input_count": len(inputs), "tracked_inputs_clean": True}))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("phase", "language", "source-head", "source-tree", "output"):
        parser.add_argument("--" + name, required=True)
    collect(parser.parse_args())


if __name__ == "__main__":
    main()
