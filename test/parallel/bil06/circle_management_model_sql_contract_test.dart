import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';

import 'circle_management_client_fixture.dart';

void main() {
  // Load the actual disposable-PostgreSQL response evidence before test clocks.
  // No process, network connection or provider session is started by this file.
  final evidence =
      jsonDecode(
            File(
              'tool/qa_parallel/bil06/sql/evidence/sql_protocol_samples.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final samples = (evidence['samples'] as List).cast<Map<String, dynamic>>();

  test(
    'BIL-06 Dart parsers accept actual PostgreSQL RPC response evidence',
    () {
      var checked = 0;
      for (final sample in samples) {
        final rpc = sample['rpc'] as String;
        final result = sample['result'];
        final actor = sample['actor'];
        if (result == null || result is! Map) continue;
        final json = Map<String, dynamic>.from(result);
        expect(json['owner_id'], actor, reason: rpc);
        if (rpc == 'bil_circle_capabilities_v1') {
          expect(CircleCapabilities.fromJson(json).ownerId, actor);
        } else if (json['committed'] == true) {
          final receipt = CircleMutationReceipt.fromJson(json);
          expect(receipt.ownerId, actor, reason: rpc);
          expect(receipt.requestId, isNotEmpty, reason: rpc);
        } else if (rpc == 'bil_circle_read_v1') {
          if (json['circle'] != null) {
            ManagedCommunityCircle.fromJson(circleMap(json['circle']));
          }
        } else if (rpc == 'bil_circle_invite_v1') {
          if (json['invite'] != null) {
            CircleInvitation.fromJson(circleMap(json['invite']));
          }
        } else if (rpc == 'bil_circle_invites_v1') {
          for (final row in json['invites'] as List) {
            CircleInvitation.fromJson(circleMap(row));
          }
        } else if (rpc == 'bil_circle_search_v1') {
          for (final row in json['circles'] as List) {
            ManagedCommunityCircle.fromJson(circleMap(row));
          }
        } else {
          continue;
        }
        checked++;
      }
      expect(checked, greaterThan(60));
    },
  );

  test(
    'BIL-06 gateway consumes real SQL search/cursor/privacy envelopes',
    () async {
      final searches = samples.where(
        (sample) => sample['rpc'] == 'bil_circle_search_v1',
      );
      expect(searches, isNotEmpty);
      var authorizedInvitePreviews = 0;
      for (final sample in searches) {
        final params = sample['params'] as List;
        final transport = Bil06MemoryTransport()
          ..current = CircleOwnerIdentity(
            sample['actor'] as String,
            'synthetic-session',
          );
        final gateway = RepositoryCircleManagementGateway.withTransport(
          transport: transport,
          isCurrentVisit: () => true,
        );
        transport.handler = (name, actual) async {
          expect(name, 'bil_circle_search_v1');
          return sample['result'];
        };
        try {
          final page = await gateway.search(
            query: params.isNotEmpty ? params[0] as String : '',
            mine: params.length > 1 ? params[1] as bool : false,
            afterSlug: params.length > 2 ? params[2] as String? : null,
            limit: params.length > 3 ? params[3] as int : 30,
          );
          final result = sample['result'] as Map;
          expect(page.circles.length, (result['circles'] as List).length);
          expect(page.nextAfterSlug, result['next_after_slug']);
          for (final row in page.circles) {
            if (row.access.name == 'private' && !row.activeMember) {
              authorizedInvitePreviews++;
              // This is an authorized server preview, not a fabricated active
              // membership or a read-triggered invitation acceptance.
              expect(row.membershipStatus, isNull);
              expect(transport.calls.length, 1);
            }
          }
        } finally {
          gateway.dispose();
          await transport.events.close();
        }
      }
      expect(authorizedInvitePreviews, greaterThan(0));
    },
  );

  test(
    'actual SQL invitation names remain useful when BIL Code is redacted',
    () {
      var verified = 0;
      for (final sample in samples.where(
        (row) => row['rpc'] == 'bil_circle_invite_send_v1',
      )) {
        final raw = (sample['result'] as Map)['invite'];
        if (raw == null) continue;
        final json = circleMap(raw);
        final invitation = CircleInvitation.fromJson(json);
        expect(invitation.recipientCode, isNull);
        expect(invitation.inviterName, json['inviter_name']);
        expect(invitation.inviteeName, json['invitee_name']);
        if (invitation.inviterName != null || invitation.inviteeName != null) {
          verified++;
        }
      }
      expect(verified, greaterThan(0));
    },
  );
}
