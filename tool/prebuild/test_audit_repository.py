import unittest

from audit_repository import SECRETS, reviewed_url_rejection_fixture


class ReviewedUrlRejectionFixtureTest(unittest.TestCase):
    coach = "supabase/functions/ai-coach/provider_recipient_policy_test.ts"
    catalog = "test/features/nutrition/catalog_pack_security_test.dart"

    def candidate(self, host="generativelanguage.googleapis.com", path="/v1beta",
                  username="user", password="password", suffix=""):
        return "https://" + username + ":" + password + "@" + host + path + suffix

    def classify(self, file, url, quote='"'):
        source = "const value = " + quote + url + quote + ";"
        match = SECRETS["credential_url"].search(source)
        self.assertIsNotNone(match, "The secret detector must still see the input")
        return reviewed_url_rejection_fixture(file, source, match.start())

    def test_both_reviewed_dummy_inputs_are_reported_as_fixtures(self):
        self.assertTrue(self.classify(self.coach, self.candidate()))
        self.assertTrue(self.classify(self.catalog, self.candidate(
            "downloads.example.com", "/catalog.sqlite"), "'"))

    def test_real_credentials_in_either_test_file_remain_candidates(self):
        for file, host, path in [
            (self.coach, "generativelanguage.googleapis.com", "/v1beta"),
            (self.catalog, "downloads.example.com", "/catalog.sqlite"),
        ]:
            for user, password in [("actual-user", "password"),
                                   ("user", "nonplaceholder-secret")]:
                with self.subTest(file=file, user=user):
                    self.assertFalse(self.classify(file, self.candidate(
                        host, path, user, password)))

    def test_same_dummy_url_in_product_or_another_test_is_not_exempt(self):
        for file in ["lib/production.dart", "test/another_security_test.dart",
                     "supabase/functions/ai-coach/server.ts"]:
            with self.subTest(file=file):
                self.assertFalse(self.classify(file, self.candidate()))

    def test_changed_recipient_path_port_or_suffix_is_not_exempt(self):
        for url in [self.candidate("outside.example"),
                    self.candidate(path="/another-path"),
                    self.candidate("generativelanguage.googleapis.com:443"),
                    self.candidate(suffix="?token=nonplaceholder"),
                    self.candidate(suffix="#nonplaceholder")]:
            with self.subTest(url=url):
                self.assertFalse(self.classify(self.coach, url))

    def test_unterminated_literal_is_not_exempt(self):
        self.assertFalse(reviewed_url_rejection_fixture(
            self.coach, self.candidate(), 0))


if __name__ == "__main__":
    unittest.main()
