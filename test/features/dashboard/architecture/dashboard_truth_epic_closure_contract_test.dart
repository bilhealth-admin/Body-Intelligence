import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Truth Epic production boundaries remain wired and explicit', () {
    final authority = File(
      'lib/features/dashboard/domain/dashboard_decision_authority.dart',
    ).readAsStringSync();
    final truthAdapter = File(
      'lib/features/dashboard/domain/dashboard_trusted_truth_decision_adapter.dart',
    ).readAsStringSync();
    final bodyTwin = File(
      'lib/features/dashboard/domain/dashboard_trusted_body_twin_adapter.dart',
    ).readAsStringSync();
    final outcomeStore = File(
      'lib/data/repositories/decision_outcome_transition_repository.dart',
    ).readAsStringSync();
    final release = File(
      'lib/features/dashboard/domain/dashboard_decision_release_boundary.dart',
    ).readAsStringSync();

    expect(authority, contains('DashboardTrustedTruthDecisionAdapter'));
    expect(authority, contains('releaseBoundary.evaluate(trustedAction)'));
    expect(truthAdapter, contains('TrustedTruthDecisionPipeline'));
    expect(bodyTwin, contains('TrustedBodyTwinSnapshotPipeline'));
    expect(outcomeStore, contains('Legacy `decision_memories.outcome`'));
    expect(release, contains('DashboardDecisionReleaseStatus'));
    expect(release, contains('insufficientEvidence'));
    expect(release, contains('safetyBlocked'));
    expect(release, contains('scientificallyUnsupported'));
  });
}
