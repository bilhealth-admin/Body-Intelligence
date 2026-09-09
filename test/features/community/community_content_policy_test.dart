import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _snapshot({
  required String status,
  String? version = 'community-policy-v1',
  String? effectiveAt = '2026-09-08T00:00:00Z',
  String? acceptedAt,
  bool accepted = false,
  String serverNow = '2026-09-08T12:00:00Z',
}) => {
  'server_now': serverNow,
  'status': status,
  'version': version,
  'locale_code': version == null ? null : 'en',
  'document_url': version == null
      ? null
      : 'https://www.bilhealth.com/community-guidelines',
  'effective_at': effectiveAt,
  'accepted_at': acceptedAt,
  'accepted': accepted,
};

void main() {
  group('CommunityPolicyState.fromServerSnapshot', () {
    test('represents no effective policy as unavailable and fail-closed', () {
      final state = CommunityPolicyState.fromServerSnapshot(
        _snapshot(status: 'unavailable', version: null, effectiveAt: null),
      );

      expect(state.status, CommunityPolicyStatus.unavailable);
      expect(state.policy, isNull);
      expect(state.permitsCommunityPublishing, isFalse);
    });

    test('requires acceptance for the exact effective version', () {
      final state = CommunityPolicyState.fromServerSnapshot(
        _snapshot(status: 'acceptance_required'),
      );

      expect(state.status, CommunityPolicyStatus.acceptanceRequired);
      expect(state.policy?.version, 'community-policy-v1');
      expect(state.acceptedVersion, isNull);
      expect(state.permitsCommunityPublishing, isFalse);
    });

    test('accepts only a server receipt at or after policy effectiveness', () {
      final state = CommunityPolicyState.fromServerSnapshot(
        _snapshot(
          status: 'accepted',
          accepted: true,
          acceptedAt: '2026-09-08T12:00:00Z',
        ),
      );

      expect(state.status, CommunityPolicyStatus.accepted);
      expect(state.acceptedVersion, 'community-policy-v1');
      expect(state.permitsCommunityPublishing, isTrue);
    });

    test('a newly active version does not inherit the old receipt', () {
      final state = CommunityPolicyState.fromServerSnapshot(
        _snapshot(
          status: 'acceptance_required',
          version: 'community-policy-v2',
          acceptedAt: null,
        ),
      );

      expect(state.policy?.version, 'community-policy-v2');
      expect(state.acceptedVersion, isNull);
      expect(state.permitsCommunityPublishing, isFalse);
    });

    test('rejects a future-effective policy snapshot', () {
      expect(
        () => CommunityPolicyState.fromServerSnapshot(
          _snapshot(
            status: 'acceptance_required',
            effectiveAt: '2026-09-09T00:00:00Z',
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects contradictory or stale accepted receipts', () {
      expect(
        () => CommunityPolicyState.fromServerSnapshot(
          _snapshot(status: 'accepted', accepted: false),
        ),
        throwsFormatException,
      );
      expect(
        () => CommunityPolicyState.fromServerSnapshot(
          _snapshot(
            status: 'accepted',
            accepted: true,
            acceptedAt: '2026-09-07T23:59:59Z',
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects unauthenticated and malformed server states', () {
      expect(
        () => CommunityPolicyState.fromServerSnapshot(
          _snapshot(status: 'unauthenticated'),
        ),
        throwsFormatException,
      );
      expect(
        () => CommunityPolicyState.fromServerSnapshot({
          'server_now': 'not-a-time',
          'status': 'unavailable',
        }),
        throwsFormatException,
      );
    });
  });
}
