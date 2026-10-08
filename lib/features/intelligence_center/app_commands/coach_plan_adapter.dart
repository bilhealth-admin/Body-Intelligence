import 'dart:convert';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../nutrition_plans/data/diet_plan_repository.dart';
import '../../nutrition_plans/domain/diet_macro_plan.dart';
import '../../nutrition_plans/domain/nutrition_pathway.dart';
import '../../nutrition_plans/domain/nutrition_pathway_access_policy.dart';
import 'coach_health_adapter.dart';

/// Preview is read-only. Activation uses the exact application command and
/// its current verified entitlement and safety gates, inside native Coach's
/// transaction. This adapter never grants an entitlement or infers review.
final class CoachPlanCommandAdapter implements CoachHealthCommandAdapter {
  const CoachPlanCommandAdapter({
    required this.database,
    required this.command,
  });

  final AppDatabase database;
  final DietPlanCommand command;
  DietPlanRepository get repository => command.repository;

  @override
  bool supports(String toolId) => toolId == 'activate_plan';

  /// A preview does not save a draft, activate a pathway, change nutrition
  /// targets, or call the subscription loader. Access requirements are catalog
  /// metadata; only DietPlanCommand may decide whether activation is allowed.
  Future<Map<String, Object?>> preview({
    required String pathwayId,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final pathway = _planPathway(pathwayId);
    return checkedHealthAwait(
      () => database.transaction(() async {
        final state = await _readState(pathway.id, checkAccess);
        return _planFreeze({
              'kind': 'plan_preview',
              ..._planReceipt(pathway, state),
              'confirmationRequired': true,
              'activationRequirements': {
                'verifiedPremiumPrograms':
                    pathway.access == NutritionPathwayAccess.premium,
                'clinicianReview':
                    pathway.safety == NutritionPathwaySafety.clinicianReview,
                'medicalSupervision':
                    pathway.safety == NutritionPathwaySafety.medicalSupervision,
              },
            })
            as Map<String, Object?>;
      }),
      checkAccess,
    );
  }

  @override
  Future<Map<String, Object?>> resolve({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required DateTime now,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    if (!supports(toolId) ||
        arguments.keys.toSet().difference(const {
          'pathwayId',
          'clinicianReviewConfirmed',
        }).isNotEmpty ||
        arguments['clinicianReviewConfirmed'] != null &&
            arguments['clinicianReviewConfirmed'] is! bool) {
      throw ArgumentError('Invalid plan activation command');
    }
    final pathway = _planPathway(arguments['pathwayId']);
    final draft = await checkedHealthAwait(
      () => repository.read(pathway.id),
      checkAccess,
    );
    if (draft.resolveWeek() == null) {
      throw StateError('The saved plan has invalid macro targets');
    }
    return _planFreeze({
          'healthToolId': toolId,
          'operationId': operationId,
          'pathwayId': pathway.id,
          'draftJson': draft.encode(),
          // True is retained only when explicitly supplied. A request to start
          // a diet does not itself assert that a clinician reviewed it.
          'clinicianReviewConfirmed':
              arguments['clinicianReviewConfirmed'] == true,
          'resolvedAt': now.toIso8601String(),
        })
        as Map<String, Object?>;
  }

  @override
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final pathway = _resolvedPathway(resolved);
    final state = await _readState(pathway.id, checkAccess);
    return _planFreeze({
          // Include key identity and timestamp so a later same-value rewrite
          // or any draft/schedule change makes the accepted proposal stale.
          'preferences': state.rows,
          'receipt': {
            ..._planReceipt(pathway, state),
            'clinicianReviewConfirmed': resolved['clinicianReviewConfirmed'],
          },
        })
        as Map<String, Object?>;
  }

  @override
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final pathway = _resolvedPathway(resolved);
    final current = await checkedHealthAwait(
      () => snapshot(resolved: resolved, checkAccess: checkAccess),
      checkAccess,
    );
    if (!_planSame(current, before)) {
      throw StateError('Plan proposal is stale');
    }
    final draft = DietDraft.decode(resolved['draftJson'] as String?);
    if (draft == null || draft.pathwayId != pathway.id) {
      throw StateError('Invalid resolved plan draft');
    }
    final currentDraft = await checkedHealthAwait(
      () => repository.read(pathway.id),
      checkAccess,
    );
    if (!_planSame(currentDraft.toJson(), draft.toJson())) {
      throw StateError('The plan draft changed after proposal preparation');
    }
    final beforeValues = _planValues(before, pathway.id);
    final priorSchedule = NutritionGoalSchedule.decode(
      beforeValues[nutritionGoalSchedulePreferenceKey],
    );
    final expectedSchedule = NutritionGoalSchedule(
      dayTargets: draft.resolveWeek()!.map(
        (day, target) => MapEntry(day, target.toScheduledGoal()),
      ),
      mealTargets: priorSchedule.mealTargets,
    );

    // Keep the production command's unforgeable authorization boundary. Scope
    // checks also surround its asynchronous entitlement lookup, before the
    // command can enter its repository mutation.
    final scopedCommand = DietPlanCommand(
      repository: repository,
      verifiedSubscription: () =>
          checkedHealthAwait(command.verifiedSubscription, checkAccess),
    );
    await checkedHealthAwait(
      () => scopedCommand.activate(
        draft,
        clinicianReviewConfirmed: resolved['clinicianReviewConfirmed'] == true,
      ),
      checkAccess,
    );
    final saved = await _readState(pathway.id, checkAccess);
    final savedValues = _planValues({'preferences': saved.rows}, pathway.id);
    final savedSchedule = savedValues[nutritionGoalSchedulePreferenceKey];
    if (saved.activePathway != pathway.id ||
        savedValues[DietPlanRepository.activePathwayKey] != pathway.id ||
        savedValues[DietPlanRepository.draftKey(pathway.id)] !=
            draft.encode() ||
        !_planSame(saved.draft.toJson(), draft.toJson()) ||
        savedSchedule == null ||
        !_planSame(jsonDecode(savedSchedule), expectedSchedule.toJson())) {
      throw StateError('Plan activation readback does not match the proposal');
    }
  }

  @override
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final pathway = _resolvedPathway(resolved);
    final current = await checkedHealthAwait(
      () => snapshot(resolved: resolved, checkAccess: checkAccess),
      checkAccess,
    );
    if (!_planSame(current, after)) {
      throw StateError('The plan changed after this operation');
    }
    final values = _planValues(before, pathway.id);
    await checkedHealthAwait(
      () => repository.preferences.mutate(
        set: {
          for (final entry in values.entries)
            if (entry.value != null) entry.key: entry.value!,
        },
        remove: values.entries
            .where((entry) => entry.value == null)
            .map((entry) => entry.key),
      ),
      checkAccess,
    );
    final restored = await _readState(pathway.id, checkAccess);
    if (!_planSame(
      _planValues({'preferences': restored.rows}, pathway.id),
      values,
    )) {
      throw StateError('Plan compensation readback failed');
    }
  }

  Future<_PlanState> _readState(
    String pathwayId,
    void Function() checkAccess,
  ) async {
    final keys = _planKeys(pathwayId);
    final rows = await checkedHealthAwait(
      () => (database.select(
        database.preferences,
      )..where((row) => row.key.isIn(keys))).get(),
      checkAccess,
    );
    final activePathway = await checkedHealthAwait(
      repository.readActivePathway,
      checkAccess,
    );
    final draft = await checkedHealthAwait(
      () => repository.read(pathwayId),
      checkAccess,
    );
    final schedule = await checkedHealthAwait(
      repository.schedule.read,
      checkAccess,
    );
    return (
      rows: {
        for (final key in keys) key: null,
        for (final row in rows) row.key: row.toJson(),
      },
      activePathway: activePathway,
      draft: draft,
      schedule: schedule,
    );
  }
}

typedef _PlanState = ({
  Map<String, Object?> rows,
  String? activePathway,
  DietDraft draft,
  NutritionGoalSchedule schedule,
});

NutritionPathway _planPathway(Object? pathwayId) {
  if (pathwayId is! String) {
    throw ArgumentError('An exact pathwayId is required');
  }
  final pathway = nutritionPathwayForExactId(pathwayId);
  if (pathway == null) {
    throw ArgumentError.value(pathwayId, 'pathwayId', 'Unknown pathway');
  }
  return pathway;
}

NutritionPathway _resolvedPathway(Map<String, Object?> resolved) {
  if (resolved['healthToolId'] != 'activate_plan' ||
      resolved['clinicianReviewConfirmed'] is! bool) {
    throw ArgumentError('Invalid resolved plan activation');
  }
  return _planPathway(resolved['pathwayId']);
}

List<String> _planKeys(String pathwayId) => [
  DietPlanRepository.activePathwayKey,
  nutritionGoalSchedulePreferenceKey,
  DietPlanRepository.draftKey(pathwayId),
];

Map<String, String?> _planValues(
  Map<String, Object?> snapshot,
  String pathwayId,
) {
  final rows = snapshot['preferences'];
  final keys = _planKeys(pathwayId);
  if (rows is! Map ||
      rows.length != keys.length ||
      !keys.every(rows.containsKey)) {
    throw StateError('Missing or invalid plan preference snapshot');
  }
  final result = <String, String?>{};
  for (final key in keys) {
    final row = rows[key];
    if (row == null) {
      result[key] = null;
    } else if (row is Map && row['key'] == key && row['value'] is String) {
      result[key] = row['value'] as String;
    } else {
      throw StateError('Plan preference identity mismatch');
    }
  }
  return result;
}

Map<String, Object?> _planReceipt(NutritionPathway pathway, _PlanState state) =>
    {
      'pathwayId': pathway.id,
      'name': pathway.enTitle,
      'nameAr': pathway.arTitle,
      'activePathwayId': state.activePathway,
      'active': state.activePathway == pathway.id,
      'access': pathway.access.name,
      'safety': pathway.safety.name,
      'sourceIds': pathway.sourceIds,
      'draftWeekTargets': {
        for (final entry in state.draft.resolveWeek()!.entries)
          '${entry.key}': {
            'caloriesKcal': entry.value.calories,
            'carbsG': entry.value.carbsGrams,
            'proteinG': entry.value.proteinGrams,
            'fatG': entry.value.fatGrams,
          },
      },
      'effectiveWeekTargets': {
        for (final entry in state.schedule.dayTargets.entries)
          '${entry.key}': {
            'caloriesKcal': entry.value.calories,
            'carbsG': entry.value.carbsGrams,
            'proteinG': entry.value.proteinGrams,
            'fatG': entry.value.fatGrams,
          },
      },
    };

Object? _planFreeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _planFreeze(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_planFreeze));
  return value;
}

bool _planSame(Object? first, Object? second) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList(growable: false);
    return value;
  }

  return jsonEncode(canonical(first)) == jsonEncode(canonical(second));
}
