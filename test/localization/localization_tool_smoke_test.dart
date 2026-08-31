import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'extended runtime generator discovers the current onboarding sources',
    () async {
      final result = await Process.run('dart', const [
        'tool/localization/generate_extended_runtime_copy.dart',
        '--check-sources',
      ], runInShell: true);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('EXTENDED_RUNTIME_SOURCE_CHECK=PASS'));
    },
  );

  test(
    'auth and onboarding 25-locale audit runs against live sources',
    () async {
      final result = await Process.run('dart', const [
        'tool/localization/audit_auth_onboarding_25.dart',
      ], runInShell: true);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('MISSING=0'));
    },
  );
}
