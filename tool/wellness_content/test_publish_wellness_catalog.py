import json
import tempfile
import unittest
from pathlib import Path

from tool.wellness_content.publish_wellness_catalog import publish, validate_payload


class WellnessCatalogPublisherTest(unittest.TestCase):
    fixtures = Path(__file__).resolve().parent

    def test_accepts_licensed_https_content(self):
        payload = validate_payload(self.fixtures / "test-valid-pack.json")
        self.assertEqual(payload["pack_id"], "global-recipes-seed")
        self.assertEqual(len(payload["items"]), 1)

    def test_rejects_missing_rights_metadata(self):
        with self.assertRaisesRegex(ValueError, "rights_holder"):
            validate_payload(self.fixtures / "test-invalid-pack.json")

    @staticmethod
    def workout_item(index, category="strength"):
        suffix = f"{index:03d}"
        return {
            "id": f"{category}-{suffix}",
            "type": "workouts",
            "locale": "en",
            "title": f"Workout {suffix}",
            "description": "Reviewed workout demonstration.",
            "category": category,
            "category_description": f"{category.title()} workout routines.",
            "category_order": 0,
            "equipment": ["none"],
            "steps": ["Start in a stable position.", "Move under control."],
            "duration_minutes": 5,
            "audience": "all",
            "presenter": "neutral",
            "synthetic_performer": False,
            "author": "Qualified exercise professional",
            "attribution": "Licensed to BIL.",
            "publisher": "Fixture publisher",
            "source_url": f"https://example.test/workouts/{suffix}",
            "license_name": "Commercial mobile license",
            "license_url": "https://example.test/license",
            "rights": {"mobile": True, "paid": True, "offline": True},
            "reviewed_at": "2026-01-01T00:00:00Z",
            "safety_reviewed": True,
            "verified": True,
            "media": {
                "image": {
                    "url": f"https://cdn.example.test/{suffix}.webp",
                    "mime_type": "image/webp",
                    "sha256": f"{index + 1000:064x}",
                    "size_bytes": 1000 + index,
                    "media_role": "preview",
                },
                "video": {
                    "url": f"https://cdn.example.test/{suffix}.mp4",
                    "mime_type": "video/mp4",
                    "sha256": f"{index + 1:064x}",
                    "size_bytes": 100000 + index,
                    "media_role": "preview",
                },
            },
            "segments": [{
                "id": f"movement-{suffix}",
                "title": f"Movement {suffix}",
                "instruction": "Move under control through a comfortable range.",
                "reps": 8,
                "rest_seconds": 20,
                "optional": False,
                "media": {
                    "image": {
                        "url": f"https://cdn.example.test/{suffix}-movement.webp",
                        "mime_type": "image/webp",
                        "sha256": f"{index + 2000:064x}",
                        "size_bytes": 800 + index,
                        "media_role": "instruction",
                    },
                    "video": {
                        "url": f"https://cdn.example.test/{suffix}-movement.mp4",
                        "mime_type": "video/mp4",
                        "sha256": f"{index + 3000:064x}",
                        "size_bytes": 80000 + index,
                        "media_role": "instruction",
                    },
                },
            }],
        }

    def write_workout_pack(self, root, count=100):
        path = Path(root) / "workouts.json"
        path.write_text(json.dumps({
            "schema_version": 2,
            "pack_id": "strength-v2",
            "version": 1,
            "type": "workouts",
            "categories": ["strength"],
            "items": [self.workout_item(index) for index in range(count)],
        }), encoding="utf-8")
        return path

    def test_accepts_one_hundred_licensed_videos_per_category(self):
        with tempfile.TemporaryDirectory() as root:
            payload = validate_payload(self.write_workout_pack(root))
        self.assertEqual(payload["schema_version"], 2)
        self.assertEqual(len(payload["items"]), 100)

    def test_accepts_reviewed_gender_specific_synthetic_presenters(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][0].update({
                "audience": "women",
                "presenter": "adult_female",
                "synthetic_performer": True,
                "human_safety_reviewed": True,
            })
            payload["items"][1].update({
                "audience": "men",
                "presenter": "adult_male",
            })
            path.write_text(json.dumps(payload), encoding="utf-8")
            validated = validate_payload(path)

        self.assertEqual(validated["items"][0]["audience"], "women")
        self.assertEqual(validated["items"][0]["presenter"], "adult_female")
        self.assertTrue(validated["items"][0]["synthetic_performer"])

    def test_rejects_invalid_presentation_metadata_and_media_roles(self):
        mutations = (
            (lambda item: item.pop("audience"), "audience"),
            (lambda item: item.update({"audience": "children"}), "audience"),
            (lambda item: item.pop("presenter"), "presenter"),
            (lambda item: item.update({"presenter": "model"}), "presenter"),
            (
                lambda item: item.update({
                    "audience": "men",
                    "presenter": "adult_female",
                }),
                "presenter must be adult_male for men",
            ),
            (lambda item: item.pop("synthetic_performer"), "synthetic_performer"),
            (
                lambda item: item.update({"synthetic_performer": "yes"}),
                "synthetic_performer",
            ),
            (
                lambda item: item["media"]["video"].pop("media_role"),
                "media_role",
            ),
            (
                lambda item: item["media"]["video"].update(
                    {"media_role": "instruction"}
                ),
                "media_role must be preview",
            ),
            (
                lambda item: item["segments"][0]["media"]["video"].update(
                    {"media_role": "preview"}
                ),
                "media_role must be instruction",
            ),
        )
        for mutate, message in mutations:
            with self.subTest(message=message), tempfile.TemporaryDirectory() as root:
                path = self.write_workout_pack(root)
                payload = json.loads(path.read_text(encoding="utf-8"))
                mutate(payload["items"][0])
                path.write_text(json.dumps(payload), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, message):
                    validate_payload(path)

    def test_rejects_synthetic_preview_without_explicit_human_review(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][0].update({
                "audience": "women",
                "presenter": "adult_female",
                "synthetic_performer": True,
                "human_safety_reviewed": False,
                "safety_reviewed": True,
                "verified": True,
            })
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "explicit human safety review"):
                validate_payload(path)

    def test_generation_template_is_not_publishable_before_human_review(self):
        template = self.fixtures / "pack-template.json"
        with self.assertRaisesRegex(ValueError, "explicit human safety review"):
            validate_payload(template)

    def test_rejects_undersized_or_duplicate_workout_categories(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, "at least 100 videos"):
                validate_payload(self.write_workout_pack(root, count=99))

            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][-1]["media"]["video"] = payload["items"][0]["media"]["video"]
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Duplicate workout video"):
                validate_payload(path)

    def test_rejects_insecure_or_unlicensed_workout_video(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][0]["media"]["video"]["url"] = "http://example.test/video.mp4"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "must use HTTPS"):
                validate_payload(path)

            payload["items"][0]["media"]["video"]["url"] = "https://example.test/video.mp4"
            payload["items"][0]["rights"]["offline"] = False
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "not licensed"):
                validate_payload(path)

    def test_rejects_duplicate_segment_media(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            duplicate = json.loads(json.dumps(payload["items"][0]["segments"][0]))
            duplicate["id"] = "duplicate-movement"
            payload["items"][0]["segments"].append(duplicate)
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Duplicate workout video media"):
                validate_payload(path)

    def test_rejects_inconsistent_category_metadata(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][-1]["category_description"] = "Different summary."
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "inconsistent category_description"):
                validate_payload(path)

            payload["items"][-1]["category_description"] = payload["items"][0][
                "category_description"
            ]
            payload["items"][-1]["category_order"] = 1
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "inconsistent category_order"):
                validate_payload(path)

    def test_rejects_unsafe_pack_item_and_remote_names(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["pack_id"] = "../outside"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "safe identifier"):
                validate_payload(path)

            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][0]["id"] = "unsafe/item"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "safe identifier"):
                validate_payload(path)

            path = self.write_workout_pack(root)
            config = root / "config.json"
            config.write_text(json.dumps({
                "base_url": "https://cdn.example.test/packs",
                "packs": [{
                    "file": str(path),
                    "remote_name": "../workouts.json",
                    "title": "Strength library",
                    "minimum_access": "free",
                    "publisher": "Fixture publisher",
                    "source_url": "https://example.test/source",
                    "license_name": "Commercial mobile license",
                    "license_url": "https://example.test/license",
                }],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "file name"):
                publish(config, root / "manifest.json")

    def test_published_manifest_preserves_schema_and_provenance(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            pack = self.write_workout_pack(root)
            config = root / "config.json"
            config.write_text(json.dumps({
                "base_url": "https://cdn.example.test/packs",
                "packs": [{
                    "file": str(pack),
                    "title": "Strength library",
                    "minimum_access": "plus",
                    "publisher": "Fixture publisher",
                    "source_url": "https://example.test/source",
                    "license_name": "Commercial mobile license",
                    "license_url": "https://example.test/license",
                }],
            }), encoding="utf-8")
            manifest = publish(config, root / "manifest.json")
        self.assertEqual(manifest["schema_version"], 2)
        self.assertEqual(manifest["packs"][0]["schema_version"], 2)
        self.assertEqual(manifest["packs"][0]["publisher"], "Fixture publisher")


if __name__ == "__main__":
    unittest.main()
