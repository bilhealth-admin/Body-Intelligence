import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database_provider.dart';
import '../../../data/database/date_keys.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../app_commands/coach_health_adapter.dart';
import '../app_commands/coach_health_brief_provider.dart';
import '../domain/coach_context_preferences.dart';
import '../domain/coach_context_snapshot.dart';
import '../presentation/intelligence_center_page.dart'
    show coachNativeOwnerWitnessProvider, intelligenceConversationClockProvider;
import 'coach_native_command_repository.dart';

class CoachOverviewContext {
  const CoachOverviewContext({required this.snapshot, this.recordedMealCount});

  final CoachContextSnapshot snapshot;
  final int? recordedMealCount;
}

/// Local presentation data only. Opening Overview must not assemble the rich
/// model context, scan historical meals or reserve/send any AI request.
final coachOverviewContextProvider =
    FutureProvider.autoDispose<CoachOverviewContext>((ref) async {
      final database = ref.watch(databaseProvider);
      final preferences = ref.watch(preferencesRepositoryProvider);
      final witness = ref.watch(coachNativeOwnerWitnessProvider);
      final briefFuture = ref.watch(coachHealthBriefProvider.future);
      final now = ref.watch(intelligenceConversationClockProvider)();
      final day = DateTime(now.year, now.month, now.day);
      var cancelled = false;
      var permissionsRead = false;
      String? allowedRaw;
      void check() {
        if (cancelled ||
            !ref.mounted ||
            preferences.localOwnerId != database.localOwnerId ||
            witness != null && witness.readOwner() != database.localOwnerId) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.ownerChanged,
          );
        }
      }

      final owners = witness?.changes.listen((next) {
        if (next != database.localOwnerId) cancelled = true;
      }, onError: (Object _, StackTrace _) => cancelled = true);
      final permissions = preferences
          .watch(CoachContextPreferences.storageKey)
          .listen((next) {
            if (permissionsRead && next != allowedRaw) {
              cancelled = true;
              if (ref.mounted) ref.invalidateSelf();
            }
          }, onError: (Object _, StackTrace _) => cancelled = true);
      final updates = database
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              database.meals,
              database.mealItems,
              database.waterEntries,
              database.preferences,
            ]),
          )
          .listen((_) {
            if (ref.mounted) ref.invalidateSelf();
          });
      ref.onDispose(() {
        cancelled = true;
        unawaited(owners?.cancel());
        unawaited(permissions.cancel());
        unawaited(updates.cancel());
      });
      final initial = await checkedHealthAwait(
        () => Future.wait<Object?>([
          briefFuture.timeout(const Duration(seconds: 6)),
          preferences
              .get(CoachContextPreferences.storageKey)
              .timeout(const Duration(seconds: 3)),
        ], eagerError: true),
        check,
      );
      allowedRaw = initial[1] as String?;
      permissionsRead = true;
      final allowed = CoachContextPreferences.decode(allowedRaw);
      final brief = initial[0] as CoachContextSnapshot;
      final name = await checkedHealthAwait(
        () =>
            preferences.get('displayName').timeout(const Duration(seconds: 3)),
        check,
      );
      int? meals;
      if (allowed.includes(CoachContextFocus.nutrition)) {
        // Count real nonempty meals for this civil day. No food names, item
        // payloads, historical rows or made-up placeholder entries are read.
        final row = await checkedHealthAwait(
          () => database
              .customSelect(
                'SELECT COUNT(*) AS n FROM meals m '
                'WHERE m.day_key = ? AND m.deleted_at IS NULL '
                'AND EXISTS (SELECT 1 FROM meal_items i '
                'WHERE i.meal_id = m.id AND i.deleted_at IS NULL)',
                variables: [Variable<String>(dayKeyFor(day))],
                readsFrom: {database.meals, database.mealItems},
              )
              .getSingle()
              .timeout(const Duration(seconds: 3)),
          check,
        );
        meals = row.read<int>('n');
      }
      final water = <Map<String, Object?>>[];
      if (allowed.includes(CoachContextFocus.habits)) {
        final row = await checkedHealthAwait(
          () =>
              (database.select(database.waterEntries)
                    ..where(
                      (entry) =>
                          entry.dayKey.equals(dayKeyFor(day)) &
                          entry.deletedAt.isNull(),
                    )
                    ..orderBy([(entry) => OrderingTerm.desc(entry.occurredAt)])
                    ..limit(1))
                  .getSingleOrNull()
                  .timeout(const Duration(seconds: 3)),
          check,
        );
        if (row != null) {
          water.add({
            'at': row.occurredAt.toIso8601String(),
            'amountMl': row.amountMl,
          });
        }
      }
      final finalAllowed = await checkedHealthAwait(
        () => preferences
            .get(CoachContextPreferences.storageKey)
            .timeout(const Duration(seconds: 3)),
        check,
      );
      if (finalAllowed != allowedRaw) {
        throw StateError('Coach overview scope changed');
      }
      check();
      return CoachOverviewContext(
        recordedMealCount: meals,
        snapshot: CoachContextSnapshot(
          generatedAt: now,
          profile: {
            if (name != null && name.trim().isNotEmpty)
              'displayName': name.trim(),
          },
          weights: allowed.includes(CoachContextFocus.analytics)
              ? brief.weights
              : const [],
          weightReadStatus: allowed.includes(CoachContextFocus.analytics)
              ? brief.weightReadStatus
              : CoachWeightReadStatus.withheld,
          nutritionDays: allowed.includes(CoachContextFocus.nutrition)
              ? brief.nutritionDays
              : const [],
          waterHistory: water,
          computedHealth: allowed.includes(CoachContextFocus.nutrition)
              ? brief.computedHealth
              : const {},
          activityHistory: [
            if (allowed.includes(CoachContextFocus.training))
              for (final entry in brief.activityHistory)
                if (entry['steps'] is num)
                  {'day': entry['day'], 'steps': entry['steps']},
          ],
        ),
      );
    }, retry: (_, _) => null);
