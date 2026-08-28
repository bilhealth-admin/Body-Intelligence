import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'message subject is encoded inside body without inventing a schema column',
    () {
      final encoded = MessageBodyContract.compose(
        subject: 'Weekly plan',
        body: 'How are you?',
      );
      expect(encoded, '[BIL-SUBJECT]Weekly plan\nHow are you?');
      expect(MessageBodyContract.parse(encoded), (
        subject: 'Weekly plan',
        body: 'How are you?',
      ));
      expect(MessageBodyContract.parse('Legacy message'), (
        subject: '',
        body: 'Legacy message',
      ));
    },
  );

  test(
    'aggregate inbox and sent routes use bil_messages and profile lookup',
    () {
      final repository = File(
        'lib/features/community/data/community_repository.dart',
      ).readAsStringSync();
      final router = File('lib/app/router/app_router.dart').readAsStringSync();
      final settings = File(
        'lib/features/settings/settings_page.dart',
      ).readAsStringSync();

      expect(repository, contains(".from('bil_messages')"));
      expect(repository, contains('loadInboxMessages'));
      expect(repository, contains('loadSentMessages'));
      expect(repository, contains(".from('bil_public_profiles')"));
      expect(router, contains("path: '/community/messages'"));
      expect(router, contains("path: '/community/messages/new'"));
      // Keep this contract insensitive to harmless formatting and optional
      // row arguments while still proving that the Settings entry exists.
      expect(settings, contains("copy('Messages')"));
      expect(settings, contains("'/community/messages'"));
    },
  );

  test('messages copy has all five supported locales', () {
    final source = File(
      'lib/features/community/presentation/community_messages_page.dart',
    ).readAsStringSync();
    for (final locale in const ["'en'", "'ar'", "'fr'", "'es'", "'tr'"]) {
      expect(source, contains(locale));
    }
  });

  test('messages have truthful async and signed-out states', () {
    final source = File(
      'lib/features/community/presentation/community_messages_page.dart',
    ).readAsStringSync();
    expect(source, contains('_MessagesSignIn'));
    expect(source, contains('_MessagesLoadError'));
    expect(source, contains('onRefresh: onRetry'));
    expect(source, contains('Future<void> Function() onRetry'));
    expect(source, contains('PopScope('));
    expect(source, contains('canPop: !_sending'));
  });

  test('inbox enables RLS-protected realtime refresh', () {
    final source = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/community/presentation/community_messages_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/202608240001_community_connection_identity_and_message_realtime.sql',
    ).readAsStringSync();

    expect(source, contains('watchInboxChanges'));
    expect(source, contains(".eq('recipient_id', _user.id)"));
    expect(page, contains('AlwaysScrollableScrollPhysics'));
    expect(page, contains('_inboxChanges?.cancel()'));
    expect(
      migration,
      contains(
        'alter publication supabase_realtime add table public.bil_messages',
      ),
    );
  });

  test('open chat watches both RLS-protected conversation directions', () {
    final source = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();
    final chat = File(
      'lib/features/community/presentation/community_chat_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('watchConversationChanges(');
    final methodEnd = source.indexOf('loadInboxMessages()', methodStart);
    final method = source.substring(methodStart, methodEnd);

    expect(method, contains("changesWhere('sender_id')"));
    expect(method, contains("changesWhere('recipient_id')"));
    expect(method, contains(".from('bil_messages')"));
    expect(method, contains('subscription.cancel()'));
    expect(chat, contains('watchConversationChanges(widget.userId)'));
    expect(chat, contains('_conversationChanges?.cancel()'));
  });

  test('messages surface has direct copy in all extended locales', () {
    const keys = {
      'Messages',
      'Inbox',
      'Sent',
      'No messages',
      'No sent messages',
      'Send a message',
      'New message',
      'Message could not be sent.',
      'Choose a recipient and enter a message.',
      'Sign in to view and send messages.',
    };
    expect(RuntimeCopy.supported, hasLength(25));
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        expect(
          ExtendedRuntimeCopy.values[key]?.containsKey(locale),
          isTrue,
          reason: 'missing direct $locale/$key',
        );
      }
    }
  });
}
