import 'package:body_intelligence_log/features/global_platform/runtime/global_closure_audit.dart';
import 'package:flutter_test/flutter_test.dart';

ClosureEvidence proof({
  required String id,
  ClosureStatus status = ClosureStatus.completed,
  bool complete = true,
}) => ClosureEvidence(
  requirementId: id,
  requirement: 'Requirement $id',
  productionFiles: complete ? <String>['lib/$id.dart'] : const <String>[],
  runtimePath: complete ? 'root -> $id' : '',
  behavioralTests: complete
      ? <String>['test/${id}_behavior_test.dart']
      : const <String>[],
  systemTests: complete
      ? <String>['test/${id}_system_test.dart']
      : const <String>[],
  regressionTests: complete
      ? <String>['test/${id}_regression_test.dart']
      : const <String>[],
  evidence: complete ? 'Observed deterministic production behavior.' : '',
  securityReview: complete ? 'Consent and least-privilege reviewed.' : '',
  failureRecoveryCoverage: complete
      ? 'Failure and recovery paths exercised.'
      : '',
  privacyCoverage: complete ? 'Data minimization and deletion verified.' : '',
  provenanceCoverage: complete ? 'Source provenance preserved.' : '',
  decision: complete ? 'Close: evidence chain is complete.' : '',
  status: status,
);

void main() {
  test('closure requires complete evidence for every declared requirement', () {
    final audit = GlobalClosureAudit(<ClosureEvidence>[
      proof(id: 'GLOBAL-001'),
    ]);
    expect(audit.complete, isTrue);
    expect(audit.unsupported, isEmpty);
  });

  test('completed label cannot override missing proof', () {
    final audit = GlobalClosureAudit(<ClosureEvidence>[
      proof(id: 'GLOBAL-002', complete: false),
    ]);
    expect(audit.complete, isFalse);
    expect(audit.unsupported.single.requirementId, 'GLOBAL-002');
  });

  test(
    'not completed evidence blocks closure even when proof fields exist',
    () {
      final audit = GlobalClosureAudit(<ClosureEvidence>[
        proof(id: 'GLOBAL-003', status: ClosureStatus.notCompleted),
      ]);
      expect(audit.complete, isFalse);
    },
  );
}
