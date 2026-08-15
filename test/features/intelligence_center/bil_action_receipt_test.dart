import 'package:body_intelligence_log/features/intelligence_center/domain/bil_action_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mutation receipt requires a committed entity identifier', () {
    final valid = BilActionReceipt(
      actionId: 'log_weight',
      committed: true,
      completedAt: DateTime.utc(2026, 8, 11),
      entityType: 'weight_entry',
      entityId: '42',
      refreshTargets: const {'weightHistory', 'coachContext'},
    );
    final uncommitted = BilActionReceipt(
      actionId: 'log_weight',
      committed: false,
      completedAt: DateTime.utc(2026, 8, 11),
      entityType: 'weight_entry',
      entityId: '42',
    );
    final missingId = BilActionReceipt(
      actionId: 'log_weight',
      committed: true,
      completedAt: DateTime.utc(2026, 8, 11),
      entityType: 'weight_entry',
    );
    expect(valid.verified, isTrue);
    expect(uncommitted.verified, isFalse);
    expect(missingId.verified, isFalse);
  });

  test(
    'receipt exposes typed locale-neutral payload and stable refresh order',
    () {
      final receipt = BilActionReceipt(
        actionId: 'move_meal_entry',
        committed: true,
        completedAt: DateTime.utc(2026, 8, 12, 10, 30),
        entityType: 'meal_entry',
        entityId: 'meal-7',
        refreshTargets: const {'nutritionSummary', 'diary', 'coachContext'},
      );

      expect(receipt.messageKey, 'ai_coach.action_receipt.completed');
      expect(receipt.toStructuredPayload(), {
        'action_id': 'move_meal_entry',
        'committed': true,
        'verified': true,
        'completed_at': '2026-08-12T10:30:00.000Z',
        'entity_type': 'meal_entry',
        'entity_id': 'meal-7',
        'refresh_targets': ['coachContext', 'diary', 'nutritionSummary'],
        'message_key': 'ai_coach.action_receipt.completed',
      });
    },
  );
}
