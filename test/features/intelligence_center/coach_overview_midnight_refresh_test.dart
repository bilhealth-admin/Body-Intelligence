import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_overview_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends PreferencesRepository {
  _Preferences(super.database);
  final encoded = const CoachContextPreferences(
    focuses: {CoachContextFocus.training},
  ).encode();

  @override
  Future<String?> get(String key) async =>
      key == CoachContextPreferences.storageKey ? encoded : null;

  @override
  Stream<String?> watch(String key) =>
      Stream.value(key == CoachContextPreferences.storageKey ? encoded : null);
}

class _Daily extends DailyLogRepository {
  _Daily(super.database);
  final readDays = <DateTime>[];

  @override
  Future<DailyLog?> getForDay(DateTime date) async {
    readDays.add(date);
    return null;
  }
}

void main() {
  testWidgets(
    'observed Overview and brief cross midnight without a database write',
    (tester) async {
      final start = DateTime(2026, 10, 25, 23, 59, 59);
      final initialClock = tester.binding.clock.now();
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      final preferences = _Preferences(database);
      final daily = _Daily(database);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          preferencesRepositoryProvider.overrideWithValue(preferences),
          dailyLogRepositoryProvider.overrideWithValue(daily),
          coachNativeOwnerWitnessProvider.overrideWithValue(null),
          intelligenceConversationClockProvider.overrideWithValue(
            () =>
                start.add(tester.binding.clock.now().difference(initialClock)),
          ),
        ],
      );
      final brief = container.listen(coachHealthBriefProvider, (_, _) {});
      final overview = container.listen(
        coachOverviewPresentationContextProvider,
        (_, _) {},
      );
      try {
        await tester.pump();
        final before = container.read(
          coachOverviewPresentationContextProvider,
        )!;
        expect(before.snapshot.generatedAt, start);
        expect(daily.readDays, [DateTime(2026, 10, 25)]);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        final after = container.read(coachOverviewPresentationContextProvider)!;
        expect(after.snapshot.generatedAt.day, 26);
        expect(identical(after, before), isFalse);
        expect(
          container
              .read(coachHealthBriefProvider)
              .asData!
              .value
              .generatedAt
              .day,
          26,
        );
        expect(daily.readDays, [
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 26),
        ]);
      } finally {
        overview.close();
        brief.close();
        container.dispose();
        database.close().ignore();
        await tester.pump();
      }
    },
  );
}
