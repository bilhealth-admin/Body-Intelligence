import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntelligenceMessage messageWith(IntelligenceMessageAction action) =>
      IntelligenceMessage(
        id: 'answer-1',
        role: IntelligenceMessageRole.bil,
        kind: IntelligenceMessageKind.coach,
        text: 'Open your goals',
        createdAt: DateTime.utc(2026, 9, 4),
        actionLinks: <IntelligenceMessageAction>[action],
      );

  test('safe navigation action survives conversation persistence', () {
    final durable = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'open-goals',
        type: IntelligenceActionType.navigate,
        label: 'Open goals',
        requiresConfirmation: false,
        payload: <String, Object?>{'target': 'goals'},
      ),
    );

    expect(durable, isNotNull);
    final restored = IntelligenceMessage.fromJson(
      messageWith(durable!).toJson(),
    );

    expect(restored.actionLinks, hasLength(1));
    expect(restored.actionLinks.single.isTrusted, isTrue);
    expect(restored.actionLinks.single.toAction().payload, <String, Object?>{
      'target': 'goals',
    });
  });

  test('legacy V1 message without action links remains readable', () {
    final restored = IntelligenceMessage.fromJson(<String, Object?>{
      'id': 'legacy-answer',
      'role': 'bil',
      'kind': 'coach',
      'text': 'A retained answer',
      'createdAt': DateTime.utc(2026, 8, 1).toIso8601String(),
      'evidence': <String>[],
      'missingData': <String>[],
    });

    expect(restored.text, 'A retained answer');
    expect(restored.actionLinks, isEmpty);
  });

  test('damaged action-link metadata does not discard the saved message', () {
    final restored = IntelligenceMessage.fromJson(<String, Object?>{
      'id': 'retained-answer',
      'role': 'bil',
      'kind': 'coach',
      'text': 'Keep this answer',
      'createdAt': DateTime.utc(2026, 8, 1).toIso8601String(),
      'actionLinks': <String, Object?>{'not': 'a list'},
    });

    expect(restored.text, 'Keep this answer');
    expect(restored.actionLinks, isEmpty);
  });

  test('pre-release suggestedActions alias migrates to actionLinks', () {
    final restored = IntelligenceMessage.fromJson(<String, Object?>{
      'id': 'alias-answer',
      'role': 'bil',
      'kind': 'coach',
      'text': 'Review the report',
      'createdAt': DateTime.utc(2026, 8, 1).toIso8601String(),
      'suggestedActions': <Object?>[
        <String, Object?>{
          'id': 'open-report',
          'label': 'Open report',
          'type': 'openReport',
          'payload': <String, Object?>{},
        },
      ],
    });

    expect(restored.actionLinks, hasLength(1));
    expect(restored.actionLinks.single.type, IntelligenceActionType.openReport);
  });

  test(
    'tampered routes, unexpected payloads, and unsafe writes are discarded',
    () {
      final restored = IntelligenceMessage.fromJson(<String, Object?>{
        'id': 'tampered-answer',
        'role': 'bil',
        'kind': 'coach',
        'text': 'Unsafe shortcuts',
        'createdAt': DateTime.utc(2026, 8, 1).toIso8601String(),
        'actionLinks': <Object?>[
          <String, Object?>{
            'id': 'external',
            'label': 'External route',
            'type': 'navigate',
            'payload': <String, Object?>{'target': 'https://example.com'},
          },
          <String, Object?>{
            'id': 'raw-route',
            'label': 'Raw route',
            'type': 'navigate',
            'payload': <String, Object?>{'route': '/admin'},
          },
          <String, Object?>{
            'id': 'stale-plan',
            'label': 'Open plan',
            'type': 'openPlan',
            'payload': <String, Object?>{'redirect': '/admin'},
          },
          <String, Object?>{
            'id': 'write-goal',
            'label': 'Change goal',
            'type': 'updateGoal',
            'payload': <String, Object?>{'targetWeightKg': 70},
          },
          <String, Object?>{
            'id': 'delete-account',
            'label': 'Delete account',
            'type': 'requestAccountDeletion',
            'payload': <String, Object?>{},
          },
        ],
      });

      expect(restored.actionLinks, isEmpty);
    },
  );

  test('goal proposal persists briefly and always keeps confirmation', () {
    final now = DateTime.utc(2026, 9, 4, 12);
    final goal = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'goal-79',
        type: IntelligenceActionType.updateGoal,
        label: 'Set goal to 79 kg',
        requiresConfirmation: false,
        payload: <String, Object?>{'targetWeightKg': 79},
      ),
      now: now,
    );
    final subscription = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'manage-subscription',
        type: IntelligenceActionType.manageSubscription,
        label: 'Manage subscription',
        requiresConfirmation: true,
      ),
    );

    expect(goal, isNotNull);
    expect(goal!.requiresConfirmation, isTrue);
    expect(goal.payload, <String, Object?>{'targetWeightKg': 79.0});
    expect(goal.expiresAt, now.add(const Duration(hours: 24)));
    expect(subscription, isNotNull);
    expect(subscription!.requiresConfirmation, isTrue);
    expect(subscription.toAction().requiresConfirmation, isTrue);
  });

  test('restored goal proposal rejects expiry and payload tampering', () {
    final now = DateTime.utc(2026, 9, 4, 12);
    Map<String, Object?> raw({
      Object? target = 79,
      String? expiresAt,
      bool confirmation = false,
      Map<String, Object?> extras = const <String, Object?>{},
    }) => <String, Object?>{
      'id': 'update-goal-79',
      'label': 'Set target to 79 kg',
      'type': 'updateGoal',
      'payload': <String, Object?>{'targetWeightKg': target, ...extras},
      'requiresConfirmation': confirmation,
      'expiresAt':
          expiresAt ?? now.add(const Duration(hours: 2)).toIso8601String(),
    };

    final restored = IntelligenceMessageAction.tryFromJson(raw(), now: now);
    expect(restored, isNotNull);
    expect(restored!.requiresConfirmation, isTrue);
    expect(
      IntelligenceMessageAction.tryFromJson(
        raw(
          expiresAt: now.subtract(const Duration(seconds: 1)).toIso8601String(),
        ),
        now: now,
      ),
      isNull,
    );
    expect(
      IntelligenceMessageAction.tryFromJson(
        raw(expiresAt: now.add(const Duration(days: 2)).toIso8601String()),
        now: now,
      ),
      isNull,
    );
    expect(
      IntelligenceMessageAction.tryFromJson(raw(target: 5), now: now),
      isNull,
    );
    expect(
      IntelligenceMessageAction.tryFromJson(
        raw(extras: const <String, Object?>{'route': '/admin'}),
        now: now,
      ),
      isNull,
    );
  });

  test('restored subscription navigation cannot drop its confirmation', () {
    final restored = IntelligenceMessage.fromJson(<String, Object?>{
      'id': 'subscription-answer',
      'role': 'bil',
      'kind': 'coach',
      'text': 'Manage membership',
      'createdAt': DateTime.utc(2026, 9, 4).toIso8601String(),
      'actionLinks': <Object?>[
        <String, Object?>{
          'id': 'manage-subscription',
          'label': 'Manage subscription',
          'type': 'manageSubscription',
          'payload': <String, Object?>{},
          'requiresConfirmation': false,
        },
      ],
    });

    expect(restored.actionLinks, hasLength(1));
    expect(restored.actionLinks.single.requiresConfirmation, isTrue);
    expect(restored.actionLinks.single.toAction().requiresConfirmation, isTrue);
  });

  test('meal shortcut drops free-form query and keeps bounded day offset', () {
    final durable = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'review-yesterday',
        type: IntelligenceActionType.reviewMeal,
        label: 'Review yesterday meals',
        requiresConfirmation: false,
        payload: <String, Object?>{
          'query': 'arbitrary model presentation text',
          'dayOffset': -1,
        },
      ),
    );

    expect(durable, isNotNull);
    expect(durable!.payload, <String, Object?>{'dayOffset': -1});
  });
}
