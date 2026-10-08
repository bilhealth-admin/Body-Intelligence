import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';

import 'circle_management_client_fixture.dart';
import 'circle_management_model_test.dart'
    show
        bil06CapabilitiesJson,
        bil06CircleJson,
        bil06InviteJson,
        bil06MediaJson,
        bil06ReceiptJson;

const _request = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  late Bil06MemoryTransport transport;
  late RepositoryCircleManagementGateway gateway;

  setUp(() {
    transport = Bil06MemoryTransport();
    gateway = RepositoryCircleManagementGateway.withTransport(
      transport: transport,
      isCurrentVisit: () => true,
    );
  });
  tearDown(() async {
    gateway.dispose();
    await transport.events.close();
  });

  group('BIL-06 concrete adapter, synthetic transport only', () {
    test(
      'creation rechecks authoritative capability and refuses before mutation',
      () async {
        transport.handler = (name, params) async {
          expect(name, 'bil_circle_capabilities_v1');
          return bil06CapabilitiesJson(canCreate: false);
        };
        await expectLater(
          () => gateway.create(requestId: _request, draft: bil06Draft()),
          throwsA(isA<CirclePermissionDenied>()),
        );
        expect(transport.calls.map((call) => call.name), [
          'bil_circle_capabilities_v1',
        ]);
      },
    );

    test(
      'missing RPC is explicit unavailable; transport failure is not permission',
      () async {
        transport.handler = (name, params) async =>
            throw const PostgrestException(
              message:
                  'Could not find bil_circle_capabilities_v1 in schema cache',
              code: 'PGRST202',
            );
        final unavailable = await gateway.loadCapabilities();
        expect(unavailable.available, isFalse);
        expect(unavailable.canCreate, isFalse);
        transport.handler = (name, params) async =>
            throw StateError('synthetic offline');
        await expectLater(gateway.loadCapabilities(), throwsStateError);
      },
    );

    test(
      'owner envelope and capability target mismatch are rejected',
      () async {
        transport.handler = (name, params) async =>
            bil06CapabilitiesJson(owner: bil06OwnerB);
        await expectLater(gateway.loadCapabilities(), throwsFormatException);
        transport.handler = (name, params) async =>
            bil06CapabilitiesJson(slug: 'other-circle');
        await expectLater(gateway.loadCapabilities(), throwsFormatException);
      },
    );

    test(
      'create uses same supplied UUID and reviewed canonical payload',
      () async {
        transport.handler = (name, params) async {
          if (name == 'bil_circle_capabilities_v1') {
            return bil06CapabilitiesJson();
          }
          expect(name, 'bil_circle_create_v1');
          expect(params['p_request_id'], _request);
          expect(params['p_display_name'], 'Synthetic circle');
          expect(params['p_access'], 'public');
          expect(params['p_join_policy'], 'request');
          return bil06ReceiptJson(_request, 'create');
        };
        expect(
          (await gateway.create(
            requestId: _request,
            draft: bil06Draft(),
          )).requestId,
          _request,
        );
        expect(transport.calls.length, 2);
      },
    );

    test(
      'queued A B A cancels original owner forever and suppresses readback',
      () async {
        final pending = Completer<Object?>();
        transport.handler = (name, params) => pending.future;
        final future = gateway.loadCapabilities();
        transport.changeOwner(
          const CircleOwnerIdentity(bil06OwnerB, 'session-b'),
        );
        transport.changeOwner(
          const CircleOwnerIdentity(bil06OwnerA, 'session-a'),
        );
        pending.complete(bil06CapabilitiesJson());
        await expectLater(
          future,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        await expectLater(
          () => gateway.readOperation(_request),
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        expect(transport.calls.length, 1);
        expect(gateway.isCurrent, isFalse);
      },
    );

    test(
      'new session with same owner cancels; normal same-session event does not',
      () async {
        transport.handler = (name, params) async => bil06CapabilitiesJson();
        transport.changeOwner(
          const CircleOwnerIdentity(bil06OwnerA, 'session-a'),
        );
        expect((await gateway.loadCapabilities()).canCreate, isTrue);
        transport.changeOwner(
          const CircleOwnerIdentity(bil06OwnerA, 'new-session'),
        );
        await expectLater(
          () => gateway.loadCapabilities(),
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        expect(transport.calls.length, 1);
      },
    );

    test('repository replacement rejects before any dispatch', () async {
      transport.identity = Object();
      await expectLater(
        () => gateway.loadCapabilities(),
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      expect(transport.calls, isEmpty);
    });

    test(
      'parent dialog visit closes and cannot be revived by reopening',
      () async {
        gateway.dispose();
        final changes = ValueNotifier(0);
        var current = true;
        gateway = RepositoryCircleManagementGateway.withTransport(
          transport: transport,
          isCurrentVisit: () => current,
          ownerChanges: changes,
        );
        current = false;
        changes.value++;
        current = true;
        await expectLater(
          () => gateway.create(requestId: _request, draft: bil06Draft()),
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        expect(transport.calls, isEmpty);
        changes.dispose();
      },
    );

    test('scoped readback cannot hydrate media from another circle', () async {
      gateway.dispose();
      gateway = RepositoryCircleManagementGateway.withTransport(
        transport: transport,
        isCurrentVisit: () => true,
        circleSlug: 'other-circle',
      );
      var signed = 0;
      transport.signHandler = (media) async {
        signed++;
        return 'https://images.example.test/a';
      };
      transport.handler = (name, params) async =>
          bil06ReceiptJson(_request, 'create')
            ..['circle'] = (bil06CircleJson()..['avatar'] = bil06MediaJson());
      await expectLater(
        gateway.readOperation(_request),
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      expect(signed, 0);
    });

    test('server search validates owner/query/mode/cursor', () async {
      transport.handler = (name, params) async => {
        'owner_id': bil06OwnerA,
        'query': 'run',
        'mine': false,
        'circles': [bil06CircleJson()],
        'next_after_slug': 'synthetic-circle',
      };
      final page = await gateway.search(query: ' run ');
      expect(page.nextAfterSlug, 'synthetic-circle');
      expect(transport.calls.single.params['p_query'], 'run');
      await expectLater(
        gateway.search(query: 'wrong-query'),
        throwsFormatException,
      );
      transport.handler = (name, params) async => {
        'owner_id': bil06OwnerB,
        'query': '',
        'mine': false,
        'circles': [
          bil06CircleJson()
            ..['access'] = 'private'
            ..['membership_status'] = null,
        ],
        'next_after_slug': null,
      };
      await expectLater(gateway.search(query: ''), throwsFormatException);
    });

    test('repeated or nonadvancing page cursor is rejected', () async {
      transport.handler = (name, params) async => {
        'owner_id': bil06OwnerA,
        'query': '',
        'mine': false,
        'circles': [bil06CircleJson()],
        'next_after_slug': 'synthetic-circle',
      };
      await expectLater(
        gateway.search(query: '', afterSlug: 'synthetic-circle'),
        throwsFormatException,
      );
    });

    test(
      'invitation reads never accept and third user cannot use stale permission',
      () async {
        transport.handler = (name, params) async {
          if (name == 'bil_circle_invites_v1') {
            return {
              'owner_id': bil06OwnerA,
              'invites': [bil06InviteJson()],
              'next_after_id': null,
            };
          }
          if (name == 'bil_circle_invite_v1') {
            return {'owner_id': bil06OwnerA, 'invite': null};
          }
          throw StateError('Unexpected mutation $name');
        };
        expect(
          (await gateway.loadInvites()).invites.single.status,
          CircleInviteStatus.pending,
        );
        await expectLater(
          () => gateway.actOnInvite(
            requestId: _request,
            invite: bil06Invite(),
            action: CircleInviteAction.accept,
          ),
          throwsA(isA<CirclePermissionDenied>()),
        );
        expect(
          transport.calls.every((call) => !call.name.endsWith('action_v1')),
          isTrue,
        );
      },
    );

    test(
      'invite cancel rechecks current manager capability after row read',
      () async {
        transport.handler = (name, params) async {
          if (name == 'bil_circle_invite_v1') {
            return {
              'owner_id': bil06OwnerA,
              'invite': bil06InviteJson(invitee: bil06OwnerB, canCancel: true),
            };
          }
          if (name == 'bil_circle_capabilities_v1') {
            return bil06CapabilitiesJson(
              slug: 'synthetic-circle',
              manage: false,
            );
          }
          throw StateError('Unexpected mutation');
        };
        await expectLater(
          () => gateway.actOnInvite(
            requestId: _request,
            invite: bil06Invite(invitee: bil06OwnerB, canCancel: true),
            action: CircleInviteAction.cancel,
          ),
          throwsA(isA<CirclePermissionDenied>()),
        );
        expect(transport.calls.length, 2);
      },
    );

    test(
      'unavailable image stays null URL while circle data is retained',
      () async {
        transport.handler = (name, params) async => {
          'owner_id': bil06OwnerA,
          'circle': bil06CircleJson()..['avatar'] = bil06MediaJson(),
        };
        transport.signHandler = (media) async =>
            throw StateError('synthetic unavailable object');
        final circle = await gateway.readCircle('synthetic-circle');
        expect(circle!.displayName, 'Synthetic circle');
        expect(circle.avatar, isNotNull);
        expect(circle.avatar!.signedUrl, isNull);
      },
    );

    test(
      'cleanup refuses other actor reservation and published object',
      () async {
        final foreign = CircleMediaReservation.fromJson(
          bil06MediaJson(status: 'cancelled')
            ..['owner_id'] = bil06OwnerB
            ..['object_path'] =
                '$bil06OwnerB/synthetic-circle/avatar/$bil06MediaId.png',
        );
        await expectLater(
          () => gateway.removeCancelledMedia(foreign),
          throwsFormatException,
        );
        await expectLater(
          () => gateway.removeCancelledMedia(
            CircleMediaReservation.fromJson(bil06MediaJson()),
          ),
          throwsA(isA<CirclePermissionDenied>()),
        );
        expect(transport.removeCalls, 0);
      },
    );

    test(
      'invalid image fails local decoding before capability RPC or upload',
      () async {
        final image = CommunityPostImageDraft(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/png',
          extension: 'png',
          width: 1,
          height: 1,
        );
        await expectLater(
          () => gateway.prepareMedia(
            requestId: _request,
            circleSlug: 'synthetic-circle',
            kind: CircleMediaKind.avatar,
            image: image,
          ),
          throwsA(isA<CommunityPostImageException>()),
        );
        expect(transport.calls, isEmpty);
        expect(transport.uploadCalls, 0);
      },
    );

    test(
      'upload re-decodes bytes and rejects fabricated metadata before transfer',
      () async {
        final bytes = Uint8List.fromList(
          img.encodePng(img.Image(width: 2, height: 2)),
        );
        final image = validateCommunityPostImage(bytes);
        final reservation = CircleMediaReservation.fromJson(
          bil06MediaJson(status: 'reserved')
            ..['bytes'] = image.byteLength
            ..['width'] = 99
            ..['height'] = 2,
        );
        await expectLater(
          () => gateway.uploadMedia(reservation, image),
          throwsFormatException,
        );
        expect(transport.uploadCalls, 0);
        expect(transport.calls, isEmpty);
      },
    );

    test(
      'real decoded upload uses only reserved path after manager read',
      () async {
        final bytes = Uint8List.fromList(
          img.encodePng(img.Image(width: 2, height: 2)),
        );
        final image = validateCommunityPostImage(bytes);
        final reservation = CircleMediaReservation.fromJson(
          bil06MediaJson(status: 'reserved')
            ..['bytes'] = image.byteLength
            ..['width'] = image.width
            ..['height'] = image.height,
        );
        transport.handler = (name, params) async =>
            bil06CapabilitiesJson(slug: 'synthetic-circle');
        await gateway.uploadMedia(reservation, image);
        expect(transport.uploadCalls, 1);
        expect(transport.calls.single.name, 'bil_circle_capabilities_v1');
      },
    );

    test(
      'membership interface reads real capability and does not mutate',
      () async {
        transport.handler = (name, params) async =>
            bil06CapabilitiesJson(slug: 'synthetic-circle');
        final permission = await gateway.readMembership('synthetic-circle');
        expect(permission.ownerId, bil06OwnerA);
        expect(permission.canInvite, isTrue);
        expect(transport.calls.map((call) => call.name), [
          'bil_circle_capabilities_v1',
        ]);
      },
    );
  });
}
