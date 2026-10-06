import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../visual_closure/visual_evidence_font.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _peer = '33333333-3333-4333-8333-333333333333';

class _CaptureRepository extends CommunityRepository {
  _CaptureRepository(super.client, this.arabic);
  final bool arabic;
  @override
  String get currentUserId => _owner;
  @override
  Stream<void> watchConversationChanges(String peer) => const Stream.empty();
  @override
  Stream<void> watchInboxChanges() => const Stream.empty();
  @override
  Future<List<CommunityMessage>> loadMessages(String peer) async => [
    CommunityMessage(
      id: '55555555-5555-4555-8555-555555555555',
      senderId: _peer,
      recipientId: _owner,
      body: arabic ? 'كيف كان التمرين اليوم؟' : 'How was your workout today?',
      createdAt: DateTime.utc(2026, 10, 6, 10, 24),
    ),
    CommunityMessage(
      id: '66666666-6666-4666-8666-666666666666',
      senderId: _owner,
      recipientId: _peer,
      body: arabic
          ? 'مشي خفيف لمدة عشرين دقيقة. سأكرر ذلك غدًا.'
          : 'A gentle twenty-minute walk. I will do it again tomorrow.',
      createdAt: DateTime.utc(2026, 10, 6, 10, 26),
      readAt: DateTime.utc(2026, 10, 6, 10, 27),
    ),
  ];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async => ids.length;
  @override
  Future<Set<String>> loadReadMessageIds(String peer, List<String> ids) async =>
      ids.toSet();
  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async => [
    {
      'id': '55555555-5555-4555-8555-555555555555',
      'sender_id': _peer,
      'recipient_id': _owner,
      'body': arabic ? 'كيف كان التمرين اليوم؟' : 'How was your workout today?',
      'created_at': '2026-10-06T10:24:00Z',
      'read_at': null,
      'profile': {'display_name': arabic ? 'عضو تجريبي' : 'Sample member'},
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async => [];
  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async => [
    {'user_id': _peer, 'display_name': arabic ? 'عضو تجريبي' : 'Sample member'},
  ];
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.fromServerSnapshot({
    'server_now': '2026-10-06T12:00:00Z',
    'status': 'accepted',
    'version': 'fixture-policy',
    'document_url': 'https://policy.example.invalid/community',
    'effective_at': '2026-10-01T00:00:00Z',
    'accepted': true,
    'accepted_at': '2026-10-02T00:00:00Z',
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['BIL_CHAT_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  late SupabaseClient client;
  setUp(
    () => client = SupabaseClient(
      'https://capture.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  tearDown(() => client.dispose());
  for (final language in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final surface in ['chat', 'inbox', 'new']) {
        testWidgets('actual private $surface $language ${scale}x QA capture', (
          tester,
        ) async {
          tester.view.physicalSize = scale == 1
              ? const Size(390, 844)
              : const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _CaptureRepository(client, language == 'ar');
          final key = GlobalKey();
          final page = switch (surface) {
            'chat' => CommunityChatPage(
              userId: _peer,
              displayName: language == 'ar' ? 'عضو تجريبي' : 'Sample member',
              repository: repo,
            ),
            'inbox' => CommunityMessagesPage(repository: repo),
            _ => NewCommunityMessagePage(repository: repo),
          };
          try {
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: visualEvidenceTheme(
                  BilFlagshipTheme.light(isArabic: language == 'ar'),
                  fontFamily: language == 'ar'
                      ? 'NotoArabicEvidence'
                      : 'RobotoEvidence',
                ),
                home: page,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: key,
                    child: visualEvidenceTextSurface(
                      Stack(
                        children: [
                          Positioned.fill(child: child!),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: Colors.black87,
                                child: Text(
                                  'QA FIXTURE · Synthetic private messages',
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9 / scale,
                                    fontFamily: 'RobotoEvidence',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (surface == 'new') {
              await tester.tap(
                find.text(language == 'ar' ? 'عضو تجريبي' : 'Sample member'),
              );
              await tester.pumpAndSettle();
              final subject = find.byKey(
                const Key('community-message-subject'),
              );
              final body = find.byKey(const Key('community-message-body'));
              await tester.ensureVisible(subject);
              await tester.enterText(
                subject,
                language == 'ar' ? 'خطة هذا الأسبوع' : 'This week’s plan',
              );
              await tester.ensureVisible(body);
              await tester.enterText(
                body,
                language == 'ar'
                    ? 'هل يناسبك المشي صباحًا؟'
                    : 'Would a morning walk work for you?',
              );
              tester.testTextInput.hide();
              await tester.pumpAndSettle();
            }
            await _capture(
              tester,
              key,
              'private-$surface-$language-${scale.toInt()}x',
            );
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('community-safe-return')),
              findsOneWidget,
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        });
      }
    }
  }
}
