"""Control-plane STORE_QA_ONLY qualification; never public-release clearance.

The unchanged checked-out Dart validator must explicitly FAIL78 on the one
known unresolved-review issue. The eight open release gaps remain positive.
This tool does not build/sign/submit or change Production. Its upload command
delegates only to the separately reviewed internal-testing upload helper.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

SOURCE_SHA = "3f0085e6e6686f2e87e9cf14789e9e578ea64159"
REPOSITORY = "bilhealth-admin/Body-Intelligence"
APPLICATION_ID = "com.bilhealth.bodyintelligencelog"
RUNS = (
    ("Targeted", 37222502029, 373618485, "BIL community acceptance targeted QA",
     ".github/workflows/bil_community_acceptance_targeted_qa.yml"),
    ("Candidate", 37222502185, 370008508, "BIL Community 30-33 committed candidate QA",
     ".github/workflows/bil_community_3033_candidate_qa.yml"),
    ("Store", 37222502031, 374392375, "BIL pre-build store and backend contracts",
     ".github/workflows/bil_prebuild_store_backend_qa.yml"),
)
GAP_IDS = {
    "NATIVE_COMMERCE", "REVIEWER_ACCESS", "STORE_PRIVACY_DISCLOSURES",
    "GEMINI_PROCESSOR_RETENTION", "AUTH_DATABASE_SECURITY",
    "PRIVILEGED_RPC_HISTORICAL_RECONCILIATION",
    "REFERENCE_AND_NATIVE_UI_BOUNDARIES", "OWNER_ATTESTATIONS",
}
EXPECTED_ERROR = (
    "unresolved_release_review_items: "
    "The frozen release manifest must contain zero unresolved reviews."
)
EXPECTED_FAILURE = ["RELEASE_CONFIGURATION_GATE=FAIL", EXPECTED_ERROR]
PREBUILD_RECEIPTS = {
    "BIL-store-qa-upstream-qa.txt", "BIL-store-qa-configuration.txt",
    "BIL-apple-release-toolchain.txt", "BIL-apple-release-toolchain.json",
}
ANDROID_BUILD_RECEIPTS = {
    "BIL-android-signature.txt", "BIL-android-upload-certificate.txt",
    "BIL-android-aab.sha256", "BIL-android-aab.size", "BIL-source-head.txt",
    "BIL-control-head.txt", "BIL-store-qa-manifest.json", "BIL-store-qa-boundary.txt",
    "BIL-build-number.txt", "BIL-android-crypto-scan.txt",
    "BIL-android-production-admob-source.txt", "BIL-android-gate-status.txt",
    "BIL-store-qa-play-upload.txt",
} | {
    "BIL-android-16k-evidence/" + name for name in (
        "BIL-android-bundletool-install.txt", "BIL-android-base-manifest.xml",
        "BIL-android-artifact-version.json", "BIL-android-production-admob.txt",
        "BIL-android-target-sdk.txt", "BIL-android-target-sdk.json",
        "BIL-android-optional-hardware.txt", "BIL-android-optional-hardware.json",
        "BIL-android-16k-bundletool.txt", "BIL-android-16k-elf.txt",
        "BIL-android-16k-summary.json",
    )
}


class GateError(RuntimeError):
    """Finite fail-closed control-plane error; never include credentials."""


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise GateError("Duplicate manifest/API JSON field")
        result[key] = value
    return result


def _json(raw):
    try:
        return json.loads(raw, object_pairs_hook=_object,
                          parse_constant=lambda _: (_ for _ in ()).throw(
                              GateError("Nonfinite JSON value")))
    except (ValueError, TypeError) as error:
        raise GateError("Invalid manifest/API JSON") from error


def _positive(value):
    return type(value) is int and value > 0


def validate_manifest(manifest, platform):
    if not isinstance(manifest, dict):
        raise GateError("Manifest must be an object")
    if (manifest.get("schema_version") != 1 or
            manifest.get("phase") != "STORE_QA_ONLY" or
            manifest.get("repository") != REPOSITORY or
            manifest.get("source_sha") != SOURCE_SHA or
            manifest.get("release_version") != "1.0.0" or
            manifest.get("public_release_ready") is not False or
            manifest.get("no_review_submission") is not True or
            manifest.get("no_production_rollout") is not True):
        raise GateError("Unsupported source/phase/public-release scope")
    count = manifest.get("unresolved_review_count")
    gaps = manifest.get("known_release_gaps")
    if (type(count) is not int or count != 8 or not isinstance(gaps, list) or
            len(gaps) != count or
            any(not isinstance(gap, dict) or gap.get("status") != "OPEN" or
                gap.get("severity") not in {"BLOCKER", "HIGH"} or
                not isinstance(gap.get("description"), str) or
                not gap["description"].strip() for gap in gaps) or
            {gap.get("id") for gap in gaps} != GAP_IDS):
        raise GateError("All eight unresolved release gaps must remain OPEN")
    ci = manifest.get("upstream_ci")
    expected_ci = [
        dict(role=role, run_id=run_id, workflow_id=workflow_id,
             workflow_name=name, workflow_path=path)
        for role, run_id, workflow_id, name, path in RUNS
    ]
    if ci != expected_ci:
        raise GateError("Manifest upstream CI identities do not match approved runs")
    if platform not in {"android", "ios"}:
        raise GateError("Platform must be android or ios")
    target = manifest.get(platform)
    if not isinstance(target, dict) or not _positive(target.get("build_number")):
        raise GateError("Platform build must be a positive integer")
    if platform == "ios":
        if (target.get("bundle_id") != APPLICATION_ID or
                target.get("build_number") <= 34 or
                target.get("destination") != "testflight"):
            raise GateError("Only a new iOS TestFlight candidate is authorized")
    else:
        if (target.get("package_name") != APPLICATION_ID or
                target.get("build_number") <= 31 or
                target.get("track") != "internal" or
                target.get("release_status") not in {"draft", "completed"} or
                target.get("changes_not_sent_for_review") is not True or
                target.get("review_boundary") != "ERROR_IF_IN_REVIEW"):
            raise GateError("Only constrained Play internal testing is authorized")
    return target


def load_manifest(path, platform, environment):
    try:
        raw = Path(path).read_bytes()
    except OSError as error:
        raise GateError("Approved manifest could not be read") from error
    digest = hashlib.sha256(raw).hexdigest()
    expected = environment.get("BIL_STORE_QA_MANIFEST_SHA256", "")
    if not re.fullmatch(r"[0-9a-f]{64}", expected) or expected != digest:
        raise GateError("Approved STORE_QA manifest byte digest mismatch")
    manifest = _json(raw)
    target = validate_manifest(manifest, platform)
    return manifest, target, digest


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        raise GateError("GitHub API redirect refused")


def _api_get(path, token):
    # Fixed GET-only GitHub origin; never follow an authorization-bearing redirect.
    request = urllib.request.Request(
        "https://api.github.com/repos/" + REPOSITORY + "/" + path,
        headers={"Authorization": "Bearer " + token,
                 "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28",
                 "User-Agent": "BIL-store-qa-readonly"},
        method="GET",
    )
    try:
        with urllib.request.build_opener(_NoRedirect()).open(request, timeout=30) as response:
            raw = response.read(2 * 1024 * 1024 + 1)
        if len(raw) > 2 * 1024 * 1024:
            raise GateError("GitHub readback exceeded bounded JSON budget")
        result = _json(raw)
        if not isinstance(result, dict):
            raise GateError("GitHub readback must be an object")
        return result
    except urllib.error.HTTPError as error:
        raise GateError("GitHub read-only API HTTP " + str(error.code)) from None
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise GateError("GitHub read-only API unavailable") from error


def verify_ci(manifest, environment, get=_api_get):
    token = environment.get("GITHUB_TOKEN", "").strip()
    if not token:
        raise GateError("GITHUB_TOKEN required for current read-only CI verification")
    receipts = []
    for item in manifest["upstream_ci"]:
        run = get("actions/runs/" + str(item["run_id"]), token)
        if (run.get("id") != item["run_id"] or
                run.get("head_sha") != SOURCE_SHA or
                run.get("status") != "completed" or run.get("conclusion") != "success" or
                run.get("workflow_id") != item["workflow_id"] or
                run.get("name") != item["workflow_name"] or
                run.get("path") != item["workflow_path"] or
                run.get("repository", {}).get("full_name") != REPOSITORY or
                run.get("head_repository", {}).get("full_name") != REPOSITORY):
            raise GateError("Upstream run is not exact-source successful approved QA")
        workflow = get("actions/workflows/" + str(item["workflow_id"]), token)
        if (workflow.get("id") != item["workflow_id"] or
                workflow.get("name") != item["workflow_name"] or
                workflow.get("path") != item["workflow_path"]):
            raise GateError("Upstream workflow identity mismatch")
        receipts.append(dict(role=item["role"], run_id=item["run_id"],
                             workflow_id=item["workflow_id"], source_sha=SOURCE_SHA,
                             conclusion="success"))
    return receipts


def _run(command, *, cwd, env=None, timeout=300):
    try:
        return subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                              text=True, check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise GateError("Bounded control-plane subprocess failed") from error


def validate_source(manifest, target, platform, environment, cwd, run=_run,
                    *, after_build=False):
    head = run(["git", "rev-parse", "--verify", "HEAD"], cwd=cwd)
    status = run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=cwd)
    if head.returncode != 0 or head.stdout.strip() != SOURCE_SHA or status.returncode != 0:
        raise GateError("Checked-out application source must bind exact tested SHA")
    allowed = PREBUILD_RECEIPTS | (ANDROID_BUILD_RECEIPTS if after_build else set())
    generated = []
    for line in status.stdout.splitlines():
        if len(line) < 4:
            raise GateError("Malformed Git source-status receipt")
        state, path = line[:2], line[3:]
        if state == "??" and (path == "control/" or path in allowed):
            continue
        # Only this explicit iOS signing file may change after native compilation.
        # Android registrants and build outputs are ignored by the source's own
        # .gitignore, not by a blanket source-clean exception here.
        if (after_build and platform == "ios" and state == " M" and
                path == "ios/Flutter/Release.xcconfig"):
            generated.append(path)
            continue
        raise GateError("Unexpected source change before/after build: " + path)
    controller = environment.get("GITHUB_SHA", "")
    if not re.fullmatch(r"[0-9a-f]{40}", controller):
        raise GateError("Exact controller GITHUB_SHA required")
    control_head = run(["git", "-C", "control", "rev-parse", "--verify", "HEAD"], cwd=cwd)
    control_clean = run(["git", "-C", "control", "diff", "--quiet", "HEAD", "--"], cwd=cwd)
    if (control_head.returncode != 0 or control_head.stdout.strip() != controller or
            control_clean.returncode != 0):
        raise GateError("Control-plane checkout must be unchanged exact workflow SHA")
    if environment.get("BIL_RELEASE_PRODUCTION") != "true":
        raise GateError("Production runtime configuration must not be disabled")
    if environment.get("BIL_RELEASE_PLATFORM") != platform:
        raise GateError("Injected platform mismatch")
    for name in ("BIL_SOURCE_COMMIT", "BIL_AUDITED_SOURCE_COMMIT",
                 "BIL_COUNTERPART_AUDITED_SOURCE_COMMIT"):
        if environment.get(name) != manifest["source_sha"]:
            raise GateError("Injected source binding mismatch: " + name)
    build = str(target["build_number"])
    for name in ("BIL_RELEASE_EXPECTED_BUILD_NUMBER", "BIL_STORE_QA_BUILD_NUMBER"):
        if environment.get(name) != build:
            raise GateError("Injected build-number binding mismatch: " + name)
    return {"source_sha": SOURCE_SHA, "controller_sha": controller,
            "platform": platform, "build_number": target["build_number"],
            "generated_native_configuration": generated}


def _checkpoint_path(environment, platform):
    temporary = environment.get("RUNNER_TEMP", "")
    if not temporary or not Path(temporary).is_dir():
        raise GateError("Existing RUNNER_TEMP required for source checkpoint")
    return Path(temporary) / ("BIL-store-qa-source-" + platform + ".json")


def freeze_text(manifest, target, platform, digest):
    return (
        "# Owner-authorized STORE_QA_ONLY candidate; NOT accepted public release\n"
        "\nSTAGING_MANIFEST_COMPLETE: YES\nCANDIDATE_FROZEN_OR_ACCEPTED: YES\n"
        "UNRESOLVED_REVIEW_COUNT: " + str(manifest["unresolved_review_count"]) + "\n"
        "RELEASE_VERSION: " + manifest["release_version"] + "\n"
        "RELEASE_BUILD_NUMBER: " + str(target["build_number"]) + "\n"
        "\nPHASE: STORE_QA_ONLY\nPUBLIC_RELEASE_READY: NO\n"
        "SOURCE_COMMIT: " + manifest["source_sha"] + "\n"
        "PLATFORM: " + platform + "\nCONTROLLER_MANIFEST_SHA256: " + digest + "\n"
        "\nComplete/frozen qualifies the source handoff only; all eight public-release "
        "gaps remain OPEN. The original production gate MUST FAIL, not be bypassed.\n"
    )


def qualify_validator_result(result):
    # No filter/waiver/continue-on-error: exactly one known failure is mandatory.
    if (result.returncode != 78 or result.stdout.strip() or
            result.stderr.splitlines() != EXPECTED_FAILURE):
        raise GateError("Unmodified production gate did not report exactly the known review failure")


def configuration(manifest, target, platform, digest, environment, cwd, run=_run):
    source = validate_source(manifest, target, platform, environment, cwd, run)
    temporary = environment.get("RUNNER_TEMP", "")
    if not temporary or not Path(temporary).is_dir():
        raise GateError("Existing RUNNER_TEMP required for ephemeral phase freeze")
    with tempfile.TemporaryDirectory(prefix="bil-store-qa-", dir=temporary) as folder:
        freeze = Path(folder) / ("BIL_STORE_QA_" + platform + "_freeze.md")
        freeze.write_bytes(freeze_text(manifest, target, platform, digest).encode("utf-8"))
        freeze_digest = hashlib.sha256(freeze.read_bytes()).hexdigest()
        injected = dict(environment)
        injected["BIL_RELEASE_MANIFEST_PATH"] = str(freeze)
        injected["BIL_AUDITED_FREEZE_MANIFEST_SHA256"] = freeze_digest
        # Source tool is unchanged and receives positive unresolved review count8.
        result = run(["dart", "run", "tool/release/validate_release_configuration.dart"],
                     cwd=cwd, env=injected)
        if result.stdout:
            print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
        if result.stderr:
            print(result.stderr, file=sys.stderr,
                  end="" if result.stderr.endswith("\n") else "\n")
        qualify_validator_result(result)
        checkpoint = dict(source, manifest_sha256=digest,
                          phase="STORE_QA_ONLY", configuration_gate="PASS",
                          original_production_gate="FAIL", unresolved_review_count=8)
        checkpoint_raw = (json.dumps(checkpoint, sort_keys=True) + "\n").encode("utf-8")
        _checkpoint_path(environment, platform).write_bytes(checkpoint_raw)
        print("ORIGINAL_PRODUCTION_RELEASE_GATE=FAIL")
        print("UNRESOLVED_RELEASE_REVIEW_COUNT=8")
        print("STORE_QA_FREEZE_MANIFEST_SHA256=" + freeze_digest)
        print("STORE_QA_SOURCE_CHECKPOINT_SHA256=" + hashlib.sha256(checkpoint_raw).hexdigest())
        print("STORE_QA_CONFIGURATION_GATE=PASS")
        print("PUBLIC_RELEASE_READY=NO")


def _read_receipt(path):
    try:
        if path.stat().st_size > 2 * 1024 * 1024:
            raise GateError("Oversized bounded artifact receipt")
        return path.read_bytes()
    except OSError as error:
        raise GateError("Required signed-artifact receipt unavailable") from error


def validate_android_artifact(manifest, target, aab, digest, source, environment, cwd):
    checkpoint = _json(_read_receipt(_checkpoint_path(environment, "android")))
    expected = dict(source, manifest_sha256=digest, phase="STORE_QA_ONLY",
                    configuration_gate="PASS", original_production_gate="FAIL",
                    unresolved_review_count=8)
    if checkpoint != expected:
        raise GateError("Successful exact-source prebuild configuration checkpoint required")
    root, artifact = Path(cwd), Path(aab).resolve()
    checksum = hashlib.sha256()
    with artifact.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            checksum.update(chunk)
    actual = checksum.hexdigest()
    fields = _read_receipt(root / "BIL-android-aab.sha256").decode("utf-8").strip().split(maxsplit=1)
    if (len(fields) != 2 or fields[0] != actual or
            (root / fields[1].lstrip("*")).resolve() != artifact or
            _read_receipt(root / "BIL-android-aab.size").decode().strip() != str(artifact.stat().st_size)):
        raise GateError("Signed AAB hash/path/size receipt mismatch")
    version = _json(_read_receipt(root / "BIL-android-16k-evidence/BIL-android-artifact-version.json"))
    if version != dict(package=APPLICATION_ID, version_name=manifest["release_version"],
                       version_code=str(target["build_number"])):
        raise GateError("Signed AAB package/version receipt mismatch")
    text_receipts = {
        "BIL-source-head.txt": SOURCE_SHA, "BIL-control-head.txt": source["controller_sha"],
        "BIL-build-number.txt": "BUILD_NUMBER=" + str(target["build_number"]),
        "BIL-android-upload-certificate.txt": "ANDROID_UPLOAD_CERTIFICATE_SHA256=MATCH",
    }
    if any(_read_receipt(root / path).decode().strip() != value
           for path, value in text_receipts.items()):
        raise GateError("Signed AAB source/control/build/certificate receipt mismatch")
    if (hashlib.sha256(_read_receipt(root / "BIL-store-qa-manifest.json")).hexdigest() != digest or
            not _read_receipt(root / "BIL-android-signature.txt").strip()):
        raise GateError("Signed AAB manifest/signature receipt mismatch")
    print("STORE_QA_SIGNED_AAB_SHA256=" + actual)


def upload_play(manifest, target, aab, manifest_path, environment, cwd, run=_run,
                *, publishing_state_checked=False):
    # Sibling owns the bounded Edits API/track/version/artifact receipt checks.
    # This wrapper neither submits pending review changes nor touches production.
    if not publishing_state_checked:
        raise GateError("Fresh owner publishing-state check required for testing upload")
    source = validate_source(manifest, target, "android", environment, cwd, run,
                             after_build=True)
    if not aab or not Path(aab).is_file():
        raise GateError("Existing built AAB required; this helper does not build")
    child = Path(__file__).resolve().with_name("store_qa_play_upload.py")
    if not child.is_file():
        raise GateError("Reviewed Play testing upload helper is unavailable")
    _, _, digest = load_manifest(manifest_path, "android", environment)
    validate_android_artifact(manifest, target, aab, digest, source, environment, cwd)
    result = run([sys.executable, str(child), "--aab", str(Path(aab).resolve()),
                  "--manifest", str(Path(manifest_path).resolve()),
                  "--owner-publishing-state-checked"],
                 cwd=cwd, env=dict(environment), timeout=1800)
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr,
              end="" if result.stderr.endswith("\n") else "\n")
    if result.returncode != 0:
        raise GateError("Play testing upload helper did not complete successfully")
    print("PUBLIC_RELEASE_READY=NO")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("verify", "configuration", "upload-play"))
    parser.add_argument("--platform", required=True, choices=("android", "ios"))
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--aab")
    parser.add_argument("--owner-publishing-state-checked", action="store_true")
    args = parser.parse_args(argv)
    try:
        manifest, target, digest = load_manifest(args.manifest, args.platform, os.environ)
        if args.command == "verify":
            receipts = verify_ci(manifest, os.environ)
            print(json.dumps(dict(checked_at_utc=datetime.now(timezone.utc).isoformat(),
                                  source_sha=SOURCE_SHA, manifest_sha256=digest,
                                  upstream_ci=receipts), sort_keys=True))
            print("STORE_QA_UPSTREAM_CI_GATE=PASS")
            print("PUBLIC_RELEASE_READY=NO")
        elif args.command == "configuration":
            configuration(manifest, target, args.platform, digest, os.environ, Path.cwd())
        else:
            if args.platform != "android":
                raise GateError("Play upload requires android platform")
            upload_play(manifest, target, args.aab, args.manifest, os.environ, Path.cwd(),
                        publishing_state_checked=args.owner_publishing_state_checked)
        return 0
    except GateError as error:
        print("STORE_QA_" + args.command.upper() + "_GATE=FAIL", file=sys.stderr)
        print(str(error), file=sys.stderr)
        print("PUBLIC_RELEASE_READY=NO", file=sys.stderr)
        return 78


if __name__ == "__main__":
    raise SystemExit(main())

