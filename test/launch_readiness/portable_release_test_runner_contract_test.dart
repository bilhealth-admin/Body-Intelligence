import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const runnerPath = 'tool/release/run_portable_release_tests.py';
  const androidWorkflowPath =
      '.github/workflows/bil_android_release_candidate.yml';
  const iosWorkflowPath = '.github/workflows/bil_ios_signed_release.yml';

  test('portable release runner excludes only the reviewed failing files', () {
    final source = File(runnerPath).readAsStringSync();
    final exclusions = RegExp(
      r'"(test/[^"\r\n]+_test\.dart)"',
    ).allMatches(source).map((match) => match.group(1)!).toSet();

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
