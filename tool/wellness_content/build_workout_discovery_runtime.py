#!/usr/bin/env python3
"""Build the redacted workout discovery catalog and free-preview policy.

The inputs are the owner-approved 302-record bundle manifests and the two
already-generated schema-v2 delivery packs. Premium instructions are omitted.
Authorization is derived only from the generated bundle-scoped object keys;
localized order and UI position never grant access.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]
WORKOUT = ROOT / "artifacts" / "workout_media"
RUNTIME = WORKOUT / "cloudflare_runtime_v2"
REGISTRY = WORKOUT / "workout_release_bundle_registry_v1.json"
DISCOVERY = WORKOUT / "workout_discovery_catalog_v1.json"
PREVIEWS = RUNTIME / "free_preview_keys_v1.json"
GENERATED_DART = (
    ROOT
    / "lib"
    / "features"
    / "wellness"
    / "domain"
    / "workout_free_preview_policy.generated.dart"
)


def canonical(value: object) -> bytes:
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


def read(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(canonical(payload))
    os.replace(temporary, path)


def object_key(url: str) -> str:
    path = urlsplit(url).path
    prefix = "/v2/objects/"
    if not path.startswith(prefix):
        raise ValueError(f"unexpected workout object URL: {url}")
    return path.removeprefix(prefix)


def redacted_item(
    raw: dict[str, object],
    record: dict[str, object],
    bundle_id: str,
) -> dict[str, object]:
    if raw.get("id") != record.get("assetId"):
        raise ValueError("pack/release workout identity mismatch")
    media = raw.get("media")
    if not isinstance(media, dict) or set(media) != {"image", "video"}:
        raise ValueError("workout discovery media is incomplete")
    video = media["video"]
    if not isinstance(video, dict):
        raise ValueError("workout video metadata is invalid")
    if (
        object_key(str(video.get("url"))) != record.get("objectPath")
        or video.get("sha256") != record.get("sha256")
        or video.get("size_bytes") != record.get("byteLength")
    ):
        raise ValueError("workout delivery pin mismatch")

    keep = {
        "attribution",
        "audience",
        "author",
        "category",
        "category_description",
        "category_order",
        "description",
        "difficulty",
        "duration_seconds",
        "equipment",
        "human_safety_reviewed",
        "id",
        "license_name",
        "license_url",
        "locale",
        "media",
        "presenter",
        "publisher",
        "reviewed_at",
        "rights",
        "safety_reviewed",
        "source_url",
        "synthetic_performer",
        "tags",
        "title",
        "type",
        "verified",
    }
    item = {key: raw[key] for key in sorted(keep) if key in raw}
    item.update(
        {
            "_pack_minimum_access": "pro",
            "_pack_schema_version": 2,
            "_plan_group_ids": record["planGroupIds"],
            "_primary_plan_group_id": record["primaryGroupId"],
            "_release_bundle_id": bundle_id,
            "_release_key": record["releaseKey"],
        }
    )
    forbidden = {"steps", "instructions", "segments"}
    if forbidden.intersection(item):
        raise ValueError("premium instructions leaked into discovery metadata")
    return item


def build() -> None:
    registry = read(REGISTRY)
    if not isinstance(registry, dict) or registry.get("playableCount") != 302:
        raise ValueError("approved workout registry is invalid")
    descriptors = registry.get("bundles")
    if not isinstance(descriptors, list) or len(descriptors) != 2:
        raise ValueError("approved workout bundles are incomplete")
    descriptors = sorted(
        descriptors,
        key=lambda value: 0 if value.get("bundleId") == "gym-six-month" else 1,
    )

    discovery_items: list[dict[str, object]] = []
    preview_groups: list[dict[str, object]] = []
    source_bundles: list[dict[str, object]] = []
    seen_release_keys: set[str] = set()
    seen_groups: set[str] = set()

    for descriptor in descriptors:
        if not isinstance(descriptor, dict):
            raise ValueError("bundle descriptor is invalid")
        bundle_id = str(descriptor["bundleId"])
        content_pack_id = str(descriptor["contentPackId"])
        manifest_path = ROOT / str(descriptor["manifestAsset"])
        pack_path = RUNTIME / "packs" / f"{content_pack_id}-v1.json"
        if digest(manifest_path) != descriptor.get("manifestSha256"):
            raise ValueError("release manifest digest mismatch")
        manifest = read(manifest_path)
        pack = read(pack_path)
        if not isinstance(manifest, dict) or not isinstance(pack, dict):
            raise ValueError("workout bundle input is invalid")
        records = manifest.get("records")
        items = pack.get("items")
        groups = manifest.get("planGroups")
        if (
            not isinstance(records, list)
            or not isinstance(items, list)
            or not isinstance(groups, list)
            or len(records) != len(items)
            or len(records) != descriptor.get("playableCount")
        ):
            raise ValueError("workout bundle counts do not match")
        records_by_id = {str(record["assetId"]): record for record in records}
        items_by_id = {str(item["id"]): item for item in items}
        if set(records_by_id) != set(items_by_id):
            raise ValueError("workout pack does not match approved records")

        for asset_id in sorted(records_by_id):
            item = redacted_item(
                items_by_id[asset_id], records_by_id[asset_id], bundle_id
            )
            release_key = str(item["_release_key"])
            if release_key in seen_release_keys:
                raise ValueError("duplicate bundle-scoped workout release key")
            seen_release_keys.add(release_key)
            discovery_items.append(item)

        for group in sorted(groups, key=lambda value: int(value["order"])):
            group_id = str(group["id"])
            if group_id in seen_groups:
                raise ValueError("duplicate workout group")
            seen_groups.add(group_id)
            members = [
                record
                for record in records
                if group_id in record.get("planGroupIds", [])
            ]
            if not members:
                raise ValueError("workout group is empty")
            chosen = min(
                members,
                key=lambda record: str(items_by_id[str(record["assetId"])]["title"]),
            )
            chosen_item = items_by_id[str(chosen["assetId"])]
            image = chosen_item["media"]["image"]
            preview_groups.append(
                {
                    "bundleId": bundle_id,
                    "groupId": group_id,
                    "groupOrder": int(group["order"]),
                    "posterObjectKey": object_key(str(image["url"])),
                    "releaseKey": chosen["releaseKey"],
                    "videoObjectKey": chosen["objectPath"],
                    "videoSha256": chosen["sha256"],
                    "videoSizeBytes": chosen["byteLength"],
                }
            )
        source_bundles.append(
            {
                "bundleId": bundle_id,
                "manifestSha256": digest(manifest_path),
                "packSha256": digest(pack_path),
            }
        )

    if len(discovery_items) != 302 or len(preview_groups) != 20:
        raise ValueError("workout discovery/free-preview count is invalid")
    video_keys = sorted({str(group["videoObjectKey"]) for group in preview_groups})
    release_keys = sorted({str(group["releaseKey"]) for group in preview_groups})
    if len(video_keys) != 15 or len(release_keys) != 15:
        raise ValueError("free-preview policy must resolve to 15 exact videos")

    source = {
        "registrySha256": digest(REGISTRY),
        "bundles": source_bundles,
    }
    write(
        DISCOVERY,
        {
            "itemCount": 302,
            "items": discovery_items,
            "schema": "bil.workout-media.discovery.v1",
            "source": source,
            "version": 1,
        },
    )
    write(
        PREVIEWS,
        {
            "groupCount": 20,
            "groups": preview_groups,
            "releaseKeys": release_keys,
            "schema": "bil.workout-media.free-previews.v1",
            "source": source,
            "uniqueVideoCount": 15,
            "videoObjectKeys": video_keys,
            "version": 1,
        },
    )

    dart_values = "\n".join(f"  {json.dumps(value)}," for value in release_keys)
    dart_groups = "\n".join(
        f"  {json.dumps(str(group['groupId']))}: "
        f"{json.dumps(str(group['releaseKey']))},"
        for group in preview_groups
    )
    GENERATED_DART.write_text(
        "// GENERATED FILE. DO NOT EDIT.\n"
        "// Source: tool/wellness_content/build_workout_discovery_runtime.py\n\n"
        "const workoutFreePreviewReleaseKeys = <String>{\n"
        f"{dart_values}\n"
        "};\n\n"
        "const workoutFreePreviewReleaseKeyByGroup = <String, String>{\n"
        f"{dart_groups}\n"
        "};\n",
        encoding="utf-8",
        newline="\n",
    )


if __name__ == "__main__":
    build()
