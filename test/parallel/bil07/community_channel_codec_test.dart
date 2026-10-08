import 'package:body_intelligence_log/features/community/channels/data/community_channel_codec.dart';
import 'package:body_intelligence_log/features/community/channels/domain/community_channel_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_text_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const codecOwner = '11111111-1111-4111-8111-111111111111';
const codecPeer = '22222222-2222-4222-8222-222222222222';
const codecChannel = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const codecMessage = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

Map<String, Object?> codecEnvelope({bool channel = false}) => {
  'contract_version': 1,
  'owner_id': codecOwner,
  'server_time': '2026-10-07T12:00:00Z',
  if (channel) 'channel_id': codecChannel,
};

Map<String, Object?> codecMessageRow({String? author}) => {
  'id': codecMessage,
  'channel_id': codecChannel,
  'sequence': 1,
  'author_id': author ?? codecPeer,
  'author_display_name': null,
  'text': 'Synthetic channel message',
  'client_message_id': null,
  'created_at': '2026-10-07T11:59:00Z',
  'is_read': false,
};

Map<String, Object?> codecChannelRow() => {
  'id': codecChannel,
  'slug': 'general',
  'title': 'Fixture General',
  'description': 'Declared synthetic fixture',
  'visibility': 'public',
  'enabled': true,
  'membership': 'active',
  'can_read': true,
  'can_send': true,
  'unread_count': 1,
  'latest_sequence': 1,
  'max_text_code_points': 2000,
};

void main() {
  test('channel Unicode limit is explicit and independent from post1200', () {
    final exact = List.filled(2000, '😀').join();
    expect(exact.length, 4000);
    expect(
      () => CommunityChannelText.validate(exact, maxCodePoints: 2000),
      returnsNormally,
    );
    expect(
      () => CommunityChannelText.validate('$exact😀', maxCodePoints: 2000),
      throwsA(isA<ChannelFailure>()),
    );
    expect(
      () => CommunityChannelText.validate('hello', maxCodePoints: 1200),
      throwsA(isA<ChannelFailure>()),
    );
  });

  test(
    'exact payload allows whitespace around content and never truncates',
    () {
      const text = ' \tText\n\r ';
      expect(
        () => CommunityChannelText.validate(text, maxCodePoints: 2000),
        returnsNormally,
      );
      expect(text, ' \tText\n\r ');
      for (final text in [
        '',
        ' \t\n\r',
        '\u00a0\u1680\u2000\u2007\u202f\u3000\ufeff',
        'hidden\u0000control',
        'control\u000b',
        'control\u007f',
      ]) {
        expect(
          () => CommunityChannelText.validate(text, maxCodePoints: 2000),
          throwsA(isA<ChannelFailure>()),
        );
      }
    },
  );

  test('channel sends reuse the existing contact-exchange policy', () {
    for (final text in [
      'Contact me at name@example.com',
      'See https://example.com',
      'راسلني على واتساب',
      '@synthetic_handle',
    ]) {
      expect(
        () => CommunityChannelText.validate(text, maxCodePoints: 2000),
        throwsA(isA<CommunityTextPolicyException>()),
      );
    }
  });

  test(
    'unsupported capability version is unavailable, never an empty success',
    () {
      expect(
        () => CommunityChannelCodec.capabilities({
          ...codecEnvelope(),
          'contract_version': 2,
        }, codecOwner),
        throwsA(isA<ChannelFailure>()),
      );
      expect(
        () => CommunityChannelCodec.capabilities(null, codecOwner),
        throwsFormatException,
      );
    },
  );

  test('response owner and channel must match the exact visit', () {
    expect(
      () => CommunityChannelCodec.envelope(codecEnvelope(), ownerId: codecPeer),
      throwsFormatException,
    );
    expect(
      () => CommunityChannelCodec.envelope(
        codecEnvelope(channel: true),
        ownerId: codecOwner,
        channelId: codecMessage,
      ),
      throwsFormatException,
    );
  });

  test(
    'directory rejects members-only access for a nonmember and banned access',
    () {
      for (final changes in [
        {'visibility': 'members', 'membership': 'none', 'can_send': false},
        {'membership': 'banned'},
        {'enabled': false},
        {'can_read': false, 'can_send': true},
      ]) {
        expect(
          () => CommunityChannelCodec.directory({
            ...codecEnvelope(),
            'channels': [
              {...codecChannelRow(), ...changes},
            ],
            'next_after_id': null,
          }, codecOwner),
          throwsFormatException,
        );
      }
    },
  );

  test('duplicate directory IDs and invalid next cursor are rejected', () {
    expect(
      () => CommunityChannelCodec.directory({
        ...codecEnvelope(),
        'channels': [codecChannelRow(), codecChannelRow()],
      }, codecOwner),
      throwsFormatException,
    );
    expect(
      () => CommunityChannelCodec.directory({
        ...codecEnvelope(),
        'channels': [codecChannelRow()],
        'next_after_id': codecMessage,
      }, codecOwner),
      throwsFormatException,
    );
  });

  test('nullable profile name and peer retry key remain null', () {
    final row = CommunityChannelCodec.message(
      codecMessageRow(),
      codecOwner,
      codecChannel,
    );
    expect(row.authorDisplayName, isNull);
    expect(row.clientMessageId, isNull);
    expect(row.isRead, isFalse);
  });

  test(
    'message envelope rejects forbidden control and whitespace-only text',
    () {
      for (final text in [
        '\u2007\ufeff',
        'control\u0000',
        List.filled(2001, 'x').join(),
      ]) {
        expect(
          () => CommunityChannelCodec.message(
            {...codecMessageRow(), 'text': text},
            codecOwner,
            codecChannel,
          ),
          throwsA(isA<ChannelFailure>()),
        );
      }
    },
  );

  test(
    'sequence ordering, paging envelope and cursor are validated together',
    () {
      final envelope = {
        ...codecEnvelope(channel: true),
        'messages': [codecMessageRow()],
        'has_more': false,
        'next_before_sequence': 1,
        'next_after_sequence': 1,
      };
      expect(
        CommunityChannelCodec.messages(
          envelope,
          codecOwner,
          codecChannel,
        ).messages,
        hasLength(1),
      );
      expect(
        () => CommunityChannelCodec.messages(
          envelope,
          codecOwner,
          codecChannel,
          afterSequence: 1,
        ),
        throwsFormatException,
      );
      expect(
        () => CommunityChannelCodec.messages(
          {...envelope, 'next_after_sequence': 2},
          codecOwner,
          codecChannel,
        ),
        throwsFormatException,
      );
      expect(
        () => CommunityChannelCodec.messages(
          {
            ...envelope,
            'messages': [],
            'next_before_sequence': null,
            'next_after_sequence': null,
            'has_more': true,
          },
          codecOwner,
          codecChannel,
        ),
        throwsFormatException,
      );
    },
  );

  test('partial authoritative receipt confirms only exact requested IDs', () {
    final response = {
      ...codecEnvelope(channel: true),
      'acknowledged_message_ids': [codecMessage],
      'unread_count': 4,
    };
    final receipt = CommunityChannelCodec.readback(
      response,
      codecOwner,
      codecChannel,
      {codecMessage, codecPeer},
    );
    expect(receipt.confirmedIds, {codecMessage});
    expect(receipt.unreadCount, 4);
    expect(
      () => CommunityChannelCodec.readback(
        {
          ...response,
          'acknowledged_message_ids': [codecPeer],
        },
        codecOwner,
        codecChannel,
        {codecMessage},
      ),
      throwsFormatException,
    );
  });

  test('unknown, negative and fractional counts are not coerced to zero', () {
    for (final value in [null, -1, 1.5, '0']) {
      expect(
        () => CommunityChannelCodec.readback(
          {
            ...codecEnvelope(channel: true),
            'acknowledged_message_ids': [],
            'unread_count': value,
          },
          codecOwner,
          codecChannel,
          {},
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'presence zero is authoritative only within server freshness interval',
    () {
      final payload = {
        ...codecEnvelope(channel: true),
        'online_count': 0,
        'expires_at': null,
        'ttl_seconds': 90,
        'valid_until': '2026-10-07T12:00:30Z',
      };
      final presence = CommunityChannelCodec.presence(
        payload,
        codecOwner,
        codecChannel,
      );
      expect(presence.onlineCount, 0);
      expect(presence.ownExpiresAt, isNull);
      for (final until in [
        '2026-10-07T12:00:31Z',
        '2026-10-07T12:00:00Z',
        '2026-10-07T12:00:30',
      ]) {
        expect(
          () => CommunityChannelCodec.presence(
            {...payload, 'valid_until': until},
            codecOwner,
            codecChannel,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
