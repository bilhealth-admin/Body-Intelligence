"""Real signed-APK capture control. Stdlib only; never builds or patches BIL."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile

PACKAGE = "com.bilhealth.bodyintelligencelog"
PRODUCER = ".github/workflows/bil_android_release_candidate.yml"
REPO = "bilhealth-admin/Body-Intelligence"
MEAL_GOAL_CHAPTER = "Premium meal calorie-goal content (four meals) without paywall"
MEAL_GOAL_STAGE = "PREMIUM_MEAL_CALORIE_GOALS_CONTENT_VISIBLE_4_MEALS_READ_ONLY"


class Blocked(RuntimeError):
    pass


def require(condition, code):
    if not condition:
        raise Blocked(code)


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def json_file(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def save(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def validate_producer(run, artifact, source, run_id, artifact_id):
    require(re.fullmatch(r"[0-9a-f]{40}", source), "invalid_source_sha")
    require(run.get("id") == run_id and run.get("head_sha") == source,
            "producer_run_or_source_mismatch")
    require(run.get("path", "").split("@")[0] == PRODUCER
            and run.get("repository", {}).get("full_name") == REPO
            and run.get("status") == "completed" and run.get("conclusion") == "success"
            and run.get("event") == "workflow_dispatch", "producer_not_successful_signed_workflow")
    require(artifact.get("id") == artifact_id and artifact.get("expired") is False
            and artifact.get("name") == f"bil-android-signed-aab-{source}"
            and 0 < artifact.get("size_in_bytes", 0) <= 2_000_000_000,
            "invalid_or_expired_artifact")
    identity = artifact.get("workflow_run", {})
    require(identity.get("id") == run_id and identity.get("head_sha") == source,
            "artifact_run_or_source_mismatch")
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", artifact.get("digest") or ""),
            "missing_github_artifact_digest")


def extract_signed_inputs(archive, output):
    names = {"BIL-Android33-derived-universal.apk", "BIL-android-recording-apk-receipt.json"}
    selected = {}
    with zipfile.ZipFile(archive) as z:
        require(sum(i.file_size for i in z.infolist()) <= 3_000_000_000, "artifact_expansion_too_large")
        for item in z.infolist():
            p = PurePosixPath(item.filename)
            require(not p.is_absolute() and ".." not in p.parts and "\\" not in item.filename
                    and ":" not in item.filename and (item.external_attr >> 16) & 0o170000 != 0o120000,
                    "unsafe_artifact_entry")
            if p.name in names:
                require(p.name not in selected, "ambiguous_artifact_entry")
                require(item.file_size <= 1_500_000_000, "artifact_file_too_large")
                dest = Path(output) / p.name
                dest.parent.mkdir(parents=True, exist_ok=True)
                with z.open(item) as src, dest.open("wb") as dst:
                    import shutil
                    shutil.copyfileobj(src, dst)
                selected[p.name] = dest
    require(set(selected) == names, "signed_apk_or_receipt_missing")
    return selected


def validate_receipt(receipt, apk, source, certificate):
    certificate = certificate.replace(":", "").lower()
    require(re.fullmatch(r"[0-9a-f]{64}", certificate), "expected_certificate_missing")
    require(receipt.get("status") == "VERIFIED_DERIVED_SIGNED_QA_APK"
            and receipt.get("source_sha") == source and receipt.get("build") == 33
            and receipt.get("package") == PACKAGE and receipt.get("app_recompiled") is False
            and receipt.get("play_upload_performed") is False
            and receipt.get("installation_source") == "not_installed",
            "signed_receipt_identity_mismatch")
    require(receipt.get("certificate_sha256") == certificate
            and receipt.get("apk_sha256") == sha256(apk)
            and re.fullmatch(r"[0-9a-f]{64}", receipt.get("aab_sha256") or ""),
            "signed_receipt_hash_or_certificate_mismatch")


def gh_json(resource):
    result = subprocess.run(["gh", "api", resource], check=True, capture_output=True)
    return json.loads(result.stdout)


def fetch(args):
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    run = gh_json(f"repos/{REPO}/actions/runs/{args.run_id}")
    artifact = gh_json(f"repos/{REPO}/actions/artifacts/{args.artifact_id}")
    validate_producer(run, artifact, args.source, args.run_id, args.artifact_id)
    archive = out / "signed-producer.zip"
    with archive.open("wb") as stream:
        subprocess.run(["gh", "api", f"repos/{REPO}/actions/artifacts/{args.artifact_id}/zip"],
                       stdout=stream, stderr=subprocess.DEVNULL, check=True)
    require("sha256:" + sha256(archive) == artifact["digest"], "github_archive_digest_mismatch")
    selected = extract_signed_inputs(archive, out)
    apk = selected["BIL-Android33-derived-universal.apk"]
    receipt = json_file(selected["BIL-android-recording-apk-receipt.json"])
    validate_receipt(receipt, apk, args.source, os.environ.get("EXPECTED_UPLOAD_CERT_SHA256", ""))
    save(out / "producer-identity.json", {"source_sha": args.source, "run_id": args.run_id,
         "artifact_id": args.artifact_id, "archive_digest": artifact["digest"],
         "apk_sha256": receipt["apk_sha256"], "package": PACKAGE, "build": 33,
         "installation_source": "not_installed", "play_delivery_proven": False})
    print("EXACT_SIGNED_PRODUCER_ARTIFACT=PASS")


def parse_nodes(xml):
    require(len(xml) <= 2_000_000 and "<!DOCTYPE" not in xml and "<!ENTITY" not in xml,
            "unsafe_or_oversized_ui_xml")
    start = xml.find("<?xml")
    if start < 0:
        start = xml.find("<hierarchy")
    require(start >= 0, "missing_visible_ui_hierarchy")
    root = ET.fromstring(xml[start:])
    nodes = []
    for node in root.iter("node"):
        a = dict(node.attrib)
        match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", a.get("bounds", ""))
        if match:
            x1, y1, x2, y2 = map(int, match.groups())
            if 0 <= x1 < x2 <= 10000 and 0 <= y1 < y2 <= 10000:
                a["center"] = ((x1 + x2) // 2, (y1 + y2) // 2)
                nodes.append(a)
    return nodes


def labels(node):
    return [re.sub(r"\s+", " ", node.get(k, "")).strip() for k in ("text", "content-desc")]


def classify_blocker(nodes):
    text = "\n".join(label for n in nodes if n.get("package") == PACKAGE for label in labels(n))
    checks = [
        (r"Your local data could not be opened", "local_data_open_failed"),
        (r"Enter.*verification code|Verify your email", "otp_required_not_reusable_reviewer_login"),
        (r"What would you like to work on\?|What is your baseline activity\?|A few facts for your estimate|What is your height\?|What is your current weight\?|Choose your target weight|Finish setup", "onboarding_requires_explicit_test_profile_no_values_invented"),
        (r"The email address or password is incorrect|Authentication failed", "reviewer_authentication_failed"),
        (r"device integrity|device could not be verified|integrity check", "production_integrity_blocked_sideload"),
    ]
    return next((code for pattern, code in checks if re.search(pattern, text, re.I)), None)


def select(nodes, pattern, package=PACKAGE, edit_index=None):
    candidates = [n for n in nodes if n.get("package") == package and n.get("enabled") == "true"]
    if edit_index is not None:
        candidates = [n for n in candidates if n.get("class") == "android.widget.EditText"]
        require(len(candidates) == 2 and edit_index in (0, 1), "reviewer_form_not_exactly_two_fields")
        return sorted(candidates, key=lambda n: n["center"][1])[edit_index]
    matched = [n for n in candidates if any(re.fullmatch(pattern, label, re.I) for label in labels(n))]
    # Flutter may expose nested semantic and text nodes at the same tap location.
    unique = {n["center"]: n for n in matched}
    require(len(unique) == 1, "visible_selector_missing_or_ambiguous")
    return next(iter(unique.values()))


def visible_premium_active(nodes):
    return any(n.get("package") == PACKAGE and any(re.fullmatch(r"Active", s, re.I)
               for s in labels(n)) for n in nodes)


def validate_meal_goal_content(nodes, viewport):
    width, height = viewport
    require(0 < width <= 10000 and 0 < height <= 10000,
            "meal_calorie_goals_viewport_unavailable")
    own = [n for n in nodes if n.get("package") == PACKAGE
           and n.get("visible-to-user", "true") != "false"
           and 0 < n["center"][0] < width and 0 < n["center"][1] < height]
    require(own, "meal_calorie_goals_wrong_app_package")
    text = [s for n in own for s in labels(n)]
    # A title, an Active badge, or a route into Plans is not paid-feature proof.
    require(not any(re.search(r"^Plans$|\bView Premium plans\b|\bExplore Premium\b|\bRetry subscription check\b|\bRestore purchases\b|\bOpening secure purchase\b|^Continue(?:\s*[Ã‚Â·Ã¢â‚¬Â¢].*)?$", s, re.I)
                    for s in text), "meal_calorie_goals_paywall_or_unverified")
    require(any(re.fullmatch(r"Set a separate calorie goal for each meal\.", s, re.I)
                for s in text), "meal_calorie_goals_content_not_visible")
    centers = []
    for meal in ("breakfast", "lunch", "dinner", "snack"):
        matches = [n for n in own if any(re.fullmatch(
            meal + r"(?:\s+(?:No meal goal|\d+(?:[.,]\d+)?\s*kcal))?", s, re.I)
            for s in labels(n))]
        require(matches, "meal_calorie_goals_four_meals_not_visible")
        row_centers = {n["center"] for n in matches}
        require(len(row_centers) == 1, "meal_calorie_goals_ambiguous_row")
        centers.append(next(iter(row_centers)))
    require(len(set(centers)) == 4, "meal_calorie_goals_distinct_rows_not_visible")
    return {"package": PACKAGE,
            "content_landmark": "Set a separate calorie goal for each meal.",
            "meal_rows": ["breakfast", "lunch", "dinner", "snack"],
            "read_only": True, "goals_saved_or_cleared": False,
            "scope": "visible native content only; not an edit, purchase or live AI response"}


def capture_premium_meal_goal_chapter(device, result):
    try:
        device.more()
        device.scroll_to(r"Goals")
        device.tap(r"Goals")
        # Read the actual per-meal Premium feature, not the ordinary Nutrition
        # Goals editor or a Plans upsell. Never tap a meal, Save or Clear.
        device.scroll_to(r"Calorie Goals By Meal")
        device.tap(r"Calorie Goals By Meal")
        proof = device.wait_meal_goal_content()
        result["premium_meal_goal_evidence"] = proof
        result["stages"].append(MEAL_GOAL_STAGE)
        result["not_demonstrated"].remove(MEAL_GOAL_CHAPTER)
        time.sleep(4)
        return True
    except Blocked as exc:
        result["blocked_chapters"].append({"chapter": "premium_meal_calorie_goals", "code": str(exc)})
        return False


def package_identity(text):
    match = re.search(r"versionCode=(\d+)\b", text)
    require(match and int(match.group(1)) == 33, "installed_version_code_mismatch")
    require("versionName=1.0.0" in text, "installed_version_name_mismatch")


def validate_manifest(xml):
    require("<!DOCTYPE" not in xml and "<!ENTITY" not in xml, "unsafe_apk_manifest")
    root = ET.fromstring(xml)
    ns = "{http://schemas.android.com/apk/res/android}"
    require(root.tag == "manifest" and root.get("package") == PACKAGE
            and root.get(ns + "versionCode") == "33" and root.get(ns + "versionName") == "1.0.0",
            "apk_manifest_identity_mismatch")
    app = root.find("application")
    require(app is not None and app.get(ns + "debuggable", "false") == "false",
            "debuggable_binary_not_release_evidence")


def redact(text, secrets=()):
    for value in secrets:
        if value:
            variants = {value}
            for _ in range(2):
                variants |= {html.escape(v, quote=q) for v in tuple(variants) for q in (True, False)}
            for variant in sorted(variants, key=len, reverse=True):
                text = text.replace(variant, "[REDACTED]")
    return re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[EMAIL_REDACTED]", text)


def sanitized_ui_xml(xml, secrets=()):
    # Parse first, so XML character references are decoded before value redaction.
    parse_nodes(xml)  # Reuse the size/DTD/entity guard before XML parsing.
    start = xml.find("<?xml")
    if start < 0:
        start = xml.find("<hierarchy")
    root = ET.fromstring(xml[start:])
    for node in root.iter():
        password = node.get("password", "").lower() == "true"
        for key, value in tuple(node.attrib.items()):
            node.set(key, "[PASSWORD_REDACTED]" if password and key in ("text", "content-desc", "hint", "tooltip")
                     else redact(value, secrets))
        if node.text:
            node.text = "[PASSWORD_REDACTED]" if password else redact(node.text, secrets)
        if node.tail:
            node.tail = redact(node.tail, secrets)
    return ET.tostring(root, encoding="unicode", xml_declaration=True)


def capture_exit(result):
    return 1 if (result.get("status") == "BLOCKED_NATIVE_JOURNEY_NOT_CERTIFIED"
                 or result.get("blocked_chapters") or result.get("recording_finalization_error")
                 or not result.get("clips")) else 0


def finalize_capture(device, output, result):
    try:
        device.stop()
    except Exception as exc:
        result["recording_finalization_error"] = type(exc).__name__
        result["status"] = "BLOCKED_NATIVE_JOURNEY_NOT_CERTIFIED"
        result["failure_code"] = "native_recording_finalization_failed"
    result["clips"] = device.clips
    if not result["clips"]:
        result["status"] = "BLOCKED_NATIVE_JOURNEY_NOT_CERTIFIED"
        result.setdefault("failure_code", "no_valid_native_video_recorded")
    result["recorded_at_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    save(Path(output) / "capture-receipt.json", result)
    return capture_exit(result)


def android_text_commands(value):
    require(value and len(value) <= 254 and value.isascii()
            and not any(ord(c) < 32 or ord(c) == 127 for c in value),
            "credential_requires_unsupported_input_method")
    # Separate characters avoid Android input-text's special %s -> space substitution.
    # Shell quoting protects punctuation without changing the credential itself.
    return ["input keyevent KEYCODE_SPACE" if c == " " else "input text " + shlex.quote(c) for c in value]


class Device:
    def __init__(self, serial, out, secrets):
        self.serial, self.out, self.secrets = serial, Path(out), secrets
        self.proc, self.current, self.clips = None, None, []

    def adb(self, *args, timeout=20, binary=False):
        try:
            r = subprocess.run(["adb", "-s", self.serial, *map(str, args)],
                               capture_output=True, timeout=timeout, check=True)
            return r.stdout if binary else r.stdout.decode("utf-8", "replace")
        except (subprocess.SubprocessError, OSError):
            # Never surface a credential-bearing adb command in an exception.
            raise Blocked("adb_operation_failed") from None

    def nodes(self, snapshot=None):
        self.adb("shell", "uiautomator", "dump", "/sdcard/bil-capture-ui.xml")
        xml = self.adb("exec-out", "cat", "/sdcard/bil-capture-ui.xml")
        parsed = parse_nodes(xml)
        if snapshot:
            (self.out / f"{snapshot}.xml").write_text(sanitized_ui_xml(xml, self.secrets), encoding="utf-8")
        return parsed

    def wait(self, pattern, seconds=30, snapshot=None, package=PACKAGE):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            try:
                n = self.nodes()
                selected = select(n, pattern, package=package)
                if snapshot:
                    self.nodes(snapshot)
                return selected
            except Blocked as exc:
                if str(exc) != "visible_selector_missing_or_ambiguous":
                    raise
                blocker = classify_blocker(n)
                if blocker:
                    raise Blocked(blocker)
            time.sleep(1)
        raise Blocked("visible_selector_timeout")

    def tap(self, pattern, package=PACKAGE):
        node = self.wait(pattern, package=package)
        self.adb("shell", "input", "tap", *node["center"])
        time.sleep(1)

    def see(self, pattern, seconds=20, package=PACKAGE):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            nodes = self.nodes()
            if any(n.get("package") == package and any(re.search(pattern, s, re.I) for s in labels(n)) for n in nodes):
                return nodes
            blocker = classify_blocker(nodes)
            if blocker:
                raise Blocked(blocker)
            time.sleep(1)
        raise Blocked("visible_content_timeout")

    def wait_meal_goal_content(self, seconds=40):
        size = re.search(r"Physical size: (\d+)x(\d+)", self.adb("shell", "wm", "size"))
        require(size, "screen_dimensions_unavailable")
        viewport = tuple(map(int, size.groups()))
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            nodes = self.nodes("premium-meal-calorie-goals")
            blocker = classify_blocker(nodes)
            if blocker:
                raise Blocked(blocker)
            try:
                return validate_meal_goal_content(nodes, viewport)
            except Blocked as exc:
                if str(exc) not in ("meal_calorie_goals_content_not_visible",
                                    "meal_calorie_goals_four_meals_not_visible"):
                    raise
            time.sleep(1)
        raise Blocked("meal_calorie_goals_content_timeout")

    def scroll_to(self, pattern):
        for direction in ("down", "up"):
            for _ in range(6):
                try:
                    return select(self.nodes(), pattern)
                except Blocked as exc:
                    if str(exc) != "visible_selector_missing_or_ambiguous":
                        raise
                    wm = self.adb("shell", "wm", "size")
                    size = re.search(r"Physical size: (\d+)x(\d+)", wm)
                    require(size, "screen_dimensions_unavailable")
                    w, h = map(int, size.groups())
                    y1, y2 = (h*3//4, h//3) if direction == "down" else (h//3, h*3//4)
                    self.adb("shell", "input", "swipe", w//2, y1, w//2, y2, 500)
        raise Blocked("visible_scroll_target_not_found")

    def reviewer_entry(self):
        end = time.monotonic() + 90
        account_gateway_opened = False
        while time.monotonic() < end:
            nodes = self.nodes()
            blocker = classify_blocker(nodes)
            if blocker:
                raise Blocked(blocker)
            try:
                select(nodes, r"Store reviewer access")
                self.nodes("reviewer-entry-before-credentials")
                self.tap(r"Store reviewer access")
                return
            except Blocked as exc:
                if str(exc) != "visible_selector_missing_or_ambiguous":
                    raise
            if any(n.get("package") == PACKAGE and n.get("class") == "android.widget.EditText" for n in nodes):
                self.scroll_to(r"Store reviewer access")
                continue
            if not account_gateway_opened:
                try:
                    select(nodes, r"Sign in|Sign in or create account")
                    self.tap(r"Sign in|Sign in or create account")
                    account_gateway_opened = True
                    continue
                except Blocked as exc:
                    if str(exc) != "visible_selector_missing_or_ambiguous":
                        raise
            time.sleep(1)
        raise Blocked("ordinary_account_gateway_or_reviewer_entry_not_reached")

    def authenticated_navigation(self):
        end = time.monotonic() + 90
        skipped_checkin = False
        self.demo_setup_evidence = None
        while time.monotonic() < end:
            nodes = self.nodes()
            blocker = classify_blocker(nodes)
            if blocker:
                if blocker == "onboarding_requires_explicit_test_profile_no_values_invented" and self.demo_setup_evidence is None:
                    from demo_setup import complete_demo_setup
                    self.demo_setup_evidence = complete_demo_setup(self,require,labels,select,PACKAGE)
                    end = time.monotonic() + 90
                    continue
                raise Blocked(blocker)
            try:
                select(nodes, r"More(?: Tab \d of \d)?")
                return skipped_checkin
            except Blocked as exc:
                if str(exc) != "visible_selector_missing_or_ambiguous":
                    raise
            if not skipped_checkin:
                try:
                    select(nodes, r"Skip today")
                    self.tap(r"Skip today")
                    skipped_checkin = True
                    continue
                except Blocked as exc:
                    if str(exc) != "visible_selector_missing_or_ambiguous":
                        raise
            time.sleep(1)
        raise Blocked("authenticated_main_navigation_not_reached")

    def more(self):
        for _ in range(4):
            try:
                node = select(self.nodes(), r"More(?: Tab \d of \d)?")
                self.adb("shell", "input", "tap", *node["center"])
                time.sleep(1)
                return
            except Blocked as exc:
                if str(exc) not in ("visible_selector_timeout", "visible_selector_missing_or_ambiguous"):
                    raise
                self.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        raise Blocked("cannot_return_to_visible_more_navigation")

    def field(self, index, value):
        commands = android_text_commands(value)
        node = select(self.nodes(), "", edit_index=index)
        self.adb("shell", "input", "tap", *node["center"])
        self.adb("shell", "input", "keyevent", "KEYCODE_MOVE_END")
        # Fresh form only; do not inject a clipboard/IME or access app internals.
        for command in commands:
            self.adb("shell", command)

    def start(self, chapter):
        require(self.proc is None, "recording_already_active")
        remote = f"/sdcard/bil-evidence-{chapter}.mp4"
        filename = self.out / "assets" / "raw" / f"{chapter}.mp4"
        filename.parent.mkdir(parents=True, exist_ok=True)
        self.current = (chapter, remote, filename, time.monotonic())
        self.proc = subprocess.Popen(["adb", "-s", self.serial, "shell", "screenrecord",
                                      "--time-limit", "150", "--bit-rate", "6000000", remote],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)
        require(self.proc.poll() is None, "native_screenrecord_failed")

    def stop(self):
        if self.proc is None:
            return
        chapter, remote, filename, started = self.current
        try:
            if self.proc.poll() is None:
                pids = self.adb("shell", "pidof screenrecord || true").strip().split()
                require(pids and all(p.isdigit() for p in pids), "screenrecord_process_missing")
                for pid in pids:
                    self.adb("shell", "kill", "-2", pid)
            self.proc.wait(timeout=15)
            self.adb("pull", remote, filename, timeout=45)
            require(filename.stat().st_size > 10000, "native_video_empty")
            probe = subprocess.run(["ffprobe", "-v", "error", "-show_format", "-show_streams",
                                    "-of", "json", str(filename)], capture_output=True, check=True)
            metadata = json.loads(probe.stdout)
            duration = float(metadata["format"]["duration"])
            require(duration > 0 and any(s.get("codec_type") == "video" for s in metadata["streams"]),
                    "native_video_not_decodable")
            self.clips.append({"path": filename.relative_to(self.out).as_posix(),
                               "sha256": sha256(filename), "duration_seconds": duration,
                               "chapter": chapter, "scope": "actual native recording, behavior not yet visually certified"})
        finally:
            if self.proc.poll() is None:
                self.proc.terminate()
            self.proc = None


def capture(args):
    require(os.environ.get("BIL_CAPTURE_SYNTHETIC_ACCOUNT_ACK") == "DEDICATED_REVIEW_ACCOUNT_ONLY",
            "synthetic_reviewer_ack_missing")
    email = os.environ.get("BIL_GOOGLE_REVIEWER_EMAIL", "")
    password = os.environ.get("BIL_GOOGLE_REVIEWER_PASSWORD", "")
    require(email and len(password) >= 8, "dedicated_google_reviewer_credentials_missing")
    expected_email_hash = os.environ.get("BIL_EXPECTED_REVIEWER_EMAIL_SHA256", "")
    require(re.fullmatch(r"[a-f0-9]{64}", expected_email_hash)
            and hashlib.sha256(email.strip().lower().encode()).hexdigest() == expected_email_hash,
            "reviewer_identity_hash_mismatch_refuse_purchase_test_account")
    out, inputs = Path(args.output), Path(args.inputs)
    out.mkdir(parents=True, exist_ok=True)
    apk = inputs / "BIL-Android33-derived-universal.apk"
    receipt = json_file(inputs / "BIL-android-recording-apk-receipt.json")
    validate_receipt(receipt, apk, args.source, os.environ.get("EXPECTED_UPLOAD_CERT_SHA256", ""))
    d = Device(args.serial, out, (email, password))
    result = {"schema": "bil.google_native_capture.v1", "status": "IN_PROGRESS", "source_sha": args.source, "apk_sha256": sha256(apk),
              "package": PACKAGE, "build": 33, "artifact_scope": "sideloaded-signed-release",
              "production_protections_changed": False, "entitlement_changes": False,
              "reviewer_email_sha256": expected_email_hash,
              "credential_recording": False, "appeal_sent": False, "stages": [], "blocked_chapters": [],
              "not_demonstrated": [MEAL_GOAL_CHAPTER, "Health Connect native optional-denial journey", "actual confirmed logging/readback",
                                   "live Coach answer and receipt", "Play billing and Integrity recognition",
                                   "privacy review of raw footage", "final composed MP4"]}
    try:
        require(args.serial.startswith("emulator-") and d.adb("shell", "getprop", "ro.kernel.qemu").strip() == "1",
                "require_disposable_emulator_not_personal_device")
        require(d.adb("shell", "getprop", "sys.boot_completed").strip() == "1", "emulator_not_booted")
        require(not d.adb("shell", "pm", "list", "packages", PACKAGE).strip(),
                "app_already_installed_refuse_clear_or_overwrite")
        require(not d.adb("shell", "pidof screenrecord || true").strip(), "another_recording_is_active")
        d.adb("install", apk, timeout=120)
        package_identity(d.adb("shell", "dumpsys", "package", PACKAGE))
        paths = d.adb("shell", "pm", "path", PACKAGE).strip().splitlines()
        require(len(paths) == 1 and paths[0].startswith("package:/data/app/"), "unexpected_installed_apk_path")
        installed = out / "installed-base.apk"
        d.adb("pull", paths[0][8:], installed, timeout=60)
        require(sha256(installed) == receipt["apk_sha256"], "installed_apk_bytes_mismatch")
        installed.unlink()
        result["stages"].append("INSTALLED_EXACT_SIGNED_APK_BYTES_VERIFIED")
        d.start("launch-and-reviewer-entry")
        d.adb("shell", "am", "start", "-n", PACKAGE + "/.MainActivity")
        d.reviewer_entry()
        d.wait(r"Store reviewer access", snapshot="reviewer-form-empty")
        # Flutter's editable hint need not be an independent UIAutomator text
        # node. Require the actual two enabled input controls, not a hint string.
        fields = d.nodes("reviewer-form-controls-empty")
        select(fields, "", edit_index=0)
        select(fields, "", edit_index=1)
        d.stop()  # Authentication input is deliberately not in any recording.
        d.field(0, email)
        d.field(1, password)
        d.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        d.tap(r"Sign in")
        if d.authenticated_navigation():
            result["stages"].append("OPTIONAL_DAILY_WEIGHT_CHECKIN_SKIPPED_NO_WEIGHT_LOGGED")
        result["stages"].append("REVIEWER_SIGNIN_REACHED_VISIBLE_MAIN_NAVIGATION")
        if getattr(d,"demo_setup_evidence",None):
            result["dedicated_demo_setup"] = d.demo_setup_evidence
            result["stages"].append("VISIBLE_DEDICATED_DEMO_SETUP_FINISH_CONFIRMED_NOT_PERSONAL_HEALTH_DATA")
        d.start("authenticated-visible-navigation")
        d.more()
        nodes = d.see(r"Active|Explore Premium|Retry subscription check", seconds=40)
        d.nodes("actual-membership-state")
        if visible_premium_active(nodes):
            result["stages"].append("MORE_PREMIUM_ACTIVE_VISIBLE")
            capture_premium_meal_goal_chapter(d, result)
            try:
                d.more()
                d.tap(r"AI Coach(?: Tab \d of \d)?")
                d.wait(r"Coach controls", seconds=45, snapshot="coach-conversation")
                d.tap(r"Coach controls")
                d.tap(r"Overview")
                d.wait(r"Chat", seconds=30, snapshot="coach-overview")
                result["stages"].append("COACH_OVERVIEW_VISIBLE_NOT_A_LIVE_RESPONSE_PROOF")
            except Blocked as exc:
                result["blocked_chapters"].append({"chapter": "coach", "code": str(exc)})
        else:
            result["blocked_chapters"].append({"chapter": "reviewer_premium_and_ai", "code": "visible_free_or_unverified_account_not_reviewer_full_access"})
        d.stop()
        d.more()
        d.start("privacy-controls")
        d.scroll_to(r"Sharing & Privacy")
        d.tap(r"Sharing & Privacy")
        d.wait(r"Diary sharing", snapshot="sharing-privacy")
        result["stages"].append("SHARING_PRIVACY_CONTROLS_VISIBLE")
        time.sleep(4)
        d.stop()
        d.more()
        d.start("native-health-permission-attempt")
        try:
            d.scroll_to(r"Apps & Devices")
            d.tap(r"Apps & Devices")
            nodes = d.see(r"Health Connect|Grant health access|Unavailable on this device|must be installed or updated", seconds=40)
            d.nodes("health-source-before-request")
            require(not any(re.search(r"Unavailable on this device|must be installed or updated", s, re.I) for n in nodes for s in labels(n)), "health_provider_unavailable_on_capture_runtime")
            d.tap(r"Grant health access")
            # The only cross-package tap allowed is declining a native Health Connect permission.
            native_package = None
            end = time.monotonic() + 30
            while time.monotonic() < end:
                nodes = d.nodes()
                native_package = next((p for p in ("com.google.android.healthconnect.controller", "com.android.healthconnect.controller") if any(n.get("package") == p for n in nodes)), None)
                if native_package:
                    break
                time.sleep(1)
            require(native_package, "native_health_permission_screen_not_observed")
            d.nodes("native-health-request-categories")
            time.sleep(4)
            d.tap(r"Don.t allow|Deny|Cancel", package=native_package)
            d.see(r"Permission was denied", seconds=30)
            d.nodes("health-permission-denied")
            d.more()
            d.tap(r"Home(?: Tab \d of \d)?")
            d.see(r"Calories|Fitness snapshot", seconds=30)
            result["stages"].append("NATIVE_HEALTH_DENIAL_AND_RETURN_TO_USABLE_HOME_VISIBLE")
            result["not_demonstrated"].remove("Health Connect native optional-denial journey")
        except Blocked as exc:
            result["blocked_chapters"].append({"chapter": "health_permissions", "code": str(exc)})
            d.nodes("health-attempt-blocked")
        result["status"] = "PARTIAL_NATIVE_EVIDENCE_REQUIRES_REMAINING_JOURNEYS_AND_VISUAL_REVIEW"
    except (Blocked, subprocess.SubprocessError, OSError, ValueError, ET.ParseError) as exc:
        result["status"] = "BLOCKED_NATIVE_JOURNEY_NOT_CERTIFIED"
        result["failure_code"] = str(exc) if isinstance(exc, Blocked) else type(exc).__name__
        # XML is sanitized and no logcat/token output is exported. Never resume recording an entered credential form.
        try:
            d.nodes("blocked-visible-ui-redacted")
        except Exception:
            result["ui_diagnostic"] = "unavailable"
    finally:
        exit_code = finalize_capture(d, out, result)
    print(json.dumps({k: result[k] for k in ("status", "source_sha", "build", "stages")}))
    return exit_code
    # Exit0 means capture control ran its available chapters, never a final video certification.


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="command", required=True)
    fetcher = sub.add_parser("fetch")
    for key in ("run-id", "artifact-id"):
        fetcher.add_argument("--" + key, required=True, type=int)
    fetcher.add_argument("--source", required=True)
    fetcher.add_argument("--output", required=True)
    recorder = sub.add_parser("capture")
    for key in ("source", "inputs", "output", "serial"):
        recorder.add_argument("--" + key, required=True)
    args = p.parse_args()
    try:
        return fetch(args) if args.command == "fetch" else capture(args)
    except (Blocked, subprocess.SubprocessError, OSError, ValueError, zipfile.BadZipFile) as exc:
        # Do not print subprocess args/environment, auth responses or credentials.
        print(json.dumps({"status": "BLOCKED", "code": str(exc) if isinstance(exc, Blocked) else type(exc).__name__}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
