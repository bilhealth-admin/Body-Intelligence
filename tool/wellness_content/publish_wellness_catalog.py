"""Validate manifests for licensed BIL recipe and workout packs."""

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

TYPES = {"recipes", "workouts", "sleep", "fasting"}
ACCESS = {"free", "plus", "pro", "coach", "clinic", "enterprise"}
LOCALES = {"ar", "en", "fr", "es", "tr", "all"}
VIDEO_MIME_TYPES = {"video/mp4", "video/webm"}
WORKOUT_AUDIENCES = {"all", "men", "women"}
WORKOUT_PRESENTERS = {"adult_male", "adult_female", "neutral"}
MEDIA_ROLES = {"preview", "instruction"}
RELEASE_RECORD_COUNT = 302
RELEASE_APPROVED_VIDEO_COUNT = 302
RELEASE_UNIQUE_PAYLOAD_COUNT = 301
RELEASE_VIDEO_DURATION_SECONDS = {7, 10}
SAFE_IDENTIFIER = re.compile(r"^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$")
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WORKOUT_RELEASE_MANIFEST = (
    REPOSITORY_ROOT
    / "artifacts"
    / "workout_media"
    / "workout_release_bundle_registry_v1.json"
)


def text(value, field):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing text field: {field}")
    return value.strip()


def https(value, field):
    value = text(value, field)
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError(f"{field} must use HTTPS")
    return value


def safe_identifier(value, field):
    value = text(value, field)
    if not SAFE_IDENTIFIER.fullmatch(value):
        raise ValueError(f"{field} is not a safe identifier")
    return value


def boolean(value, field):
    if not isinstance(value, bool):
        raise ValueError(f"{field} must be a boolean")
    return value


def choice(value, field, allowed):
    value = text(value, field).lower()
    if value not in allowed:
        raise ValueError(f"{field} must be one of: {', '.join(sorted(allowed))}")
    return value


def text_list(value, field):
    if not isinstance(value, list) or not value:
        raise ValueError(f"{field} must be a non-empty list")
    cleaned = [text(entry, field) for entry in value]
    if len(set(cleaned)) != len(cleaned):
        raise ValueError(f"{field} contains duplicate values")
    return cleaned


def media_asset(value, field, kind, expected_role):
    if not isinstance(value, dict):
        raise ValueError(f"{field} metadata is required")
    url = https(value.get("url"), f"{field}.url")
    mime = text(value.get("mime_type"), f"{field}.mime_type").lower()
    digest = text(value.get("sha256"), f"{field}.sha256").lower()
    size = value.get("size_bytes")
    media_role = choice(value.get("media_role"), f"{field}.media_role", MEDIA_ROLES)
    if not mime.startswith(f"{kind}/"):
        raise ValueError(f"{field}.mime_type must be a {kind} MIME type")
    if kind == "video" and mime not in VIDEO_MIME_TYPES:
        raise ValueError(f"Unsupported workout video MIME type: {mime}")
    if not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise ValueError(f"{field}.sha256 must be a SHA-256 digest")
    if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
        raise ValueError(f"{field}.size_bytes must be a positive integer")
    if media_role != expected_role:
        raise ValueError(f"{field}.media_role must be {expected_role}")
    return {
        "url": url,
        "mime_type": mime,
        "sha256": digest,
        "size_bytes": size,
        "media_role": media_role,
    }


def _canonical(value):
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def load_approved_workout_release(path=DEFAULT_WORKOUT_RELEASE_MANIFEST):
    registry_path = Path(path)
    registry = json.loads(registry_path.read_text(encoding="utf-8-sig"))
    if (
        registry.get("schema") != "bil.workout-media.bundle-registry.v1"
        or registry.get("bundleCount") != 2
        or registry.get("totalRecordCount") != RELEASE_RECORD_COUNT
        or registry.get("playableCount") != RELEASE_APPROVED_VIDEO_COUNT
        or registry.get("uniquePayloadCount") != RELEASE_UNIQUE_PAYLOAD_COUNT
        or not isinstance(registry.get("bundles"), list)
    ):
        raise ValueError("Workout bundle registry is invalid")

    approved_by_pack = {}
    payload_digests = set()
    release_keys = set()
    for descriptor in registry["bundles"]:
        manifest_path = REPOSITORY_ROOT / text(
            descriptor.get("manifestAsset"), "manifestAsset"
        )
        approval_path = REPOSITORY_ROOT / text(
            descriptor.get("ownerApprovalAsset"), "ownerApprovalAsset"
        )
        if (
            hashlib.sha256(manifest_path.read_bytes()).hexdigest()
            != descriptor.get("manifestSha256")
            or hashlib.sha256(approval_path.read_bytes()).hexdigest()
            != descriptor.get("ownerApprovalSha256")
        ):
            raise ValueError("Workout bundle metadata hash mismatch")
        bundle = json.loads(manifest_path.read_text(encoding="utf-8"))
        owner = json.loads(approval_path.read_text(encoding="utf-8"))
        records = bundle.get("records")
        bundle_id = text(descriptor.get("bundleId"), "bundleId")
        pack_id = safe_identifier(descriptor.get("contentPackId"), "contentPackId")
        count = descriptor.get("playableCount")
        if (
            bundle.get("schema") != "bil.workout-media.bundle-release-manifest.v1"
            or bundle.get("bundleId") != bundle_id
            or bundle.get("contentPackId") != pack_id
            or bundle.get("recordCount") != count
            or not isinstance(records, list)
            or len(records) != count
            or bundle.get("recordsSha256")
            != hashlib.sha256(_canonical(records).encode("utf-8")).hexdigest()
            or owner.get("bundleId") != bundle_id
            or owner.get("decision") != "accept_all_without_exception"
            or owner.get("ownerApprovedCount") != count
        ):
            raise ValueError("Workout bundle approval is invalid")
        expected_keys = [record.get("releaseKey") for record in records]
        if owner.get("approvedReleaseKeysSha256") != hashlib.sha256(
            _canonical(expected_keys).encode("utf-8")
        ).hexdigest():
            raise ValueError("Workout owner approval digest is invalid")
        approved = {}
        for index, record in enumerate(records):
            prefix = f"{bundle_id}.records[{index}]"
            item_id = safe_identifier(record.get("assetId"), f"{prefix}.assetId")
            duration_ms = record.get("durationMilliseconds")
            frames = record.get("frameCount")
            technical = (
                record.get("bundleId") == bundle_id
                and record.get("releaseKey") == f"{bundle_id}:{item_id}"
                and record.get("candidateAvailable") is True
                and record.get("playable") is True
                and record.get("reviewStatus") == "human_approved"
                and record.get("mimeType") == "video/mp4"
                and record.get("codecName") == "h264"
                and record.get("fpsNumerator") == 30
                and record.get("fpsDenominator") == 1
                and record.get("width") == 720
                and record.get("height") == 1280
                and (duration_ms, frames) in {(7000, 210), (10000, 300)}
                and re.fullmatch(r"[0-9a-f]{64}", str(record.get("sha256", "")))
                and isinstance(record.get("byteLength"), int)
                and not isinstance(record.get("byteLength"), bool)
                and record["byteLength"] > 0
            )
            if not technical or item_id in approved:
                raise ValueError(f"{prefix} has invalid technical/owner evidence")
            approved[item_id] = {
                "bundle_id": bundle_id,
                "release_key": record["releaseKey"],
                "category": record["primaryGroupId"],
                "plan_group_ids": record["planGroupIds"],
                "duration_seconds": duration_ms // 1000,
                "object_path": record["objectPath"],
                "sha256": record["sha256"],
                "size_bytes": record["byteLength"],
            }
            if record["releaseKey"] in release_keys:
                raise ValueError("Workout release key is duplicated")
            release_keys.add(record["releaseKey"])
            payload_digests.add(record["sha256"])
        approved_by_pack[pack_id] = approved
    if (
        sum(map(len, approved_by_pack.values())) != RELEASE_RECORD_COUNT
        or len(release_keys) != RELEASE_RECORD_COUNT
        or len(payload_digests) != RELEASE_UNIQUE_PAYLOAD_COUNT
        or len(approved_by_pack.get("bil-workouts-home-v1", {})) != 200
        or len(approved_by_pack.get("bil-workouts-gym-six-month-v1", {})) != 102
    ):
        raise ValueError("Combined workout bundle inventory is invalid")
    return approved_by_pack


def validate_v2_workouts(data, items, approved_release):
    categories = text_list(data.get("categories"), "categories")
    expected_categories = {
        entry["category"] for entry in approved_release.values()
    }
    if set(categories) != expected_categories or len(categories) != len(expected_categories):
        raise ValueError("Workout pack categories must match the approved release")
    if len(items) != len(approved_release):
        raise ValueError("Workout pack must contain its complete approved bundle")
    declared = set(categories)
    counts = {category: 0 for category in categories}
    category_descriptions = {}
    category_orders = {}
    video_urls = set()
    video_digests = set()
    for index, item in enumerate(items):
        prefix = f"items[{index}]"
        item_id = safe_identifier(item.get("id"), f"{prefix}.id")
        approval = approved_release.get(item_id)
        if approval is None:
            raise ValueError(f"Workout {item_id} is not owner-approved")
        category = text(item.get("category"), f"{prefix}.category")
        if category not in declared:
            raise ValueError(f"Workout {item_id} uses undeclared category: {category}")
        category_description = text(
            item.get("category_description"),
            f"{prefix}.category_description",
        )
        category_order = item.get("category_order")
        if (
            not isinstance(category_order, int)
            or isinstance(category_order, bool)
            or category_order < 0
        ):
            raise ValueError(f"{prefix}.category_order must be a nonnegative integer")
        previous_description = category_descriptions.setdefault(
            category,
            category_description,
        )
        previous_order = category_orders.setdefault(category, category_order)
        if previous_description != category_description:
            raise ValueError(
                f"Category {category} has inconsistent category_description values"
            )
        if previous_order != category_order:
            raise ValueError(f"Category {category} has inconsistent category_order values")
        counts[category] += 1
        audience = choice(
            item.get("audience"),
            f"{prefix}.audience",
            WORKOUT_AUDIENCES,
        )
        presenter = choice(
            item.get("presenter"),
            f"{prefix}.presenter",
            WORKOUT_PRESENTERS,
        )
        synthetic_performer = boolean(
            item.get("synthetic_performer"),
            f"{prefix}.synthetic_performer",
        )
        if audience == "men" and presenter != "adult_male":
            raise ValueError(f"{prefix}.presenter must be adult_male for men")
        if audience == "women" and presenter != "adult_female":
            raise ValueError(f"{prefix}.presenter must be adult_female for women")
        if synthetic_performer and boolean(
            item.get("human_safety_reviewed"),
            f"{prefix}.human_safety_reviewed",
        ) is not True:
            raise ValueError(
                f"{prefix} synthetic workout media requires explicit human safety review"
            )
        text_list(item.get("equipment"), f"{prefix}.equipment")
        if item.get("steps") is not None:
            text_list(item["steps"], f"{prefix}.steps")
        text(item.get("author"), f"{prefix}.author")
        text(item.get("attribution"), f"{prefix}.attribution")
        text(item.get("publisher"), f"{prefix}.publisher")
        https(item.get("source_url"), f"{prefix}.source_url")
        text(item.get("license_name"), f"{prefix}.license_name")
        https(item.get("license_url"), f"{prefix}.license_url")
        reviewed_at = text(item.get("reviewed_at"), f"{prefix}.reviewed_at")
        try:
            reviewed = datetime.fromisoformat(reviewed_at.replace("Z", "+00:00"))
        except ValueError as error:
            raise ValueError(f"{prefix}.reviewed_at must be ISO-8601") from error
        if reviewed.tzinfo is None or reviewed.astimezone(timezone.utc) > datetime.now(timezone.utc):
            raise ValueError(f"{prefix}.reviewed_at must be a past, zoned timestamp")
        if boolean(item.get("safety_reviewed"), f"{prefix}.safety_reviewed") is not True:
            raise ValueError(f"{prefix}.safety_reviewed must be true")
        if item.get("verified") is not True:
            raise ValueError(f"{prefix}.verified must be true")
        duration = item.get("duration_seconds")
        if duration != approval["duration_seconds"] or isinstance(duration, bool):
            raise ValueError(
                f"{prefix}.duration_seconds does not match approved evidence"
            )
        rights = item.get("rights")
        if not isinstance(rights, dict):
            raise ValueError(f"{prefix}.rights is required")
        mobile = boolean(rights.get("mobile"), f"{prefix}.rights.mobile")
        boolean(rights.get("paid"), f"{prefix}.rights.paid")
        offline = boolean(rights.get("offline"), f"{prefix}.rights.offline")
        if not mobile or not offline:
            raise ValueError(f"{prefix} is not licensed for mobile offline use")
        media = item.get("media")
        if not isinstance(media, dict):
            raise ValueError(f"{prefix}.media is required")
        cover = media_asset(
            media.get("image"),
            f"{prefix}.media.image",
            "image",
            "preview",
        )
        video = media_asset(
            media.get("video"),
            f"{prefix}.media.video",
            "video",
            "preview",
        )
        expected_video_path = f"/{approval['object_path']}"
        if (
            category != approval["category"]
            or not urlsplit(video["url"]).path.endswith(expected_video_path)
            or video["sha256"] != approval["sha256"]
            or video["size_bytes"] != approval["size_bytes"]
        ):
            raise ValueError(
                f"{prefix}.media.video does not match approved path/SHA/size evidence"
            )
        if video["url"] in video_urls or video["sha256"] in video_digests:
            raise ValueError(f"Duplicate workout video media: {item_id}")
        video_urls.add(video["url"])
        video_digests.add(video["sha256"])
        segments = item.get("segments", [])
        if not isinstance(segments, list):
            raise ValueError(f"{prefix}.segments must be a list")
        if segments:
            raise ValueError(
                f"{prefix}.segments must be empty in a movement-video bundle"
            )
        segment_ids = set()
        segment_urls = {cover["url"], video["url"]}
        segment_digests = {cover["sha256"], video["sha256"]}
        for segment_index, segment in enumerate(segments):
            segment_prefix = f"{prefix}.segments[{segment_index}]"
            if not isinstance(segment, dict):
                raise ValueError(f"{segment_prefix} must be an object")
            segment_id = safe_identifier(segment.get("id"), f"{segment_prefix}.id")
            if segment_id in segment_ids:
                raise ValueError(f"Duplicate workout segment id: {segment_id}")
            segment_ids.add(segment_id)
            text(segment.get("title"), f"{segment_prefix}.title")
            text(segment.get("instruction"), f"{segment_prefix}.instruction")
            reps = segment.get("reps")
            seconds = segment.get("seconds")
            for value, field, allow_zero in (
                (reps, "reps", False),
                (seconds, "seconds", False),
                (segment.get("rest_seconds"), "rest_seconds", True),
            ):
                if value is None:
                    continue
                invalid = (
                    not isinstance(value, int)
                    or isinstance(value, bool)
                    or value < (0 if allow_zero else 1)
                )
                if invalid:
                    raise ValueError(f"{segment_prefix}.{field} is invalid")
            if reps is None and seconds is None:
                raise ValueError(f"{segment_prefix} requires reps or seconds")
            if segment.get("optional") is not None:
                boolean(segment["optional"], f"{segment_prefix}.optional")
            segment_media = segment.get("media")
            if not isinstance(segment_media, dict):
                raise ValueError(f"{segment_prefix}.media is required")
            segment_image = media_asset(
                segment_media.get("image"),
                f"{segment_prefix}.media.image",
                "image",
                "instruction",
            )
            segment_video = media_asset(
                segment_media.get("video"),
                f"{segment_prefix}.media.video",
                "video",
                "instruction",
            )
            if (
                segment_video["url"] in video_urls
                or segment_video["sha256"] in video_digests
            ):
                raise ValueError(f"Duplicate workout video media: {segment_id}")
            video_urls.add(segment_video["url"])
            video_digests.add(segment_video["sha256"])
            for asset in (segment_image, segment_video):
                if asset["url"] in segment_urls or asset["sha256"] in segment_digests:
                    raise ValueError(f"Duplicate workout segment media: {segment_id}")
                segment_urls.add(asset["url"])
                segment_digests.add(asset["sha256"])
    expected_counts = {category: 0 for category in expected_categories}
    for approval in approved_release.values():
        expected_counts[approval["category"]] += 1
    incorrectly_sized = [
        category for category, count in counts.items()
        if count != expected_counts[category]
    ]
    if incorrectly_sized:
        raise ValueError(
            "Workout category counts must match the approved release: "
            f"{', '.join(incorrectly_sized)}"
        )


def validate_payload(
    path,
    workout_release_manifest=DEFAULT_WORKOUT_RELEASE_MANIFEST,
):
    data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    schema_version = data.get("schema_version")
    if schema_version not in {1, 2} or data.get("type") not in TYPES:
        raise ValueError("Unsupported pack schema or type")
    if schema_version == 2 and data["type"] != "workouts":
        raise ValueError("Schema v2 is currently reserved for workout video packs")
    if not isinstance(data.get("version"), int) or data["version"] < 1:
        raise ValueError("version must be a positive integer")
    safe_identifier(data.get("pack_id"), "pack_id")
    items = data.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError("items must be a non-empty list")
    seen = set()
    for index, item in enumerate(items):
        item_id = safe_identifier(item.get("id"), f"items[{index}].id")
        if item_id in seen:
            raise ValueError(f"Duplicate item id: {item_id}")
        seen.add(item_id)
        text(item.get("title"), f"items[{index}].title")
        if item.get("locale", "en") not in LOCALES:
            raise ValueError(f"Unsupported locale in item {item_id}")
        if schema_version == 1:
            text(item.get("rights_holder"), f"items[{index}].rights_holder")
            text(item.get("license"), f"items[{index}].license")
            https(item.get("image_url"), f"items[{index}].image_url")
        if schema_version == 1 and data["type"] == "workouts":
            https(item.get("video_url"), f"items[{index}].video_url")
            if not isinstance(item.get("duration_minutes"), int):
                raise ValueError(f"items[{index}].duration_minutes required")
        if data["type"] == "recipes" and not item.get("ingredients"):
            raise ValueError(f"items[{index}].ingredients required")
    if schema_version == 2:
        validate_v2_workouts(
            data,
            items,
            load_approved_workout_release(workout_release_manifest).get(
                data["pack_id"],
                {},
            ),
        )
    return data


def publish(config_path, output_path):
    config = json.loads(Path(config_path).read_text(encoding="utf-8-sig"))
    base_url = https(config.get("base_url"), "base_url").rstrip("/")
    packs = []
    for entry in config.get("packs", []):
        source = Path(text(entry.get("file"), "file"))
        payload = validate_payload(source)
        access = entry.get("minimum_access", "free")
        if access not in ACCESS:
            raise ValueError(f"Unsupported access: {access}")
        raw = source.read_bytes()
        remote_name = text(entry.get("remote_name", source.name), "remote_name")
        if Path(remote_name).name != remote_name or "/" in remote_name or "\\" in remote_name:
            raise ValueError("remote_name must be a file name, not a path")
        if payload["schema_version"] == 2 and access != "free":
            if any(item["rights"]["paid"] is not True for item in payload["items"]):
                raise ValueError("Paid workout packs require paid distribution rights")
        first_item = payload["items"][0]
        legacy_publisher = first_item.get("rights_holder", "")
        legacy_license = first_item.get("license", "")
        packs.append({
            "id": payload["pack_id"], "version": payload["version"],
            "schema_version": payload["schema_version"],
            "type": payload["type"], "title": text(entry.get("title"), "title"),
            "description": str(entry.get("description", "")),
            "locale": entry.get("locale", "en"),
            "download_url": f"{base_url}/{remote_name}",
            "size_bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "item_count": len(payload["items"]), "minimum_access": access,
            "publisher": text(entry.get("publisher", legacy_publisher), "publisher"),
            "source_url": https(entry.get("source_url", base_url), "source_url"),
            "license_name": text(entry.get("license_name", legacy_license), "license_name"),
            "license_url": https(entry.get("license_url", base_url), "license_url"),
        })
    if not packs:
        raise ValueError("packs must be a non-empty list")
    manifest = {
        "schema_version": max(pack["schema_version"] for pack in packs),
        "packs": packs,
    }
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    print(json.dumps(publish(args.config, args.output), ensure_ascii=False, indent=2))
