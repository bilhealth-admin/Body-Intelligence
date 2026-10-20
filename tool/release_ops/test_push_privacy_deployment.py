import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import urllib.error

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("push_deploy", HERE / "push_privacy_deployment.py")
deploy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(deploy)


def valid_metadata():
    return {"id": deploy.FUNCTION_ID, "slug": deploy.SLUG, "name": deploy.SLUG,
            "status": "ACTIVE", "version": 56, "verify_jwt": False, "import_map": False,
            "ezbr_sha256": deploy.PREVIOUS_BUNDLE}


class DeploymentGuards(unittest.TestCase):
    def test_previous_metadata_accepts_only_the_exact_original_function(self):
        deploy.validate_previous(valid_metadata())
        for key, value in (("id", "other"), ("slug", "ai-coach"),
                           ("name", "other"), ("status", "DEPLOYING"),
                           ("version", 57), ("verify_jwt", True), ("import_map", True),
                           ("ezbr_sha256", "changed")):
            with self.subTest(key=key):
                changed = valid_metadata()
                changed[key] = value
                with self.assertRaises(deploy.GuardFailure):
                    deploy.validate_previous(changed)

    def test_other_function_mutation_is_not_hidden_by_target_deployment(self):
        target = valid_metadata()
        other = {**target, "id": "other", "slug": "ai-coach", "name": "ai-coach", "version": 111}
        before = deploy.other_functions([target, other])
        deploy.require_others_unchanged(before, deploy.other_functions([other, {**target, "version": 57}]))
        with self.assertRaises(deploy.GuardFailure):
            deploy.require_others_unchanged(before, deploy.other_functions([{**other, "version": 112}]))

    def test_sources_require_both_only_expected_modules_and_exact_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "index.ts").write_text('import "./server.ts";\n')
            (root / "server.ts").write_text("export const version = 'original';\n")
            original = deploy.source_manifest(root)
            deploy.require_same_source(deploy.source_manifest(root), original)
            (root / "server.ts").write_text("export const version = 'changed';\n")
            with self.assertRaises(deploy.GuardFailure):
                deploy.require_same_source(deploy.source_manifest(root), original)
            (root / "server_test.ts").write_text("Deno.test(() => {});\n")
            deploy.source_manifest(root, allow_tests=True)
            with self.assertRaises(deploy.GuardFailure):
                deploy.source_manifest(root)
            (root / "unexpected.ts").write_text("export {};\n")
            with self.assertRaises(deploy.GuardFailure):
                deploy.source_manifest(root)

    def test_source_snapshot_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "actual.ts").write_text("export {};\n")
            (root / "index.ts").symlink_to(root / "actual.ts")
            (root / "server.ts").write_text("export {};\n")
            with self.assertRaises(deploy.GuardFailure):
                deploy.source_manifest(root)

    def test_negative_probe_requires_exact_dispatch_secret_rejection(self):
        deploy.validate_unauthorized(401, {"error": "unauthorized"})
        for status, body in ((200, {"processed": 0}), (503, {"error": "cloud_not_configured"}),
                             (401, {"error": "Missing authorization header"})):
            with self.subTest(status=status, body=body):
                with self.assertRaises(deploy.GuardFailure):
                    deploy.validate_unauthorized(status, body)

    def test_smoke_never_sends_a_valid_dispatch_credential(self):
        calls = []
        class Fake:
            def open(self, request, timeout):
                calls.append(request)
                raise urllib.error.HTTPError(request.full_url, 401, "Unauthorized", {},
                                             io.BytesIO(b'{"error":"unauthorized"}'))
        result = deploy.negative_smoke(Fake())
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0].method, "POST")
        self.assertIsNone(calls[0].get_header("Authorization"))
        self.assertIsNone(calls[0].get_header("X-bil-dispatch-secret"))
        self.assertEqual(calls[1].get_header("X-bil-dispatch-secret"), "public-negative-probe-not-a-secret")
        self.assertTrue(all(not row["push_dispatch_path_entered"] for row in result))

    def test_management_resource_cannot_target_another_function_or_schema(self):
        for path in ("/ai-coach", "/../database/query", "/community-push-dispatch/secrets"):
            with self.subTest(path=path):
                with self.assertRaises(deploy.GuardFailure):
                    deploy.management(path)


if __name__ == "__main__":
    unittest.main()
