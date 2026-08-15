import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hand-maintained Dart sources stay below the architecture ceiling', () {
    const maximumLines = 700;
    const documentedExceptions = <String>{
      'lib/app/localization/app_localizations.dart',
      'lib/data/repositories/food_repository.dart',
      'lib/data/repositories/meal_repository.dart',
      // Cohesive, independently reviewed presentation/content boundaries.
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      'lib/features/wellness/domain/wellness_content_pack.dart',
      'lib/features/wellness/presentation/recipe_library_page.dart',
      'lib/features/wellness/presentation/workout_library_page.dart',
      'lib/features/wellness/presentation/bil_workout_routines_list.dart',
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
