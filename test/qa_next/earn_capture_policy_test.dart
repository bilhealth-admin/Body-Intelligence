import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Earn keeps every behavioral case when optional PNG output is off', () {
    const earn = 'test/features/community/community_earn_composer_test.dart';
    final source = File('tool/prebuild/run_code_tests.py').readAsStringSync();
    final directories = RegExp(
      r'ENV_CAPTURE_DIRECTORIES = \{([\s\S]*?)\n\}',
    ).firstMatch(source)!.group(1)!;
    expect(directories, contains('"$earn": "BIL_EARN_CAPTURE_DIR"'));
    for (final table in ['NOT_RUN', 'MIXED_NAMES']) {
      final block = RegExp(
        '$table = \\{([\\s\\S]*?)\\n\\}',
      ).firstMatch(source)!.group(1)!;
      expect(block, isNot(contains(earn)), reason: table);
    }
    expect(source, contains('os.environ.pop(flag, None)'));
    final suite = File(earn).readAsStringSync();
    expect(suite, contains("if (directory == null) return;"));
    expect(suite, contains('for (final scale in [1.0, 2.0])'));
    expect(suite, contains('expect(repo.publications, isEmpty)'));
    expect(suite, contains('expect(repo.claims, 0)'));
  });
}
