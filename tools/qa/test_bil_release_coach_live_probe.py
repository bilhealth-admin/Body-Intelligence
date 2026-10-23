import copy
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import bil_release_coach_live_probe as probe


class CoachLiveProbeGuards(unittest.TestCase):
    def result(self, actions=None):
        return dict(success=True, session_revoked=True, user_deleted=True,
                    cascade_clean=True, quota_reserved=0, duplicate_status=409,
                    provider='gemini', provider_attempts=1,
                    proposed_actions=actions or [], missing_data=['duration'], reply='راجع خطتك')

    def test_target_is_never_an_observed_weight(self):
        action = dict(type='log_weight', arguments={'weightKg': 60}, requires_confirmation=True)
        with self.assertRaisesRegex(ValueError, 'observed diary'):
            probe.validate('target_goal', self.result([action]))
        probe.validate('target_goal', self.result([dict(type='update_goal', arguments={'targetWeightKg': 60})]))

    def test_real_numeric_value_and_confirmation_are_required(self):
        action = dict(type='log_weight', arguments={'weightKg': 60}, requires_confirmation=True)
        probe.validate('log_weight', self.result([action]))
        for arguments in ({}, {'weightKg': 82}, {'weightKg': '60'}):
            with self.assertRaises(ValueError):
                probe.validate('log_weight', self.result([{**action, 'arguments': arguments}]))
        with self.assertRaisesRegex(ValueError, 'confirmation'):
            probe.validate('log_weight', self.result([{**action, 'requires_confirmation': False}]))

    def test_plan_duration_and_focus_survive_the_actual_response(self):
        action = dict(type='create_smart_plan_draft', arguments={'horizon': 'month', 'focus': 'combined'})
        probe.validate('combined_month', self.result([action]))
        with self.assertRaisesRegex(ValueError, 'duration'):
            probe.validate('three_months', self.result([action]))
        with self.assertRaisesRegex(ValueError, 'focus'):
            probe.validate('combined_month', self.result([{**action, 'arguments': {'horizon': 'month'}}]))

    def test_missing_saved_plan_cannot_become_a_fabricated_action(self):
        for action in ('record_smart_plan_workout', 'request_smart_plan_revision'):
            with self.assertRaisesRegex(ValueError, 'absent saved plan'):
                probe.validate('today', self.result([{'type': action, 'arguments': {'planId': 'invented'}}]))

    def test_cleanup_settlement_and_duplicate_checks_cannot_be_skipped(self):
        for key, value in [('success', False), ('session_revoked', False), ('user_deleted', False),
                           ('cascade_clean', False), ('quota_reserved', 1), ('duplicate_status', 200)]:
            response = copy.deepcopy(self.result())
            response[key] = value
            with self.assertRaises(ValueError):
                probe.validate('missed', response)

    def test_generated_probe_keeps_existing_cleanup_and_no_model_override(self):
        source = probe.script_for('log_weight')
        self.assertIn('supabase@2.121.0', source)
        self.assertNotIn('supabase@latest', source)
        self.assertIn('smart_plan_tools_version = 1', source)
        self.assertIn('Log my weight as 60 kg.', source)
        self.assertIn('finally {', source)
        self.assertIn('cascade_clean = $cascadeClean', source)
        self.assertIn('Remove-Variable serverKey, publishableKey, password', source)
        self.assertNotIn('$PSScriptRoot', source)
        self.assertNotIn('functions deploy', source)


    def test_actual_powershell_request_ast_matches_native_capability_versions(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        self.assertIsNotNone(shell, 'PowerShell is required by the live QA contract')
        audit = r"""
param([string]$ProbePath)
$tokens=$null; $errors=$null
$tree=[System.Management.Automation.Language.Parser]::ParseFile($ProbePath,[ref]$tokens,[ref]$errors)
if ($errors.Count -ne 0) { throw 'Generated probe has PowerShell syntax errors' }
$assignments=@($tree.FindAll({
 param($node)
 $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
 $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
 $node.Left.VariablePath.UserPath -eq 'body'
},$true))
if($assignments.Count -ne 1){throw 'Expected one actual request-body assignment'}
$table=$assignments[0].Right.PipelineElements[0].Expression
if($table -isnot [System.Management.Automation.Language.HashtableAst]){throw 'Request body is not a literal hashtable'}
$caps=@{}
foreach($pair in $table.KeyValuePairs){
 $key=$pair.Item1.Value
 if($key -in @('health_citation_catalog_version','smart_plan_tools_version')){
  $value=$pair.Item2.PipelineElements[0].Expression
  if($value -isnot [System.Management.Automation.Language.ConstantExpressionAst]){throw 'Capability must be a numeric literal'}
  $caps[$key]=$value.Value
 }
}
$caps | ConvertTo-Json -Compress
"""
        with tempfile.TemporaryDirectory(prefix='bil-coach-capability-ast-') as folder:
            script = Path(folder) / 'probe.ps1'
            parser = Path(folder) / 'audit.ps1'
            script.write_text(probe.script_for('log_weight'), encoding='utf8')
            parser.write_text(audit, encoding='utf8')
            result = subprocess.run([shell, '-NoLogo', '-NoProfile', '-NonInteractive',
                                     '-File', str(parser), '-ProbePath', str(script)],
                                    capture_output=True, text=True, encoding='utf8', timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr[-1500:])
        self.assertEqual(json.loads(result.stdout),
                         {'smart_plan_tools_version': 1, 'health_citation_catalog_version': 2})

    def test_food_probe_uses_only_static_consented_fixture_context(self):
        for case in ('allergy_dinner_ar', 'allergy_dinner_en'):
            source = probe.script_for(case)
            self.assertIn('dietaryPreferences = @{ allergens = @("peanut", "milk", "sesame")', source)
            self.assertIn("p_purpose = 'remote_ai'", source)
            self.assertIn('cascade_clean = $cascadeClean', source)
            self.assertNotIn('functions deploy', source)

    def test_third_call_requires_verified_total_deadline_and_one_settlement(self):
        response = self.result()
        response.update(provider_attempts=3, latency_ms=21000)
        probe.validate('today', response)
        for elapsed in (None, False, -1, 28000, '21000'):
            with self.assertRaises(ValueError):
                probe.validate('today', {**response, 'latency_ms': elapsed})
        with self.assertRaises(ValueError):
            probe.validate('today', {**response, 'quota_reserved': 1})

    def test_failure_can_continue_only_after_all_real_cleanup_counts_are_zero(self):
        report = dict(kind='cleanup', session_revoked=True, user_deleted=True, cascade_clean=True,
            counts={k: 0 for k in ('auth_users', 'grants', 'subscriptions', 'events', 'usage',
                'credit_weekly_usage', 'credit_monthly_usage', 'credit_balances', 'feedback', 'consents')})
        encode = lambda value: 'BIL_AI_COACH_DIAGNOSTIC='+json.dumps(value)
        self.assertTrue(probe.verified_failed_cleanup(encode(report)))
        self.assertFalse(probe.verified_failed_cleanup(''))
        for value in (False, None, '0', 1):
            broken = copy.deepcopy(report)
            broken['counts']['auth_users'] = value
            self.assertFalse(probe.verified_failed_cleanup(encode(broken)))
        self.assertFalse(probe.verified_failed_cleanup(encode({**report, 'user_deleted': False})))

    def test_false_draft_claim_is_rejected_in_text_and_voice(self):
        for key in ('reply', 'spoken_reply'):
            response = self.result()
            response[key] = 'I have initiated a draft Smart Plan for your review.'
            with self.assertRaisesRegex(ValueError, 'native receipt'):
                probe.validate('need_plan', response)


if __name__ == '__main__':
    unittest.main()
