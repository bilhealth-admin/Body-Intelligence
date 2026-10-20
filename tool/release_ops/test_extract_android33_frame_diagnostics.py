#!/usr/bin/env python3
"""Offline controls: synthetic metadata/ZIPs only; never call gh or a network."""

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

import extract_android33_frame_diagnostics as extractor


def metadata():
    run = {"id": extractor.RUN, "head_sha": extractor.PRODUCER_HEAD,
           "path": extractor.WORKFLOW, "run_attempt": 1,
           "head_branch": "audit/frozen-native-security-20261020",
           "status": "completed", "conclusion": "failure"}
    job = {"id": extractor.JOB, "run_id": extractor.RUN,
           "name": "CodeQL (java-kotlin)", "status": "completed", "conclusion": "failure"}
    artifact = {"id": extractor.ARTIFACT, "name": extractor.NAME,
                "size_in_bytes": extractor.SIZE, "digest": "sha256:" + extractor.DIGEST,
                "expired": False, "workflow_run": {"id": extractor.RUN,
                "head_sha": extractor.PRODUCER_HEAD, "repository_id": 1300988782,
                "head_repository_id": 1300988782}}
    return run, job, artifact


class ExtractorTest(unittest.TestCase):
    def _zip(self, directory, entries):
        archive = Path(directory) / "fixture.zip"
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(archive, "w") as target:
                for name, content in entries:
                    target.writestr(name, content)
        return archive

    def test_exact_producer_metadata_is_accepted(self):
        extractor.validate_metadata(*metadata())

    def test_wrong_run_job_artifact_and_digest_all_block(self):
        for index, field, value in (
            (0, "head_sha", "a" * 40), (0, "run_attempt", 2),
            (0, "path", ".github/workflows/other.yml"),
            (1, "run_id", 1), (1, "name", "CodeQL (swift)"),
            (2, "id", 1), (2, "name", "another-platform"),
            (2, "size_in_bytes", 1), (2, "digest", "sha256:" + "0" * 64),
            (2, "expired", True),
        ):
            with self.subTest(index=index, field=field):
                fixture = list(metadata())
                fixture[index][field] = value
                with self.assertRaises(ValueError):
                    extractor.validate_metadata(*fixture)

    def test_frame_identity_numbers_and_raw_json_bytes_are_preserved(self):
        raw = b'{"first_absent_frame_number":701,"native_frame_timings":[{"frame_number":700},{"frame_number":702}]}\n'
        with tempfile.TemporaryDirectory() as directory:
            archive = self._zip(directory, [("journey/native-metadata.json", raw),
                ("console.log", "timing missing\n"), ("app.apk", b"APK"),
                ("capture.png", b"PNG"), ("video.mp4", b"MP4"),
                ("raw-pixels.txt", "pixel bytes")])
            output = Path(directory) / "out"
            receipt = extractor.extract_diagnostics(archive, output)
            self.assertEqual((output / "diagnostics/journey/native-metadata.json").read_bytes(), raw)
            self.assertEqual(receipt["files"], 2)
            self.assertFalse((output / "diagnostics/app.apk").exists())
            self.assertFalse((output / "diagnostics/raw-pixels.txt").exists())

    def test_path_escape_absolute_windows_and_controls_are_rejected(self):
        for name in ("../outside.json", "/absolute.json", "C:/outside.json", "dir\\outside.json", "bad\nname.json"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                archive = self._zip(directory, [(name, "{}")])
                with self.assertRaises(ValueError):
                    extractor.extract_diagnostics(archive, Path(directory) / "out")
                self.assertFalse((Path(directory) / "outside.json").exists())

    def test_symlinks_and_encrypted_entries_are_rejected(self):
        symlink = zipfile.ZipInfo("linked.json")
        symlink.external_attr = 0o120777 << 16
        with self.assertRaises(ValueError):
            extractor.safe_member(symlink)
        encrypted = zipfile.ZipInfo("encrypted.json")
        encrypted.flag_bits |= 1
        with self.assertRaises(ValueError):
            extractor.safe_member(encrypted)

    def test_duplicate_names_are_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self._zip(directory, [("native-metadata.json", "{}"), ("native-metadata.json", "[]")])
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                extractor.extract_diagnostics(archive, Path(directory) / "out")

    def test_per_file_bound_is_enforced_without_extracting_large_logs(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self._zip(directory, [("native-metadata.json", "{}"), ("large.log", "x" * 64)])
            output = Path(directory) / "out"
            with patch.object(extractor, "MAX_FILE", 16):
                extractor.extract_diagnostics(archive, output)
            self.assertFalse((output / "diagnostics/large.log").exists())

    def test_total_bound_prioritizes_native_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self._zip(directory, [("aaa.log", "x" * 20), ("journey/native-metadata.json", "{}")])
            output = Path(directory) / "out"
            with patch.object(extractor, "MAX_TOTAL", 16):
                receipt = extractor.extract_diagnostics(archive, output)
            self.assertEqual(receipt["diagnostic_bytes"], 2)
            self.assertTrue((output / "diagnostics/journey/native-metadata.json").is_file())
            self.assertFalse((output / "diagnostics/aaa.log").exists())

    def test_missing_native_timing_report_is_blocked(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self._zip(directory, [("console.log", "missing data")])
            with self.assertRaisesRegex(ValueError, "timing report"):
                extractor.extract_diagnostics(archive, Path(directory) / "out")

    def test_binary_disguised_as_text_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self._zip(directory, [("native-metadata.json", "{}"), ("binary.log", b"\xff\xfe")])
            with self.assertRaises(UnicodeDecodeError):
                extractor.extract_diagnostics(archive, Path(directory) / "out")


if __name__ == "__main__":
    unittest.main(verbosity=2)
