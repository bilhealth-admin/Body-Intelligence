import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_conversation_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _peer = '22222222-2222-4222-8222-222222222222';
const _message = '33333333-3333-4333-8333-333333333333';

class _EnvelopeRepository extends CommunityRepository {
  _EnvelopeRepository(
    super.client, {
    required this.wireBody,
    this.mine = false,
  });
  final String wireBody;
  final bool mine;

  @override
  String get currentUserId => _owner;
  @override
  Stream<void> watchConversationChanges(String id) => const Stream.empty();
  @override
  Future<List<CommunityMessage>> loadMessages(String id) async => [
    CommunityMessage(
      id: _message,
      senderId: mine ? _owner : _peer,
      recipientId: mine ? _peer : _owner,
      body: wireBody,
      createdAt: DateTime.utc(2026, 11, 16, 16),
    ),
  ];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async => ids.length;
  @override
  Future<Set<String>> loadReadMessageIds(String peer, List<String> ids) async =>
      ids.toSet();
}

Widget _app(
  _EnvelopeRepository repository, {
  Brightness brightness = Brightness.light,
  String locale = 'en',
}) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(brightness: brightness),
  home: CommunityChatPage(
    userId: _peer,
    displayName: 'Synthetic peer',
    repository: repository,
  ),
);

BilConversationText _rendered(WidgetTester tester) =>
    tester.widget<BilConversationText>(
      find.byKey(const ValueKey('community-message-body-$_message')),
    );
SelectableText _selectable(WidgetTester tester) =>
    tester.widget<SelectableText>(
      find.byKey(const ValueKey('community-message-text-$_message')),
    );

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://dm-envelope-fixture.invalid',
      'synthetic-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() async => client.dispose());

  test(
    'compose and public parse retain the exact stored envelope contract',
    () {
      final wire = MessageBodyContract.compose(
        subject: '  Weekly\r\nplan  ',
        body: '  Original message 👩‍💻\nsecond line  ',
      );
      expect(
        wire,
        '[BIL-SUBJECT]Weekly plan\nOriginal message 👩‍💻\nsecond line',
      );
      expect(MessageBodyContract.parse(wire), (
        subject: 'Weekly plan',
        body: 'Original message 👩‍💻\nsecond line',
      ));
      const plain = '  Original legacy\n[BIL-SUBJECT]literal text 👩‍💻  ';
      expect(MessageBodyContract.parse(plain), (subject: '', body: plain));
    },
  );

  for (final mine in [true, false]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'conversation displays decoded ${mine ? 'outgoing' : 'incoming'} subject and body (${brightness.name})',
        (tester) async {
          const wire = '[BIL-SUBJECT]Weekly plan\nOriginal message 👩‍💻';
          const display = 'Weekly plan\nOriginal message 👩‍💻';
          final repo = _EnvelopeRepository(client, wireBody: wire, mine: mine);
          await tester.pumpWidget(_app(repo, brightness: brightness));
          await tester.pumpAndSettle();
          final rendered = _rendered(tester);
          final selectable = _selectable(tester);
          expect(rendered.text, display);
          expect(selectable.data, display);
          expect(selectable.enableInteractiveSelection, isTrue);
          expect(rendered.direction, TextDirection.ltr);
          expect(selectable.textDirection, rendered.direction);
          expect(selectable.style?.color, rendered.style.color);
          if (mine) expect(rendered.style.color, Colors.white);
          final arrival = tester.widget<BilConversationArrival>(
            find.ancestor(
              of: find.byKey(
                const ValueKey('community-message-body-$_message'),
              ),
              matching: find.byType(BilConversationArrival),
            ),
          );
          expect(arrival.text, display);
          expect(find.text(wire), findsNothing);
          expect(repo.wireBody, wire);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }

  testWidgets(
    'Arabic envelope determines direction after metadata is removed',
    (tester) async {
      const wire = '[BIL-SUBJECT]خطة\nهذه رسالة عربية خاصة';
      final repo = _EnvelopeRepository(client, wireBody: wire);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(_rendered(tester).text, 'خطة\nهذه رسالة عربية خاصة');
      expect(_rendered(tester).direction, TextDirection.rtl);
      expect(_selectable(tester).textDirection, TextDirection.rtl);
      expect(repo.wireBody, wire);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'legacy whitespace multiline emoji and literal marker stay intact',
    (tester) async {
      const wire = '  Legacy hello 👩‍💻\n[BIL-SUBJECT]literal text  ';
      final repo = _EnvelopeRepository(client, wireBody: wire);
      await tester.pumpWidget(_app(repo, locale: 'ar'));
      await tester.pumpAndSettle();
      expect(_rendered(tester).text, wire);
      expect(_selectable(tester).data, wire);
      expect(_rendered(tester).direction, TextDirection.ltr);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  final malformed = <String, String>{
    'missing envelope separator': '[BIL-SUBJECT]Hidden subject',
    'empty envelope body': '[BIL-SUBJECT]Hidden subject\n   ',
    'oversized subject': '[BIL-SUBJECT]${'s' * 121}\nHidden body',
    'control character': '[BIL-SUBJECT]Hidden\nPrivate\u0000body',
    'oversized stored text': 'x' * 2001,
  };
  for (final entry in malformed.entries) {
    test('public parser refuses ${entry.key}', () {
      expect(
        () => MessageBodyContract.parse(entry.value),
        throwsFormatException,
      );
    });
    testWidgets('chat safely hides ${entry.key} without raw metadata', (
      tester,
    ) async {
      final repo = _EnvelopeRepository(client, wireBody: entry.value);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      const placeholder = 'Messages could not be loaded safely.';
      expect(_rendered(tester).text, placeholder);
      expect(_selectable(tester).data, placeholder);
      expect(find.text(entry.value), findsNothing);
      expect(repo.wireBody, entry.value);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  for (final entry in const {
    'ar': 'تعذر تحميل الرسائل بأمان.',
    'fr': 'Impossible de charger les messages en toute sécurité.',
    'de': 'Nachrichten konnten nicht sicher geladen werden.',
  }.entries) {
    testWidgets('malformed placeholder reuses existing ${entry.key} copy', (
      tester,
    ) async {
      final repo = _EnvelopeRepository(
        client,
        wireBody: '[BIL-SUBJECT]private metadata without separator',
      );
      await tester.pumpWidget(_app(repo, locale: entry.key));
      await tester.pumpAndSettle();
      expect(_rendered(tester).text, entry.value);
      expect(_selectable(tester).data, entry.value);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
