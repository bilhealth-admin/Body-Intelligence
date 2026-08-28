#!/usr/bin/env python3
"""Build the two owner-approved workout bundle manifests from local media.

This tool is intentionally local-only. It probes and hashes existing files; it
never creates video, uploads media, or places video bytes in the Flutter app.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
MEDIA_ROOT = Path(r"G:\BIL_Workout_Media")
ARTIFACTS = REPO / "artifacts" / "workout_media"
GYM_PLAN = (
    REPO
    / "tool"
    / "workout_media"
    / "pipeline"
    / "contracts"
    / "gym_six_month_video_plan.json"
)

BUNDLE_SCHEMA = "bil.workout-media.bundle-release-manifest.v1"
REGISTRY_SCHEMA = "bil.workout-media.bundle-registry.v1"
OWNER_APPROVAL_SCHEMA = "bil.workout-media.bundle-owner-approval.v1"

CATEGORY_PREFIXES = (
    "resistance-upper-body",
    "resistance-lower-body",
    "resistance-full-body",
    "mobility-flexibility",
    "balance-coordination",
    "cardio-conditioning",
    "cardio-low-impact",
    "recovery-beginner",
    "home-bodyweight",
    "core-stability",
)

HOME_GROUPS = (
    ("home-resistance-upper-body", "Upper-body strength"),
    ("home-resistance-lower-body", "Lower-body strength"),
    ("home-resistance-full-body", "Full-body strength"),
    ("home-cardio-conditioning", "Cardio conditioning"),
    ("home-cardio-low-impact", "Low-impact cardio"),
    ("home-home-bodyweight", "Home bodyweight"),
    ("home-core-stability", "Core stability"),
    ("home-mobility-flexibility", "Mobility & flexibility"),
    ("home-recovery-beginner", "Beginner recovery"),
    ("home-balance-coordination", "Balance & coordination"),
)

GYM_GROUPS = (
    ("gym-push", "Push"),
    ("gym-pull", "Pull"),
    ("gym-legs", "Legs"),
    ("gym-warm-up-mobility", "Warm-up & mobility"),
    ("gym-full-body", "Full Body"),
    ("gym-upper-lower", "Upper / Lower"),
    ("gym-muscle-pair-split", "Muscle Pair Split"),
    ("gym-arnold-split", "Arnold Split"),
    ("gym-powerbuilding", "Strength + Hypertrophy"),
    ("gym-exercise-technique", "Exercise Technique"),
)


def canonical(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(canonical(value) + "\n")


def normalize_id(value: str) -> str:
    normalized = value.lower().replace("--", "-").replace(".", "-")
    normalized = re.sub(r"[^a-z0-9-]+", "-", normalized)
    normalized = re.sub(r"-+", "-", normalized).strip("-")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", normalized):
        raise ValueError(f"unsafe media id: {value}")
    return normalized


def category_for(exercise_id: str) -> str:
    for prefix in CATEGORY_PREFIXES:
        if exercise_id == prefix or exercise_id.startswith(prefix + "-"):
            return prefix
    raise ValueError(f"unknown exercise category: {exercise_id}")


def probe(path: Path) -> dict[str, Any]:
    process = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=codec_name,width,height,avg_frame_rate,nb_frames",
            "-show_entries",
            "format=duration",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    payload = json.loads(process.stdout)
    streams = payload.get("streams")
    if not isinstance(streams, list) or len(streams) != 1:
        raise ValueError(f"expected one video stream: {path}")
    stream = streams[0]
    numerator, denominator = str(stream["avg_frame_rate"]).split("/", 1)
    duration_ms = round(float(payload["format"]["duration"]) * 1000)
    result = {
        "codecName": str(stream["codec_name"]),
        "durationMilliseconds": duration_ms,
        "fpsDenominator": int(denominator),
        "fpsNumerator": int(numerator),
        "frameCount": int(stream["nb_frames"]),
        "height": int(stream["height"]),
        "width": int(stream["width"]),
    }
    if (
        result["codecName"] not in {"h264", "mpeg4"}
        or result["durationMilliseconds"] not in {7000, 10000}
        or result["fpsNumerator"] != 30
        or result["fpsDenominator"] != 1
        or result["frameCount"] not in {210, 300}
        or result["width"] != 720
        or result["height"] != 1280
    ):
        raise ValueError(f"unsupported existing workout media: {path}: {result}")
    return result


def technical_record(
    *,
    path: Path,
    source_group: str,
    bundle_id: str,
    asset_id: str,
    exercise_id: str,
    object_path: str,
    primary_group_id: str,
    plan_group_ids: list[str],
    lineage: dict[str, Any] | None = None,
) -> dict[str, Any]:
    record = {
        "assetId": asset_id,
        "bundleId": bundle_id,
        "byteLength": path.stat().st_size,
        "candidateAvailable": True,
        "exerciseId": exercise_id,
        "mimeType": "video/mp4",
        "objectPath": object_path,
        "planGroupIds": sorted(set(plan_group_ids)),
        "playable": True,
        "primaryGroupId": primary_group_id,
        "releaseKey": f"{bundle_id}:{asset_id}",
        "reviewStatus": "human_approved",
        "sha256": sha256_file(path),
        "sourceGroup": source_group,
        **probe(path),
    }
    if lineage is not None:
        record["lineage"] = lineage
    return record


def home_sources() -> list[tuple[Path, str, str, str, dict[str, Any] | None]]:
    result: list[
        tuple[Path, str, str, str, dict[str, Any] | None]
    ] = []
    for source_group, directory in (
        ("bulk-legacy", MEDIA_ROOT / "bulk_1000" / "processed"),
        ("female-10s", MEDIA_ROOT / "bulk_1000_female_10s" / "processed"),
    ):
        for path in sorted(directory.glob("*.mp4")):
            asset_id = normalize_id(path.stem)
            exercise_id = asset_id.removesuffix("-7s-original")
            result.append((path, source_group, asset_id, exercise_id, None))
    pilot = MEDIA_ROOT / "output" / "fal_longcat_pilot" / "processed"
    delivery = MEDIA_ROOT / "delivery_h264" / "home"
    for original in sorted(pilot.glob("*.mp4")):
        exercise_id = normalize_id(original.name.removesuffix(".bil.mp4"))
        asset_id = f"{exercise_id}-paid-pilot"
        path = delivery / f"{asset_id}.mp4"
        if not path.is_file():
            raise ValueError(f"missing non-destructive H.264 delivery transcode: {path}")
        result.append(
            (
                path,
                "paid-pilot-h264-delivery",
                asset_id,
                exercise_id,
                {
                    "operation": "non_destructive_h264_delivery_transcode",
                    "sourceCodecName": "mpeg4",
                    "sourceRelativePath": (
                        "output/fal_longcat_pilot/processed/" + original.name
                    ),
                    "sourceSha256": sha256_file(original),
                    "sourcePreserved": True,
                },
            )
        )
    if len(result) != 200:
        raise ValueError(f"home source must contain exactly 200 files, got {len(result)}")
    if len({item[2] for item in result}) != 200:
        raise ValueError("home asset identities are not unique")
    return result


def gym_plan_memberships(plan: dict[str, Any]) -> dict[str, set[str]]:
    queue = plan.get("generation_queue")
    if not isinstance(queue, list) or len(queue) != 102:
        raise ValueError("gym plan must contain 102 queue entries")
    movement_to_id = {
        str(item["movement"]).strip().casefold(): normalize_id(item["exercise_id"])
        for item in queue
    }
    memberships: dict[str, set[str]] = defaultdict(set)
    for session in plan.get("sessions", []):
        name = str(session.get("name", "")).casefold()
        group = next(
            (candidate for candidate in ("push", "pull", "legs") if name.startswith(candidate)),
            None,
        )
        if group is None:
            continue
        for exercise in session.get("exercises", []):
            movement = str(exercise.get("movement", "")).strip().casefold()
            exercise_id = movement_to_id.get(movement)
            if exercise_id is not None:
                memberships[exercise_id].add(f"gym-{group}")
    return memberships


def build_home() -> dict[str, Any]:
    records = []
    for path, source_group, asset_id, exercise_id, lineage in home_sources():
        category = category_for(exercise_id)
        group = f"home-{category}"
        records.append(
            technical_record(
                path=path,
                source_group=source_group,
                bundle_id="home-training",
                asset_id=asset_id,
                exercise_id=exercise_id,
                object_path=f"workouts/v1/home/movements/{asset_id}.mp4",
                primary_group_id=group,
                plan_group_ids=[group],
                lineage=lineage,
            )
        )
    return bundle_manifest(
        bundle_id="home-training",
        content_pack_id="bil-workouts-home-v1",
        title="Home Training",
        records=records,
        groups=HOME_GROUPS,
    )


def build_gym() -> dict[str, Any]:
    plan = json.loads(GYM_PLAN.read_text(encoding="utf-8-sig"))
    queue = plan["generation_queue"]
    queue_ids = {normalize_id(item["exercise_id"]) for item in queue}
    directory = MEDIA_ROOT / "bulk_1000_gym_six_month" / "processed"
    paths = sorted(directory.glob("*.mp4"))
    if len(paths) != 102 or {path.stem for path in paths} != queue_ids:
        raise ValueError("gym processed directory does not match its exact 102 plan")
    memberships = gym_plan_memberships(plan)
    records = []
    for path in paths:
        exercise_id = path.stem
        category = category_for(exercise_id)
        groups = set(memberships.get(exercise_id, set()))
        if category == "resistance-lower-body":
            groups.add("gym-legs")
        elif category == "resistance-full-body":
            groups.add("gym-full-body")
        elif category in {"mobility-flexibility", "recovery-beginner"}:
            groups.add("gym-warm-up-mobility")
        elif category == "core-stability":
            groups.add("gym-exercise-technique")
        if category.startswith("resistance-") or category == "core-stability":
            groups.update({"gym-upper-lower", "gym-powerbuilding"})
        if category in {"resistance-upper-body", "resistance-lower-body"}:
            groups.update({"gym-muscle-pair-split", "gym-arnold-split"})
        groups.add("gym-exercise-technique")
        primary = next(
            (
                candidate
                for candidate in (
                    "gym-push",
                    "gym-pull",
                    "gym-legs",
                    "gym-full-body",
                    "gym-warm-up-mobility",
                    "gym-exercise-technique",
                )
                if candidate in groups
            ),
            "gym-exercise-technique",
        )
        records.append(
            technical_record(
                path=path,
                source_group="gym-six-month",
                bundle_id="gym-six-month",
                asset_id=exercise_id,
                exercise_id=exercise_id,
                object_path=f"workouts/v1/gym-six-month/movements/{exercise_id}.mp4",
                primary_group_id=primary,
                plan_group_ids=sorted(groups),
            )
        )
    return bundle_manifest(
        bundle_id="gym-six-month",
        content_pack_id="bil-workouts-gym-six-month-v1",
        title="Gym Programs",
        records=records,
        groups=GYM_GROUPS,
        source_plan={
            "contractId": plan["contract_id"],
            "generationQueueCount": plan["generation_queue_count"],
        },
    )


def bundle_manifest(
    *,
    bundle_id: str,
    content_pack_id: str,
    title: str,
    records: list[dict[str, Any]],
    groups: tuple[tuple[str, str], ...],
    source_plan: dict[str, Any] | None = None,
) -> dict[str, Any]:
    known_groups = {group_id for group_id, _ in groups}
    for record in records:
        if record["primaryGroupId"] not in known_groups or not set(
            record["planGroupIds"]
        ).issubset(known_groups):
            raise ValueError(f"unknown plan group in {record['releaseKey']}")
    result = {
        "bundleId": bundle_id,
        "contentPackId": content_pack_id,
        "ownerApproval": {
            "approvedBy": "BIL owner",
            "decision": "accept_all_without_exception",
            "playableCount": len(records),
        },
        "planGroups": [
            {"id": group_id, "order": index, "title": title}
            for index, (group_id, title) in enumerate(groups)
        ],
        "recordCount": len(records),
        "records": records,
        "recordsSha256": hashlib.sha256(canonical(records).encode()).hexdigest(),
        "schema": BUNDLE_SCHEMA,
        "summary": {"blocked": 0, "playable": len(records)},
        "title": title,
    }
    result["summary"]["totalMediaBytes"] = sum(
        int(record["byteLength"]) for record in records
    )
    if source_plan is not None:
        result["sourcePlan"] = source_plan
    return result


def approval(bundle: dict[str, Any]) -> dict[str, Any]:
    keys = [record["releaseKey"] for record in bundle["records"]]
    return {
        "approvedBy": "BIL owner",
        "approvedReleaseKeysSha256": hashlib.sha256(canonical(keys).encode()).hexdigest(),
        "bundleId": bundle["bundleId"],
        "decision": "accept_all_without_exception",
        "ownerApprovedCount": len(keys),
        "qualifiedBiomechanicsCertification": False,
        "schema": OWNER_APPROVAL_SCHEMA,
    }


def main() -> int:
    home = build_home()
    gym = build_gym()
    outputs = (
        ("workout_release_bundle_home_v1.json", home),
        ("workout_release_bundle_gym_six_month_v1.json", gym),
        ("workout_owner_approval_home_200.json", approval(home)),
        ("workout_owner_approval_gym_102.json", approval(gym)),
    )
    for filename, payload in outputs:
        write_json(ARTIFACTS / filename, payload)
    bundle_files = [
        (outputs[0], outputs[2]),
        (outputs[1], outputs[3]),
    ]
    registry_bundles = []
    for (filename, bundle), (approval_filename, _) in bundle_files:
        path = ARTIFACTS / filename
        approval_path = ARTIFACTS / approval_filename
        registry_bundles.append(
            {
                "bundleId": bundle["bundleId"],
                "contentPackId": bundle["contentPackId"],
                "manifestAsset": f"artifacts/workout_media/{filename}",
                "manifestSha256": sha256_file(path),
                "ownerApprovalAsset": (
                    f"artifacts/workout_media/{approval_filename}"
                ),
                "ownerApprovalSha256": sha256_file(approval_path),
                "playableCount": bundle["summary"]["playable"],
            }
        )
    registry = {
        "bundleCount": 2,
        "bundles": registry_bundles,
        "playableCount": 302,
        "schema": REGISTRY_SCHEMA,
        "totalRecordCount": 302,
        "uniquePayloadCount": len(
            {
                record["sha256"]
                for bundle in (home, gym)
                for record in bundle["records"]
            }
        ),
    }
    if registry["uniquePayloadCount"] != 301:
        raise ValueError(
            "combined delivery payload count must remain exactly 301"
        )
    write_json(ARTIFACTS / "workout_release_bundle_registry_v1.json", registry)
    print("WORKOUT_BUNDLE_REGISTRY_BUILT home=200 gym=102 total=302")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
