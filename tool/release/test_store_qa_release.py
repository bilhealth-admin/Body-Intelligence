"""Mocked control-plane contracts ONLY; no Dart/native build, store or Production proof."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("store_qa_release", HERE / "store_qa_release.py")
qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qa)
MANIFEST = HERE.parent.parent / "docs/release/BIL_STORE_QA_CANDIDATE_2026-10-04.json"


def completed(code=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], code, stdout, stderr)


class StoreQaControlContractTest(unittest.TestCase):
    def setUp(self):
        self.raw = MANIFEST.read_bytes()
        self.manifest = json.loads(self.raw)
        self.digest = hashlib.sha256(self.raw).hexdigest()

    def environment(self, platform="ios", temporary=""):
        return {
            "BIL_STORE_QA_MANIFEST_SHA256": self.digest,
            "BIL_RELEASE_PRODUCTION": "true",
            "BIL_RELEASE_PLATFORM": platform,
            "BIL_SOURCE_COMMIT": qa.SOURCE_SHA,
            "BIL_AUDITED_SOURCE_COMMIT": qa.SOURCE_SHA,
            "BIL_COUNTERPART_AUDITED_SOURCE_COMMIT": qa.SOURCE_SHA,
            "BIL_RELEASE_EXPECTED_BUILD_NUMBER": str(self.manifest[platform]["build_number"]),
            "BIL_STORE_QA_BUILD_NUMBER": str(self.manifest[platform]["build_number"]),
            "RUNNER_TEMP": temporary,
            "GITHUB_TOKEN": "mock-token-no-real-credential",
            "GITHUB_SHA": "a" * 40,
        }

    def test_manifest_preserves_eight_open_release_gaps_for_both_platforms(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                manifest, target, digest = qa.load_manifest(
                    MANIFEST, platform, self.environment(platform))
                self.assertEqual(manifest["unresolved_review_count"], 8)
                self.assertEqual({gap["status"] for gap in manifest["known_release_gaps"]}, {"OPEN"})
                self.assertEqual(digest, self.digest)
                self.assertGreater(target["build_number"], 34 if platform == "ios" else 31)

    def test_digest_absence_and_mismatch_rejected(self):
        for bad in ("", "0" * 64):
            with self.subTest(digest=bad):
                with self.assertRaises(qa.GateError):
                    qa.load_manifest(MANIFEST, "ios", {"BIL_STORE_QA_MANIFEST_SHA256": bad})

    def test_duplicate_and_nonfinite_json_rejected(self):
        for raw in ('{"phase":"STORE_QA_ONLY","phase":"RELEASE"}', '{"value":NaN}'):
            with self.subTest(raw=raw):
                with self.assertRaises(qa.GateError):
                    qa._json(raw)

    def test_zero_closed_missing_or_duplicate_gaps_rejected(self):
        mutations = []
        candidate = copy.deepcopy(self.manifest)
        candidate["unresolved_review_count"] = 0
        mutations.append(candidate)
        candidate = copy.deepcopy(self.manifest)
        candidate["known_release_gaps"][0]["status"] = "WAIVED"
        mutations.append(candidate)
        candidate = copy.deepcopy(self.manifest)
        candidate["known_release_gaps"].pop()
        mutations.append(candidate)
        candidate = copy.deepcopy(self.manifest)
        candidate["known_release_gaps"][0] = candidate["known_release_gaps"][1]
        mutations.append(candidate)
        for candidate in mutations:
            with self.assertRaises(qa.GateError):
                qa.validate_manifest(candidate, "ios")

    def test_scope_source_old_build_and_production_track_rejected(self):
        for key, value in (("phase", "PUBLIC_RELEASE"), ("source_sha", "0" * 40),
                           ("public_release_ready", True), ("no_review_submission", False),
                           ("no_production_rollout", False)):
            candidate = copy.deepcopy(self.manifest)
            candidate[key] = value
            with self.subTest(key=key), self.assertRaises(qa.GateError):
                qa.validate_manifest(candidate, "ios")
        for key, value in (("track", "production"), ("build_number", 31),
                           ("release_status", "inProgress"),
                           ("changes_not_sent_for_review", False),
                           ("review_boundary", "IGNORE")):
            candidate = copy.deepcopy(self.manifest)
            candidate["android"][key] = value
            with self.subTest(android_key=key), self.assertRaises(qa.GateError):
                qa.validate_manifest(candidate, "android")
        candidate = copy.deepcopy(self.manifest)
        candidate["ios"]["build_number"] = 34
        with self.assertRaises(qa.GateError):
            qa.validate_manifest(candidate, "ios")

    def mocked_ci(self, mutate_run=None, mutate_workflow=None):
        calls = []
        def get(path, token):
            self.assertEqual(token, "mock-token-no-real-credential")
            calls.append(path)
            for item in self.manifest["upstream_ci"]:
                if path == "actions/runs/" + str(item["run_id"]):
                    result = {
                        "id": item["run_id"], "head_sha": qa.SOURCE_SHA,
                        "status": "completed", "conclusion": "success",
                        "workflow_id": item["workflow_id"], "name": item["workflow_name"],
                        "path": item["workflow_path"],
                        "repository": {"full_name": qa.REPOSITORY},
                        "head_repository": {"full_name": qa.REPOSITORY},
                    }
                    if mutate_run:
                        mutate_run(result)
                    return result
                if path == "actions/workflows/" + str(item["workflow_id"]):
                    result = {"id": item["workflow_id"], "name": item["workflow_name"],
                              "path": item["workflow_path"]}
                    if mutate_workflow:
                        mutate_workflow(result)
                    return result
            self.fail("Unexpected network endpoint")
        return get, calls

    def test_verified_ci_requires_all_three_exact_run_and_workflow_identities(self):
        get, calls = self.mocked_ci()
        receipt = qa.verify_ci(self.manifest, self.environment(), get)
        self.assertEqual(len(receipt), 3)
        self.assertEqual(len(calls), 6)
        self.assertEqual({item["source_sha"] for item in receipt}, {qa.SOURCE_SHA})
        self.assertTrue(all(path.startswith(("actions/runs/", "actions/workflows/"))
                            for path in calls))

    def test_ci_missing_token_is_denied_before_any_network(self):
        get, calls = self.mocked_ci()
        with self.assertRaises(qa.GateError):
            qa.verify_ci(self.manifest, {}, get)
        self.assertEqual(calls, [])

    def test_wrong_sha_failure_pending_wrong_workflow_and_fork_rejected(self):
        cases = (
            ("head_sha", "0" * 40), ("conclusion", "failure"), ("status", "in_progress"),
            ("workflow_id", 1), ("name", "Unrelated workflow"), ("path", "other.yml"),
            ("head_repository", {"full_name": "someone/Body-Intelligence"}),
        )
        for key, value in cases:
            with self.subTest(key=key):
                get, _ = self.mocked_ci(lambda row: row.update({key: value}))
                with self.assertRaises(qa.GateError):
                    qa.verify_ci(self.manifest, self.environment(), get)
        get, _ = self.mocked_ci(mutate_workflow=lambda row: row.update({"name": "Wrong workflow"}))
        with self.assertRaises(qa.GateError):
            qa.verify_ci(self.manifest, self.environment(), get)

    def source_runner(self, *, head=qa.SOURCE_SHA, dirty="", controller="a" * 40,
                      controller_dirty=False):
        def run(command, *, cwd, env=None, timeout=300):
            if command == ["git", "rev-parse", "--verify", "HEAD"]:
                return completed(stdout=head + "\n")
            if command == ["git", "status", "--porcelain", "--untracked-files=all"]:
                return completed(stdout=dirty)
            if command == ["git", "-C", "control", "rev-parse", "--verify", "HEAD"]:
                return completed(stdout=controller + "\n")
            if command == ["git", "-C", "control", "diff", "--quiet", "HEAD", "--"]:
                return completed(1 if controller_dirty else 0)
            self.fail("Unexpected subprocess")
        return run

    def test_wrong_head_dirty_checkout_platform_source_or_build_binding_rejected(self):
        target = self.manifest["ios"]
        for run in (self.source_runner(head="0" * 40), self.source_runner(dirty=" M app.dart\n")):
            with self.assertRaises(qa.GateError):
                qa.validate_source(self.manifest, target, "ios", self.environment(), HERE, run)
        for key, value in (
            ("BIL_RELEASE_PRODUCTION", "false"), ("BIL_RELEASE_PLATFORM", "android"),
            ("BIL_SOURCE_COMMIT", "0" * 40), ("BIL_AUDITED_SOURCE_COMMIT", ""),
            ("BIL_COUNTERPART_AUDITED_SOURCE_COMMIT", "0" * 40),
            ("BIL_RELEASE_EXPECTED_BUILD_NUMBER", "34"), ("BIL_STORE_QA_BUILD_NUMBER", ""),
            ("GITHUB_SHA", ""),
        ):
            environment = self.environment()
            environment[key] = value
            with self.subTest(key=key), self.assertRaises(qa.GateError):
                qa.validate_source(self.manifest, target, "ios", environment,
                                   HERE, self.source_runner())

    def test_configuration_accepts_only_exact_untracked_control_and_named_receipts(self):
        status = "?? control/\n" + "".join("?? " + path + "\n" for path in qa.PREBUILD_RECEIPTS)
        qa.validate_source(self.manifest, self.manifest["ios"], "ios", self.environment(),
                           HERE, self.source_runner(dirty=status))
        for unexpected in ("?? BIL-unreviewed.txt\n", "?? assets/fake.png\n",
                           "?? control-forged/\n", " M pubspec.lock\n", " M lib/main.dart\n"):
            with self.subTest(status=unexpected), self.assertRaises(qa.GateError):
                qa.validate_source(self.manifest, self.manifest["ios"], "ios",
                                   self.environment(), HERE, self.source_runner(dirty=unexpected))
        for runner in (self.source_runner(controller="b" * 40),
                       self.source_runner(controller_dirty=True)):
            with self.assertRaises(qa.GateError):
                qa.validate_source(self.manifest, self.manifest["ios"], "ios",
                                   self.environment(), HERE, runner)

    def test_after_build_keeps_app_and_lock_clean_without_rejecting_named_evidence(self):
        status = "".join("?? " + path + "\n" for path in qa.ANDROID_BUILD_RECEIPTS)
        qa.validate_source(self.manifest, self.manifest["android"], "android",
                           self.environment("android"), HERE, self.source_runner(dirty=status),
                           after_build=True)
        for dirty in (" M lib/main.dart\n", " M pubspec.lock\n", " M android/app/build.gradle\n",
                      "?? BIL-android-16k-evidence/forged.json\n", "?? lib/injected.dart\n"):
            with self.subTest(dirty=dirty), self.assertRaises(qa.GateError):
                qa.validate_source(self.manifest, self.manifest["android"], "android",
                                   self.environment("android"), HERE,
                                   self.source_runner(dirty=dirty), after_build=True)

    def test_original_production_fail78_is_mandatory_and_any_other_result_rejected(self):
        expected = "\n".join(qa.EXPECTED_FAILURE) + "\n"
        qa.qualify_validator_result(completed(78, stderr=expected))
        for result in (
            completed(0, stdout="RELEASE_CONFIGURATION_GATE=PASS\n"),
            completed(1, stderr=expected), completed(78, stderr=""),
            completed(78, stderr=expected + "unaudited_source_commit: bad\n"),
            completed(78, stderr=expected + expected),
            completed(78, stdout="AUDITED_SOURCE_COMMIT_GATE=PASS\n", stderr=expected),
        ):
            with self.assertRaises(qa.GateError):
                qa.qualify_validator_result(result)

    def test_ephemeral_freeze_keeps_positive8_and_original_fail_visible(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temporary:
                environment = self.environment(platform, temporary)
                snapshots = []
                source_run = self.source_runner()
                def run(command, *, cwd, env=None, timeout=300):
                    if command[0] == "git":
                        return source_run(command, cwd=cwd, env=env)
                    self.assertEqual(command, ["dart", "run",
                                              "tool/release/validate_release_configuration.dart"])
                    freeze = Path(env["BIL_RELEASE_MANIFEST_PATH"])
                    self.assertTrue(freeze.is_relative_to(Path(temporary)))
                    raw = freeze.read_bytes()
                    snapshots.append(freeze)
                    self.assertIn(b"UNRESOLVED_REVIEW_COUNT: 8\n", raw)
                    self.assertNotIn(b"UNRESOLVED_REVIEW_COUNT: 0", raw)
                    self.assertIn(b"CANDIDATE_FROZEN_OR_ACCEPTED: YES", raw)
                    self.assertIn(b"PUBLIC_RELEASE_READY: NO", raw)
                    self.assertEqual(env["BIL_AUDITED_FREEZE_MANIFEST_SHA256"],
                                     hashlib.sha256(raw).hexdigest())
                    return completed(78, stderr="\n".join(qa.EXPECTED_FAILURE) + "\n")
                stdout, stderr = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                    qa.configuration(self.manifest, self.manifest[platform], platform,
                                     self.digest, environment, HERE, run)
                self.assertIn("RELEASE_CONFIGURATION_GATE=FAIL", stderr.getvalue())
                self.assertIn("STORE_QA_CONFIGURATION_GATE=PASS", stdout.getvalue())
                self.assertIn("PUBLIC_RELEASE_READY=NO", stdout.getvalue())
                self.assertNotIn("RELEASE_CONFIGURATION_GATE=PASS",
                                 stdout.getvalue() + stderr.getvalue())
                self.assertTrue(all(not path.exists() for path in snapshots))
                checkpoint = json.loads(qa._checkpoint_path(environment, platform).read_bytes())
                self.assertEqual(checkpoint["source_sha"], qa.SOURCE_SHA)
                self.assertEqual(checkpoint["controller_sha"], environment["GITHUB_SHA"])
                self.assertEqual(checkpoint["unresolved_review_count"], 8)
                self.assertEqual(checkpoint["original_production_gate"], "FAIL")

    def test_missing_runner_temp_fails_before_dart(self):
        with self.assertRaises(qa.GateError):
            qa.configuration(self.manifest, self.manifest["ios"], "ios", self.digest,
                             self.environment(), HERE, self.source_runner())

    def test_redirect_is_denied_without_forwarding_credential(self):
        with self.assertRaises(qa.GateError):
            qa._NoRedirect().redirect_request(None, None, 302, "",
                                             {}, "https://other.invalid/endpoint")

    def artifact_receipts(self, root, aab, environment):
        source = qa.validate_source(self.manifest, self.manifest["android"], "android",
                                    environment, root, self.source_runner(), after_build=True)
        checkpoint = dict(source, manifest_sha256=self.digest, phase="STORE_QA_ONLY",
                          configuration_gate="PASS", original_production_gate="FAIL",
                          unresolved_review_count=8)
        qa._checkpoint_path(environment, "android").write_text(json.dumps(checkpoint))
        receipts = {
            "BIL-android-aab.sha256": hashlib.sha256(aab.read_bytes()).hexdigest() + "  " + str(aab),
            "BIL-android-aab.size": str(aab.stat().st_size),
            "BIL-source-head.txt": qa.SOURCE_SHA,
            "BIL-control-head.txt": environment["GITHUB_SHA"],
            "BIL-build-number.txt": "BUILD_NUMBER=32",
            "BIL-android-upload-certificate.txt": "ANDROID_UPLOAD_CERTIFICATE_SHA256=MATCH",
            "BIL-android-signature.txt": "MOCKED_SIGNING_RECEIPT_NOT_NATIVE_PROOF",
        }
        for name, text in receipts.items():
            (root / name).write_text(text + "\n")
        (root / "BIL-store-qa-manifest.json").write_bytes(self.raw)
        (root / "BIL-android-16k-evidence").mkdir()
        (root / "BIL-android-16k-evidence/BIL-android-artifact-version.json").write_text(
            json.dumps(dict(package=qa.APPLICATION_ID, version_name="1.0.0", version_code="32")))
        return source

    def test_play_upload_delegates_only_reviewed_sibling_and_preserves_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            aab = Path(temporary) / "candidate.aab"
            aab.write_bytes(b"MOCKED_ARTIFACT_NOT_AN_ANDROID_BUILD")
            environment = self.environment("android", temporary)
            self.artifact_receipts(Path(temporary), aab, environment)
            calls = []
            source = self.source_runner()
            def run(command, *, cwd, env=None, timeout=300):
                if command[0] == "git":
                    return source(command, cwd=cwd, env=env)
                calls.append((command, env, timeout))
                return completed(stdout="MOCKED_UPLOAD_BOUNDARY_ONLY\n")
            with mock.patch.object(qa.Path, "is_file", return_value=True):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    qa.upload_play(self.manifest, self.manifest["android"], aab,
                                   MANIFEST, environment, Path(temporary), run,
                                   publishing_state_checked=True)
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0][0], [qa.sys.executable,
                str(HERE / "store_qa_play_upload.py"), "--aab", str(aab.resolve()),
                "--manifest", str(MANIFEST.resolve()), "--owner-publishing-state-checked"])
            self.assertEqual(calls[0][1], environment)
            self.assertEqual(calls[0][2], 1800)
            self.assertIn("PUBLIC_RELEASE_READY=NO", output.getvalue())

    def test_play_upload_missing_artifact_or_sibling_fails_before_delegate(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = self.environment("android", temporary)
            with self.assertRaises(qa.GateError):
                qa.upload_play(self.manifest, self.manifest["android"],
                               Path(temporary) / "missing.aab", MANIFEST,
                               environment, HERE, self.source_runner(),
                               publishing_state_checked=True)
            aab = Path(temporary) / "candidate.aab"
            aab.write_bytes(b"MOCKED_ARTIFACT_NOT_AN_ANDROID_BUILD")
            child = HERE / "store_qa_play_upload.py"
            actual_is_file = qa.Path.is_file
            def exists(path):
                return False if path == child else actual_is_file(path)
            with mock.patch.object(qa.Path, "is_file", exists):
                with self.assertRaises(qa.GateError):
                    qa.upload_play(self.manifest, self.manifest["android"], aab,
                                   MANIFEST, environment, HERE, self.source_runner(),
                                   publishing_state_checked=True)

    def test_play_upload_child_failure_is_not_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            aab = Path(temporary) / "candidate.aab"
            aab.write_bytes(b"MOCKED_ARTIFACT_NOT_AN_ANDROID_BUILD")
            environment = self.environment("android", temporary)
            self.artifact_receipts(Path(temporary), aab, environment)
            source = self.source_runner()
            def run(command, *, cwd, env=None, timeout=300):
                return source(command, cwd=cwd, env=env) if command[0] == "git" else completed(78)
            with mock.patch.object(qa.Path, "is_file", return_value=True):
                with self.assertRaises(qa.GateError):
                    qa.upload_play(self.manifest, self.manifest["android"], aab,
                                   MANIFEST, environment, Path(temporary), run,
                                   publishing_state_checked=True)

    def test_no_prebuild_checkpoint_or_unbound_signed_artifact_can_upload(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            aab = root / "candidate.aab"
            aab.write_bytes(b"MOCKED_ARTIFACT_NOT_AN_ANDROID_BUILD")
            environment = self.environment("android", temporary)
            source = self.artifact_receipts(root, aab, environment)
            for name, replacement in (
                ("BIL-android-aab.sha256", "0" * 64 + "  " + str(aab)),
                ("BIL-android-upload-certificate.txt", "NO_MATCH"),
                ("BIL-source-head.txt", "0" * 40),
                ("BIL-android-16k-evidence/BIL-android-artifact-version.json", "{}"),
            ):
                path, original = root / name, (root / name).read_bytes()
                path.write_text(replacement)
                with self.subTest(receipt=name), self.assertRaises(qa.GateError):
                    qa.validate_android_artifact(self.manifest, self.manifest["android"], aab,
                                                 self.digest, source, environment, root)
                path.write_bytes(original)
            qa._checkpoint_path(environment, "android").unlink()
            with self.assertRaises(qa.GateError):
                qa.validate_android_artifact(self.manifest, self.manifest["android"], aab,
                                             self.digest, source, environment, root)

    def test_upload_requires_explicit_owner_check_before_subprocess(self):
        runner = mock.Mock(side_effect=AssertionError("Must not run without owner check"))
        with self.assertRaises(qa.GateError):
            qa.upload_play(self.manifest, self.manifest["android"], "candidate.aab", MANIFEST,
                           self.environment("android"), HERE, runner)
        runner.assert_not_called()


if __name__ == "__main__":
    unittest.main()

