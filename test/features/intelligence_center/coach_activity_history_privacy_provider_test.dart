import 'dart:convert';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_cloud_privacy_boundary.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/providers/product_intelligence_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression of physical D39-015 using the actual production context provider.
// Only native readback is replaced; no cloud request or device mutation occurs.
class _ReadOnlyHealth implements ConnectedHealthGateway {
  _ReadOnlyHealth(this.value);
  final ConnectedHealthSnapshot value;
  @override
  Future<ConnectedHealthSnapshot> load() async => value;
  Never _unexpected() =>
      throw StateError('No native or remote mutation allowed');
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
  for (final selected in <Set<CoachContextFocus>>[
    {CoachContextFocus.training},
    {CoachContextFocus.habits},
    {CoachContextFocus.training, CoachContextFocus.habits},
    <CoachContextFocus>{},
  ]) {
    final label = selected.isEmpty
        ? 'none'
        : selected.map((v) => v.name).join('+');
    test(
      'withheld sleep cannot enter actual serialized production snapshot with category $label',
      () async {
        final database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'isolated-privacy-reproduction-owner',
        );
        ProviderContainer? container;
        addTearDown(() async {
          container?.dispose();
          await database.close();
        });
        await PreferencesRepository(database).setMany({
          'goal.calories': '2000',
          'goal.carbsPercent': '40',
          'goal.proteinPercent': '30',
          'goal.fatPercent': '30',
          CoachContextPreferences.storageKey: CoachContextPreferences(
            focuses: selected,
          ).encode(),
        });
        final now = DateTime.now();
        final health = _ReadOnlyHealth(
          ConnectedHealthSnapshot(
            status: ConnectedHealthStatus.synchronized,
            platformSource: 'isolated-fixture',
            availableSources: const ['isolated-fixture'],
            signals: [
              ConnectedHealthSignalView(
                key: 'sleep',
                value: 7.25,
                unit: 'h',
                source: 'isolated-fixture',
                observedAt: now,
                confidence: 1,
              ),
            ],
            importedCount: 1,
            lastSyncAt: now,
            failureCode: null,
            deviceVerified: true,
          ),
        );
        final current = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            connectedHealthGatewayProvider.overrideWithValue(health),
            productIntelligenceOutputProvider.overrideWithValue(
              AsyncError(
                StateError(
                  'Optional canonical engine unavailable in isolated test',
                ),
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
        final snapshot = await current.read(
          coachContextSnapshotProvider.future,
        );
        final remote = projectCoachCloudContext(
          question: 'Explain my recorded sleep trend',
          context: snapshot,
        );
        if (!selected.contains(CoachContextFocus.habits)) {
          expect(jsonEncode(remote.context), isNot(contains('sleepHours')));
          expect(jsonEncode(remote.context), isNot(contains('7.25')));
        }
        final today = snapshot.computedHealth['today']! as Map;
        if (selected.contains(CoachContextFocus.habits)) {
          expect(today, contains('sleep'));
          expect(snapshot.activityHistory.single['sleepHours'], 7.25);
        } else {
          expect(today, isNot(contains('sleep')));
          if (selected.contains(CoachContextFocus.training)) {
            expect(snapshot.activityHistory, isEmpty);
            expect(snapshot.toJson()['activityHistory'], isEmpty);
          } else {
            expect(snapshot.activityHistory, isEmpty);
          }
        }
      },
    );
  }
}
