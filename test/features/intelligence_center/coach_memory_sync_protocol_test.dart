import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_sync_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const old = {
    'id': 'memory',
    'text': 'Evening workouts',
    'kind': 'preference',
    'status': 'confirmed',
    'source': 'explicit_user_confirmation',
    'confidence': 1.0,
    'savedAt': '2026-10-22T10:00:00Z',
    'updatedAt': '2026-10-22T10:00:00Z',
  };
  final updated = {
    ...old,
    'text': 'Morning workouts',
    'updatedAt': '2026-10-23T10:00:00Z',
  };
  const version = '2026-10-22T10:00:00Z';
  test(
    'new fact can create only when no previously synchronized row disappeared',
    () {
      expect(
        decideCoachMemorySync(local: old, remote: null, remoteVersion: null),
        CoachMemorySyncDecision.create,
      );
      expect(
        decideCoachMemorySync(
          local: old,
          remote: null,
          remoteVersion: null,
          baselineVersion: version,
          baselineDigest: coachMemoryFactDigest(old),
        ),
        CoachMemorySyncDecision.conflict,
      );
    },
  );
  test('a confirmed baseline allows only an exact conditional update', () {
    expect(
      decideCoachMemorySync(
        local: updated,
        remote: old,
        remoteVersion: '2026-10-22T10:00:00+00:00',
        baselineVersion: version,
        baselineDigest: coachMemoryFactDigest(old),
      ),
      CoachMemorySyncDecision.update,
    );
    expect(
      decideCoachMemorySync(
        local: updated,
        remote: {...old, 'text': 'Other device'},
        remoteVersion: '2026-10-23T11:00:00Z',
        baselineVersion: version,
        baselineDigest: coachMemoryFactDigest(old),
      ),
      CoachMemorySyncDecision.conflict,
    );
  });
  test('same server value is acknowledged without a duplicate write', () {
    expect(
      decideCoachMemorySync(
        local: updated,
        remote: updated,
        remoteVersion: '2026-10-23T10:00:00Z',
      ),
      CoachMemorySyncDecision.verified,
    );
  });
  test(
    'deletion never erases an unseen concurrent edit and cannot revive a tombstone',
    () {
      expect(
        decideCoachMemorySync(
          local: null,
          remote: old,
          remoteVersion: version,
          baselineVersion: version,
          baselineDigest: coachMemoryFactDigest(old),
        ),
        CoachMemorySyncDecision.delete,
      );
      expect(
        decideCoachMemorySync(
          local: null,
          remote: updated,
          remoteVersion: '2026-10-23T10:00:00Z',
          baselineVersion: version,
          baselineDigest: coachMemoryFactDigest(old),
        ),
        CoachMemorySyncDecision.conflict,
      );
      expect(
        decideCoachMemorySync(
          local: old,
          remote: old,
          remoteVersion: version,
          remoteDeleted: true,
        ),
        CoachMemorySyncDecision.conflict,
      );
      expect(
        decideCoachMemorySync(
          local: null,
          remote: old,
          remoteVersion: version,
          remoteDeleted: true,
        ),
        CoachMemorySyncDecision.verified,
      );
    },
  );
  test('unknown legacy states never fall back to last-writer-wins', () {
    expect(
      decideCoachMemorySync(
        local: updated,
        remote: old,
        remoteVersion: version,
      ),
      CoachMemorySyncDecision.conflict,
    );
    expect(
      decideCoachMemorySync(
        local: updated,
        remote: old,
        remoteVersion: version,
        baselineVersion: 'invalid',
        baselineDigest: coachMemoryFactDigest(old),
      ),
      CoachMemorySyncDecision.conflict,
    );
  });
}
