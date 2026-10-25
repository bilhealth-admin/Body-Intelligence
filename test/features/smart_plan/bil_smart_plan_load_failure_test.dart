import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_load_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local read/parse faults are distinct from catalog validation', () {
    expect(
      classifySmartPlanLoadFailure(
        const FormatException('truncated saved JSON'),
        duringCatalog: false,
      ),
      'smart_plan_saved_data_invalid',
    );
    expect(
      classifySmartPlanLoadFailure(
        StateError('unavailable local storage'),
        duringCatalog: false,
      ),
      'smart_plan_storage_unavailable',
    );
    expect(
      classifySmartPlanLoadFailure(
        StateError('offline preferences'),
        duringCatalog: true,
      ),
      'smart_plan_catalog_unavailable',
    );
  });

  test('owner and revision conflicts take priority over recovery stage', () {
    for (final catalogStage in [false, true]) {
      expect(
        classifySmartPlanLoadFailure(
          StateError('smart_plan_foreign_owner'),
          duringCatalog: catalogStage,
        ),
        'smart_plan_owner_mismatch',
      );
      expect(
        classifySmartPlanLoadFailure(
          StateError('smart_plan_owner_changed'),
          duringCatalog: catalogStage,
        ),
        'smart_plan_owner_changed',
      );
      expect(
        classifySmartPlanLoadFailure(
          StateError('smart_plan_revision_conflict'),
          duringCatalog: catalogStage,
        ),
        'smart_plan_revision_conflict',
      );
    }
  });

  test('raw storage details are not returned to UI', () {
    final code = classifySmartPlanLoadFailure(
      StateError('user=owner-a read failed local key foo'),
      duringCatalog: false,
    );
    expect(code, 'smart_plan_storage_unavailable');
    expect(code, isNot(contains('owner-a')));
  });

  test('recovery copy is localized for every supported failure family', () {
    String en(String english, String arabic) => english;
    String ar(String english, String arabic) => arabic;
    const errors = [
      'sign_in_required',
      'smart_plan_owner_mismatch',
      'smart_plan_owner_changed',
      'smart_plan_storage_unavailable',
      'smart_plan_saved_data_invalid',
      'smart_plan_catalog_unavailable',
      'smart_plan_revision_conflict',
      'sync_conflict',
      'during_sync',
      'reopen_day_first',
      'workout_receipt',
      'undo_conflict',
      'report_not_sent',
      'export_failed',
      'verified_subscription_required',
      'no_verified_workout',
      'home_strength_recovery_days_required',
      'requires_review',
      'arbitrary_failure',
    ];
    for (final code in errors) {
      final english = smartPlanLoadFailureMessage(code, en);
      final arabic = smartPlanLoadFailureMessage(code, ar);
      expect(english, isNotEmpty, reason: code);
      expect(arabic, isNotEmpty, reason: code);
      expect(arabic, isNot(english), reason: code);
    }
    expect(
      smartPlanLoadFailureMessage('smart_plan_storage_unavailable', en),
      contains('has not been overwritten'),
    );
    expect(
      smartPlanLoadFailureMessage('smart_plan_catalog_unavailable', en),
      contains('Retry before editing it'),
    );
    expect(
      smartPlanLoadFailureMessage('smart_plan_owner_changed', en),
      contains('correct account'),
    );
  });

  test('failed writes never expose storage paths or owner identifiers', () {
    final fault = StateError(
      'write failed /synthetic/owner-A/token=synthetic-secret',
    );
    expect(classifySmartPlanWriteFailure(fault), 'arbitrary_failure');
    expect(
      classifySmartPlanWriteFailure(
        StateError('smart_plan_revision_conflict'),
      ),
      'smart_plan_revision_conflict',
    );
    expect(
      classifySmartPlanWriteFailure(
        StateError('smart_plan_owner_changed'),
      ),
      'smart_plan_owner_changed',
    );
    for (final code in [
      'no_verified_workout',
      'sync_conflict',
      'requires_review',
    ]) {
      expect(classifySmartPlanWriteFailure(StateError(code)), code);
    }
    expect(
      classifySmartPlanWriteFailure(
        StateError('sync_conflict details=owner-A'),
      ),
      'arbitrary_failure',
    );
    String en(String english, String arabic) => english;
    final copy = smartPlanLoadFailureMessage(
      classifySmartPlanWriteFailure(fault),
      en,
    );
    expect(copy, 'Action not completed. Please review saved data and retry.');
    expect(copy, isNot(contains('owner-A')));
    expect(copy, isNot(contains('synthetic-secret')));
  });

  test('untrusted errors cannot leak owner identifiers in recovery text', () {
    String en(String english, String arabic) => english;
    final copy = smartPlanLoadFailureMessage(
      'internal path /synthetic/owner-A/token=synthetic-secret',
      en,
    );
    expect(copy, 'Action not completed. Please review saved data and retry.');
    expect(copy, isNot(contains('owner-A')));
    expect(copy, isNot(contains('synthetic-secret')));
  });

  test('catalog failures and retries remain read-only', () {
    for (final hasPlan in [true, false]) {
      for (final catalogBlocked in [true, false]) {
        final blocked = shouldBlockUnverifiedSmartPlanWrites(
          hasPlan: hasPlan,
          catalogBlocked: catalogBlocked,
        );
        expect(blocked, hasPlan && catalogBlocked);
      }
    }
  });
}
