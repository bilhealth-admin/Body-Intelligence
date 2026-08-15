import unittest
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INDEX = (ROOT / "supabase/functions/analyze-meal/index.ts").read_text(encoding="utf-8")
NORMALIZE = (ROOT / "supabase/functions/analyze-meal/providers/normalize.ts").read_text(encoding="utf-8")
TYPES = (ROOT / "supabase/functions/analyze-meal/providers/types.ts").read_text(encoding="utf-8")
HARDENING = (ROOT / "supabase/migrations/202608110001_bil_meal_vision_runtime_hardening.sql").read_text(encoding="utf-8")


class ProviderIntegrationContractTest(unittest.TestCase):
    def test_provider_selection_and_legacy_are_server_side(self):
        for marker in ("BIL_MEAL_VISION_PROVIDER", "legacy_gateway", "loadProviderConfig", "buildProviderRequest", "normalizeProviderResponse"):
            self.assertIn(marker, INDEX)
        dart_sources = "\n".join(path.read_text(encoding="utf-8", errors="ignore") for path in (ROOT / "lib").rglob("*.dart"))
        for secret in ("BIL_OPENAI_API_KEY", "BIL_GEMINI_API_KEY", "BIL_MISTRAL_API_KEY"):
            self.assertNotIn(secret, dart_sources)

    def test_quota_reservation_and_settlement_boundary_remains(self):
        self.assertEqual(INDEX.count("bil_reserve_ai_vision"), 1)
        self.assertEqual(INDEX.count("bil_settle_ai_vision"), 1)
        self.assertLess(INDEX.index("bil_reserve_ai_vision"), INDEX.index("await fetch("))
        self.assertIn("reservation?.duplicate === true", INDEX)
        self.assertIn("await settle(true", INDEX)
        self.assertGreaterEqual(INDEX.count("await settle(false"), 5)

    def test_unified_candidate_and_nullable_metrics_contract(self):
        for field in ("amount", "unit", "alternatives", "uncertainty", "warnings"):
            self.assertIn(field, TYPES)
            self.assertIn(field, NORMALIZE)
        for field in ("input_tokens", "output_tokens", "cost_usd"):
            self.assertIn(f"{field}: number | null", TYPES)
            self.assertIn(field, INDEX)
        self.assertIn("provider_metrics", INDEX)
        self.assertIn("requires_verified_food_match", TYPES)
        self.assertNotIn("sk-", INDEX)
        self.assertNotIn("AIza", INDEX)

    def test_retry_is_bounded_and_reuses_one_reservation(self):
        self.assertIn("attempt <= 2", INDEX)
        self.assertIn("transientStatus", INDEX)
        self.assertIn("provider_attempts", INDEX)
        self.assertEqual(INDEX.count("bil_reserve_ai_vision"), 1)

    def test_runtime_hardening_is_additive_and_server_managed(self):
        for marker in ("bil_reclaim_stale_vision_reservations", "reservation_ttl_seconds",
                       "bil_vision_model_pricing", "bil_estimate_vision_cost",
                       "bil_settle_vision_request_v2", "provider_attempts", "cost_source"):
            self.assertIn(marker, HARDENING)
        self.assertIn("'used',v_usage.used,'reserved',v_usage.reserved+1", HARDENING)
        self.assertIn("cost_source", INDEX)

    def test_owned_synthetic_smoke_manifest_has_real_local_paths(self):
        path = ROOT / "tool/meal_vision_benchmark/benchmark_manifest.synthetic_owned.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["cases"]), 7)
        for case in manifest["cases"]:
            self.assertTrue(case["synthetic"])
            self.assertFalse(case["fixture_only"])
            self.assertTrue((ROOT / case["image_path"]).is_file())


if __name__ == "__main__":
    unittest.main()
