import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BodyMeasurementRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BodyMeasurementRepository(database);
  });
  tearDown(() => database.close());

  test('stores all six measurements and updates one logical day', () async {
    final date = DateTime(2026, 8, 11, 8);
    await repository.saveForDay(
      date: date,
      neckCm: 38,
      waistCm: 88,
      hipsCm: 96,
      chestCm: 102,
      armCm: 34,
      thighCm: 57,
    );
    await repository.saveForDay(
      date: DateTime(2026, 8, 11, 20),
      neckCm: 37.5,
      waistCm: 87,
      hipsCm: 95,
      chestCm: 101,
      armCm: 34,
      thighCm: 56.5,
    );

    final rows = await repository.watchHistory().first;
    expect(rows, hasLength(1));
    expect(rows.single.hipsCm, 95);
    expect(rows.single.waistCm, 87);
    expect(rows.single.revision, 2);
  });

  test('keeps historical days separate and rejects unsafe values', () async {
    await repository.saveForDay(date: DateTime(2026, 8, 10), waistCm: 90);
    await repository.saveForDay(date: DateTime(2026, 8, 11), waistCm: 89);
    expect(await repository.watchHistory().first, hasLength(2));
    expect(
      () => repository.saveForDay(
        date: DateTime(2026, 8, 12),
        hipsCm: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.saveForDay(date: DateTime(2026, 8, 12), neckCm: 301),
      throwsArgumentError,
    );
  });

  test('empty optional snapshot creates no row', () async {
    await repository.saveForDay(date: DateTime(2026, 8, 11));
    expect(await repository.watchHistory().first, isEmpty);
  });
}
