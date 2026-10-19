import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class VisionDeployReadinessStaticContract(unittest.TestCase):
    def test_schema_separates_identity_from_visible_observations(self):
        types = (ROOT / "supabase/functions/analyze-meal/providers/types.ts").read_text(encoding="utf-8")
        prompt = (ROOT / "supabase/functions/analyze-meal/providers/prompt.ts").read_text(encoding="utf-8")
        normalizer = (ROOT / "supabase/functions/analyze-meal/providers/normalize.ts").read_text(encoding="utf-8")
        for marker in ("dish_identity", "visible_components"):
            self.assertIn(marker, types)
            self.assertIn(marker, prompt)
            self.assertIn(marker, normalizer)
        self.assertIn("identity.confidence < 0.90", normalizer)
        self.assertIn("item.confidence >= 0.92", normalizer)
        self.assertIn("nonFoodComponentLabel", normalizer)
        self.assertIn("dish_identity = null", normalizer)

    def test_deterministic_provider_validation_is_not_retried(self):
        runner = (ROOT / "tool/meal_vision_benchmark/run_live_synthetic_benchmark.ps1").read_text(encoding="utf-8")
        self.assertIn("nonRetryableProviderValidation", runner)
        self.assertIn("malformed_response|not_configured", runner)

    def test_live_http_failure_diagnostics_keep_the_original_response(self):
        helper = (ROOT / "tool/release/http_failure_body.ps1").read_text(encoding="utf-8")
        self.assertIn("$Failure.ErrorDetails.Message", helper)
        self.assertIn("$content.ReadAsStringAsync()", helper)
        self.assertIn("return [string]$exception.Message", helper)
        self.assertNotIn("Get-HttpFailureBody($Exception)", helper)
        for relative in (
            "tool/ai_coach/run_live_text_e2e.ps1",
            "tool/meal_vision_benchmark/run_live_synthetic_benchmark.ps1",
            "tool/meal_vision_benchmark/run_live_supabase_e2e.ps1",
        ):
            runner = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIn("http_failure_body.ps1", runner)
            self.assertIn("Get-HttpFailureBody $_", runner)

    def test_versioned_pro_pricing_migration_is_additive(self):
        migration = (ROOT / "supabase/migrations/202608110003_bil_gemini_25_pro_pricing.sql").read_text(encoding="utf-8")
        self.assertIn("gemini-2.5-pro", migration)
        self.assertIn("on conflict", migration.casefold())
        for destructive in ("drop table", "truncate", "delete from"):
            self.assertNotIn(destructive, migration.casefold())

    def test_holdout7_is_frozen_and_has_separate_truth(self):
        manifest = (ROOT / "tool/meal_vision_benchmark/benchmark_manifest.holdout7_separated_owned.json").read_text(encoding="utf-8")
        self.assertIn('"dish_identity_truth"', manifest)
        self.assertIn('"visible_component_truth"', manifest)
        self.assertIn('"image_policy"', manifest)


if __name__ == "__main__":
    unittest.main()
