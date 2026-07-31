import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('governance documents agree on the accepted program baseline', () {
    const baseline = 'ea024c85365ee2a14e8594231d6a14d941acd246';
    const documents = <String>[
      'docs/PROJECT_STATE.md',
      'docs/ROADMAP.md',
      'docs/MASTER_ROADMAP.md',
      'docs/NEXT_PACKAGES.md',
    ];

    for (final path in documents) {
      final source = File(path).readAsStringSync();
      expect(source, contains(baseline), reason: path);
      expect(source, contains('post-program'), reason: path);
    }
  });

  test('closed work is not advertised as a pending package', () {
    final nextPackages = File('docs/NEXT_PACKAGES.md').readAsStringSync();

    expect(nextPackages, contains('No implementation package is currently'));
    expect(nextPackages, contains('must not be listed as future work'));
    expect(nextPackages, contains('Historical package candidates are records'));
  });
}
