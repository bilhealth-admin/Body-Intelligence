import hashlib
import json
import unittest
from pathlib import Path
from urllib.parse import urlsplit

from tool.wellness_content.build_cloudflare_workout_runtime import canonical_bytes
from tool.wellness_content.publish_wellness_catalog import validate_payload


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
RUNTIME_ROOT = (
    REPOSITORY_ROOT / "artifacts" / "workout_media" / "cloudflare_runtime_v2"
)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class CloudflareWorkoutRuntimeBuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.summary = read_json(RUNTIME_ROOT / "runtime_build_summary_v2.json")
        cls.plan = read_json(RUNTIME_ROOT / "runtime_object_plan_v2.json")
        cls.poster_manifest = read_json(
            RUNTIME_ROOT / "workout_poster_manifest_v2.json"
        )
        cls.protected_objects = read_json(
            RUNTIME_ROOT / "protected_object_keys_v2.json"
        )
        cls.pack_paths = sorted((RUNTIME_ROOT / "packs").glob("*.json"))
        cls.catalog_path = Path(cls.summary["catalogPath"])
        cls.catalog = read_json(cls.catalog_path)

    def test_exact_two_bundle_release_is_schema_v2_and_publisher_valid(self):
        counts = {}
        for path in self.pack_paths:
            raw = path.read_bytes()
            payload = read_json(path)
            self.assertEqual(raw, canonical_bytes(payload))
            validated = validate_payload(path)
            counts[validated["pack_id"]] = len(validated["items"])

        self.assertEqual(
            counts,
            {
                "bil-workouts-gym-six-month-v1": 102,
                "bil-workouts-home-v1": 200,
            },
        )

    def test_every_item_has_a_real_pinned_poster_and_explicit_rights(self):
        posters = {
            record["objectPath"]: record
            for record in self.poster_manifest["records"]
        }
        self.assertEqual(len(posters), 302)
        expected_rights = {"mobile": True, "offline": True, "paid": True}

        seen = set()
        for pack_path in self.pack_paths:
            for item in read_json(pack_path)["items"]:
                image = item["media"]["image"]
                key = urlsplit(image["url"]).path.removeprefix("/v2/objects/")
                record = posters[key]
                poster_path = Path(record["localPath"])
                self.assertTrue(poster_path.is_file())
                self.assertEqual(poster_path.stat().st_size, image["size_bytes"])
                self.assertEqual(sha256_file(poster_path), image["sha256"])
                self.assertEqual(record["sha256"], image["sha256"])
                self.assertIn(image["sha256"], key)
                self.assertEqual(
                    record["sourceVideoSha256"], image["source_video_sha256"]
                )
                self.assertEqual(record["frameMilliseconds"], image["source_frame_milliseconds"])
                self.assertEqual(image["rights"], expected_rights)
                self.assertEqual(item["rights"], expected_rights)
                self.assertEqual(image["mime_type"], "image/webp")
                self.assertTrue(image["derivation"].startswith("ffmpeg-middle-frame-webp-"))
                seen.add(key)

        self.assertEqual(seen, set(posters))
        portable_records = [
            {key: value for key, value in record.items() if key != "localPath"}
            for record in self.poster_manifest["records"]
        ]
        self.assertEqual(
            hashlib.sha256(canonical_bytes(portable_records)).hexdigest(),
            self.catalog["release_pins"]["poster_records_sha256"],
        )
        toolchain_sha = hashlib.sha256(
            canonical_bytes(self.poster_manifest["toolchain"])
        ).hexdigest()
        self.assertEqual(toolchain_sha, self.poster_manifest["toolchainSha256"])
        self.assertEqual(
            toolchain_sha,
            self.catalog["release_pins"]["poster_toolchain_sha256"],
        )
        self.assertEqual(
            toolchain_sha,
            self.plan["sourcePins"]["posterToolchainSha256"],
        )

    def test_public_manifest_and_pack_downloads_are_content_pinned(self):
        catalog_bytes = self.catalog_path.read_bytes()
        catalog_sha = hashlib.sha256(catalog_bytes).hexdigest()
        self.assertEqual(catalog_bytes, canonical_bytes(self.catalog))
        self.assertEqual(catalog_sha, self.summary["catalogSha256"])
        self.assertEqual(
            self.catalog_path.name,
            f"wellness-workouts-v2-{catalog_sha}.json",
        )
        self.assertEqual(self.catalog["schema_version"], 2)

        pack_by_id = {
            read_json(path)["pack_id"]: path for path in self.pack_paths
        }
        for descriptor in self.catalog["packs"]:
            pack_path = pack_by_id[descriptor["id"]]
            self.assertEqual(pack_path.stat().st_size, descriptor["size_bytes"])
            self.assertEqual(sha256_file(pack_path), descriptor["sha256"])
            self.assertIn(descriptor["sha256"], descriptor["download_url"])
            self.assertEqual(descriptor["minimum_access"], "pro")

    def test_protected_delivery_uses_the_exact_generated_object_allowlist(self):
        keys = self.protected_objects["keys"]
        key_set = set(keys)
        self.assertEqual(len(keys), 606)
        self.assertEqual(len(key_set), 606)
        self.assertEqual(keys, sorted(keys))
        digest = hashlib.sha256(canonical_bytes(keys)).hexdigest()
        self.assertEqual(digest, self.protected_objects["keysSha256"])
        self.assertEqual(
            digest,
            self.catalog["release_pins"]["protected_object_keys_sha256"],
        )
        self.assertEqual(digest, self.plan["protectedDelivery"]["objectKeysSha256"])
        for descriptor in self.catalog["packs"]:
            key = urlsplit(descriptor["download_url"]).path.removeprefix(
                "/v2/objects/"
            )
            self.assertIn(key, key_set)
        for pack_path in self.pack_paths:
            for item in read_json(pack_path)["items"]:
                for media in item["media"].values():
                    key = urlsplit(media["url"]).path.removeprefix("/v2/objects/")
                    self.assertIn(key, key_set)

    def test_runtime_plan_never_reuploads_an_mp4(self):
        counts = self.plan["counts"]
        self.assertEqual(
            counts,
            {
                "packs": 2,
                "posters": 302,
                "publicManifests": 1,
                "total": 305,
                "videos": 0,
            },
        )
        self.assertEqual(len(self.plan["items"]), 305)
        existing = self.plan["existingVideoObjects"]
        self.assertEqual(
            existing["action"], "reuse-uploaded-in-place-never-upload"
        )
        self.assertEqual(existing["logicalCount"], 302)
        self.assertEqual(existing["uniquePayloadCount"], 301)
        self.assertRegex(existing["evidenceLedgerSha256"], r"^[0-9a-f]{64}$")
        self.assertEqual(
            existing["evidenceLedgerSha256"],
            self.plan["sourcePins"]["baselineUploadLedgerSha256"],
        )
        self.assertLessEqual(
            self.plan["storageBudget"]["combinedBytes"],
            self.plan["storageBudget"]["safetyCeilingBytes"],
        )
        for item in self.plan["items"]:
            self.assertNotEqual(item["kind"], "video")
            self.assertFalse(item["objectKey"].lower().endswith(".mp4"))
            local_path = Path(item["localPath"])
            self.assertEqual(local_path.stat().st_size, item["sizeBytes"])
            self.assertEqual(sha256_file(local_path), item["sha256"])


if __name__ == "__main__":
    unittest.main()
