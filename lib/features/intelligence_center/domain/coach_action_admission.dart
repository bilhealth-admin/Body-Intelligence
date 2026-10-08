import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'bil_navigation_registry.dart';
import 'bil_tool_registry.dart';
import 'coach_action_permission.dart';
import 'intelligence_action.dart';
import '../settings_commands/coach_settings_tool_catalog.dart';

/// A validated, immutable native command. A missing descriptor is possible
/// only for an explicitly validated, route-only legacy action.
final class CoachActionBinding {
  const CoachActionBinding({required this.action, this.descriptor});

  final IntelligenceAction action;
  final BilToolDescriptor? descriptor;

  bool get writesData =>
      descriptor != null &&
      (descriptor!.trustBoundary ==
                  BilToolTrustBoundary.trustedLocalRepository &&
              descriptor!.risk != BilToolRisk.readOnly ||
          action.type == IntelligenceActionType.signOut ||
          action.type == IntelligenceActionType.healthCommand);

  bool allows(CoachActionPermissionMode mode) =>
      descriptor == null ||
      const CoachActionPermissionGate().allows(
        mode: mode,
        descriptor: descriptor!,
      );

  bool requiresConfirmation(CoachActionPermissionMode mode) =>
      action.requiresFreshConfirmation ||
      (descriptor == null
          ? action.requiresConfirmation
          : const CoachActionPermissionGate().requiresConfirmation(
              mode: mode,
              descriptor: descriptor!,
            ));
}

/// Shared admission for deterministic, model, restored, and native UI actions.
/// Tool identity never comes from the legacy action/widget key.
final class CoachActionAdmission {
  const CoachActionAdmission();

  static final _operationId = RegExp(r'^[a-zA-Z0-9._:-]{1,160}$');
  static const _dailyLogActions = {
    'barcode',
    'voice',
    'photo',
    'water',
    'notes',
    'exercise',
  };

  static bool validOperationId(String? value) =>
      value != null && _operationId.hasMatch(value);

  CoachActionBinding? bind(
    IntelligenceAction action, {
    bool requireOperationId = false,
  }) {
    if (action.operationId != null && !validOperationId(action.operationId)) {
      return null;
    }
    final declaredTool = action.toolId;
    BilToolDescriptor? descriptor;
    Map<String, Object?>? payload;
    if (declaredTool != null) {
      final canonical = const BilToolRegistry().lookup(declaredTool);
      final local = const CoachSettingsToolCatalog().lookup(declaredTool);
      descriptor = canonical ?? local;
      if (descriptor == null || descriptor.type != action.type) return null;
      payload = canonical != null
          ? _toolPayload(descriptor, action.payload)
          : const CoachSettingsToolCatalog().validate(
              declaredTool,
              action.payload,
            );
    } else if (action.type == IntelligenceActionType.manageSubscription &&
        action.id == 'manage-subscription') {
      // This old persisted shortcut is a confirmed handoff, not a purchase.
      descriptor = const BilToolRegistry().lookup('manage_subscription');
      payload = descriptor!.validateArguments(action.payload);
    } else {
      payload = _nativeNavigationPayload(action);
    }
    if (payload == null) return null;
    final binding = CoachActionBinding(
      action: action.copyWith(
        toolId: descriptor?.name,
        payload: Map<String, Object?>.unmodifiable(payload),
        destructive: action.destructive || descriptor?.destructive == true,
        requiresConfirmation:
            action.requiresConfirmation ||
            descriptor?.requiresConfirmation == true,
      ),
      descriptor: descriptor,
    );
    if (requireOperationId &&
        binding.writesData &&
        !validOperationId(action.operationId)) {
      return null;
    }
    return binding;
  }

  /// Call once when a new proposal enters the conversation, before separating
  /// its transient confirmation sheet from any persistent action chip.
  IntelligenceAction? admitProposal(
    IntelligenceAction action, {
    String Function()? createOperationId,
  }) {
    final binding = bind(action);
    if (binding == null) return null;
    if (!binding.writesData || binding.action.operationId != null) {
      return binding.action;
    }
    final operationId = (createOperationId ?? const Uuid().v4)();
    if (!validOperationId(operationId)) return null;
    return binding.action.copyWith(operationId: operationId);
  }

  static Map<String, Object?>? _toolPayload(
    BilToolDescriptor descriptor,
    Map<String, Object?> raw,
  ) {
    // These tools have empty wire arguments and app-derived route payloads.
    // Do not validate that derived payload as if it were new model input.
    if (descriptor.name == 'open_weight_log') {
      return raw.length == 1 && raw['target'] == 'weight_history'
          ? const {'target': 'weight_history'}
          : null;
    }
    if (descriptor.name == 'open_meals_yesterday') {
      return raw.length == 1 &&
              raw['dayOffset'] is int &&
              raw['dayOffset'] == -1
          ? const {'dayOffset': -1}
          : null;
    }
    return descriptor.validateArguments(raw);
  }

  static Map<String, Object?>? _nativeNavigationPayload(
    IntelligenceAction action,
  ) {
    final raw = action.payload;
    switch (action.type) {
      case IntelligenceActionType.navigate:
        if (raw.length != 1 ||
            !BilNavigationRegistry.targets.containsKey(raw['target'])) {
          return null;
        }
        return {'target': raw['target']};
      case IntelligenceActionType.openDailyLog:
        if (raw.isEmpty) return const {};
        return raw.length == 1 && _dailyLogActions.contains(raw['action'])
            ? {'action': raw['action']}
            : null;
      case IntelligenceActionType.reviewMeal:
        if (!raw.keys.every(const {'dayOffset', 'query'}.contains)) return null;
        final offset = raw['dayOffset'];
        if (offset != null && (offset is! int || offset < -31 || offset > 31)) {
          return null;
        }
        if (raw['query'] != null && raw['query'] is! String) return null;
        return {...raw};
      case IntelligenceActionType.reviewWorkout:
        if (!raw.keys.every(const {'query'}.contains) ||
            raw['query'] != null && raw['query'] is! String) {
          return null;
        }
        return {...raw};
      case IntelligenceActionType.readNutritionRemaining:
      case IntelligenceActionType.readProfileIdentity:
      case IntelligenceActionType.addWeight:
      case IntelligenceActionType.openPlan:
      case IntelligenceActionType.openReport:
      case IntelligenceActionType.openAiCoachSubscription:
      case IntelligenceActionType.buyAiBoost:
        // addWeight is route-only here strictly when no value was supplied.
        return raw.isEmpty ? const {} : null;
      case IntelligenceActionType.addWater:
      case IntelligenceActionType.setThemeMode:
      case IntelligenceActionType.setLanguage:
      case IntelligenceActionType.setUnitPreference:
      case IntelligenceActionType.setReminder:
      case IntelligenceActionType.reviewMemories:
      case IntelligenceActionType.prepareLocalExport:
      case IntelligenceActionType.updateGoal:
      case IntelligenceActionType.saveMeasurements:
      case IntelligenceActionType.quickAddMacros:
      case IntelligenceActionType.logFoods:
      case IntelligenceActionType.replaceMealItem:
      case IntelligenceActionType.updateMealItem:
      case IntelligenceActionType.moveMealItem:
      case IntelligenceActionType.deleteMealItem:
      case IntelligenceActionType.requestAccountDeletion:
      case IntelligenceActionType.signOut:
      case IntelligenceActionType.saveMemory:
      case IntelligenceActionType.manageSubscription:
      case IntelligenceActionType.healthCommand:
      case IntelligenceActionType.readHealthData:
        return null;
    }
  }

  /// The only persisted legacy write is a bounded target-goal proposal.
  /// Recognize its known old producer IDs; never infer a tool for other IDs.
  static bool isLegacyGoalId(String id, num target) {
    if (id == 'update_goal') return true;
    final match = RegExp(r'^update-goal-(\d+(?:\.\d+)?)$').firstMatch(id);
    return match != null &&
        double.tryParse(match.group(1)!) == target.toDouble();
  }

  /// Stable migration identity. The repository additionally scopes its journal
  /// by database owner. Re-decoding a legacy proposal must not create a replay.
  static String legacyGoalOperationId({
    required String scope,
    required String id,
    required Map<String, Object?> payload,
    required DateTime expiresAt,
  }) =>
      'legacy-goal:${sha256.convert(utf8.encode(jsonEncode([scope, id, 'update_goal', payload, expiresAt.toUtc().toIso8601String()])))}';
}
