import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_library_source.dart';

void main() {
  test('dashboard omits retired body metrics without removing engine data', () {
    final dashboard = readDartLibrarySource(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    );
    final composer = File(
      'lib/features/dashboard/domain/dashboard_intelligence_composer.dart',
    ).readAsStringSync();
    final adapter = File(
      'lib/features/dashboard/composition/dashboard_intelligence_input_adapter.dart',
    ).readAsStringSync();
    final engine = File('lib/engine/bil_engine.dart').readAsStringSync();
    final connectedHealth = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    // BMR, TDEE, and body-composition values remain available to non-dashboard
    // engine consumers, but the production dashboard must not render or wire
    // the retired metrics back into its presentation tree.
    expect(engine, contains('final double bmr;'));
    expect(engine, contains('final double tdee;'));
    expect(composer, contains('bil.bodyModel.composition'));
    expect(composer, contains('tdee: bil.tdee.round()'));
    expect(composer, isNot(contains('BodyCompositionEngine.calculate(')));

    expect(dashboard, isNot(contains('DashboardBodyProfileSnapshot(')));
    expect(dashboard, isNot(contains('DashboardSummaryFactory.build(')));
    expect(dashboard, isNot(contains('PersonalHealthAiPanel(')));
    expect(dashboard, isNot(contains('bodyFatUnit:')));
    expect(dashboard, isNot(contains('fatFreeMass:')));
    expect(dashboard, isNot(contains('dailyMetabolism:')));
    expect(
      dashboard,
      contains("hiddenSignalKeys: const <String>{'bodyFat', 'leanMass'},"),
    );
    expect(connectedHealth, contains('!hiddenSignalKeys.contains(signal.key)'));
    for (final retiredLabel in const [
      'معدل الأيض اليومي',
      'مؤشر كتلة الجسم',
      'نسبة دهون الجسم',
      'الكتلة الخالية من الدهون',
    ]) {
      expect(
        dashboard,
        isNot(contains(retiredLabel)),
        reason: 'Retired dashboard metric returned: $retiredLabel',
      );
    }

    // Measurements are still adapted for engine consumers; their presence in
    // the input contract is not permission to expose the retired dashboard UI.
    expect(adapter, contains('profile.neck'));
    expect(adapter, contains('profile.waist'));
    expect(
      adapter,
      contains('neckCm: latestBodyMeasurement?.neckCm ?? profile.neck'),
    );
    expect(
      adapter,
      contains('waistCm: latestBodyMeasurement?.waistCm ?? profile.waist'),
    );
    expect(adapter, contains('hipsCm: latestBodyMeasurement?.hipsCm'));
  });
}
