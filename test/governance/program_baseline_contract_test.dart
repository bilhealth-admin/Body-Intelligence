import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _normalized(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('governance documents agree on the accepted current baseline', () {
    const baseline = '9fe26c3ceddf6e1d1de6bcb04344da043f3bb338';
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
      expect(source, contains('Premium UI'), reason: path);
    }
  });

  test('only the authorized launch phase is advertised as pending work', () {
    final nextPackages = _normalized(
      File('docs/NEXT_PACKAGES.md').readAsStringSync(),
    );

    expect(nextPackages, contains('BIL V1 Global Launch Readiness'));
    expect(nextPackages, contains('BIL-V1-LAUNCH-001'));
    expect(nextPackages, contains('must not be listed as future work'));
    expect(nextPackages, contains('Historical package candidates are records'));
  });

  test('premium UI closure is durable and no longer future work', () {
    final roadmap = _normalized(File('docs/ROADMAP.md').readAsStringSync());
    final closure = File(
      'docs/architecture/BIL_PREMIUM_UI_EPIC_CLOSURE.md',
    ).readAsStringSync();

    expect(roadmap, contains('Premium UI is accepted closed work'));
    expect(closure, contains('repository scope'));
    expect(closure, contains('External acceptance gates'));
  });
}
