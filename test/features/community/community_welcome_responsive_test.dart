import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';

import 'community_entry_flow_test.dart' as entry;
import 'community_preload_probe.dart';

void main() {
  testWidgets(
    'community full viewport welcome releases at 2.2 seconds with one authorized prewarm',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Supabase owns a real JSON-worker isolate; create it outside the widget fake clock.
      final client = (await tester.runAsync(
        () async => entry.createEntryTestClient(),
      ))!;
      final repository = entry.EntryRepositoryFixture(client)
        ..profiles[entry.ownerA] = entry.profile(entry.ownerA);
      var prepared = 0;
      final fixture = entry.EntryWidgetFixture(repository)
        ..welcome = true
        ..destination = CommunityPreloadProbe(onInit: () => prepared++);
      try {
        final entryClockStart = tester.binding.clock.now();
        await tester.pumpWidget(fixture.app(scale: 2));
        await tester.pump();
        // The route/profile/code continuation can cross the real SDK runner
        // zone. Flush that queue and render readiness without advancing the
        // widget clock: the assertions below still test 2199ms + 1ms exactly
        // from the original gate mount, not from a restarted welcome timer.
        for (var attempt = 0; attempt < 20 && prepared == 0; attempt++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          });
          await tester.pump();
        }
        expect(
          tester.binding.clock.now(),
          entryClockStart,
          reason: 'Authorization readiness must not consume the welcome hold.',
        );
        expect(repository.reads, 1);
        expect(repository.codeReads, 1);
        expect(repository.writes, isEmpty);
        expect(find.byType(CommunityWelcome), findsOneWidget);
        expect(
          tester.getRect(find.byType(CommunityWelcome)),
          const Rect.fromLTWH(0, 0, 320, 568),
        );
        expect(
          prepared,
          1,
          reason:
              'Authorized destination must prewarm once; '
              'profile reads=${repository.reads}, code reads=${repository.codeReads}.',
        );
        expect(find.text('TEST prepared feed'), findsNothing);
        expect(
          find.byKey(const Key('community-safe-return')).hitTestable(),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 2199));
        expect(find.byType(CommunityWelcome), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.byType(CommunityWelcome), findsNothing);
        expect(find.text('TEST prepared feed'), findsOneWidget);
        expect(
          prepared,
          1,
          reason: 'no extra splash or remount after the timed welcome',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.router?.dispose();
        await tester.runAsync(client.dispose);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
  testWidgets(
    'community full viewport welcome keeps a real return action and cancels on exit',
    (tester) async {
      // Supabase owns a real JSON-worker isolate; create it outside the widget fake clock.
      final client = (await tester.runAsync(
        () async => entry.createEntryTestClient(),
      ))!;
      final repository = entry.EntryRepositoryFixture(client)
        ..profiles[entry.ownerA] = entry.profile(entry.ownerA);
      final fixture = entry.EntryWidgetFixture(repository)..welcome = true;
      try {
        await tester.pumpWidget(fixture.app());
        await tester.pump();
        await tester.tap(find.byKey(const Key('community-safe-return')));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2200));
        expect(find.byType(CommunityWelcome), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.router?.dispose();
        await tester.runAsync(client.dispose);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
  testWidgets(
    'community owner change cancels welcome and retains account authorization gate',
    (tester) async {
      // Keep both SDK workers in the real runner zone, as the existing entry tests do.
      final clientA = (await tester.runAsync(
        () async => entry.createEntryTestClient(),
      ))!;
      final clientB = (await tester.runAsync(
        () async => entry.createEntryTestClient(),
      ))!;
      final repositoryA = entry.EntryRepositoryFixture(clientA)
        ..profiles[entry.ownerA] = entry.profile(entry.ownerA);
      final repositoryB = entry.EntryRepositoryFixture(
        clientB,
        owner: entry.ownerB,
      );
      final fixture = entry.EntryWidgetFixture(repositoryA)..welcome = true;
      try {
        await tester.pumpWidget(fixture.app());
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CommunityWelcome), findsOneWidget);
        fixture.update(() => fixture.repository = repositoryB);
        await tester.pump();
        expect(find.byType(CommunityWelcome), findsNothing);
        expect(
          find.textContaining('Member destination'),
          findsNothing,
          reason:
              'B has no saved profile and code; cancellation never authorizes member content',
        );
        expect(repositoryB.writes, isEmpty);
        await tester.pump(const Duration(milliseconds: 2200));
        expect(find.byType(CommunityWelcome), findsNothing);
        expect(find.textContaining('Member destination'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.router?.dispose();
        await tester.runAsync(() async {
          await clientA.dispose();
          await clientB.dispose();
        });
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

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
          expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
          final progress = tester.widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          );
          expect(
            progress.animating,
            isFalse,
            reason:
                'reduced motion shows a static segmented status, not a made-up percentage',
          );
          expect(progress.radius, 12);
          expect(find.byType(LinearProgressIndicator), findsNothing);
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
