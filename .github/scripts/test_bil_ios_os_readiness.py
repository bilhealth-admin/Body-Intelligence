"""OS provisioning clocks/subprocess fixtures; never real Simulator/app proof."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

import bil_ios_os_readiness as readiness

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/qa'))
import bil_native_source_evidence as source_evidence

DEVICE = '12345678-1234-5678-1234-1234567890ab'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-27-2'


class Clock:
    value = 0.0

    def __call__(self):
        return self.value


class FakeRun:
    def __init__(self, clock, durations=(), initial='Shutdown', final='Booted', fail=None, status=7, png=True,
                 runtime=RUNTIME, final_document=None, fail_label=None):
        self.clock, self.durations = clock, list(durations)
        self.initial, self.final, self.fail, self.status, self.png = initial, final, fail, status, png
        self.runtime, self.final_document, self.fail_label = runtime, final_document, fail_label
        self.calls, self.state_queries = [], 0

    def __call__(self, command, **options):
        self.calls.append((command, options))
        self.clock.value += self.durations.pop(0) if self.durations else 0
        text = ''
        if command[2] == 'list':
            is_final = self.state_queries > 0
            state = self.initial if self.state_queries == 0 else self.final
            self.state_queries += 1
            if is_final and self.final_document is not None:
                text = self.final_document if isinstance(self.final_document, str) else json.dumps(self.final_document)
            else:
                text = json.dumps({'devices': {self.runtime: [{'udid': DEVICE, 'state': state}]}})
        elif command[2] == 'io' and self.png:
            Path(command[-1]).write_bytes(b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR' + struct.pack('>II', 1200, 1600))
        elif command[2] == 'spawn':
            text = 'system = { responsive synthetic guest fixture }\n'
        options['log_path'].write_text(text, encoding='utf8')
        options['receipt_path'].write_text('{}', encoding='utf8')
        return self.status if command[2] == self.fail or options['label'] == self.fail_label else 0


class OSReadinessTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bil-ios-os-budget-')
        self.path = Path(self.temp.name).resolve()
        self.addCleanup(self.cleanup_owned_fixture)
        self.clock = Clock()

    def cleanup_owned_fixture(self):
        base = Path(tempfile.gettempdir()).resolve()
        if self.path == base or not self.path.is_relative_to(base):
            raise RuntimeError('Fixture cleanup must remain in its explicit temp directory')
        self.temp.cleanup()

    def invoke(self, run, *, runtime=RUNTIME, output=None, **options):
        path = self.path if output is None else output
        status = readiness.require_os_readiness(DEVICE, runtime, path, 'runner-tests',
            run=run, clock=self.clock, resources=lambda _: {'fixture_resources': True}, host='darwin', **options)
        receipt = json.loads((path / 'runner-tests-os-readiness.json').read_text())
        return status, receipt

    def test_budget_uses_selected_runtime_major_only_and_keeps_26_default(self):
        self.assertEqual(readiness.budget_seconds('com.apple.CoreSimulator.SimRuntime.iOS-26-1'), 180)
        self.assertEqual(readiness.budget_seconds(RUNTIME), 600)
        self.assertEqual(readiness.budget_seconds('com.apple.CoreSimulator.SimRuntime.iOS-27-0'), 600)
        self.assertEqual(readiness.budget_seconds('com.apple.CoreSimulator.SimRuntime.iOS-28-0'), 180)
        with self.assertRaises(ValueError):
            readiness.budget_seconds('27')

    def test_observed_slow_boot_and_os_health_share_one_remaining_budget(self):
        run = FakeRun(self.clock, durations=[2, 5, 328, 2, 29, 12])
        status, receipt = self.invoke(run)
        self.assertEqual(status, 0)
        self.assertEqual(receipt['actual_elapsed_seconds'], 378)
        self.assertEqual([c[1]['timeout_seconds'] for c in run.calls], [600, 598, 593, 265, 263, 234])
        self.assertEqual(sum(c[0][2] == 'boot' for c in run.calls), 1)
        self.assertEqual(sum(c[0][2] == 'bootstatus' for c in run.calls), 1)
        self.assertFalse(receipt['application_acceptance'])
        self.assertFalse(receipt['native_tests_proven'])

    def test_sdk27_postboot_query_selects_exact_uuid_and_keeps_initial_catalog(self):
        run = FakeRun(self.clock)
        status, receipt = self.invoke(run)
        self.assertEqual(status, 0)
        queries = [command for command, _ in run.calls if command[2] == 'list']
        self.assertEqual(queries, [
            ['xcrun', 'simctl', 'list', 'devices', '-j'],
            ['xcrun', 'simctl', 'list', 'devices', DEVICE, '--json'],
        ])
        self.assertEqual(receipt['total_budget_seconds'], 600)
        self.assertEqual(receipt['status'], 'OS_READY')
        self.assertTrue(any(command[2] == 'io' for command, _ in run.calls))
        self.assertTrue(any(command[2] == 'spawn' for command, _ in run.calls))

    def test_sdk26_state_queries_and_remaining_budget_remain_unchanged(self):
        runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-26-1'
        run = FakeRun(self.clock, runtime=runtime, durations=[1, 2, 3, 4, 5, 6])
        status, receipt = self.invoke(run, runtime=runtime)
        self.assertEqual(status, 0)
        self.assertEqual([command for command, _ in run.calls if command[2] == 'list'], [
            ['xcrun', 'simctl', 'list', 'devices', '-j'],
            ['xcrun', 'simctl', 'list', 'devices', '-j'],
        ])
        self.assertEqual(receipt['total_budget_seconds'], 180)
        self.assertEqual([options['timeout_seconds'] for _, options in run.calls], [180, 179, 177, 174, 170, 165])

    def test_filtered_response_keeps_exact_runtime_uuid_uniqueness_and_booted_guards(self):
        target = {'udid': DEVICE, 'state': 'Booted'}
        cases = {
            'missing': {'devices': {RUNTIME: []}},
            'wrong-target': {'devices': {RUNTIME: [{'udid': 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'state': 'Booted'}]}},
            'lookalike-target': {'devices': {RUNTIME: [{'udid': DEVICE + '-other', 'state': 'Booted'}]}},
            'ambiguous': {'devices': {RUNTIME: [target, dict(target)]}},
            'wrong-runtime': {'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-26-1': [target]}},
            'shutdown': {'devices': {RUNTIME: [{'udid': DEVICE, 'state': 'Shutdown'}]}},
            'still-booting': {'devices': {RUNTIME: [{'udid': DEVICE, 'state': 'Booting'}]}},
            'invalid-json': '{not valid JSON',
        }
        for name, document in cases.items():
            with self.subTest(name=name):
                self.clock.value = 0
                run = FakeRun(self.clock, final_document=document)
                status, receipt = self.invoke(run, output=self.path / name)
                self.assertNotEqual(status, 0)
                self.assertEqual(receipt['status'], 'FAILED_CLOSED')
                self.assertEqual(len(run.calls), 4)
                self.assertFalse(any(command[2] in ('io', 'spawn') for command, _ in run.calls))
                self.assertFalse(receipt['application_acceptance'])
                self.assertFalse(receipt['native_tests_proven'])

    def test_filtered_query_error_and_timeout_never_fallback_or_refresh_budget(self):
        for name, code, duration in [('error', 7, 1), ('timeout', 124, 266)]:
            with self.subTest(name=name):
                self.clock.value = 0
                run = FakeRun(self.clock, durations=[2, 5, 328, duration],
                              fail_label='runner-tests-os-ready-state', status=code)
                status, receipt = self.invoke(run, output=self.path / name)
                self.assertEqual(status, code)
                self.assertEqual(len(run.calls), 4)
                self.assertEqual(run.calls[-1][1]['timeout_seconds'], 265)
                self.assertEqual(receipt['commands'][-1]['stage'], 'os-ready-state')
                self.assertEqual(receipt['status'], 'FAILED_CLOSED')
                self.assertFalse(any(command[2] in ('io', 'spawn') for command, _ in run.calls))

    def test_already_booted_skips_boot_request_but_keeps_one_bootstatus(self):
        run = FakeRun(self.clock, initial='Booted')
        status, receipt = self.invoke(run)
        self.assertEqual(status, 0)
        self.assertFalse(any(c[0][2] == 'boot' for c in run.calls))
        self.assertEqual(sum(c[0][2] == 'bootstatus' for c in run.calls), 1)
        self.assertEqual(receipt['boot_request'], 'SKIPPED_ALREADY_BOOTED')

    def test_boot_failure_stops_before_bootstatus_and_any_application_work(self):
        run = FakeRun(self.clock, fail='boot', status=7)
        status, receipt = self.invoke(run)
        self.assertEqual(status, 7)
        self.assertEqual([c[0][2] for c in run.calls], ['list', 'boot'])
        self.assertEqual(receipt['status'], 'FAILED_CLOSED')

    def test_bootstatus_stall_never_retries_or_starts_health_or_app(self):
        run = FakeRun(self.clock, durations=[2, 5, 603], fail='bootstatus', status=124)
        status, receipt = self.invoke(run)
        self.assertEqual(status, 124)
        self.assertEqual(receipt['actual_elapsed_seconds'], 610)
        self.assertEqual(receipt['deadline_overshoot_seconds'], 10)
        self.assertEqual([c[0][2] for c in run.calls], ['list', 'boot', 'bootstatus'])
        self.assertEqual(receipt['commands'][-1]['actual_elapsed_seconds'], 603)

    def test_zero_exit_after_total_deadline_is_still_failure(self):
        run = FakeRun(self.clock, durations=[0, 0, 600])
        status, receipt = self.invoke(run)
        self.assertEqual(status, 124)
        self.assertEqual(len(run.calls), 3)
        self.assertEqual(receipt['status'], 'FAILED_CLOSED')

    def test_remaining_budget_includes_screenshot_and_guest_health(self):
        run = FakeRun(self.clock, durations=[1, 2, 500, 1, 80, 17])
        status, receipt = self.invoke(run)
        self.assertEqual(status, 124)
        self.assertEqual(run.calls[-1][1]['timeout_seconds'], 16)
        self.assertEqual(receipt['deadline_overshoot_seconds'], 1)
        self.assertEqual(receipt['commands'][-1]['stage'], 'os-guest-health')

    def test_unresponsive_guest_fails_after_successful_bootstatus_without_retry(self):
        run = FakeRun(self.clock, fail='spawn', status=124)
        status, receipt = self.invoke(run)
        self.assertEqual(status, 124)
        self.assertEqual(sum(c[0][2] == 'bootstatus' for c in run.calls), 1)
        self.assertEqual(receipt['status'], 'FAILED_CLOSED')

    def test_wrong_os_state_and_missing_screenshot_fail_closed(self):
        run = FakeRun(self.clock, final='Shutdown')
        status, _ = self.invoke(run)
        self.assertNotEqual(status, 0)
        self.assertFalse(any(c[0][2] == 'io' for c in run.calls))

    def test_missing_screenshot_does_not_reach_guest_or_app(self):
        run = FakeRun(self.clock, png=False)
        status, receipt = self.invoke(run)
        self.assertNotEqual(status, 0)
        self.assertEqual(receipt['status'], 'FAILED_CLOSED')
        self.assertFalse(any(c[0][2] == 'spawn' for c in run.calls))

    def test_subprocess_boundary_exception_keeps_actual_elapsed_and_fails(self):
        def broken(command, **options):
            self.clock.value += 14
            raise OSError('synthetic process spawn failure')
        status, receipt = self.invoke(broken)
        self.assertNotEqual(status, 0)
        self.assertEqual(receipt['actual_elapsed_seconds'], 14)
        self.assertEqual(receipt['commands'][0]['actual_elapsed_seconds'], 14)

    def test_existing_native_source_pins_include_exact_new_helper_bytes(self):
        name = '.github/scripts/bil_ios_os_readiness.py'
        for device in ('iphone', 'ipad'):
            self.assertIn(name, source_evidence.native_source_paths(device))
            self.assertEqual(source_evidence.native_source_pins(ROOT, device)[name],
                hashlib.sha256((ROOT / name).read_bytes()).hexdigest())

    def test_actual_caller_keeps_sdk26_deadlines_and_gates_sdk27_before_app_work(self):
        script = (ROOT / '.github/scripts/bil39_ios_native_integration.sh').read_text()
        self.assertIn('stage runner-tests-bootstatus 180 ', script)
        self.assertIn('stage "$LABEL-$KIND-bootstatus" 180 ', script)
        self.assertLess(script.index('require_sdk27_os_readiness runner-tests'),
                        script.index('python3 .github/scripts/bil_ios_runner_tests.py'))
        loop = script.split('for KIND in "${KINDS[@]}"; do', 1)[1]
        self.assertLess(loop.index('require_sdk27_os_readiness "$LABEL-$KIND"'),
                        loop.index('stage "$KIND-generic-config"'))
        self.assertIn('if [[ "$RUNTIME" != com.apple.CoreSimulator.SimRuntime.iOS-27-* ]]', loop)
        self.assertNotIn('continue-on-error', script)


if __name__ == '__main__':
    unittest.main(verbosity=2)
