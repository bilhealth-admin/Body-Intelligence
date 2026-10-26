import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/providers/product_intelligence_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_reader.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

enum _ReadCase { empty, error, timeout, withheld }

class _WeightFault extends WeightRepository {
  _WeightFault(super.database, this.scenario);

  _ReadCase scenario;
  final delayed = Completer<List<WeightEntry>>();

  @override
  Future<List<WeightEntry>> getAll() {
    return switch (scenario) {
      _ReadCase.error => Future.error(
        StateError('Fixture repository read failed'),
      ),
      _ReadCase.timeout => delayed.future,
      _ => super.getAll(),
    };
  }
}

class _NoNativeHealth implements ConnectedHealthGateway {
  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();

  Never _unexpected() =>
      throw StateError('No native health writes in this test');

  @override
  Future<ConnectedHealthSnapshot> synchronize() => _unexpected();
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => _unexpected();
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() =>
      _unexpected();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => _unexpected();
  @override
  Future<void> openSystemSettings() => _unexpected();
}

void main() {
  for (final scenario in _ReadCase.values) {
    test('actual context distinguishes ${scenario.name} weight read', () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'bil39-weight-context-fixture',
      );
      final repository = _WeightFault(database, scenario);
      ProviderContainer? container;
      addTearDown(() async {
        container?.dispose();
        await database.close();
      });
      if (scenario != _ReadCase.empty) {
        await WeightRepository(database).addWeight(83.2);
      }
      await PreferencesRepository(database).set(
        CoachContextPreferences.storageKey,
        CoachContextPreferences(
          focuses: scenario == _ReadCase.withheld
              ? const {}
              : const {CoachContextFocus.analytics},
        ).encode(),
      );
      final current = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          weightRepositoryProvider.overrideWithValue(repository),
          connectedHealthGatewayProvider.overrideWithValue(_NoNativeHealth()),
          productIntelligenceOutputProvider.overrideWithValue(
            AsyncError(
              StateError('No external engine in fixture'),
              StackTrace.empty,
            ),
          ),
        ],
      );
      container = current;
      final daily = current.listen(latestDailyLogProvider, (_, _) {});
      final life = current.listen(insightLifeContextProvider, (_, _) {});
      final goals = current.listen(nutritionGoalSnapshotProvider, (_, _) {});
      addTearDown(daily.close);
      addTearDown(life.close);
      addTearDown(goals.close);
      await current.read(latestDailyLogProvider.future);
      await current.read(insightLifeContextProvider.future);
      await current.read(nutritionGoalSnapshotProvider.future);
      await current.read(connectedHealthProvider.notifier).refresh();
      final result = await readCoachContextSnapshot(current);
      expect(result.weightReadStatus, switch (scenario) {
        _ReadCase.empty => CoachWeightReadStatus.verified,
        _ReadCase.withheld => CoachWeightReadStatus.withheld,
        _ => CoachWeightReadStatus.unavailable,
      });
      expect(result.weights, isEmpty);
      final actual = await WeightRepository(database).getAll();
      expect(actual, hasLength(scenario == _ReadCase.empty ? 0 : 1));
      if (scenario == _ReadCase.timeout) {
        repository.delayed.complete(actual);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          current
              .read(coachContextSnapshotProvider)
              .requireValue
              .weightReadStatus,
          CoachWeightReadStatus.unavailable,
        );
        repository.scenario = _ReadCase.empty;
        current.invalidate(coachContextSnapshotProvider);
        final retried = await readCoachContextSnapshot(current);
        expect(retried.weightReadStatus, CoachWeightReadStatus.verified);
        expect(retried.weights.single.kg, 83.2);
        expect(await WeightRepository(database).getAll(), hasLength(1));
      }
    });
  }
}
