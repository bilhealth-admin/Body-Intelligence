#!/usr/bin/env python3
"""Generate a deterministic, read-only release-candidate manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_record(path: str, index: dict[str, tuple[str, str]]) -> dict[str, Any]:
    content = (ROOT / path).read_bytes()
    mode, blob = index[path]
    return {
        "path": path,
        "bytes": len(content),
        "mode": mode,
        "git_blob": blob,
        "sha256": digest(content),
    }


def tracked_index() -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    for record in git("ls-files", "-s", "-z").split("\0"):
        if not record:
            continue
        meta, path = record.split("\t", 1)
        mode, blob, _stage = meta.split()
        result[path] = (mode, blob)
    return result


def parse_pub_lock(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    packages: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        package = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", raw)
        if package:
            if current and current.get("version"):
                packages.append(current)
            current = {"name": package.group(1), "ecosystem": "Pub"}
            continue
        if current is None:
            continue
        version = re.match(r'^    version:\s*["\']?([^"\']+)["\']?\s*$', raw)
        source = re.match(r"^    source:\s*(\S+)\s*$", raw)
        dependency = re.match(r"^    dependency:\s*(\S+)\s*$", raw)
        if version:
            current["version"] = version.group(1)
        elif source:
            current["source"] = source.group(1)
        elif dependency:
            current["dependency"] = dependency.group(1)
    if current and current.get("version"):
        packages.append(current)
    return sorted(packages, key=lambda item: item["name"])


def parse_package_lock(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    packages: list[dict[str, str]] = []
    for key, value in (data.get("packages") or {}).items():
        if not key or not isinstance(value, dict) or not value.get("version"):
            continue
        name = value.get("name")
        if not name:
            marker = "node_modules/"
            if marker in key:
                name = key.split(marker, 1)[1]
        if not name:
            continue
        packages.append({
            "name": str(name),
            "version": str(value["version"]),
            "ecosystem": "npm",
            "lockfile": path.as_posix(),
        })
    return sorted(packages, key=lambda item: (item["name"], item["version"]))


def parse_deno_lock(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    result: list[dict[str, str]] = []
    for ecosystem in ("npm", "jsr"):
        for coordinate in sorted((data.get(ecosystem) or {}).keys()):
            if "@" not in coordinate:
                continue
            name, version = coordinate.rsplit("@", 1)
            result.append({
                "name": name,
                "version": version,
                "ecosystem": ecosystem,
                "lockfile": path.as_posix(),
            })
    return result


def records(paths: list[str], index: dict[str, tuple[str, str]]) -> list[dict[str, Any]]:
    return [file_record(path, index) for path in sorted(paths) if path in index]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    head = git("rev-parse", "HEAD").strip()
    if head != args.expected_sha:
        raise SystemExit(f"RC_SHA_MISMATCH expected={args.expected_sha} actual={head}")
    status = git("status", "--porcelain=v1", "--untracked-files=all").splitlines()
    if status:
        raise SystemExit("RC_WORKTREE_NOT_CLEAN: " + " | ".join(status))

    index = tracked_index()
    all_paths = sorted(index)
    all_files = records(all_paths, index)
    merkle = hashlib.sha256()
    for item in all_files:
        merkle.update(item["path"].encode("utf-8"))
        merkle.update(b"\0")
        merkle.update(item["sha256"].encode("ascii"))
        merkle.update(b"\n")

    migrations = [p for p in all_paths if p.startswith("supabase/migrations/") and p.endswith(".sql")]
    edge_sources = [
        p for p in all_paths
        if p.startswith("supabase/functions/")
        and not p.endswith("/deno.lock")
        and Path(p).suffix.lower() in {".ts", ".js", ".json", ".jsonc"}
    ]
    cloudflare = [
        p for p in all_paths
        if p.startswith("cloudflare/")
        or p in {"tool/release/bilhealth_site_worker.mjs", "tool/release/bilhealth_site_worker.test.mjs"}
    ]
    ios_config = [
        p for p in all_paths
        if p.startswith("ios/")
        and (
            Path(p).suffix.lower() in {".plist", ".xcprivacy", ".entitlements", ".pbxproj", ".xcconfig", ".swift"}
            or Path(p).name in {"Podfile", "Package.resolved"}
        )
    ]
    android_config = [
        p for p in all_paths
        if p.startswith("android/")
        and (
            Path(p).suffix.lower() in {".xml", ".kt", ".kts", ".gradle", ".properties", ".pro"}
            or Path(p).name.startswith("gradlew")
        )
    ]
    workflow_paths = [p for p in all_paths if p.startswith(".github/workflows/")]
    dependency_manifests = [
        p for p in all_paths
        if Path(p).name in {
            "pubspec.yaml", "pubspec.lock", "package.json", "package-lock.json",
            "deno.lock", "settings.gradle.kts", "build.gradle.kts", "gradle.properties",
            "Package.resolved", "Podfile.lock",
        }
    ]

    software = parse_pub_lock(ROOT / "pubspec.lock")
    for lock in ("cloudflare/workout-runtime/package-lock.json", "supabase/tests/package-lock.json"):
        software.extend(parse_package_lock(ROOT / lock))
    software.extend(parse_deno_lock(ROOT / "supabase/functions/deno.lock"))
    software = sorted(
        {(
            item["ecosystem"], item["name"], item["version"], item.get("lockfile", "")
        ): item for item in software}.values(),
        key=lambda item: (item["ecosystem"], item["name"], item["version"], item.get("lockfile", "")),
    )

    manifest = {
        "schema_version": 1,
        "repository": "bilhealth-admin/Body-Intelligence",
        "rc_commit": head,
        "commit_timestamp_utc": git("show", "-s", "--format=%cI", "HEAD").strip(),
        "git_tree": git("show", "-s", "--format=%T", "HEAD").strip(),
        "source_file_count": len(all_files),
        "source_merkle_sha256": merkle.hexdigest(),
        "source_files": all_files,
        "software_inventory": software,
        "dependency_manifests": records(dependency_manifests, index),
        "supabase_migrations": records(migrations, index),
        "supabase_edge_function_sources": records(edge_sources, index),
        "cloudflare_sources": records(cloudflare, index),
        "ios_configuration": records(ios_config, index),
        "android_configuration": records(android_config, index),
        "github_workflows": records(workflow_paths, index),
        "certification_constraints": {
            "source_mutation_after_freeze": "FORBIDDEN_RESTART_CERTIFICATION_IF_CHANGED",
            "android_build_authorized": False,
            "ios_build_authorized": False,
            "store_upload_authorized": False,
            "asset_replacement_authorized": False,
            "onboarding_flow_change_authorized": False,
        },
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "BIL_RC_MANIFEST.json"
    payload = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    output.write_bytes(payload)
    manifest_sha = digest(payload)
    (args.output_dir / "BIL_RC_MANIFEST.sha256").write_text(
        f"{manifest_sha}  BIL_RC_MANIFEST.json\n", encoding="utf-8"
    )
    print(json.dumps({
        "rc_commit": head,
        "manifest_sha256": manifest_sha,
        "source_merkle_sha256": manifest["source_merkle_sha256"],
        "files": len(all_files),
        "software_components": len(software),
        "migrations": len(migrations),
        "edge_sources": len(edge_sources),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
