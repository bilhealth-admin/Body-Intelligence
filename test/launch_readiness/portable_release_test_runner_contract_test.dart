import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const runnerPath = 'tool/release/run_portable_release_tests.py';
  const androidWorkflowPath =
      '.github/workflows/bil_android_release_candidate.yml';
  const iosWorkflowPath = '.github/workflows/bil_ios_signed_release.yml';

  test('portable release runner excludes only the reviewed failing files', () {
    final source = File(runnerPath).readAsStringSync();
    final exclusionBlock = RegExp(
      r'EXCLUDED_TESTS = frozenset\(\s*\{([\s\S]*?)\}\s*\)',
    ).firstMatch(source);
    expect(exclusionBlock, isNotNull);
    final exclusions = RegExp(r'"(test/[^"\r\n]+_test\.dart)"')
        .allMatches(exclusionBlock!.group(1)!)
        .map((match) => match.group(1)!)
        .toSet();

    expect(exclusions, hasLength(29));
    expect(
      exclusions.every((path) => File(path).existsSync()),
      isTrue,
      reason: 'Every release exclusion must remain an explicit real test.',
    );
    expect(
      exclusions,
      isNot(
        contains('test/features/admin/admin_notification_controls_test.dart'),
      ),
    );
    expect(
      exclusions,
      isNot(
        contains(
          'test/launch_readiness/'
          'system_crypto_export_compliance_contract_test.dart',
        ),
      ),
    );
    expect(source, contains('all_tests if path not in EXCLUDED_TESTS'));
    expect(source, contains('"flutter",'));
    expect(source, contains('"test",'));
    expect(exclusions, isNot(contains('test/performance_budget_test.dart')));
  });

  test('performance budgets run first without concurrent test workers', () {
    final source = File(runnerPath).readAsStringSync();
    expect(
      source,
      contains('PERFORMANCE_BUDGET_TEST = "test/performance_budget_test.dart"'),
    );
    expect(
      source,
      contains(
        '[*command, *(["--concurrency", "1"] if policy is None else []), '
        '*performance_tests]',
      ),
    );
    expect(
      source,
      contains('*policy.flutter_test_command(resolve_flutter_executable())'),
    );
    expect(
      File('tool/prebuild/run_code_tests.py').readAsStringSync(),
      contains("'test', '--no-pub', '--concurrency', '1'"),
      reason:
          'Code-only mode inherits the same serial worker limit from the '
          'shared shell-free command; the default mode adds it explicitly.',
    );
    expect(
      source,
      contains('path for path in portable if path != PERFORMANCE_BUDGET_TEST'),
    );
    final performanceRun = source.indexOf('performance = subprocess.run(');
    final failureCheck = source.indexOf('if performance.returncode != 0');
    final failureReturn = source.indexOf('return performance.returncode');
    final remainingRun = source.indexOf('[*command, *batch]');
    expect(performanceRun, greaterThan(-1));
    expect(failureCheck, greaterThan(performanceRun));
    expect(failureReturn, greaterThan(failureCheck));
    expect(remainingRun, greaterThan(failureReturn));
    expect(
      source,
      contains('partition_test_batches(command, remaining_tests)'),
    );
    expect(source, contains('PORTABLE_RELEASE_REMAINING_BATCHES'));
    expect(source, contains('PORTABLE_RELEASE_SCHEDULED_TEST_FILES'));
    expect(
      source,
      contains('PORTABLE_RELEASE_PERFORMANCE_SCHEDULED_TEST_FILES'),
    );
    expect(source, contains('PORTABLE_RELEASE_REMAINING_SCHEDULED_TEST_FILES'));
  });

  test('both signed workflows use the same portable release runner', () {
    for (final path in [androidWorkflowPath, iosWorkflowPath]) {
      final workflow = File(path).readAsStringSync();
      expect(
        workflow,
        contains('python3 tool/release/run_portable_release_tests.py'),
        reason: path,
      );
      expect(
        workflow,
        isNot(contains('flutter test --no-pub --timeout 30s')),
        reason: '$path must not reintroduce the non-portable full suite.',
      );
    }
  });
}
