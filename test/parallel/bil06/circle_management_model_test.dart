import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';

import 'circle_management_client_fixture.dart';

Map<String, dynamic> bil06CircleJson() => {
  'slug': 'synthetic-circle',
  'title_copy_key': circleNativeTitleCopyKey,
  'description_copy_key': 'community_circle_custom_description',
  'rules_copy_key': 'community_circle_custom_rules',
  'access': 'public',
  'join_policy': 'request',
  'featured': false,
  'member_count': 1,
  'post_count': 0,
  'membership_status': 'active',
  'membership_role': 'moderator',
  'display_name': 'Synthetic circle',
  'description': 'Synthetic test description.',
  'rules': 'Respect members.',
  'avatar': null,
  'cover': null,
};

Map<String, dynamic> bil06MediaJson({
  String status = 'published',
  String slot = 'avatar',
}) => {
  'id': bil06MediaId,
  'owner_id': bil06OwnerA,
  'circle_slug': 'synthetic-circle',
  'slot': slot,
  'object_path': '$bil06OwnerA/synthetic-circle/$slot/$bil06MediaId.png',
  'mime_type': 'image/png',
  'bytes': 70,
  'width': 1,
  'height': 1,
  'status': status,
};

Map<String, dynamic> bil06CapabilitiesJson({
  String owner = bil06OwnerA,
  String? slug,
  bool canCreate = true,
  bool manage = true,
}) => {
  'owner_id': owner,
  'circle_slug': slug,
  'available': true,
  'can_create': canCreate,
  'can_search': true,
  'can_read_invites': true,
  'can_invite': manage && slug != null,
  'can_manage_media': manage && slug != null,
  'is_member': manage && slug != null,
  'role': manage && slug != null ? 'moderator' : null,
};

Map<String, dynamic> bil06InviteJson({
  String status = 'pending',
  String invitee = bil06OwnerA,
  bool canCancel = false,
}) => {
  'id': bil06InviteId,
  'circle_slug': 'synthetic-circle',
  'circle_name': 'Synthetic circle',
  'inviter_id': bil06OwnerB,
  'invitee_id': invitee,
  'recipient_code': null,
  'status': status,
  'can_accept': status == 'pending' && invitee == bil06OwnerA,
  'can_decline': status == 'pending' && invitee == bil06OwnerA,
  'can_cancel': canCancel,
};

Map<String, dynamic> bil06ReceiptJson(
  String requestId,
  String operation, {
  Map<String, dynamic>? media,
  Map<String, dynamic>? invite,
}) => {
  'owner_id': bil06OwnerA,
  'request_id': requestId,
  'operation': operation,
  'committed': true,
  'circle_slug': 'synthetic-circle',
  'invite_id': invite?['id'],
  'media_id': media?['id'],
  'circle': bil06CircleJson(),
  'invite': invite,
  'media': media,
};

void main() {
  group('BIL-06 strict models', () {
    test(
      'native data retains base contract, real counts, and metadata on copy',
      () {
        final row = ManagedCommunityCircle.fromJson(bil06CircleJson());
        expect(row, isA<CommunityCircle>());
        expect(row.displayName, 'Synthetic circle');
        expect(row.memberCount, 1);
        final changed = row.copyWith(memberCount: 2, clearMembership: true);
        expect(changed.displayName, row.displayName);
        expect(changed.memberCount, 2);
        expect(changed.membershipRole, isNull);
      },
    );

    test('missing count stays unknown failure instead of becoming zero', () {
      final json = bil06CircleJson()..['member_count'] = null;
      expect(
        () => ManagedCommunityCircle.fromJson(json),
        throwsFormatException,
      );
    });

    test('fractional and negative counts fail closed', () {
      for (final value in [-1, 1.5, '12']) {
        expect(
          () => ManagedCommunityCircle.fromJson(
            bil06CircleJson()..['post_count'] = value,
          ),
          throwsFormatException,
        );
      }
    });

    test(
      'custom title requires server native name; seeded keys may use copy',
      () {
        expect(
          () => ManagedCommunityCircle.fromJson(
            bil06CircleJson()..remove('display_name'),
          ),
          throwsFormatException,
        );
        final seeded = bil06CircleJson()
          ..['title_copy_key'] = 'community_circle_running'
          ..['display_name'] = null;
        expect(ManagedCommunityCircle.fromJson(seeded).displayName, isNull);
      },
    );

    test('Unicode scalar limits match SQL and private-open is rejected', () {
      bil06Draft(name: List.filled(80, '🏃').join()).validate();
      expect(
        () => bil06Draft(name: List.filled(81, '🏃').join()).validate(),
        throwsFormatException,
      );
      expect(() => bil06Draft(name: 'A').validate(), throwsArgumentError);
      expect(
        () => bil06Draft(name: 'Two\nlines').validate(),
        throwsArgumentError,
      );
      expect(
        () => const CircleDraft(
          displayName: 'Private circle',
          description: '',
          rules: '',
          access: CommunityCircleAccess.private,
          joinPolicy: CommunityCircleJoinPolicy.open,
        ).validate(),
        throwsArgumentError,
      );
    });

    test(
      'capability bools are required typed values, never truthy strings',
      () {
        expect(
          () => CircleCapabilities.fromJson(
            bil06CapabilitiesJson()..['can_create'] = 'true',
          ),
          throwsFormatException,
        );
        expect(
          () => CircleCapabilities.fromJson(
            bil06CapabilitiesJson()..remove('can_manage_media'),
          ),
          throwsFormatException,
        );
      },
    );

    test('media reference has no URL until authorized storage resolution', () {
      final record = CircleMediaReference.fromJson(
        bil06MediaJson()
          ..['signed_url'] = 'https://untrusted.example/image.png',
      );
      expect(record.signedUrl, isNull);
    });

    test(
      'media rejects actor, circle, slot, ID, extension and bucket substitution',
      () {
        final mutations = <Map<String, dynamic>>[
          {'owner_id': bil06OwnerB},
          {'circle_slug': 'other-circle'},
          {'slot': 'cover'},
          {'id': bil06InviteId},
          {'mime_type': 'image/jpeg'},
          {'bucket': 'public-media'},
        ];
        for (final mutation in mutations) {
          expect(
            () => CircleMediaReference.fromJson({
              ...bil06MediaJson(),
              ...mutation,
            }),
            throwsFormatException,
          );
        }
      },
    );

    test('circle image cannot display a reserved or another circle asset', () {
      expect(
        () => ManagedCommunityCircle.fromJson(
          bil06CircleJson()..['avatar'] = bil06MediaJson(status: 'reserved'),
        ),
        throwsFormatException,
      );
      expect(
        () => ManagedCommunityCircle.fromJson(
          bil06CircleJson()..['cover'] = bil06MediaJson(slot: 'avatar'),
        ),
        throwsFormatException,
      );
      final other = bil06MediaJson()
        ..['circle_slug'] = 'other-circle'
        ..['object_path'] =
            '$bil06OwnerA/other-circle/avatar/$bil06MediaId.png';
      expect(
        () => ManagedCommunityCircle.fromJson(
          bil06CircleJson()..['avatar'] = other,
        ),
        throwsFormatException,
      );
    });

    test('uncommitted or wrong-target receipts cannot confirm a mutation', () {
      final request = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      expect(
        () => CircleMutationReceipt.fromJson(
          bil06ReceiptJson(request, 'create')..['committed'] = false,
        ),
        throwsFormatException,
      );
      expect(
        () => CircleMutationReceipt.fromJson(
          bil06ReceiptJson(request, 'create')..['circle_slug'] = 'wrong-circle',
        ),
        throwsFormatException,
      );
    });

    test('invite operation key never stores the raw BIL Code', () {
      final key = CircleOperationKeys.inviteSend(
        'synthetic-circle',
        bil06RecipientCode,
      );
      expect(key, isNot(contains(bil06RecipientCode)));
      expect(key, contains(circleOperationDigest(bil06RecipientCode)));
    });

    test(
      'historical receipt accepts immutable IDs after projection deletion',
      () {
        final request = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        final invite = CircleMutationReceipt.fromJson({
          ...bil06ReceiptJson(request, 'invite_accept'),
          'invite_id': bil06InviteId,
          'invite': null,
        });
        expect(invite.inviteId, bil06InviteId);
        expect(invite.invite, isNull);
        final media = CircleMutationReceipt.fromJson({
          ...bil06ReceiptJson(request, 'media_finish'),
          'media_id': bil06MediaId,
          'media': null,
        });
        expect(media.mediaId, bil06MediaId);
        expect(media.media, isNull);
      },
    );

    test('recipient action cannot be borrowed by a third user', () {
      final invite = bil06Invite();
      expect(invite.permits(CircleInviteAction.accept, bil06OwnerA), isTrue);
      expect(invite.permits(CircleInviteAction.accept, bil06OwnerC), isFalse);
      expect(invite.permits(CircleInviteAction.decline, bil06OwnerC), isFalse);
      expect(
        bil06Invite(
          status: CircleInviteStatus.expired,
        ).permits(CircleInviteAction.accept, bil06OwnerA),
        isFalse,
      );
    });

    test(
      'invitation names are optional verified strings, never copied from code',
      () {
        final json = bil06InviteJson()
          ..['inviter_name'] = 'Synthetic sender'
          ..['invitee_name'] = 'Synthetic recipient';
        final invite = CircleInvitation.fromJson(json);
        expect(invite.inviterName, 'Synthetic sender');
        expect(invite.inviteeName, 'Synthetic recipient');
        expect(invite.recipientCode, isNull);
        expect(
          () => CircleInvitation.fromJson({...json, 'invitee_name': 27}),
          throwsFormatException,
        );
      },
    );
  });
}
