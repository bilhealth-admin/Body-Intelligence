"""Pure offline contract checks; no production access."""
import unittest
from bil_workout_video_http_audit import ORIGIN, validate


def r(name, code, content_type=None, **headers):
    h = {"cache-control": "no-store", "content-type": content_type or "application/json"}
    h.update(headers)
    return {"name": name, "status": code, "headers": h, "html_sample": False,
            "sample_size": 1024 if name == "premium_range" else 0}


class ContractTests(unittest.TestCase):
    def baseline(self):
        return [
            r("anonymous_head", 401),
            r("anonymous_range", 401),
            r("browser_like_range", 401),
            r("cors_allowed", 204, "", **{
                "access-control-allow-origin": ORIGIN,
                "access-control-allow-headers": "authorization, range",
            }),
            r("cors_disallowed", 403),
        ]

    def test_anonymous_baseline(self):
        self.assertEqual(validate(self.baseline(), False), [])

    def test_200_html_gate_is_detected(self):
        checks = self.baseline()
        checks[2] = r("browser_like_range", 200, "text/html")
        checks[2]["html_sample"] = True
        findings = validate(checks, False)
        self.assertTrue(any("expected HTTP 401" in x for x in findings))
        self.assertTrue(any("HTML body" in x for x in findings))

    def test_authorized_partial_stream(self):
        h = {"content-type": "video/mp4", "accept-ranges": "bytes",
             "cache-control": "private, max-age=31536000, immutable",
             "etag": '"abc"', "vary": "Authorization, Origin",
             "access-control-allow-origin": ORIGIN}
        head = r("premium_head", 200, **{**h, "content-length": "10000"})
        partial = r("premium_range", 206, **{
            **h, "content-length": "1024", "content-range": "bytes 0-1023/10000"})
        self.assertEqual(validate(self.baseline() + [head, partial], True), [])

    def test_missing_partial_content_is_detected(self):
        checks = self.baseline() + [
            r("premium_head", 200, "video/mp4"),
            r("premium_range", 200, "text/html"),
        ]
        self.assertTrue(any("premium_range: expected HTTP 206" in x for x in validate(checks, True)))


if __name__ == "__main__":
    unittest.main()
