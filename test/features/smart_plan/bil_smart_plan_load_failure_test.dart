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
}
