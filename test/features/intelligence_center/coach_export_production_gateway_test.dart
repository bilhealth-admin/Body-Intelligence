import 'package:body_intelligence_log/app/services/local_data_lifecycle_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_export_command.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'default production export prepares every selected dataset locally',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final lifecycle = LocalDataLifecycleService(database);
      final service = CoachExportCommandService.production(lifecycle);
      final prepared = await service.prepare();
      expect(prepared.datasets, {
        'progress',
        'meal_nutrition',
        'exercise_notes',
      });
      expect(
        prepared.files.keys,
        unorderedEquals([
          'BIL-progress.csv',
          'BIL-meal-nutrition.csv',
          'BIL-exercise.csv',
        ]),
      );
      final actual = await lifecycle.exportCsvFiles();
      expect(prepared.files, actual);
      expect(
        prepared.files.values.every((csv) => csv.trim().isNotEmpty),
        isTrue,
      );
    },
  );
  test(
    'missing selected dataset produces explicit error before sharing',
    () async {
      final service = CoachExportCommandService(
        data: _Missing(),
        share: _NoShare(),
      );
      await expectLater(
        service.prepare(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('exercise_notes'),
          ),
        ),
      );
    },
  );
}

class _Missing implements CoachExportDataGateway {
  @override
  Future<Map<String, String>> exportCsvFiles({
    DateTime? from,
    DateTime? to,
  }) async => {
    'BIL-progress.csv': 'date,weight',
    'BIL-meal-nutrition.csv': 'date,meal',
  };
}

class _NoShare implements CoachExportShareGateway {
  @override
  Future<void> sharePortableCsvFiles(Map<String, String> files) =>
      throw StateError('Preparation must not share');
}
