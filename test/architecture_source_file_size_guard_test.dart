import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hand-maintained Dart sources stay below the architecture ceiling', () {
    const maximumLines = 700;
    const documentedExceptions = <String>{
      'lib/app/localization/app_localizations.dart',
      'lib/data/repositories/food_repository.dart',
      'lib/data/repositories/meal_repository.dart',
    };

    final oversized = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final path = entity.path.replaceAll(Platform.pathSeparator, '/');
      if (path.endsWith('.g.dart') || documentedExceptions.contains(path)) {
        continue;
      }

      final lines = entity.readAsLinesSync().length;
      if (lines > maximumLines) oversized.add('$path ($lines lines)');
    }

    expect(
      oversized,
      isEmpty,
      reason:
          'Split oversized sources by responsibility. If a cohesive boundary '
          'must exceed $maximumLines lines, document and review the exception.',
    );
  });
}
