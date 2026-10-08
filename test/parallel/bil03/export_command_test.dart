import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_export_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepare export never invokes share boundary', () async {
    final data = _FakeExportData();
    final share = _FakeShare();
    final service = CoachExportCommandService(data: data, share: share);

    final prepared = await service.prepare(
      from: DateTime(2026, 9, 1, 20),
      to: DateTime(2026, 9, 30, 22),
      datasets: const {'progress', 'meal_nutrition'},
    );

    expect(prepared.from, DateTime(2026, 9, 1));
    expect(prepared.to, DateTime(2026, 9, 30));
    expect(prepared.files.keys, {'BIL-progress.csv', 'BIL-meal-nutrition.csv'});
    expect(share.calls, 0);
  });

  test(
    'share is a second explicit handoff and does not claim delivery',
    () async {
      final data = _FakeExportData();
      final share = _FakeShare();
      final service = CoachExportCommandService(data: data, share: share);
      final prepared = await service.prepare(
        datasets: const {'exercise_notes'},
      );

      final status = await service.sharePrepared(prepared);

      expect(status, CoachExportShareStatus.handoffReturned);
      expect(share.calls, 1);
      expect(share.lastFiles!.keys, {'BIL-exercise-notes.csv'});
    },
  );

  test('invalid date range fails before reading health data', () async {
    final data = _FakeExportData();
    final service = CoachExportCommandService(data: data, share: _FakeShare());

    await expectLater(
      service.prepare(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 1)),
      throwsArgumentError,
    );
    expect(data.calls, 0);
  });
}

class _FakeExportData implements CoachExportDataGateway {
  int calls = 0;

  @override
  Future<Map<String, String>> exportCsvFiles({
    DateTime? from,
    DateTime? to,
  }) async {
    calls += 1;
    return const {
      'BIL-progress.csv': 'date,weightKg\n2026-09-01,90.4',
      'BIL-meal-nutrition.csv': 'date,calories\n2026-09-01,1200',
      'BIL-exercise-notes.csv': 'date,note\n2026-09-01,walk',
    };
  }
}

class _FakeShare implements CoachExportShareGateway {
  int calls = 0;
  Map<String, String>? lastFiles;

  @override
  Future<void> sharePortableCsvFiles(Map<String, String> files) async {
    calls += 1;
    lastFiles = files;
  }
}
