import 'package:body_intelligence_log/features/ai_platform/domain/ai_platform_capability.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_platform_closure_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconciles completed partial and remaining capability states', () {
    final capabilities = AiPlatformClosurePlan.capabilities;

    expect(
      capabilities.where(
        (item) => item.status == AiPlatformCapabilityStatus.completed,
      ),
      hasLength(1),
    );
    expect(
      capabilities
          .where((item) => item.status == AiPlatformCapabilityStatus.partial)
          .single
          .key,
      'body_twin',
    );
    expect(
      capabilities.where(
        (item) => item.status == AiPlatformCapabilityStatus.remaining,
      ),
      isNotEmpty,
    );
    expect(AiPlatformClosurePlan.isClosed, isFalse);
  });

  test('authorizes BIL-AI-026 as the first production package', () {
    final next = AiPlatformClosurePlan.firstProductionPackage;

    expect(next.key, 'body_twin');
    expect(next.nextPackage, 'BIL-AI-026');
    expect(next.exitCriteria, isNotEmpty);
  });
}
