"""Record focused Flutter validation without permitting root tests or builds."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]

def source_inputs() -> dict[str, str]:
    names = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard'], cwd=ROOT).decode('utf-8').splitlines()
    values = {}
    for name in sorted(set(names)):
        path = ROOT / name
        # Flutter's generated comparisons are evidence, not test inputs. Keep
        # every real test and Golden master in the fingerprint. Do not stage or
        # reinterpret a failure PNG as a new accepted master.
        generated = '/failures/' in name and name.endswith((
            '_masterImage.png', '_testImage.png',
            '_isolatedDiff.png', '_maskedDiff.png'))
        if not generated and (name.startswith(('lib/', 'test/', 'supabase/functions/', 'supabase/migrations/', 'supabase/tests/', 'tools/qa/', 'ios/Runner/', 'ios/Runner.xcodeproj/', 'android/app/')) or name in ('pubspec.yaml', 'pubspec.lock', 'assets/branding/google_translate_color.png', 'assets/branding/google_translate_white.png', 'tool/release/candidate_versions.json', 'tool/release/candidate_version_args.py')) and path.is_file():
            values[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return values


def fingerprint(values=None) -> str:
    values = source_inputs() if values is None else values
    return hashlib.sha256('\n'.join(
        name + ':' + digest for name, digest in sorted(values.items())
    ).encode('utf-8')).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("label")
    parser.add_argument("files", nargs="*")
    parser.add_argument("--case")
    parser.add_argument("--name", help="test name regular expression")
    parser.add_argument("--analyze", action="store_true")
    parser.add_argument('--check-public-workout-stream', action='store_true',
                        help='Opt into the existing read-only unauthenticated 32-byte CDN smoke test')
    parser.add_argument('--capture-purchase-review', action='store_true',
                        help='Enable commerce with fixture-only legal URLs for mocked host integration')
    parser.add_argument('--capture-health-review', action='store_true',
                        help='Enable the existing real Flutter health capture harness')
    parser.add_argument('--capture-ipad', action='store_true',
                        help='Include all existing iPad Golden cases, without updating masters')
    parser.add_argument('--wall-timeout', type=int, default=1800)
    parser.add_argument("--flutter", default=os.environ.get("BIL_FLUTTER", "flutter"))
    args = parser.parse_args()
    if not args.label.replace("-", "").replace("_", "").isalnum():
        parser.error("label must be a plain run name")
    if not args.analyze and not args.files:
        parser.error("focused test file paths are required")
    for path in args.files:
        resolved = (ROOT / path).resolve()
        if not resolved.is_relative_to(ROOT / "test") or not resolved.is_file() or not path.endswith("_test.dart"):
            parser.error(f"invalid focused test path: {path}")
    command = [args.flutter, "analyze", "--no-pub"] if args.analyze else [args.flutter, "test", "--no-pub", "--concurrency=1", "--timeout=3m", "--reporter=json", *args.files]
    if args.capture_purchase_review:
        if args.analyze:
            parser.error('purchase fixture configuration applies only to tests')
        command += ['--dart-define=BIL_PAYMENTS_ENABLED=true',
                    '--dart-define=BIL_TERMS_URL=https://billing-fixture.invalid/terms',
                    '--dart-define=BIL_PRIVACY_URL=https://billing-fixture.invalid/privacy']
    if args.capture_health_review:
        if args.analyze:
            parser.error('capture applies only to tests')
        command += ['--dart-define=BIL_CAPTURE_HEALTH_REVIEW=true']
    if args.check_public_workout_stream:
        if args.analyze:
            parser.error('public stream smoke applies only to tests')
        command += ['--dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true']
    if args.capture_ipad:
        if args.analyze:
            parser.error('iPad capture applies only to tests')
        command += ['--dart-define=BIL_CAPTURE_IPAD=true']
    if args.case:
        if args.analyze:
            parser.error("case applies only to tests")
        command += ["--plain-name", args.case]
    if args.name:
        if args.analyze or args.case:
            parser.error("name requires tests and cannot be combined with case")
        command += ["--name", args.name]
    target = ROOT / "build" / "stage1-closure"
    target.mkdir(parents=True, exist_ok=True)
    log = target / f"{args.label}.log"
    record = target / f"{args.label}.json"
    if log.exists() or record.exists():
        parser.error("run label already recorded; choose a new label")
    state = {"label": args.label, "command": command, "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "started": time.time(), "files": {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in args.files}}
    state['fingerprint_version'] = 3
    state['source_inputs'] = source_inputs()
    state['source_fingerprint'] = fingerprint(state['source_inputs'])
    with log.open("wb") as output:
        invocation = command
        # Windows invokes .bat files through cmd even with shell=False. Regex
        # metacharacters can then become shell operators. Run the installed
        # Flutter tool snapshot directly with its matching bundled Dart VM.
        if os.name == 'nt' and Path(command[0]).suffix.lower() == '.bat':
            flutter_bin = Path(command[0]).resolve().parent
            dart = flutter_bin / 'cache/dart-sdk/bin/dart.exe'
            snapshot = flutter_bin / 'cache/flutter_tools.snapshot'
            if not dart.is_file() or not snapshot.is_file():
                parser.error('the requested Flutter installation is not initialized')
            invocation = [str(dart), str(snapshot), *command[1:]]
        state['invocation'] = invocation
        process = subprocess.Popen(invocation, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        state["pid"] = process.pid
        record.write_text(json.dumps(state, indent=2), encoding="utf-8")
        print(json.dumps({"pid": process.pid, "log": str(log)}), flush=True)
        try:
            state['exit_code'] = process.wait(timeout=args.wall_timeout)
        except subprocess.TimeoutExpired:
            state['wall_timeout'] = True
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            else:
                process.kill()
            process.wait()
            state['exit_code'] = 124
    state["finished"] = time.time()
    state['end_fingerprint'] = fingerprint()
    state['stable_source'] = state['source_fingerprint'] == state['end_fingerprint']
    tests, outcomes, errors, completed = {}, {}, [], set()
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") == "testStart":
            tests[event["test"]["id"]] = event["test"]
        if event.get("type") == "testDone":
            completed.add(event["testID"])
            if not event.get("hidden"):
                outcomes[event["testID"]] = "skip" if event.get("skipped") else event["result"]
        if event.get("type") == "error":
            errors.append(event)
    state["tests"] = [{"name": tests.get(key, {}).get("name"), "url": tests.get(key, {}).get("root_url") or tests.get(key, {}).get("url"), "result": value} for key, value in outcomes.items()]
    state["counts"] = {name: list(outcomes.values()).count(name) for name in ("success", "failure", "error", "skip")}
    state["errors"] = errors
    state['incomplete_tests'] = [test['name'] for key, test in tests.items() if key not in completed]
    if not args.analyze and not outcomes and state['exit_code'] == 0:
        state['exit_code'] = 79
        state['no_tests_executed'] = True
    record.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"exit_code": state["exit_code"], "counts": state["counts"], "seconds": round(state["finished"] - state["started"], 2)}), flush=True)
    return state["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
