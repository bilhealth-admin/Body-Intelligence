import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production text sources contain no common mojibake markers', () {
    const forbidden = <String>['Ø', 'Ù', 'Ã', 'Â', 'â€', '\uFFFD'];
    const extensions = <String>{
      '.dart',
      '.arb',
      '.json',
      '.yaml',
      '.yml',
      '.txt',
      '.csv',
    };
    final violations = <String>[];

    for (final rootPath in const ['lib', 'assets']) {
      final root = Directory(rootPath);
      if (!root.existsSync()) continue;

      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        final extension = dot == -1 ? '' : name.substring(dot).toLowerCase();
        if (!extensions.contains(extension)) continue;

        String content;
        try {
          content = entity.readAsStringSync();
        } on FileSystemException {
          continue;
        }

        for (final marker in forbidden) {
          if (content.contains(marker)) {
            violations.add('${entity.path}: contains "$marker"');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Corrupted production text was found:\n'
          '${violations.join('\n')}',
    );
  });
}
