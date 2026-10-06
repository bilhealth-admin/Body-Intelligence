import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 6, 12);
  const tools = {
    IntelligenceActionType.setThemeMode: 'set_theme_mode',
    IntelligenceActionType.setLanguage: 'set_language',
    IntelligenceActionType.addWater: 'log_water',
    IntelligenceActionType.addWeight: 'log_weight',
    IntelligenceActionType.saveMeasurements: 'save_measurements',
    IntelligenceActionType.quickAddMacros: 'quick_add_macros',
    IntelligenceActionType.updateMealItem: 'update_meal_item',
    IntelligenceActionType.moveMealItem: 'move_meal_item',
    IntelligenceActionType.deleteMealItem: 'delete_meal_item',
    IntelligenceActionType.requestAccountDeletion: 'request_account_deletion',
    IntelligenceActionType.signOut: 'sign_out',
    IntelligenceActionType.saveMemory: 'save_memory',
  };
  const forbidden = {
    IntelligenceActionType.setThemeMode: {'mode': 'dark'},
    IntelligenceActionType.setLanguage: {'locale': 'ar'},
    IntelligenceActionType.addWater: {'amountMl': 250},
    IntelligenceActionType.addWeight: {'weightKg': 79},
    IntelligenceActionType.saveMeasurements: {'neckCm': 39},
    IntelligenceActionType.quickAddMacros: {
      'mealType': 'lunch',
      'calories': 300,
      'protein': 20,
      'carbohydrates': 30,
      'fat': 10,
    },
    IntelligenceActionType.updateMealItem: {'itemId': 1, 'quantityGrams': 100},
    IntelligenceActionType.moveMealItem: {'itemId': 1, 'mealType': 'lunch'},
    IntelligenceActionType.deleteMealItem: {'itemId': 1},
    IntelligenceActionType.requestAccountDeletion: <String, Object?>{},
    IntelligenceActionType.signOut: <String, Object?>{},
    IntelligenceActionType.saveMemory: {'text': 'An explicit preference'},
  };
  for (final entry in forbidden.entries) {
    test(
      '${entry.key.name} cannot persist with normal or goal-shaped payload',
      () {
        for (final payload in [
          entry.value,
          <String, Object?>{'targetWeightKg': 79},
        ]) {
          final action = IntelligenceAction(
            id: 'unsafe-${entry.key.name}',
            toolId: tools[entry.key],
            operationId: 'transient-${entry.key.name}',
            type: entry.key,
            label: 'Untrusted proposal',
            requiresConfirmation: true,
            payload: payload,
          );
          expect(
            IntelligenceMessageAction.fromAction(action, now: now),
            isNull,
            reason:
                'Runtime conversion must enforce the transient-write boundary.',
          );
          expect(
            IntelligenceMessageAction.tryFromJson({
              'id': action.id,
              'toolId': action.toolId,
              'operationId': action.operationId,
              'type': entry.key.name,
              'label': action.label,
              'payload': payload,
              'requiresConfirmation': true,
            }, now: now),
            isNull,
            reason:
                'A saved goal-shaped payload cannot restore another write type.',
          );
        }
      },
    );
  }
  for (final id in ['navigate', 'unknown_native_write']) {
    test('legacy goal rejects mismatched or unknown identity $id', () {
      expect(
        IntelligenceMessageAction.tryFromJson({
          'id': id,
          'type': 'updateGoal',
          'label': 'Set target to 79 kg',
          'payload': {'targetWeightKg': 79},
          'requiresConfirmation': true,
          'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
        }, now: now),
        isNull,
      );
    });
  }

  const admission = CoachActionAdmission();
  const registry = BilToolRegistry();
  test(
    'canonical tool identity is independent of the legacy presentation ID',
    () {
      final action = registry.createAction(
        name: 'log_water',
        actionId: 'add-water-250',
        arguments: const {'amountMl': 250},
        label: 'Water',
      )!;
      expect(action.id, 'add-water-250');
      expect(action.toolId, 'log_water');
      expect(action.operationId, isNull);
      final binding = admission.bind(action)!;
      expect(binding.allows(CoachActionPermissionMode.readOnly), isFalse);
      expect(admission.bind(action, requireOperationId: true), isNull);
    },
  );

  for (final toolId in <String?>[
    null,
    'unknown_tool',
    'navigate',
    'read_profile_identity',
  ]) {
    test('mutation cannot borrow missing/unknown/mismatched tool $toolId', () {
      final action = IntelligenceAction(
        id: 'log_water',
        toolId: toolId,
        operationId: 'operation-a',
        type: IntelligenceActionType.addWater,
        label: 'Water',
        requiresConfirmation: false,
        payload: const {'amountMl': 250},
      );
      expect(admission.bind(action, requireOperationId: true), isNull);
      expect(admission.admitProposal(action), isNull);
    });
  }

  test(
    'proposal admission freezes arguments and allocates identity only once',
    () {
      final payload = <String, Object?>{'amountMl': 250};
      final action = IntelligenceAction(
        id: 'water',
        toolId: 'log_water',
        type: IntelligenceActionType.addWater,
        label: 'Water',
        requiresConfirmation: true,
        payload: payload,
      );
      var allocations = 0;
      String nextId() => 'proposal-${++allocations}';
      final first = admission.admitProposal(action, createOperationId: nextId)!;
      payload['amountMl'] = 500;
      final second = admission.admitProposal(
        action,
        createOperationId: nextId,
      )!;
      final retry = admission.admitProposal(first, createOperationId: nextId)!;
      expect(first.payload, {'amountMl': 250});
      expect(second.payload, {'amountMl': 500});
      expect(first.operationId, 'proposal-1');
      expect(second.operationId, 'proposal-2');
      expect(retry.operationId, first.operationId);
      expect(allocations, 2);
      expect(() => first.payload['amountMl'] = 700, throwsUnsupportedError);
      expect(admission.bind(first, requireOperationId: true), isNotNull);
    },
  );

  test(
    'production UUIDs distinguish equal explicit requests with equal UI IDs',
    () {
      final action = registry.createAction(
        name: 'log_water',
        arguments: const {'amountMl': 250},
        label: 'Water',
      )!;
      final first = admission.admitProposal(action)!;
      final second = admission.admitProposal(action)!;
      expect(first.id, second.id);
      expect(first.toolId, second.toolId);
      expect(first.operationId, isNot(second.operationId));
      expect(first.operationId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    },
  );

  test(
    'local water and model factory share the canonical validated tool contract',
    () {
      final local = const LocalCoachCommandParser()
          .parse('سجل ٣٧٥ مل ماء', locale: 'ar')
          .single;
      final model = registry.createAction(
        name: 'log_water',
        arguments: const {'amountMl': 375},
        label: 'Water',
      )!;
      expect(local.id, 'add-water-375');
      expect(local.toolId, model.toolId);
      expect(local.type, model.type);
      expect(local.payload, model.payload);
      expect(
        admission.bind(local)!.allows(CoachActionPermissionMode.readOnly),
        isFalse,
      );
    },
  );

  test(
    'model metadata cannot choose native operation identity or weaken tool policy',
    () async {
      final api = ModelBackedLocalCoachApi(
        gateway: const _UntrustedIdentityGateway(),
        context: CoachContextSnapshot.empty(),
      );
      final result = await api.understand(
        const LocalCoachRequest(
          text: 'Proceed with the prepared BIL operation',
          locale: 'en',
        ),
      );
      final proposal = result.actions.single;
      expect(proposal.toolId, 'log_water');
      expect(proposal.type, IntelligenceActionType.addWater);
      expect(proposal.operationId, isNull);
      final admitted = admission.admitProposal(proposal)!;
      expect(admitted.operationId, isNot('provider-selected-operation'));
      expect(
        admission.bind(admitted)!.allows(CoachActionPermissionMode.readOnly),
        isFalse,
      );
      expect(
        admission
            .bind(admitted)!
            .requiresConfirmation(CoachActionPermissionMode.askBeforeWrite),
        isTrue,
      );
    },
  );

  test('native binding validates numeric bounds and rejects extra keys', () {
    for (final payload in [
      <String, Object?>{'amountMl': 5001},
      <String, Object?>{'amountMl': 250, 'route': '/admin'},
      <String, Object?>{'amountMl': double.nan},
    ]) {
      expect(
        admission.bind(
          IntelligenceAction(
            id: 'legacy',
            toolId: 'log_water',
            operationId: 'op',
            type: IntelligenceActionType.addWater,
            label: 'Water',
            requiresConfirmation: true,
            payload: payload,
          ),
        ),
        isNull,
      );
    }
  });

  test('app-derived navigation aliases retain their exact schema', () {
    for (final name in ['open_weight_log', 'open_meals_yesterday']) {
      final action = registry.createAction(
        name: name,
        arguments: const {},
        label: 'Open',
      )!;
      expect(admission.bind(action, requireOperationId: true), isNotNull);
      expect(
        admission.bind(action.copyWith(payload: const {'target': 'dashboard'})),
        isNull,
      );
    }
    const review = IntelligenceAction(
      id: 'review-weight',
      type: IntelligenceActionType.addWeight,
      label: 'Open check-in',
      requiresConfirmation: false,
    );
    expect(admission.bind(review), isNotNull);
    expect(
      admission.bind(review.copyWith(payload: const {'weightKg': 'bad'})),
      isNull,
    );
  });

  test(
    'canonical risk cannot lose destructive confirmation through caller flags',
    () {
      const raw = IntelligenceAction(
        id: 'delete',
        toolId: 'request_account_deletion',
        type: IntelligenceActionType.requestAccountDeletion,
        label: 'Review deletion',
        requiresConfirmation: false,
      );
      final binding = admission.bind(raw)!;
      expect(binding.action.destructive, isTrue);
      expect(
        binding.requiresConfirmation(CoachActionPermissionMode.writeAllowed),
        isTrue,
      );
      expect(binding.allows(CoachActionPermissionMode.readOnly), isFalse);
    },
  );

  test('calorie-only Quick Add preserves missing/null macro knowledge', () {
    for (final args in [
      <String, Object?>{'mealType': 'lunch', 'calories': 1905},
      <String, Object?>{
        'mealType': 'lunch',
        'calories': 1905,
        'protein': null,
        'carbohydrates': null,
        'fat': null,
      },
    ]) {
      final action = registry.createAction(
        name: 'quick_add_macros',
        arguments: args,
        label: 'Calories',
      );
      expect(action, isNotNull);
      expect(action!.payload, args);
      expect(admission.bind(action), isNotNull);
    }
    expect(
      registry.createAction(
        name: 'quick_add_macros',
        arguments: const {'mealType': 'lunch', 'calories': 0},
        label: 'Empty',
      ),
      isNull,
    );
    expect(
      registry.createAction(
        name: 'quick_add_macros',
        arguments: const {'mealType': 'lunch', 'calories': 1905, 'fat': -1},
        label: 'Invalid',
      ),
      isNull,
    );
  });

  test(
    'goal identity survives conversion JSON restore and repeated toAction',
    () {
      final action = admission.admitProposal(
        registry.createAction(
          name: 'update_goal',
          actionId: 'same-goal-key',
          arguments: const {'targetWeightKg': 79},
          label: 'Target',
        )!,
      )!;
      final saved = IntelligenceMessageAction.fromAction(action, now: now)!;
      final restored = IntelligenceMessageAction.tryFromJson(
        saved.toJson(),
        now: now,
      )!;
      expect(restored.operationId, action.operationId);
      expect(restored.toolId, 'update_goal');
      expect(restored.toAction().operationId, restored.toAction().operationId);
      expect(restored.expiresAt, saved.expiresAt);
      expect(
        admission
            .bind(restored.toAction())!
            .requiresConfirmation(CoachActionPermissionMode.writeAllowed),
        isTrue,
      );
    },
  );

  test(
    'legacy migration identity is stable and distinct between source messages',
    () {
      Map<String, Object?> raw(String messageId) => {
        'id': messageId,
        'role': 'bil',
        'kind': 'action',
        'text': 'Target proposal',
        'createdAt': now.toIso8601String(),
        'actionLinks': [
          {
            'id': 'update-goal-79',
            'type': 'updateGoal',
            'label': 'Target',
            'payload': {'targetWeightKg': 79},
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          },
        ],
      };
      final firstJson = raw('message-a');
      final secondJson = {...firstJson, 'id': 'message-b'};
      final first = IntelligenceMessage.fromJson(firstJson).actionLinks.single;
      final second = IntelligenceMessage.fromJson(
        secondJson,
      ).actionLinks.single;
      final again = IntelligenceMessage.fromJson(firstJson).actionLinks.single;
      expect(first.operationId, again.operationId);
      expect(first.operationId, isNot(second.operationId));
      expect(first.toolId, 'update_goal');
      expect(first.requiresConfirmation, isTrue);
    },
  );
}

class _UntrustedIdentityGateway implements LocalModelGateway {
  const _UntrustedIdentityGateway();

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async => const LocalModelResult.answer(
    LocalModelAnswer(
      text: 'A prepared action.',
      action: {
        'name': 'log_water',
        'arguments': {'amountMl': 250},
        'toolId': 'navigate',
        'operationId': 'provider-selected-operation',
        'type': 'navigate',
        'requiresConfirmation': false,
      },
    ),
  );
}
