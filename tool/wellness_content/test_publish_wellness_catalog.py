import unittest
from pathlib import Path

from tool.wellness_content.publish_wellness_catalog import validate_payload


class WellnessCatalogPublisherTest(unittest.TestCase):
    fixtures = Path(__file__).resolve().parent

    def test_accepts_licensed_https_content(self):
        payload = validate_payload(self.fixtures / "test-valid-pack.json")
        self.assertEqual(payload["pack_id"], "global-recipes-seed")
        self.assertEqual(len(payload["items"]), 1)

    def test_rejects_missing_rights_metadata(self):
        with self.assertRaisesRegex(ValueError, "rights_holder"):
            validate_payload(self.fixtures / "test-invalid-pack.json")


if __name__ == "__main__":
    unittest.main()
