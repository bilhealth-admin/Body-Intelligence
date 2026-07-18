import 'package:body_intelligence_log/engine/ai_write_policy.dart';
import 'package:body_intelligence_log/engine/sync_conflict_engine.dart';
import 'package:body_intelligence_log/engine/update_policy_engine.dart';
import 'package:body_intelligence_log/app/services/external_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unverified external capabilities never advertise availability', () {
    for (final capability in ExternalCapability.values) {
      final status = ExternalCapabilities.status(capability);
      expect(status.capability, capability);
      expect(status.available, isFalse);
      expect(status.reason.trim(), isNotEmpty);
    }
    expect(
      ExternalCapabilities.status(ExternalCapability.sync).reason,
      contains('No data is uploaded'),
    );
    expect(
      ExternalCapabilities.status(ExternalCapability.commerce).reason,
      contains('No payment details are collected'),
    );
  });
  test('required update is distinguished from optional update', () {
    const policy = UpdatePolicy(
      latestVersion: '2.1.0',
      minimumVersion: '2.0.0',
      maintenance: false,
    );
    expect(
      UpdatePolicyEngine.evaluate(
        currentVersion: '1.9.9',
        policy: policy,
      ).requirement,
      UpdateRequirement.required,
    );
    expect(
      UpdatePolicyEngine.evaluate(
        currentVersion: '2.0.0',
        policy: policy,
      ).requirement,
      UpdateRequirement.optional,
    );
  });

  test('sync tombstone wins an equal-revision conflict', () {
    final now = DateTime(2026, 7, 18);
    final winner = SyncConflictEngine.resolve(
      local: SyncRecordMetadata(revision: 3, updatedAt: now, deleted: true),
      remote: SyncRecordMetadata(revision: 3, updatedAt: now, deleted: false),
    );
    expect(winner, SyncWinner.local);
  });

  test(
    'AI writes require consent and confirmation and cannot change targets',
    () {
      expect(
        AiWritePolicy.mayCommit(
          kind: AiWriteKind.addWater,
          userDataConsent: true,
          explicitConfirmation: false,
        ),
        isFalse,
      );
      expect(
        AiWritePolicy.mayCommit(
          kind: AiWriteKind.changeTarget,
          userDataConsent: true,
          explicitConfirmation: true,
        ),
        isFalse,
      );
    },
  );
}
