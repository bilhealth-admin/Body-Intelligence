import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app-owned Material surfaces use pearl presenters across all features', () {
    const nativeRenderers = {
      'lib/shared/widgets/bil_pearl_material.dart',
      'lib/shared/widgets/bil_pearl_alert_dialog.dart',
    };
    final raw = RegExp(
      r'(?<![\w.])(?:AlertDialog|SimpleDialog|Card|Dialog)(?:\.(?:adaptive|filled|outlined))?\(',
    );
    final failures = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || nativeRenderers.contains(path)) continue;
      if (raw.hasMatch(file.readAsStringSync())) failures.add(path);
    }
    expect(
      failures,
      isEmpty,
      reason:
          'New internal surfaces must retain the shared finish. Native permission sheets remain OS-owned.',
    );
  });
}
