#!/usr/bin/env python3
"""Read only: verify one frozen CI artifact and export bounded text diagnostics."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
import zipfile

REPO = "bilhealth-admin/Body-Intelligence"
RUN = 39418226826
JOB = 118612376688
ARTIFACT = 12264505409
PRODUCER_HEAD = "1f49ddfe2539bda529904aa5111a99eea75ec868"
APP_SOURCE = "5da21a5660b26e59e9ead7b0927d4ed7cf2c3996"
NAME = f"bil-android33-native-integration-{APP_SOURCE}"
SIZE = 270099580
DIGEST = "ad9bd70cf2a68303077a2158cb5ce300aefcf703c55fd0a6f6729760a9ae0f77"
WORKFLOW = ".github/workflows/bil_frozen_native_security_20261020.yml"
WORKFLOW_SHA256 = "65f6d7c292b19cfcc9bb44fed8ab5ee6b7179f5cb442b5c92d130342adb5e4a8"
MAX_FILE = 24 * 1024 * 1024
MAX_TOTAL = 24 * 1024 * 1024
MAX_INDEX = 2 * 1024 * 1024
EXTENSIONS = {".json", ".jsonl", ".ndjson", ".txt", ".log", ".csv"}


def github_json(endpoint: str):
    result = subprocess.run(["gh", "api", endpoint], capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError("GitHub read failed; response/token deliberately not logged")
    if len(result.stdout) > 8 * 1024 * 1024:
        raise ValueError("Unexpected oversized GitHub metadata")
    return json.loads(result.stdout)


def validate_metadata(run: dict, job: dict, artifact: dict) -> None:
    if (run.get("id") != RUN or run.get("head_sha") != PRODUCER_HEAD
            or run.get("path") != WORKFLOW or run.get("run_attempt") != 1
            or run.get("head_branch") != "audit/frozen-native-security-20261020"
            or run.get("status") != "completed" or run.get("conclusion") != "failure"):
        raise ValueError("Producer run identity/type/attempt changed")
    if (job.get("id") != JOB or job.get("run_id") != RUN
            or job.get("name") != "CodeQL (java-kotlin)"
            or job.get("status") != "completed" or job.get("conclusion") != "failure"):
        raise ValueError("Producer Android job identity/type changed")
    identity = artifact.get("workflow_run", {})
    if (artifact.get("id") != ARTIFACT or artifact.get("name") != NAME
            or artifact.get("size_in_bytes") != SIZE
            or artifact.get("digest") != "sha256:" + DIGEST
            or artifact.get("expired") is not False
            or identity.get("id") != RUN or identity.get("head_sha") != PRODUCER_HEAD
            or identity.get("repository_id") != 1300988782
            or identity.get("head_repository_id") != 1300988782):
        raise ValueError("Exact Android artifact identity/digest/type changed")


def safe_member(info: zipfile.ZipInfo) -> str:
    name = info.filename
    path = PurePosixPath(name)
    if (not name or len(name) > 512 or "\\" in name or ":" in name
            or any(ord(char) < 32 or ord(char) == 127 for char in name)
            or path.is_absolute() or ".." in path.parts
            or stat.S_ISLNK(info.external_attr >> 16) or info.flag_bits & 1):
        raise ValueError("Unsafe ZIP entry rejected before any diagnostic extraction")
    return path.as_posix()


def extract_diagnostics(archive: Path, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    index = []
    total = 0
    selected = []
    with zipfile.ZipFile(archive) as source:
        members = source.infolist()
        if len(members) > 4096:
            raise ValueError("ZIP entry count exceeds the bounded diagnostic scope")
        names = [safe_member(info) for info in members]
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP names are ambiguous")
        entries = list(zip(members, names))
        entries.sort(key=lambda pair: (
            0 if PurePosixPath(pair[1]).name == "native-metadata.json" else
            1 if re.search(r"timing|warmup|trace|failure", pair[1], re.I) else 2,
            pair[1],
        ))
        for info, name in entries:
            record = {"path": name, "uncompressed_bytes": info.file_size}
            if info.is_dir():
                record["status"] = "directory"
            elif (PurePosixPath(name).suffix.lower() not in EXTENSIONS
                  or re.search(r"(?:pixels|pixel[-_]raw|raw[-_]pixels|rgba|argb|bgra|framebuffer)", name, re.I)):
                record["status"] = "omitted_binary_video_apk_or_pixel_raw"
            elif info.file_size > MAX_FILE:
                record["status"] = "omitted_text_file_over24MiB"
            elif total + info.file_size > MAX_TOTAL:
                record["status"] = "omitted_total_text_budget24MiB"
            else:
                with source.open(info) as stream:
                    content = stream.read(MAX_FILE + 1)
                if len(content) != info.file_size or len(content) > MAX_FILE:
                    raise ValueError("ZIP member length exceeded its verified bound")
                content.decode("utf-8")  # Refuse binary content disguised as text.
                target = output / "diagnostics" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                record.update(status="extracted_exact_bytes", sha256=hashlib.sha256(content).hexdigest())
                total += len(content)
                selected.append(name)
            index.append(record)
    encoded = json.dumps(index, indent=2).encode()
    if len(encoded) > MAX_INDEX:
        raise ValueError("ZIP index exceeds2MiB output bound")
    (output / "archive-index.json").write_bytes(encoded)
    if not any(PurePosixPath(name).name == "native-metadata.json" for name in selected):
        raise ValueError("Bounded native-metadata.json timing report was not extracted")
    return {"files": len(selected), "diagnostic_bytes": total,
            "max_output_bytes": MAX_TOTAL + MAX_INDEX + 1024 * 1024,
            "native_metadata_extracted": True, "raw_bytes_preserved": True}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = {"status": "BLOCKED", "producer_run": RUN, "producer_job": JOB,
              "producer_head": PRODUCER_HEAD, "application_source": APP_SOURCE,
              "source_artifact": ARTIFACT, "source_artifact_sha256": DIGEST,
              "controller_head": os.environ.get("GITHUB_SHA"),
              "read_only": True, "tests_rerun": False, "exact_frame_requirement_changed": False}
    try:
        if os.environ.get("GITHUB_REPOSITORY") != REPO:
            raise ValueError("This extractor is bound to the BIL repository")
        run = github_json(f"repos/{REPO}/actions/runs/{RUN}")
        job = github_json(f"repos/{REPO}/actions/jobs/{JOB}")
        artifacts = github_json(f"repos/{REPO}/actions/runs/{RUN}/artifacts?per_page=100")
        matches = [item for item in artifacts.get("artifacts", []) if item.get("id") == ARTIFACT]
        if len(matches) != 1:
            raise ValueError("Expected one exact source artifact")
        artifact = matches[0]
        validate_metadata(run, job, artifact)
        workflow = github_json(f"repos/{REPO}/contents/{WORKFLOW}?ref={PRODUCER_HEAD}")
        original = base64.b64decode(workflow["content"], validate=False)
        if hashlib.sha256(original).hexdigest() != WORKFLOW_SHA256:
            raise ValueError("Producer workflow source binding does not match the reviewed bytes")
        (output / "verified-producer.json").write_text(json.dumps({
            "run": {key: run.get(key) for key in ("id", "head_sha", "head_branch", "path", "run_attempt", "status", "conclusion")},
            "job": {key: job.get(key) for key in ("id", "run_id", "name", "status", "conclusion")},
            "artifact": artifact, "producer_workflow_sha256": WORKFLOW_SHA256,
            "application_checkout_in_producer": APP_SOURCE,
        }, indent=2) + "\n")
        with tempfile.TemporaryDirectory(prefix="bil-exact-frame-") as directory:
            archive = Path(directory) / "source.zip"
            with archive.open("wb") as stream:
                download = subprocess.run(
                    ["gh", "api", f"repos/{REPO}/actions/artifacts/{ARTIFACT}/zip"],
                    stdout=stream, stderr=subprocess.PIPE, timeout=240,
                )
            if download.returncode or archive.stat().st_size != SIZE:
                raise ValueError("Exact artifact download failed or its byte count changed")
            with archive.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            if digest != DIGEST:
                raise ValueError("Downloaded ZIP does not match the exact source SHA256")
            result.update(extract_diagnostics(archive, output), status="VERIFIED_DIAGNOSTICS_EXTRACTED")
    except Exception as error:
        result.update(failure_type=type(error).__name__, failure=str(error))
        raise
    finally:
        (output / "extraction-result.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
