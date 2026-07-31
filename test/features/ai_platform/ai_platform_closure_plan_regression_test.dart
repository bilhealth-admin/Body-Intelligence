import 'package:body_intelligence_log/features/ai_platform/services/ai_platform_closure_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closure sequence is unique stable and fully testable', () {
    final capabilities = AiPlatformClosurePlan.capabilities;
    final keys = capabilities.map((item) => item.key).toList();

    expect(keys.toSet(), hasLength(keys.length));
    expect(keys.first, 'truth_explain');
    expect(keys[1], 'body_twin');
    expect(keys.last, 'final_integration');
    expect(
      capabilities.every(
        (item) => item.exitCriteria.isNotEmpty && item.nextPackage.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('closure plan cannot be mutated by consumers', () {
    expect(
      () => AiPlatformClosurePlan.capabilities.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => AiPlatformClosurePlan.capabilities.first.exitCriteria.clear(),
      throwsUnsupportedError,
    );
  });
}
