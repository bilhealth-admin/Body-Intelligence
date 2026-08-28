import json
import tempfile
import unittest
from pathlib import Path

from tool.wellness_content.publish_wellness_catalog import (
    load_approved_workout_release,
    publish,
    validate_payload,
)


class WellnessCatalogPublisherTest(unittest.TestCase):
    fixtures = Path(__file__).resolve().parent

    @classmethod
    def setUpClass(cls):
        cls.approved_bundles = load_approved_workout_release()
        cls.approved_release = cls.approved_bundles["bil-workouts-home-v1"]
        cls.approved_items = list(cls.approved_release.items())
        cls.approved_categories = list(dict.fromkeys(
            entry["category"] for entry in cls.approved_release.values()
        ))

    def test_accepts_licensed_https_content(self):
        payload = validate_payload(self.fixtures / "test-valid-pack.json")
        self.assertEqual(payload["pack_id"], "global-recipes-seed")
        self.assertEqual(len(payload["items"]), 1)

    def test_rejects_missing_rights_metadata(self):
        with self.assertRaisesRegex(ValueError, "rights_holder"):
            validate_payload(self.fixtures / "test-invalid-pack.json")

    def workout_item(self, index):
        item_id, approval = self.approved_items[index]
        category = approval["category"]
        category_order = self.approved_categories.index(category)
        suffix = f"{index:03d}"
        return {
            "id": item_id,
            "type": "workouts",
            "locale": "en",
            "title": f"Workout {suffix}",
            "description": "Reviewed workout demonstration.",
            "category": category,
            "category_description": f"{category.title()} workout routines.",
            "category_order": category_order,
            "equipment": ["none"],
            "steps": ["Start in a stable position.", "Move under control."],
            "duration_minutes": 5,
            "duration_seconds": approval["duration_seconds"],
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
                    "url": f"https://cdn.example.test/{item_id}.webp",
                    "mime_type": "image/webp",
                    "sha256": f"{index + 1000:064x}",
                    "size_bytes": 1000 + index,
                    "media_role": "preview",
                },
                "video": {
                    "url": f"https://cdn.example.test/{approval['object_path']}",
                    "mime_type": "video/mp4",
                    "sha256": approval["sha256"],
                    "size_bytes": approval["size_bytes"],
                    "media_role": "preview",
                },
            },
            "segments": [],
        }

    def write_workout_pack(self, root, count=200):
        categories = self.approved_categories
        path = Path(root) / "workouts.json"
        path.write_text(json.dumps({
            "schema_version": 2,
            "pack_id": "bil-workouts-home-v1",
            "version": 1,
            "type": "workouts",
            "categories": categories,
            "items": [self.workout_item(index) for index in range(count)],
        }), encoding="utf-8")
        return path

    def test_accepts_exact_release_distribution(self):
        with tempfile.TemporaryDirectory() as root:
            payload = validate_payload(self.write_workout_pack(root))
        self.assertEqual(payload["schema_version"], 2)
        self.assertEqual(len(payload["items"]), 200)
        self.assertEqual(set(payload["categories"]), set(self.approved_categories))

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

    def test_generation_template_is_not_a_complete_release_pack(self):
        template = self.fixtures / "pack-template.json"
        with self.assertRaisesRegex(
            ValueError,
            "categories must match the approved release",
        ):
            validate_payload(template)

    def test_rejects_undersized_or_duplicate_workout_categories(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, "complete approved bundle"):
                validate_payload(self.write_workout_pack(root, count=199))

            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][-1]["media"]["video"]["sha256"] = payload["items"][0][
                "media"
            ]["video"]["sha256"]
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "approved path/SHA/size evidence"):
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

    def test_rejects_unapproved_extra_segment_video(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][0]["segments"].append({"id": "unapproved-extra"})
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "must be empty"):
                validate_payload(path)

    def test_rejects_inconsistent_category_metadata(self):
        with tempfile.TemporaryDirectory() as root:
            path = self.write_workout_pack(root)
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["items"][-1]["category_description"] = "Different summary."
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "inconsistent category_description"):
                validate_payload(path)

            same_category = next(
                item
                for item in payload["items"][:-1]
                if item["category"] == payload["items"][-1]["category"]
            )
            payload["items"][-1]["category_description"] = same_category[
                "category_description"
            ]
            payload["items"][-1]["category_order"] = (
                same_category["category_order"] + 1
            )
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
