import 'dart:io';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';

void main() {
  test('community entry welcome matches AI Coach 2.2 second minimum', () {
    final community = File(
      'lib/features/community/presentation/community_feed_tab.dart',
    ).readAsStringSync();
    final coach = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();

    const duration = 'Timer(const Duration(milliseconds: 2200)';
    expect(coach, contains(duration));
    expect(community, contains(duration));
    expect(community, contains('_entryWelcomeVisible'));
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'welcome remains reachable at 320x568 scale=$scale dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: CommunitySurface(
                child: Scaffold(
                  appBar: AppBar(
                    leading: const BackButton(),
                    title: const Text('BIL'),
                  ),
                  body: const CommunityWelcome(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            find.byKey(const Key('community-welcome-loading')),
            findsOneWidget,
          );
          expect(find.byType(BackButton), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(find.byType(SingleChildScrollView), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          final progress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(
            progress.value,
            isNull,
            reason: 'No invented completion percentage',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'inbox preserves badge and tap at 320px ${locale.languageCode} scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _LargeInboxRepository();
          final attention = CommunityAttentionController(
            () async => const CommunityAttention(
              unreadMessages: 125,
              unreadBySender: {_LargeInboxRepository.peer: 125},
            ),
          );
          attention.setOwner(_LargeInboxRepository.owner);
          await attention.refresh();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => CommunityMessagesPage(repository: repo),
              ),
              GoRoute(
                path: '/community/chat/:userId',
                builder: (_, state) => Scaffold(
                  body: Text('opened:${state.pathParameters['userId']}'),
                ),
              ),
            ],
          );
          addTearDown(attention.dispose);
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: CommunityAttentionScope(
                  controller: attention,
                  child: CommunitySurface(child: child!),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final tile = find.byKey(const ValueKey('community-inbox-message-1'));
          expect(tile, findsOneWidget);
          expect(
            find.descendant(of: tile, matching: find.text('99+')),
            findsOneWidget,
          );
          expect(
            attention.value.unreadMessages,
            125,
            reason: 'Opening the inbox never marks messages read',
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(
            find.text('opened:${_LargeInboxRepository.peer}'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

final class _LargeInboxRepository extends CommunityRepository {
  _LargeInboxRepository()
    : super(
        SupabaseClient(
          'https://inbox.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  static const owner = '11111111-1111-4111-8111-111111111111';
  static const peer = '22222222-2222-4222-8222-222222222222';
  @override
  String get currentUserId => owner;
  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async => [
    {
      'id': 'message-1',
      'sender_id': peer,
      'recipient_id': owner,
      'profile': {
        'display_name': 'اسم عضو طويل Long member name',
        'avatar_url': null,
      },
      'body':
          '[BIL-SUBJECT]عنوان طويل للمحادثة A long conversation subject\nHello مرحبًا هذه رسالة طويلة تختبر العرض والاتجاه دون فقدان المحتوى.',
      'created_at': '2026-09-29T08:20:00Z',
      'read_at': null,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async => [];
  @override
  Stream<void> watchInboxChanges() => const Stream.empty();
}
