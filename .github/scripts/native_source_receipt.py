#!/usr/bin/env python3
"""Record exact committed and working native/test input bytes before/after CI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import difflib
import stat
from bil_cocoapods_derived_proof import DERIVED_PATHS, SCHEMA as DERIVED_SCHEMA, sha256, validate, validate_toolchain
from bil_ios_simulator_spawn_diagnostic import sanitize

INPUT_ROOTS = ("android", "ios", "lib", "integration_test", "test_driver", "test", ".github/scripts",
               "pubspec.yaml", "pubspec.lock", ".github/workflows/bil_codeql_security_extended.yml")
CONTROLLER_PATH = ".github/workflows/bil_frozen_native_security_20261020.yml"
PUBLIC_PATCH_PATHS = {"ios/Runner.xcodeproj/project.pbxproj", "ios/Podfile", "ios/Runner/Info.plist",
                      "ios/Flutter/Debug.xcconfig", "ios/Flutter/Profile.xcconfig", "ios/Flutter/Release.xcconfig",
                      "ios/Flutter/AppFrameworkInfo.plist", "ios/Runner/Runner.entitlements", "ios/Runner/RunnerDebug.entitlements",
                      "ios/Runner.xcworkspace/contents.xcworkspacedata"}


def collect(args, *, run=subprocess.run):
    if args.phase not in ("checkout", "before", "after") or args.language not in ("java-kotlin", "swift"):
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
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    # Native repairs may create ignored build overlays. Tracked app, native,
    # dependency, driver and test bytes must still match the frozen commit.
    derived_requested = bool(getattr(args, "derived_contract", None))
    if derived_requested and args.language != "swift":
        raise ValueError("Derived CocoaPods proof is limited to the Swift role")
    diff = run(["git", "diff", "--exit-code", "HEAD", "--", *INPUT_ROOTS], capture_output=True, check=False)
    changed = []
    if diff.returncode:
        if diff.returncode != 1:
            raise ValueError("SOURCE_DIFF_COMMAND_FAILED")
        for raw_path in git("diff", "--name-only", "-z", "HEAD", "--", *INPUT_ROOTS).split(b"\0"):
            if not raw_path:
                continue
            name = raw_path.decode("utf-8")
            path = Path(name)
            if path.is_absolute() or ".." in path.parts or not any(name == root or name.startswith(root + "/") for root in INPUT_ROOTS):
                raise ValueError("UNEXPECTED_TRACKED_DIFF_PATH")
            original = git("show", "HEAD:" + name)
            row = {"path": name, "committed_sha256": hashlib.sha256(original).hexdigest(),
                   "working_sha256": hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() and not path.is_symlink() else None,
                   "source_phase": args.phase}
            if name in PUBLIC_PATCH_PATHS:
                patch = git("diff", "--no-ext-diff", "--no-color", "--unified=3", "HEAD", "--", name)
                if len(patch) <= 128 * 1024:
                    member = "tracked-change-" + hashlib.sha256(name.encode()).hexdigest()[:12] + ".diff"
                    (output / member).write_text(sanitize(patch))
                    row["redacted_public_native_patch_member"] = member
                else:
                    row["patch_status"] = "TOO_LARGE_NOT_PUBLISHED"
            changed.append(row)
        failure = {"schema": "bil.qa.frozen-native-source-diff.v1", "phase": args.phase,
                   "application_source_sha": args.source_head, "application_source_tree": args.source_tree,
                   "controller_sha": control, "run_id": run_id, "workflow_path": CONTROLLER_PATH,
                   "language": args.language, "tracked_native_inputs_clean": False,
                   "status": "BLOCKED_UNREVIEWED_TRACKED_NATIVE_OR_TEST_CHANGES", "changed_tracked_inputs": changed,
                   "claim": "Diagnostic metadata only; no changed input or generated project repair is accepted"}
        (output / ("native-source-" + args.phase + "-dirty.json")).write_text(json.dumps(failure, indent=2) + "\n")
        eligible = derived_requested and args.phase in ("before", "after") and {row["path"] for row in changed} == set(DERIVED_PATHS)
        print(json.dumps({"status": "OBSERVED_GENERATION_REQUIRES_SEMANTIC_VALIDATION" if eligible else failure["status"],
                          "changed_paths": [row["path"] for row in changed]}))
        if not eligible:
            raise ValueError("FROZEN_NATIVE_TRACKED_INPUTS_CHANGED")
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
    derived_proof = None
    if derived_requested and args.phase != "checkout":
        if {row["path"] for row in changed} != set(DERIVED_PATHS):
            raise ValueError("Expected exact reviewed CocoaPods integration delta")
        checkout = json.loads((output / "native-source-checkout.json").read_text())
        for key, value in {"schema": "bil.qa.frozen-native-source.v1", "phase": "checkout",
                           "application_source_sha": args.source_head, "application_source_tree": args.source_tree,
                           "controller_sha": control, "run_id": run_id, "workflow_path": CONTROLLER_PATH,
                           "language": "swift", "tracked_native_inputs_clean": True}.items():
            if checkout.get(key) != value:
                raise ValueError("Initial clean frozen checkout proof required: " + key)
        baseline = {row["path"]: row for row in checkout["inputs"]}
        if len(baseline) != len(inputs) or set(baseline) != {row["path"] for row in inputs}:
            raise ValueError("Initial and actual tracked input inventories differ")
        for row in inputs:
            initial = baseline[row["path"]]
            if initial["git_blob_sha"] != row["git_blob_sha"]:
                raise ValueError("Frozen native Git blob identity changed")
            if row["path"] not in DERIVED_PATHS and initial["working_sha256"] != row["working_sha256"]:
                raise ValueError("Unreviewed source or test working bytes changed")
        contract_data = Path(args.derived_contract).read_bytes()
        contract = json.loads(contract_data)
        originals = {path: git("show", "HEAD:" + path) for path in DERIVED_PATHS}
        if any(not stat.S_ISREG(Path(path).stat().st_mode) or Path(path).is_symlink() or
               Path(path).stat().st_mode & 0o111 for path in DERIVED_PATHS):
            raise ValueError("Generated CocoaPods inputs must retain regular non-executable source mode")
        generated = {path: Path(path).read_bytes() for path in DERIVED_PATHS}
        rows = validate(originals, generated, contract)
        if any(baseline[row["path"]]["working_sha256"] != row["committed_sha256"] for row in rows):
            raise ValueError("Derived original bytes do not match the initial checkout")
        toolchain_data = (output / "cocoapods-toolchain.json").read_bytes()
        toolchain = json.loads(toolchain_data)
        locks = validate_toolchain(Path.cwd(), toolchain)
        for path, data in [("Podfile.lock", Path("ios/Podfile.lock").read_bytes()),
                           ("Manifest.lock", Path("ios/Pods/Manifest.lock").read_bytes()),
                           ("toolchain.json", toolchain_data)]:
            if re.search(rb"https?://[^\s/]+:[^\s/@]+@|(?i:authorization|bearer|password|token)\s*[:=]", data):
                raise ValueError("Potential credential in public build metadata")
            target = output / "cocoapods-derived" / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        for row in rows:
            path = row["path"]
            for kind, data in (("original", originals[path]), ("generated", generated[path])):
                target = output / "cocoapods-derived" / kind / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                row[kind + "_member"] = str(target.relative_to(output))
            patch = "".join(difflib.unified_diff(originals[path].decode().splitlines(keepends=True),
                                                generated[path].decode().splitlines(keepends=True),
                                                fromfile="a/" + path, tofile="b/" + path))
            target = output / "cocoapods-derived" / (sha256(path.encode())[:12] + ".diff")
            target.write_text(patch)
            row["patch_member"] = str(target.relative_to(output))
            row["patch_sha256"] = sha256(target.read_bytes())
        derived_proof = {"schema": DERIVED_SCHEMA, "status": "VALIDATED_REVIEWED_BUILD_GENERATION",
                         "contract_sha256": sha256(contract_data), "initial_checkout_clean": True,
                         "initial_source_fingerprint": checkout["working_inputs_fingerprint"],
                         "reviewed_derived_inputs": rows, "all_other_tracked_inputs_unchanged": True,
                         "unchanged_tracked_input_count": len(inputs) - len(DERIVED_PATHS),
                         "toolchain_member": "cocoapods-derived/toolchain.json",
                         "toolchain_sha256": sha256(toolchain_data), "toolchain": toolchain,
                         "podfile_lock_member": "cocoapods-derived/Podfile.lock",
                         "manifest_lock_member": "cocoapods-derived/Manifest.lock", **locks,
                         "claim": "Reviewed CocoaPods project integration; actual generated bytes remain distinct from frozen Git blobs"}
    result = {"schema": "bil.qa.frozen-native-source.v1", "phase": args.phase,
              "repository": "bilhealth-admin/Body-Intelligence", "application_source_sha": args.source_head,
              "application_source_tree": args.source_tree, "controller_sha": control, "run_id": run_id,
              "workflow_path": CONTROLLER_PATH, "language": args.language, "tracked_native_inputs_clean": True,
              "input_roots": list(INPUT_ROOTS), "inputs": inputs,
              "working_inputs_fingerprint": hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
              "claim": "Actual checkout and native/test input bytes only; GitHub job/step results determine test success"}
    if derived_proof:
        result.update(schema="bil.qa.frozen-native-source.v2", tracked_native_inputs_clean=False,
                      reviewed_derived_build_inputs=True, initial_checkout_clean=True,
                      derived_build_proof=derived_proof)
        dirty = output / ("native-source-" + args.phase + "-dirty.json")
        if dirty.exists():
            observed = json.loads(dirty.read_text())
            observed["status"] = "VALIDATED_REVIEWED_BUILD_GENERATION"
            observed["claim"] = "Observed changes accepted only by separately recorded strict semantic proof"
            dirty.write_text(json.dumps(observed, indent=2) + "\n")
    if args.phase == "after":
        before = json.loads((output / "native-source-before.json").read_text())
        for field in ("repository", "application_source_sha", "application_source_tree", "controller_sha", "run_id",
                      "workflow_path", "language", "input_roots", "inputs", "working_inputs_fingerprint",
                      "derived_build_proof"):
            if field == "derived_build_proof" and before.get(field) is None and result.get(field) is None:
                continue
            if before.get(field) != result[field]:
                raise ValueError("Native/test inputs changed during execution: " + field)
        result["before_after_inputs_identical"] = True
    (output / ("native-source-" + args.phase + ".json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"phase": args.phase, "source_head": args.source_head, "language": args.language,
                      "native_input_count": len(inputs), "tracked_inputs_clean": not bool(derived_proof),
                      "reviewed_derived_build_inputs": bool(derived_proof)}))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("phase", "language", "source-head", "source-tree", "output"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--derived-contract", help="Reviewed immutable CocoaPods semantic contract; Swift only")
    collect(parser.parse_args())


if __name__ == "__main__":
    main()
