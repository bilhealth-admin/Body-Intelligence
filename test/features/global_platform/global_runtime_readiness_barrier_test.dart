import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/bil_global_product_expansion_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no-work mandatory modules are never represented as product ready', () {
    const execution = GlobalModuleExecution(
      module: GlobalModule.reports,
      status: GlobalModuleExecutionStatus.noWork,
      evidenceCount: 0,
      detail: 'No report request.',
    );
    expect(execution.operational, isFalse);
  });

  test(
    'optional cloud AI may be disabled without claiming execution evidence',
    () {
      const execution = GlobalModuleExecution(
        module: GlobalModule.cloudAi,
        status: GlobalModuleExecutionStatus.optionalDisabled,
        evidenceCount: 0,
        detail: 'Local-only mode.',
      );
      expect(execution.operational, isTrue);
      expect(execution.evidenceCount, 0);
    },
  );
}
