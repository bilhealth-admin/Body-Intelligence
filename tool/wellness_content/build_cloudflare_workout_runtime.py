#!/usr/bin/env python3
"""Build deterministic schema-v2 workout packs and their R2 runtime objects.

The 302 approved MP4 objects are treated as immutable, already-uploaded inputs.
This builder verifies their local SHA/size pins, derives one real poster frame per
record, and emits only posters, two packs, and one public pinned catalog in the
runtime upload plan. It never uploads or rewrites an MP4.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
WORKOUT_ARTIFACTS = REPOSITORY_ROOT / "artifacts" / "workout_media"
DEFAULT_REGISTRY = WORKOUT_ARTIFACTS / "workout_release_bundle_registry_v1.json"
DEFAULT_OUTPUT_ROOT = WORKOUT_ARTIFACTS / "cloudflare_runtime_v2"
DEFAULT_MEDIA_ROOT = Path(r"G:\BIL_Workout_Media")
DEFAULT_POSTER_ROOT = DEFAULT_MEDIA_ROOT / "delivery_posters" / "v2"
DEFAULT_DELIVERY_BASE_URL = "https://workouts.bilhealth.com"
PROMPT_MANIFEST = (
    REPOSITORY_ROOT
    / "tool"
    / "workout_media"
    / "pipeline"
    / "contracts"
    / "movement_prompt_manifest.json"
)
BASELINE_R2_PLAN = (
    REPOSITORY_ROOT / "artifacts" / "cloudflare_media" / "media_upload_plan_v1.json"
)
BASELINE_R2_LEDGER = (
    REPOSITORY_ROOT / "artifacts" / "cloudflare_media" / "media_upload_ledger_v1.ndjson"
)

PACK_VERSION = 1
SCHEMA_VERSION = 2
REVIEWED_AT = "2026-08-24T00:00:00Z"
POSTER_WIDTH = 360
POSTER_HEIGHT = 640
POSTER_QUALITY = 78
POSTER_MAX_TOTAL_BYTES = 200_000_000
R2_SAFETY_CEILING_BYTES = 9_500_000_000
EXPECTED_BASELINE_R2_BYTES = 9_257_051_952
EXPECTED_HOME_COUNT = 200
EXPECTED_GYM_COUNT = 102
EXPECTED_TOTAL_COUNT = EXPECTED_HOME_COUNT + EXPECTED_GYM_COUNT
EXPECTED_UNIQUE_VIDEO_PAYLOADS = 301
RUNTIME_BUCKET = "bil-premium-workouts-2026-v1"
RUNTIME_SCHEMA = "bil.cloudflare-workout-runtime.v2"
POSTER_DERIVATION = (
    f"ffmpeg-middle-frame-webp-{POSTER_WIDTH}x{POSTER_HEIGHT}-q{POSTER_QUALITY}-v1"
)
RIGHTS = {"mobile": True, "offline": True, "paid": True}
SAFE_ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SAFE_OBJECT_KEY = re.compile(r"^[a-z0-9][a-z0-9._/-]*$")


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_canonical(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(canonical_bytes(value))
    os.replace(temporary, path)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def require_https_base(value: str) -> str:
    parsed = urlsplit(value.strip())
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError("delivery base URL must be an origin-like HTTPS URL")
    return value.strip().rstrip("/")


def validate_object_key(value: str) -> str:
    if (
        not SAFE_OBJECT_KEY.fullmatch(value)
        or value.startswith("/")
        or value.endswith("/")
        or "//" in value
        or any(part in {"", ".", ".."} for part in value.split("/"))
    ):
        raise ValueError(f"unsafe R2 object key: {value}")
    return value


def normalized_id(value: str) -> str:
    result = value.lower().replace("--", "-").replace(".", "-")
    result = re.sub(r"[^a-z0-9-]+", "-", result)
    result = re.sub(r"-+", "-", result).strip("-")
    if not SAFE_ID.fullmatch(result):
        raise ValueError(f"unsafe workout identity: {value}")
    return result


def load_release(registry_path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    registry = read_json(registry_path)
    if (
        registry.get("schema") != "bil.workout-media.bundle-registry.v1"
        or registry.get("bundleCount") != 2
        or registry.get("totalRecordCount") != EXPECTED_TOTAL_COUNT
        or registry.get("playableCount") != EXPECTED_TOTAL_COUNT
        or registry.get("uniquePayloadCount") != EXPECTED_UNIQUE_VIDEO_PAYLOADS
    ):
        raise ValueError("workout bundle registry is not the approved 302 release")
    bundles: list[dict[str, Any]] = []
    release_keys: set[str] = set()
    video_payloads: set[str] = set()
    for descriptor in registry.get("bundles", []):
        manifest_path = REPOSITORY_ROOT / str(descriptor.get("manifestAsset", ""))
        approval_path = REPOSITORY_ROOT / str(descriptor.get("ownerApprovalAsset", ""))
        if not manifest_path.is_file() or not approval_path.is_file():
            raise ValueError("pinned workout bundle evidence is missing")
        if sha256_file(manifest_path) != descriptor.get("manifestSha256"):
            raise ValueError(f"bundle manifest pin mismatch: {manifest_path}")
        if sha256_file(approval_path) != descriptor.get("ownerApprovalSha256"):
            raise ValueError(f"owner approval pin mismatch: {approval_path}")
        bundle = read_json(manifest_path)
        approval = read_json(approval_path)
        records = bundle.get("records")
        expected_count = descriptor.get("playableCount")
        if (
            bundle.get("schema")
            != "bil.workout-media.bundle-release-manifest.v1"
            or bundle.get("bundleId") != descriptor.get("bundleId")
            or bundle.get("contentPackId") != descriptor.get("contentPackId")
            or bundle.get("recordCount") != expected_count
            or not isinstance(records, list)
            or len(records) != expected_count
            or bundle.get("recordsSha256")
            != sha256_bytes(
                json.dumps(
                    records,
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                    allow_nan=False,
                ).encode("utf-8")
            )
            or approval.get("bundleId") != bundle.get("bundleId")
            or approval.get("decision") != "accept_all_without_exception"
            or approval.get("ownerApprovedCount") != expected_count
        ):
            raise ValueError(f"invalid bundle/approval contract: {manifest_path}")
        expected_release_keys = [record.get("releaseKey") for record in records]
        if approval.get("approvedReleaseKeysSha256") != sha256_bytes(
            json.dumps(
                expected_release_keys,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                allow_nan=False,
            ).encode("utf-8")
        ):
            raise ValueError(f"owner approval release-key mismatch: {approval_path}")
        for record in records:
            asset_id = str(record.get("assetId", ""))
            release_key = str(record.get("releaseKey", ""))
            object_path = str(record.get("objectPath", ""))
            if (
                not SAFE_ID.fullmatch(asset_id)
                or release_key != f"{bundle['bundleId']}:{asset_id}"
                or release_key in release_keys
                or not re.fullmatch(r"[0-9a-f]{64}", str(record.get("sha256", "")))
                or record.get("mimeType") != "video/mp4"
                or record.get("codecName") != "h264"
                or record.get("reviewStatus") != "human_approved"
                or record.get("playable") is not True
                or not isinstance(record.get("byteLength"), int)
                or record["byteLength"] <= 0
            ):
                raise ValueError(f"invalid approved workout record: {release_key}")
            validate_object_key(object_path)
            release_keys.add(release_key)
            video_payloads.add(record["sha256"])
        bundles.append(bundle)
    counts = {bundle["bundleId"]: len(bundle["records"]) for bundle in bundles}
    if (
        counts != {"home-training": EXPECTED_HOME_COUNT, "gym-six-month": EXPECTED_GYM_COUNT}
        or len(release_keys) != EXPECTED_TOTAL_COUNT
        or len(video_payloads) != EXPECTED_UNIQUE_VIDEO_PAYLOADS
    ):
        raise ValueError("combined workout release counts changed")
    return registry, bundles


def source_index(media_root: Path) -> dict[tuple[str, str], Path]:
    groups = (
        ("bulk-legacy", media_root / "bulk_1000" / "processed", True),
        ("female-10s", media_root / "bulk_1000_female_10s" / "processed", True),
        ("paid-pilot-h264-delivery", media_root / "delivery_h264" / "home", False),
        ("gym-six-month", media_root / "bulk_1000_gym_six_month" / "processed", False),
    )
    result: dict[tuple[str, str], Path] = {}
    for group, directory, normalize in groups:
        if not directory.is_dir():
            raise ValueError(f"workout source directory is missing: {directory}")
        for path in sorted(directory.glob("*.mp4")):
            asset_id = normalized_id(path.stem) if normalize else path.stem
            key = (group, asset_id)
            if key in result:
                raise ValueError(f"duplicate local workout source: {key}")
            result[key] = path.resolve()
    return result


def prompt_slots() -> dict[str, dict[str, Any]]:
    payload = read_json(PROMPT_MANIFEST)
    slots = payload.get("slots")
    if payload.get("contract_id") != "bil-movement-prompt-manifest-v1" or not isinstance(
        slots, dict
    ):
        raise ValueError("movement prompt manifest is unavailable")
    return {str(key): value for key, value in slots.items() if isinstance(value, dict)}


def contract_for(
    record: dict[str, Any], video_path: Path
) -> tuple[dict[str, Any] | None, str | None]:
    candidates: list[Path] = []
    if video_path.parent.name == "processed":
        raw = video_path.parent.parent / "raw"
        candidates.extend(
            (
                raw / f"{record['exerciseId']}.mp4.contract.json",
                raw / f"{video_path.name}.contract.json",
            )
        )
    for candidate in candidates:
        if candidate.is_file():
            value = read_json(candidate)
            if value.get("exercise_id") == record.get("exerciseId"):
                return value, sha256_file(candidate)
    return None, None


def humanize_identifier(value: str) -> str:
    return " ".join(part for part in value.replace("_", "-").split("-") if part)


def fallback_title(record: dict[str, Any]) -> str:
    exercise = str(record["exerciseId"])
    prefixes = (
        "resistance-upper-body-",
        "resistance-lower-body-",
        "resistance-full-body-",
        "mobility-flexibility-",
        "balance-coordination-",
        "cardio-conditioning-",
        "cardio-low-impact-",
        "recovery-beginner-",
        "home-bodyweight-",
        "core-stability-",
    )
    for prefix in prefixes:
        if exercise.startswith(prefix):
            exercise = exercise.removeprefix(prefix)
            break
    words = humanize_identifier(exercise).split()
    while words and words[-1] in {
        "technique",
        "standard",
        "gentle",
        "flow",
        "steady",
        "original",
    }:
        words.pop()
    return (" ".join(words) or humanize_identifier(record["assetId"])).capitalize()


def movement_metadata(
    record: dict[str, Any], video_path: Path, slots: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    contract, contract_sha = contract_for(record, video_path)
    movement_slot = str(contract.get("movement_slot", "")) if contract else ""
    prompt = slots.get(movement_slot, {})
    if "|" in movement_slot:
        title = movement_slot.split("|", 1)[1].strip()
    else:
        title = fallback_title(record)
    trainer = str(prompt.get("trainer_sex", "")).strip().lower()
    if trainer not in {"male", "female"}:
        trainer = (
            "male"
            if str(record.get("exerciseId", "")).startswith("resistance-")
            else "female"
        )
    equipment_ids = prompt.get("equipment_ids")
    equipment = []
    if isinstance(equipment_ids, list):
        equipment = [
            humanize_identifier(str(value))
            for value in equipment_ids
            if str(value).strip() and str(value) not in {"none", "open_floor"}
        ]
    if not equipment:
        equipment = ["none"]
    setup_cue = str(prompt.get("setup_cue", "")).strip()
    if not setup_cue:
        setup_cue = "Set up in a stable position matching the reviewed demonstration."
    return {
        "contract_sha256": contract_sha,
        "title": title,
        "presenter": "adult_male" if trainer == "male" else "adult_female",
        "equipment": sorted(set(equipment)),
        "steps": [
            setup_cue,
            "Follow the demonstrated movement path slowly and under control.",
            "Stop if you feel pain or can no longer maintain safe form.",
        ],
    }


def command_version(command: str) -> str:
    process = subprocess.run(
        [command, "-version"],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    first_line = process.stdout.splitlines()[0].strip() if process.stdout else ""
    if not first_line:
        raise ValueError(f"{command} version is unavailable")
    return first_line


def run_checked(arguments: list[str]) -> None:
    process = subprocess.run(
        arguments,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if process.returncode != 0:
        detail = (process.stderr or process.stdout).strip()
        raise RuntimeError(f"command failed ({process.returncode}): {detail[:2000]}")


def verify_poster(path: Path) -> None:
    header = path.read_bytes()[:12]
    if len(header) != 12 or header[:4] != b"RIFF" or header[8:12] != b"WEBP":
        raise ValueError(f"poster is not WebP: {path}")
    process = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    streams = json.loads(process.stdout).get("streams", [])
    if len(streams) != 1 or streams[0] != {
        "width": POSTER_WIDTH,
        "height": POSTER_HEIGHT,
    }:
        raise ValueError(f"poster dimensions are invalid: {path}")


def materialize_poster(
    video_path: Path,
    poster_path: Path,
    frame_milliseconds: int,
) -> None:
    poster_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = poster_path.with_name(poster_path.stem + ".tmp.webp")
    if temporary.exists():
        temporary.unlink()
    run_checked(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-fflags",
            "+bitexact",
            "-i",
            str(video_path),
            "-ss",
            f"{frame_milliseconds / 1000:.3f}",
            "-frames:v",
            "1",
            "-vf",
            f"scale={POSTER_WIDTH}:{POSTER_HEIGHT}:flags=lanczos",
            "-c:v",
            "libwebp",
            "-preset",
            "picture",
            "-quality",
            str(POSTER_QUALITY),
            "-compression_level",
            "6",
            "-threads",
            "1",
            "-map_metadata",
            "-1",
            "-flags:v",
            "+bitexact",
            "-y",
            str(temporary),
        ]
    )
    verify_poster(temporary)
    os.replace(temporary, poster_path)


def baseline_r2_bytes() -> tuple[int, str | None]:
    if not BASELINE_R2_PLAN.is_file():
        return EXPECTED_BASELINE_R2_BYTES, None
    payload = read_json(BASELINE_R2_PLAN)
    total = payload.get("totalBytes")
    if payload.get("schema") != "bil.cloudflare-media-upload-plan.v1" or total != EXPECTED_BASELINE_R2_BYTES:
        raise ValueError("existing Cloudflare media baseline changed")
    return total, sha256_file(BASELINE_R2_PLAN)


def verify_existing_video_uploads(bundles: list[dict[str, Any]]) -> str:
    if not BASELINE_R2_LEDGER.is_file():
        raise ValueError("existing Cloudflare upload ledger is missing")
    expected = {
        str(record["objectPath"]): record
        for bundle in bundles
        for record in bundle["records"]
    }
    if len(expected) != EXPECTED_TOTAL_COUNT:
        raise ValueError("approved video object paths are not unique")
    uploaded: dict[str, dict[str, Any]] = {}
    scope_completed = False
    plan_sha = sha256_file(BASELINE_R2_PLAN)
    for line in BASELINE_R2_LEDGER.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        if (
            entry.get("event") == "scope-complete"
            and entry.get("scope") == "All"
            and entry.get("failed") == 0
            and entry.get("planSha256") == plan_sha
        ):
            scope_completed = True
        if entry.get("event") == "uploaded" and entry.get("kind") == "workout-video":
            key = str(entry.get("objectKey", ""))
            if key in expected:
                uploaded[key] = entry
    if not scope_completed or set(uploaded) != set(expected):
        raise ValueError("existing 302-video R2 upload evidence is incomplete")
    for key, record in expected.items():
        entry = uploaded[key]
        if (
            entry.get("bucket") != RUNTIME_BUCKET
            or entry.get("planSha256") != plan_sha
            or entry.get("sha256") != record["sha256"]
            or entry.get("sizeBytes") != record["byteLength"]
        ):
            raise ValueError(f"existing video upload pin mismatch: {key}")
    return sha256_file(BASELINE_R2_LEDGER)


def item_url(base_url: str, object_key: str) -> str:
    return f"{base_url}/v2/objects/{validate_object_key(object_key)}"


def build_runtime(
    *,
    registry_path: Path,
    media_root: Path,
    poster_root: Path,
    output_root: Path,
    delivery_base_url: str,
    poster_workers: int,
) -> dict[str, Any]:
    base_url = require_https_base(delivery_base_url)
    registry, bundles = load_release(registry_path)
    video_upload_ledger_sha = verify_existing_video_uploads(bundles)
    sources = source_index(media_root)
    slots = prompt_slots()
    prompt_manifest_sha = sha256_file(PROMPT_MANIFEST)
    poster_toolchain = {
        "ffmpeg": command_version("ffmpeg"),
        "ffprobe": command_version("ffprobe"),
    }
    poster_toolchain_sha = sha256_bytes(canonical_bytes(poster_toolchain))
    resolved: list[tuple[dict[str, Any], dict[str, Any], Path, Path, int]] = []
    video_hash_cache: dict[Path, str] = {}
    for bundle in bundles:
        family = "home" if bundle["bundleId"] == "home-training" else "gym-six-month"
        for record in bundle["records"]:
            key = (str(record["sourceGroup"]), str(record["assetId"]))
            video_path = sources.get(key)
            if video_path is None:
                raise ValueError(f"approved local video is missing: {record['releaseKey']}")
            if video_path.stat().st_size != record["byteLength"]:
                raise ValueError(f"approved video size mismatch: {record['releaseKey']}")
            actual_video_sha = video_hash_cache.get(video_path)
            if actual_video_sha is None:
                actual_video_sha = sha256_file(video_path)
                video_hash_cache[video_path] = actual_video_sha
            if actual_video_sha != record["sha256"]:
                raise ValueError(f"approved video SHA mismatch: {record['releaseKey']}")
            poster_path = poster_root / family / f"{record['assetId']}.webp"
            frame_ms = int(record["durationMilliseconds"]) // 2
            resolved.append((bundle, record, video_path, poster_path, frame_ms))

    with ThreadPoolExecutor(max_workers=max(1, min(poster_workers, 8))) as executor:
        futures = [
            executor.submit(
                materialize_poster,
                video_path,
                poster_path,
                frame_ms,
            )
            for _, _, video_path, poster_path, frame_ms in resolved
        ]
        for future in futures:
            future.result()

    poster_records: list[dict[str, Any]] = []
    metadata_input_records: list[dict[str, Any]] = []
    pack_payloads: list[tuple[dict[str, Any], dict[str, Any]]] = []
    resolved_by_bundle: dict[str, list[tuple[dict[str, Any], Path, int]]] = {}
    for bundle, record, _, poster_path, frame_ms in resolved:
        resolved_by_bundle.setdefault(bundle["bundleId"], []).append(
            (record, poster_path, frame_ms)
        )

    for bundle in bundles:
        groups = {group["id"]: group for group in bundle["planGroups"]}
        used_categories = list(
            dict.fromkeys(record["primaryGroupId"] for record in bundle["records"])
        )
        items: list[dict[str, Any]] = []
        for record, poster_path, frame_ms in resolved_by_bundle[bundle["bundleId"]]:
            poster_sha = sha256_file(poster_path)
            poster_size = poster_path.stat().st_size
            family = "home" if bundle["bundleId"] == "home-training" else "gym-six-month"
            poster_object = validate_object_key(
                f"workouts/v2/{family}/posters/{record['assetId']}-{poster_sha}.webp"
            )
            video_object = validate_object_key(str(record["objectPath"]))
            category = groups[record["primaryGroupId"]]
            metadata = movement_metadata(record, sources[(record["sourceGroup"], record["assetId"])], slots)
            metadata_input_records.append(
                {
                    "contractSha256": metadata.pop("contract_sha256"),
                    "releaseKey": record["releaseKey"],
                }
            )
            image_rights = dict(RIGHTS)
            items.append(
                {
                    "attribution": (
                        "BIL owner-approved generated demonstration; the poster is a "
                        "verified middle frame from this exact pinned video payload."
                    ),
                    "audience": "all",
                    "author": "BIL reviewed workout release",
                    "category": record["primaryGroupId"],
                    "category_description": f"{category['title']} reviewed workout movements.",
                    "category_order": category["order"],
                    "description": f"Reviewed {category['title'].lower()} movement demonstration.",
                    "duration_seconds": int(record["durationMilliseconds"]) // 1000,
                    "equipment": metadata["equipment"],
                    "human_safety_reviewed": True,
                    "id": record["assetId"],
                    "license_name": "BIL owner-approved commercial mobile and offline distribution",
                    "license_url": "https://www.bilhealth.com/terms",
                    "locale": "en",
                    "media": {
                        "image": {
                            "derivation": POSTER_DERIVATION,
                            "media_role": "preview",
                            "mime_type": "image/webp",
                            "rights": image_rights,
                            "sha256": poster_sha,
                            "size_bytes": poster_size,
                            "source_frame_milliseconds": frame_ms,
                            "source_video_sha256": record["sha256"],
                            "url": item_url(base_url, poster_object),
                        },
                        "video": {
                            "media_role": "preview",
                            "mime_type": "video/mp4",
                            "sha256": record["sha256"],
                            "size_bytes": record["byteLength"],
                            "url": item_url(base_url, video_object),
                        },
                    },
                    "presenter": metadata["presenter"],
                    "publisher": "BIL Health",
                    "reviewed_at": REVIEWED_AT,
                    "rights": dict(RIGHTS),
                    "safety_reviewed": True,
                    "segments": [],
                    "source_url": item_url(base_url, video_object),
                    "steps": metadata["steps"],
                    "synthetic_performer": True,
                    "title": metadata["title"],
                    "type": "workouts",
                    "verified": True,
                }
            )
            poster_records.append(
                {
                    "assetId": record["assetId"],
                    "bundleId": bundle["bundleId"],
                    "derivation": POSTER_DERIVATION,
                    "frameMilliseconds": frame_ms,
                    "localPath": str(poster_path.resolve()),
                    "mimeType": "image/webp",
                    "objectPath": poster_object,
                    "rights": dict(RIGHTS),
                    "sha256": poster_sha,
                    "sizeBytes": poster_size,
                    "sourceVideoObjectPath": video_object,
                    "sourceVideoSha256": record["sha256"],
                }
            )
        pack = {
            "categories": used_categories,
            "items": items,
            "pack_id": bundle["contentPackId"],
            "schema_version": SCHEMA_VERSION,
            "type": "workouts",
            "version": PACK_VERSION,
        }
        pack_payloads.append((bundle, pack))

    if len(poster_records) != EXPECTED_TOTAL_COUNT:
        raise ValueError("poster record count changed")
    poster_total_bytes = sum(record["sizeBytes"] for record in poster_records)
    if poster_total_bytes <= 0 or poster_total_bytes > POSTER_MAX_TOTAL_BYTES:
        raise ValueError(f"poster byte budget exceeded: {poster_total_bytes}")

    packs_directory = output_root / "packs"
    catalog_directory = output_root / "catalog"
    manifest_entries: list[dict[str, Any]] = []
    runtime_items: list[dict[str, Any]] = []
    pack_pins: list[dict[str, Any]] = []
    for bundle, pack in pack_payloads:
        pack_bytes = canonical_bytes(pack)
        pack_sha = sha256_bytes(pack_bytes)
        local_pack = packs_directory / f"{pack['pack_id']}-v{PACK_VERSION}.json"
        write_canonical(local_pack, pack)
        if local_pack.read_bytes() != pack_bytes:
            raise ValueError(f"pack was not written canonically: {local_pack}")
        pack_object = validate_object_key(
            f"workouts/v2/packs/{pack['pack_id']}-v{PACK_VERSION}-{pack_sha}.json"
        )
        is_home = bundle["bundleId"] == "home-training"
        manifest_entries.append(
            {
                "description": (
                    "Owner-approved Home Training movement library."
                    if is_home
                    else "Owner-approved six-month Gym movement library."
                ),
                "download_url": item_url(base_url, pack_object),
                "id": pack["pack_id"],
                "item_count": len(pack["items"]),
                "license_name": "BIL owner-approved commercial mobile and offline distribution",
                "license_url": "https://www.bilhealth.com/terms",
                "locale": "en",
                "minimum_access": "pro",
                "publisher": "BIL Health",
                "schema_version": SCHEMA_VERSION,
                "sha256": pack_sha,
                "size_bytes": len(pack_bytes),
                "source_url": "https://www.bilhealth.com/terms",
                "title": "Home Training" if is_home else "Gym Programs",
                "type": "workouts",
                "version": PACK_VERSION,
            }
        )
        runtime_items.append(
            runtime_plan_item(
                kind="wellness-pack",
                identity=pack["pack_id"],
                object_key=pack_object,
                local_path=local_pack,
                sha256=pack_sha,
                size_bytes=len(pack_bytes),
                content_type="application/json; charset=utf-8",
                public=False,
            )
        )
        pack_pins.append(
            {
                "bundleId": bundle["bundleId"],
                "contentPackId": pack["pack_id"],
                "objectPath": pack_object,
                "sha256": pack_sha,
                "sizeBytes": len(pack_bytes),
            }
        )

    protected_object_keys = sorted(
        {
            *(str(record["objectPath"]) for bundle in bundles for record in bundle["records"]),
            *(str(record["objectPath"]) for record in poster_records),
            *(str(pin["objectPath"]) for pin in pack_pins),
        }
    )
    if len(protected_object_keys) != EXPECTED_TOTAL_COUNT * 2 + 2:
        raise ValueError("protected delivery allowlist must contain exactly 606 keys")
    protected_keys_sha = sha256_bytes(canonical_bytes(protected_object_keys))
    protected_keys_payload = {
        "keys": protected_object_keys,
        "keysSha256": protected_keys_sha,
        "schema": "bil.cloudflare-workout-protected-object-keys.v2",
    }
    write_canonical(output_root / "protected_object_keys_v2.json", protected_keys_payload)

    metadata_inputs = {
        "contracts": metadata_input_records,
        "promptManifestSha256": prompt_manifest_sha,
    }
    metadata_inputs_sha = sha256_bytes(canonical_bytes(metadata_inputs))

    registry_sha = sha256_file(registry_path)
    portable_poster_records = [
        {key: value for key, value in record.items() if key != "localPath"}
        for record in poster_records
    ]
    catalog = {
        "packs": manifest_entries,
        "release_pins": {
            "pack_pins": pack_pins,
            "metadata_inputs_sha256": metadata_inputs_sha,
            "poster_toolchain_sha256": poster_toolchain_sha,
            "protected_object_count": len(protected_object_keys),
            "protected_object_keys_sha256": protected_keys_sha,
            "poster_count": EXPECTED_TOTAL_COUNT,
            "poster_records_sha256": sha256_bytes(
                canonical_bytes(portable_poster_records)
            ),
            "workout_bundle_registry_sha256": registry_sha,
        },
        "schema_version": SCHEMA_VERSION,
    }
    catalog_bytes = canonical_bytes(catalog)
    catalog_sha = sha256_bytes(catalog_bytes)
    catalog_name = f"wellness-workouts-v2-{catalog_sha}.json"
    catalog_path = catalog_directory / catalog_name
    write_canonical(catalog_path, catalog)
    catalog_object = validate_object_key(f"workouts/v2/catalog/{catalog_name}")
    runtime_items.append(
        runtime_plan_item(
            kind="public-manifest",
            identity="wellness-workouts-v2",
            object_key=catalog_object,
            local_path=catalog_path,
            sha256=catalog_sha,
            size_bytes=len(catalog_bytes),
            content_type="application/json; charset=utf-8",
            public=True,
        )
    )
    for poster in poster_records:
        runtime_items.append(
            runtime_plan_item(
                kind="workout-poster",
                identity=f"{poster['bundleId']}:{poster['assetId']}",
                object_key=poster["objectPath"],
                local_path=Path(poster["localPath"]),
                sha256=poster["sha256"],
                size_bytes=poster["sizeBytes"],
                content_type="image/webp",
                public=False,
            )
        )
    runtime_items.sort(key=lambda item: (item["kind"], item["objectKey"]))
    if (
        len(runtime_items) != EXPECTED_TOTAL_COUNT + 3
        or sum(item["kind"] == "workout-poster" for item in runtime_items)
        != EXPECTED_TOTAL_COUNT
        or any(item["kind"] == "workout-video" for item in runtime_items)
        or any(item["objectKey"].endswith(".mp4") for item in runtime_items)
    ):
        raise ValueError("runtime upload plan must contain posters/packs/catalog only")
    if len({item["objectKey"] for item in runtime_items}) != len(runtime_items):
        raise ValueError("runtime upload plan has duplicate object keys")
    baseline_bytes, baseline_plan_sha = baseline_r2_bytes()
    runtime_bytes = sum(item["sizeBytes"] for item in runtime_items)
    if baseline_bytes + runtime_bytes > R2_SAFETY_CEILING_BYTES:
        raise ValueError("runtime objects would exceed the existing R2 safety ceiling")

    poster_manifest = {
        "derivation": POSTER_DERIVATION,
        "recordCount": len(poster_records),
        "records": poster_records,
        "recordsSha256": sha256_bytes(canonical_bytes(poster_records)),
        "schema": "bil.workout-poster-release-manifest.v2",
        "toolchain": poster_toolchain,
        "toolchainSha256": poster_toolchain_sha,
        "totalBytes": poster_total_bytes,
    }
    write_canonical(output_root / "workout_poster_manifest_v2.json", poster_manifest)
    plan = {
        "bucket": RUNTIME_BUCKET,
        "counts": {
            "packs": 2,
            "posters": EXPECTED_TOTAL_COUNT,
            "publicManifests": 1,
            "total": len(runtime_items),
            "videos": 0,
        },
        "existingVideoObjects": {
            "action": "reuse-uploaded-in-place-never-upload",
            "evidenceLedgerSha256": video_upload_ledger_sha,
            "logicalCount": EXPECTED_TOTAL_COUNT,
            "uniquePayloadCount": EXPECTED_UNIQUE_VIDEO_PAYLOADS,
        },
        "items": runtime_items,
        "publicManifestObjectKey": catalog_object,
        "publicManifestSha256": catalog_sha,
        "publicManifestUrl": f"{base_url}/v2/manifest/{catalog_name}",
        "protectedDelivery": {
            "objectCount": len(protected_object_keys),
            "objectKeysSha256": protected_keys_sha,
        },
        "schema": "bil.cloudflare-workout-runtime-upload-plan.v2",
        "sourcePins": {
            "baselineMediaPlanSha256": baseline_plan_sha,
            "baselineUploadLedgerSha256": video_upload_ledger_sha,
            "metadataInputsSha256": metadata_inputs_sha,
            "movementPromptManifestSha256": prompt_manifest_sha,
            "posterToolchainSha256": poster_toolchain_sha,
            "workoutBundleRegistrySha256": registry_sha,
        },
        "storageBudget": {
            "baselineBytes": baseline_bytes,
            "combinedBytes": baseline_bytes + runtime_bytes,
            "runtimeBytes": runtime_bytes,
            "safetyCeilingBytes": R2_SAFETY_CEILING_BYTES,
        },
    }
    write_canonical(output_root / "runtime_object_plan_v2.json", plan)
    summary = {
        "catalogPath": str(catalog_path.resolve()),
        "catalogSha256": catalog_sha,
        "catalogUrl": plan["publicManifestUrl"],
        "gymItems": EXPECTED_GYM_COUNT,
        "homeItems": EXPECTED_HOME_COUNT,
        "packPins": pack_pins,
        "metadataInputsSha256": metadata_inputs_sha,
        "posterBytes": poster_total_bytes,
        "posterCount": EXPECTED_TOTAL_COUNT,
        "posterToolchainSha256": poster_toolchain_sha,
        "runtimeObjectBytes": runtime_bytes,
        "runtimeObjectCount": len(runtime_items),
        "protectedObjectCount": len(protected_object_keys),
        "protectedObjectKeysSha256": protected_keys_sha,
        "schema": RUNTIME_SCHEMA,
        "videoUploads": 0,
        "videoUploadLedgerSha256": video_upload_ledger_sha,
    }
    write_canonical(output_root / "runtime_build_summary_v2.json", summary)
    return summary


def runtime_plan_item(
    *,
    kind: str,
    identity: str,
    object_key: str,
    local_path: Path,
    sha256: str,
    size_bytes: int,
    content_type: str,
    public: bool,
) -> dict[str, Any]:
    return {
        "access": "public-manifest" if public else "authenticated-premium",
        "bucket": RUNTIME_BUCKET,
        "cacheControl": (
            "public, max-age=300, must-revalidate"
            if public
            else "private, max-age=31536000, immutable"
        ),
        "contentDisposition": "inline",
        "contentType": content_type,
        "identity": identity,
        "kind": kind,
        "localPath": str(local_path.resolve()),
        "objectKey": validate_object_key(object_key),
        "sha256": sha256,
        "sizeBytes": size_bytes,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--media-root", type=Path, default=DEFAULT_MEDIA_ROOT)
    parser.add_argument("--poster-root", type=Path, default=DEFAULT_POSTER_ROOT)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--delivery-base-url", default=DEFAULT_DELIVERY_BASE_URL)
    parser.add_argument("--poster-workers", type=int, default=4)
    arguments = parser.parse_args()
    if arguments.poster_workers < 1:
        parser.error("--poster-workers must be positive")
    summary = build_runtime(
        registry_path=arguments.registry.resolve(),
        media_root=arguments.media_root.resolve(),
        poster_root=arguments.poster_root.resolve(),
        output_root=arguments.output_root.resolve(),
        delivery_base_url=arguments.delivery_base_url,
        poster_workers=arguments.poster_workers,
    )
    print(
        "WORKOUT_RUNTIME_V2_BUILT "
        f"home={summary['homeItems']} gym={summary['gymItems']} "
        f"posters={summary['posterCount']} runtimeObjects={summary['runtimeObjectCount']} "
        f"videoUploads={summary['videoUploads']} manifestSha256={summary['catalogSha256']}"
    )
    print(f"manifestUrl={summary['catalogUrl']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
