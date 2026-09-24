import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = CoachActionPermissionGate();
  const registry = BilToolRegistry();

  test('read-only blocks writes but preserves reads and navigation', () {
    expect(
      gate.allows(
        mode: CoachActionPermissionMode.readOnly,
        descriptor: registry.lookup('log_weight')!,
      ),
      isFalse,
    );
    expect(
      gate.allows(
        mode: CoachActionPermissionMode.readOnly,
        descriptor: registry.lookup('read_profile_identity')!,
      ),
      isTrue,
    );
    expect(
      gate.allows(
        mode: CoachActionPermissionMode.readOnly,
        descriptor: registry.lookup('navigate')!,
      ),
      isTrue,
    );
  });

  test('write allowed never bypasses sensitive confirmation', () {
    expect(
      gate.requiresConfirmation(
        mode: CoachActionPermissionMode.writeAllowed,
        descriptor: registry.lookup('delete_meal_item')!,
      ),
      isTrue,
    );
    expect(
      gate.requiresConfirmation(
        mode: CoachActionPermissionMode.writeAllowed,
        descriptor: registry.lookup('log_weight')!,
      ),
      isFalse,
    );
  });
}
