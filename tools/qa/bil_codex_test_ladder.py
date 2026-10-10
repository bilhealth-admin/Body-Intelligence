#!/usr/bin/env python3
"""BIL QA local test ladder. No deploys, merges, golden rewrites, or uploads.

Run with Python 3.10+ and Flutter 3.44.6 on the designated QA branch.
Results remain under build/bil-codex-qa/ and are bound to exact worktree data.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
BRANCH = "qa/bil-quality-ux-integration-20261009"
BASE = "origin/qa/coach-community-next-20261005"
OUT = ROOT / "build" / "bil-codex-qa"
STAGES = ("source", "arabic", "p0", "focused", "broad", "full")

P0 = [
    ("food-owner-atomic", "test/features/nutrition/coach_food_commit_test.dart"),
    ("meal-owner-atomic", "test/features/nutrition/coach_meal_commit_boundary_test.dart"),
    ("first-food-commit", "test/data/repositories/first_food_milestone_commit_test.dart"),
    ("vision-review", "test/features/nutrition/meal_vision_premium_review_test.dart"),
    ("vision-durable-replay", "test/features/nutrition/meal_vision_verified_commit_test.dart"),
    ("vision-quantity-basis", "test/features/nutrition/meal_image_unified_review_contract_test.dart"),
    ("vision-capture", "test/features/nutrition/meal_vision_flutter_capture_test.dart"),
    ("architecture", "test/architecture_source_file_size_guard_test.dart"),
    ("coach-photo-bridge", "test/parallel/bil02/coach_media_page_overlay_test.dart"),
    ("coach-image-source", "test/features/intelligence_center/coach_image_source_regression_test.dart"),
    ("vision-arabic", "test/features/nutrition/meal_image_language_regression_test.dart"),
]
FOCUSED = [
    ("store-captures", "test/epic15_store_screenshot_golden_test.dart"),
    ("production-goldens", "test/visual_closure/actual_production_pages_golden_test.dart"),
    ("data-goldens", "test/visual_closure/actual_data_pages_golden_test.dart"),
    ("splash-golden", "test/premium_splash_experience_test.dart"),
    ("transaction-queue", "test/features/commerce/store_transaction_queue_test.dart"),
]
BROAD = [
    ("dashboard-nutrition", "test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart test/dashboard_polish/dashboard_polish_layout_review_test.dart test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart test/dashboard_polish/dashboard_current_preview_test.dart"),
    ("dashboard-contract-health", "test/dashboard_composition_contract_test.dart test/dashboard_epic_completion_contract_test.dart test/dashboard_polish/dashboard_live_health_hub_contract_test.dart test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart test/dashboard_polish/live_health_watch_layout_golden_test.dart test/dashboard_polish/live_health_watch_visibility_test.dart"),
    ("weekly-onboarding-goldens", "test/epic8_weekly_report_golden_test.dart test/features/onboarding/onboarding_visual_golden_test.dart test/premium_dashboard_benchmark_test.dart"),
    ("settings-language-icons", "test/semantic_icon_badge_spacing_test.dart test/bil_semantic_icons_test.dart test/launch_readiness/navigation_and_more_master_closure_test.dart test/localization/bil_25_locale_fallback_closure_test.dart test/visual_closure/visual_defect_regression_test.dart"),
    ("wellness-commerce", "test/features/commerce/verified_entitlement_surface_contract_test.dart test/features/wellness/recipe_library_polish_test.dart test/features/wellness/workout_reference_golden_test.dart"),
    ("community-cold-back", "test/features/community/community_chat_auth_session_test.dart"),
]


def git(*args, check=True):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                          check=check)


def executable_args(args):
    # Windows resolves flutter/dart through .bat launchers. CreateProcess does
    # not search PATHEXT for an extensionless command as PowerShell does.
    return [shutil.which(args[0]) or args[0], *args[1:]]


def fingerprint(head):
    h = hashlib.sha256(head.encode())
    h.update(git("rev-parse", BASE).stdout)
    h.update(git("diff", "HEAD", "--binary", "--").stdout)
    untracked = git("ls-files", "--others", "--exclude-standard", "--",
                    "lib", "test", "tools", "scripts").stdout.decode(
                        "utf-8", errors="replace").splitlines()
    for name in sorted(untracked):
        file = ROOT / name
        if file.is_file():
            h.update(name.encode())
            h.update(hashlib.sha256(file.read_bytes()).digest())
    return h.hexdigest()


def run_command(label, args):
    OUT.mkdir(parents=True, exist_ok=True)
    # Keep failed attempts available for handoff when a narrow retry succeeds.
    log = OUT / (label.replace("/", "_") + "-" + str(time.time_ns()) + ".log")
    start = time.monotonic()
    with log.open("w", encoding="utf-8", errors="replace") as dest:
        dest.write("Command: " + " ".join(args) + "\n\n")
        dest.flush()
        try:
            result = subprocess.run(executable_args(args), cwd=ROOT, stdout=dest,
                                    stderr=subprocess.STDOUT, check=False)
            code = result.returncode
        except OSError as error:
            dest.write(str(error) + "\n")
            code = 127
    item = {"exit_code": code, "seconds": round(time.monotonic() - start, 1),
            "log": str(log.relative_to(ROOT))}
    print(("[PASS] " if code == 0 else "[FAIL] ") + label +
          " -> " + item["log"], flush=True)
    return item


def changed_dart_targets():
    chosen = {
        "test/features/nutrition/meal_vision_flutter_capture_test.dart",
        "test/launch_readiness/navigation_and_more_master_closure_test.dart",
    }
    for revs in ((BASE + "...HEAD",), ("HEAD",)):
        result = git("diff", "--name-only", "--diff-filter=ACMR",
                     *revs, "--")
        for file in result.stdout.decode("utf-8", errors="replace").splitlines():
            if file.endswith(".dart") and file.startswith(("lib/", "test/")):
                chosen.add(file)
    return [name for name in sorted(chosen) if (ROOT / name).is_file()]


def run_source():
    targets = changed_dart_targets()
    print("Strict dart format targets:", len(targets), flush=True)
    # The complete PR scope exceeds cmd.exe's 8191-character limit for the
    # Windows dart.bat launcher. Check every target in bounded batches.
    formats = []
    for start in range(0, len(targets), 40):
        fmt = run_command("source-format-" + str(start // 40 + 1),
                          ["dart", "format", "--output=none",
                           "--set-exit-if-changed", *targets[start:start + 40]])
        formats.append(fmt)
        if fmt["exit_code"] != 0:
            return {"format": formats, "passed": False}
    analysis = run_command("source-analyze", ["flutter", "analyze", "--no-pub"])
    return {"format": formats, "analyze": analysis,
            "passed": analysis["exit_code"] == 0}


def run_suites(stage, suites, parallel, previous=None):
    work = []
    outcomes = {}
    for label, source in suites:
        name = stage + "-" + label
        cached = (previous or {}).get("jobs", {}).get(name)
        if cached and cached.get("exit_code") == 0:
            outcomes[name] = cached
            print("[REUSED GREEN SUITE] " + name, flush=True)
            continue
        args = ["flutter", "test", "--no-pub", "--timeout=3m"]
        args += (source.split() if isinstance(source, str) else source)
        work.append((name, args))
    with ThreadPoolExecutor(max_workers=max(1, min(parallel, len(work)))) as pool:
        jobs = {pool.submit(run_command, name, args): name for name, args in work}
        for future in as_completed(jobs):
            name = jobs[future]
            try:
                outcomes[name] = future.result()
            except Exception as exc:
                outcomes[name] = {"exit_code": 127, "error": repr(exc)}
                print("[FAIL] " + name + ": " + repr(exc), flush=True)
    return {"passed": all(x["exit_code"] == 0 for x in outcomes.values()),
            "jobs": outcomes}


def run_stage(stage, parallel, previous=None):
    if stage == "source":
        return run_source()
    if stage == "arabic":
        return run_suites(stage, [("noto-capture",
            "test/features/nutrition/meal_vision_flutter_capture_test.dart")], 1, previous)
    if stage == "p0":
        return run_suites(stage, P0, parallel, previous)
    if stage == "focused":
        return run_suites(stage, FOCUSED, parallel, previous)
    if stage == "broad":
        return run_suites(stage, BROAD, parallel, previous)
    return run_suites(stage, [
        ("shard-" + str(i), ["--total-shards=8", "--shard-index=" + str(i)])
        for i in range(8)], parallel, previous)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-stage", choices=STAGES, default="source")
    parser.add_argument("--through-stage", choices=STAGES, default="full")
    parser.add_argument("--parallel", type=int, default=1)
    parser.add_argument("--force", action="store_true",
                        help="Re-run a green stage on the identical worktree")
    args = parser.parse_args()
    if args.parallel < 1 or args.parallel > 8:
        parser.error("--parallel must be 1 through 8")
    first, last = STAGES.index(args.from_stage), STAGES.index(args.through_stage)
    if first > last:
        parser.error("--from-stage cannot follow --through-stage")
    if not shutil.which("flutter") or not shutil.which("dart"):
        parser.error("Flutter and Dart must be available on PATH")
    actual_branch = git("branch", "--show-current").stdout.decode().strip()
    if actual_branch != BRANCH:
        parser.error("Wrong branch: " + actual_branch)
    head = git("rev-parse", "HEAD").stdout.decode().strip()
    if git("rev-parse", "--verify", BASE, check=False).returncode != 0:
        parser.error("Fetch required source comparison ref: " + BASE)
    version = subprocess.run(executable_args(["flutter", "--version"]), cwd=ROOT,
                             capture_output=True, text=True, encoding="utf-8",
                             errors="replace", check=False)
    if version.returncode != 0 or "Flutter 3.44.6" not in version.stdout:
        parser.error("Pin Flutter 3.44.6; found: " + version.stdout[:180])
    setup = run_command("bootstrap-pub-get", ["flutter", "pub", "get"])
    if setup["exit_code"] != 0:
        return 1
    stamp = fingerprint(head)
    manifest_file = OUT / "manifest.json"
    try:
        old = json.loads(manifest_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        old = {}
    state = old if (old.get("head") == head and
                    old.get("worktree_sha256") == stamp) else {}
    state.update({"head": head, "branch": BRANCH,
                  "worktree_sha256": stamp, "flutter": "3.44.6"})
    stages = state.setdefault("stages", {})
    for previous in STAGES[:first]:
        if not stages.get(previous, {}).get("passed"):
            parser.error("First pass earlier gate " + previous +
                         " on this exact worktree; run from source.")
    print("BIL local QA", head, "fingerprint", stamp[:16], flush=True)
    for stage in STAGES[first:last + 1]:
        if not args.force and stages.get(stage, {}).get("passed"):
            print("[REUSED GREEN] " + stage + " (same HEAD and worktree)")
            continue
        print("==> stage:", stage, flush=True)
        # A fresh prerequisite run invalidates downstream results, even if it
        # fails or the worktree changes before the next invocation.
        for downstream in STAGES[STAGES.index(stage) + 1:]:
            stages.pop(downstream, None)
        outcome = run_stage(stage, args.parallel,
                            None if args.force else stages.get(stage))
        stages[stage] = outcome
        if fingerprint(head) != stamp or git("rev-parse", "HEAD").stdout.decode().strip() != head:
            state["stages"] = {}
            manifest_file.write_text(json.dumps(state, ensure_ascii=False,
                                                 indent=2), encoding="utf-8")
            print("Worktree changed while testing. Discard green gates.", flush=True)
            return 2
        manifest_file.write_text(json.dumps(state, ensure_ascii=False,
                                             indent=2), encoding="utf-8")
        if not outcome.get("passed"):
            print("STOP: " + stage + " is RED. Fix root cause and retest narrowly.")
            print("No full-shard run or baseline rewrite permitted.")
            return 1
    print("All requested gates GREEN for recorded HEAD/worktree only.")
    print("Not a production, store, physical-device or visual approval.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
