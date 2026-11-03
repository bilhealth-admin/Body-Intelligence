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
  const CoachOverviewContext({
    required this.snapshot,
    this.recordedMealCount,
    this.readBoundary,
  });

  final CoachContextSnapshot snapshot;
  final int? recordedMealCount;
  final Object? readBoundary;
}

/// A token changes only for ownership or consent, not ordinary diary updates.
/// It makes retained AsyncValue data safe to use across same-visit reloads.
class _OverviewReadBoundary {
  _OverviewReadBoundary(this.scope, this.ownerMatches);
  final String? scope;
  final bool ownerMatches;
}

final _overviewReadBoundaryProvider =
    StreamProvider.autoDispose<_OverviewReadBoundary>((ref) {
      final database = ref.watch(databaseProvider);
      final preferences = ref.watch(preferencesRepositoryProvider);
      final witness = ref.watch(coachNativeOwnerWitnessProvider);
      final now = ref.watch(intelligenceConversationClockProvider)();
      final midnight = Timer(
        DateTime(now.year, now.month, now.day + 1).difference(now),
        ref.invalidateSelf,
      );
      final changes = StreamController<_OverviewReadBoundary>();
      var owner = witness?.readOwner() ?? database.localOwnerId;
      var ownerFailed = false;
      var scopeFailed = false;
      var scopeReady = false;
      String? scope;
      void emit() {
        if (!scopeReady || changes.isClosed) return;
        changes.add(
          _OverviewReadBoundary(
            scope,
            !ownerFailed &&
                !scopeFailed &&
                owner == database.localOwnerId &&
                preferences.localOwnerId == database.localOwnerId,
          ),
        );
      }

      final scopes = preferences
          .watch(CoachContextPreferences.storageKey)
          .listen(
            (next) {
              if (scopeReady && !scopeFailed && next == scope) return;
              scope = next;
              scopeFailed = false;
              scopeReady = true;
              emit();
            },
            onError: (Object _, StackTrace _) {
              scopeFailed = true;
              scopeReady = true;
              emit();
            },
          );
      final owners = witness?.changes.listen(
        (next) {
          if (next == owner && !ownerFailed) return;
          owner = next;
          ownerFailed = false;
          emit();
        },
        onError: (Object _, StackTrace _) {
          ownerFailed = true;
          emit();
        },
      );
      ref.onDispose(() {
        midnight.cancel();
        unawaited(scopes.cancel());
        unawaited(owners?.cancel());
        unawaited(changes.close());
      });
      return changes.stream;
    });

/// A refresh may retain this visit's data; a new owner/consent token may not.
/// No additional health category, model context, or network read is added.
final coachOverviewPresentationContextProvider =
    Provider.autoDispose<CoachOverviewContext?>((ref) {
      final boundary = ref.watch(_overviewReadBoundaryProvider);
      final source = ref.watch(coachOverviewContextProvider);
      if (boundary.isLoading || boundary.hasError) return null;
      final current = boundary.asData?.value;
      final value = source.value;
      final now = ref.watch(intelligenceConversationClockProvider)();
      final generated = value?.snapshot.generatedAt;
      return current != null &&
              current.ownerMatches &&
              value != null &&
              generated?.year == now.year &&
              generated?.month == now.month &&
              generated?.day == now.day &&
              identical(value.readBoundary, current)
          ? value
          : null;
    });

/// Local presentation data only. Opening Overview must not assemble the rich
/// model context, scan historical meals or reserve/send any AI request.
final coachOverviewContextProvider =
    FutureProvider.autoDispose<CoachOverviewContext>((ref) async {
      final database = ref.watch(databaseProvider);
      final preferences = ref.watch(preferencesRepositoryProvider);
      final witness = ref.watch(coachNativeOwnerWitnessProvider);
      // Observe the token separately from the read's Future. If an owner visit
      // ends during an await, that exact read must reject; Riverpod must not
      // forward its awaiting caller to a later owner's replacement Future.
      final boundaryFuture = ref.read(_overviewReadBoundaryProvider.future);
      _OverviewReadBoundary? boundary;
      final briefFuture = ref.watch(coachHealthBriefProvider.future);
      // It starts in parallel with the consent boundary. Observe an early
      // failure immediately; the later bounded await still receives the error.
      briefFuture.ignore();
      final now = ref.watch(intelligenceConversationClockProvider)();
      final day = DateTime(now.year, now.month, now.day);
      var cancelled = false;
      var completed = false;
      var boundaryChanged = false;
      Timer? retryForBoundary;
      var permissionsRead = false;
      String? allowedRaw;
      void check() {
        if (cancelled ||
            !ref.mounted ||
            preferences.localOwnerId != database.localOwnerId ||
            boundary != null &&
                (!boundary.ownerMatches ||
                    !identical(
                      ref.read(_overviewReadBoundaryProvider).asData?.value,
                      boundary,
                    )) ||
            witness != null && witness.readOwner() != database.localOwnerId) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.ownerChanged,
          );
        }
      }

      ref.listen(_overviewReadBoundaryProvider, (_, next) {
        final current = next.asData?.value;
        if (boundary == null || identical(current, boundary)) return;
        boundaryChanged = true;
        cancelled = true;
        if (completed && ref.mounted) ref.invalidateSelf();
      });

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
        retryForBoundary?.cancel();
        unawaited(owners?.cancel());
        unawaited(permissions.cancel());
        unawaited(updates.cancel());
      });
      try {
        boundary = await checkedHealthAwait(
          () => boundaryFuture.timeout(const Duration(seconds: 3)),
          check,
        );
        check();
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
        if (allowedRaw != boundary!.scope) {
          throw StateError('Coach overview scope changed');
        }
        permissionsRead = true;
        final allowed = CoachContextPreferences.decode(allowedRaw);
        final brief = initial[0] as CoachContextSnapshot;
        if (brief.generatedAt.year != now.year ||
            brief.generatedAt.month != now.month ||
            brief.generatedAt.day != now.day) {
          throw StateError('Coach overview is waiting for the current day');
        }
        final name = await checkedHealthAwait(
          () => preferences
              .get('displayName')
              .timeout(const Duration(seconds: 3)),
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
                      ..orderBy([
                        (entry) => OrderingTerm.desc(entry.occurredAt),
                      ])
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
          readBoundary: boundary,
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
      } finally {
        completed = true;
        if (boundaryChanged && ref.mounted) {
          // First deliver rejection to callers of the retired read. Refresh on
          // the next event turn so the new visit can obtain its own snapshot.
          retryForBoundary = Timer(Duration.zero, () {
            if (ref.mounted) ref.invalidateSelf();
          });
        }
      }
    }, retry: (_, _) => null);
