import '../support/bil_waiting_indicators.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_sapphire.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Completer<void>? sendGate;
  int sendCalls = 0;
  final sentBodies = <String>[];
  final sentRecipients = <String>[];
  final requestIds = <String>[];
  final delivered = <CommunityMessage>[];
  final readIds = <String>{};
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
    ...delivered,
  ];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async {
    readIds.addAll(ids);
    return ids.length;
  }

  @override
  Future<void> sendMessageOperation(
    String recipientId,
    String body, {
    required String requestId,
  }) async {
    sendCalls++;
    sentRecipients.add(recipientId);
    sentBodies.add(body);
    requestIds.add(requestId);
    await sendGate?.future;
    delivered.add(
      CommunityMessage(
        id: requestId,
        senderId: _owner,
        recipientId: recipientId,
        body: body,
        createdAt: DateTime.utc(2026, 10, 6, 10, 30),
      ),
    );
  }

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
      'read_at': readIds.contains('55555555-5555-4555-8555-555555555555')
          ? '2026-10-06T10:28:00Z'
          : null,
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
  _registerAdditionalPrivateCaptures(() => client);
  _registerPrivateMessageActions(() => client);
  _registerPrivateHeaderBounds(() => client);
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

/// Production routes and widgets with synthetic local message receipts only.
/// This fixture does not prove a published backend, phone or store purchase.
Future<GoRouter> _mountPrivateScene(
  WidgetTester tester,
  _CaptureRepository repo,
  GlobalKey boundary,
  String surface,
  String language, {
  bool dark = false,
  double scale = 2,
  bool contrast = false,
  bool keyboard = false,
}) async {
  final peerName = language == 'ar' ? 'عضو تجريبي' : 'Sample member';
  final initial = switch (surface) {
    'chat' => '/community/chat/$_peer',
    'inbox' => '/community/messages',
    _ => '/community/messages/new',
  };
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('QA return')),
      ),
      GoRoute(
        path: '/community/messages',
        builder: (_, _) =>
            CommunitySurface(child: CommunityMessagesPage(repository: repo)),
      ),
      GoRoute(
        path: '/community/messages/new',
        builder: (_, _) =>
            CommunitySurface(child: NewCommunityMessagePage(repository: repo)),
      ),
      GoRoute(
        path: '/community/chat/:id',
        builder: (_, state) => CommunitySurface(
          child: CommunityChatPage(
            userId: state.pathParameters['id']!,
            displayName: peerName,
            repository: repo,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = scale == 1
      ? const Size(390, 844)
      : const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final baseTheme = dark
      ? BilFlagshipTheme.dark(isArabic: language == 'ar')
      : BilFlagshipTheme.light(isArabic: language == 'ar');
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(
        baseTheme,
        fontFamily: language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      builder: (context, child) => _privateTouchScrollDiagnostics(
        enabled: surface == 'new' && language == 'ar' && contrast && keyboard,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            highContrast: contrast,
            disableAnimations: contrast,
            accessibleNavigation: contrast,
            viewInsets: keyboard
                ? const EdgeInsets.only(bottom: 240)
                : EdgeInsets.zero,
          ),
          child: RepaintBoundary(
            key: boundary,
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
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Widget _privateTouchScrollDiagnostics({
  required bool enabled,
  required Widget child,
}) {
  if (!enabled) return child;
  void pointer(String phase, PointerEvent event) {
    debugPrint(
      'PRIVATE_SCROLL_POINTER ${jsonEncode({'phase': phase, 'x': event.position.dx, 'y': event.position.dy, 'dx': event.delta.dx, 'dy': event.delta.dy, 'timeMs': event.timeStamp.inMilliseconds, 'focus': FocusManager.instance.primaryFocus?.hasFocus ?? false})}',
    );
  }

  return NotificationListener<ScrollNotification>(
    onNotification: (notice) {
      final update = notice is ScrollUpdateNotification ? notice : null;
      final start = notice is ScrollStartNotification ? notice : null;
      final end = notice is ScrollEndNotification ? notice : null;
      debugPrint(
        'PRIVATE_SCROLL_NOTIFICATION ${jsonEncode({'kind': notice.runtimeType.toString(), 'depth': notice.depth, 'axis': notice.metrics.axisDirection.name, 'pixels': notice.metrics.pixels, 'min': notice.metrics.minScrollExtent, 'max': notice.metrics.maxScrollExtent, 'viewport': notice.metrics.viewportDimension, 'scrollDelta': update?.scrollDelta, 'dragPrimaryDelta': update?.dragDetails?.primaryDelta, 'dragDy': update?.dragDetails?.delta.dy, 'startY': start?.dragDetails?.globalPosition.dy, 'endVelocityDy': end?.dragDetails?.velocity.pixelsPerSecond.dy, 'focus': FocusManager.instance.primaryFocus?.hasFocus ?? false})}',
      );
      return false;
    },
    child: Listener(
      onPointerDown: (event) => pointer('down', event),
      onPointerMove: (event) => pointer('move', event),
      onPointerUp: (event) => pointer('up', event),
      child: child,
    ),
  );
}

Future<void> _fillPrivateDraft(WidgetTester tester, String language) async {
  await tester.tap(
    find.text(language == 'ar' ? 'عضو تجريبي' : 'Sample member'),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('community-message-recipient-clear')),
    findsOneWidget,
    reason: 'The actual recipient tap must select the peer before drafting.',
  );
  final subject = find.byKey(const Key('community-message-subject'));
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
        ? 'هل يناسبك المشي صباحًا؟ هذه رسالة اختيارية بين الأصدقاء.'
        : 'Would a morning walk work for you? This is an optional message between friends.',
  );
  await tester.pumpAndSettle();
}

Map<String, Object?> _privateFocusLayoutState(WidgetTester tester) {
  bool focused(String key) {
    final editable = find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(EditableText),
    );
    return editable.evaluate().isNotEmpty &&
        tester.widget<EditableText>(editable.first).focusNode.hasFocus;
  }

  return {
    'primaryFocusType': FocusManager.instance.primaryFocus.runtimeType
        .toString(),
    'bodyFocused': focused('community-message-body'),
    'subjectFocused': focused('community-message-subject'),
    'recipientFocused': focused('community-message-recipient-search'),
    'policyLoadingBuilt': find
        .byKey(const Key('community-policy-notice-loading'))
        .evaluate()
        .length,
    'policyErrorBuilt': find
        .byKey(const Key('community-policy-notice-error'))
        .evaluate()
        .length,
    'selectedRecipientBuilt': find
        .byKey(const Key('community-message-recipient-clear'))
        .evaluate()
        .length,
  };
}

Future<void> _scrollPrivateDraftTo(
  WidgetTester tester,
  Finder target,
  double delta, {
  required String targetName,
  GlobalKey? diagnosticBoundary,
}) async {
  final outerScroll = find
      .descendant(
        of: find.byKey(const Key('community-new-message-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  // Drag the list's clear 16px card margin, not the center occupied by a
  // multiline TextField that has its own scrolling/selection recognizers.
  if (diagnosticBoundary != null) {
    await _diagnosePrivateScroll(
      tester,
      diagnosticBoundary,
      outerScroll,
      target,
      targetName,
      'before',
    );
  }
  for (var attempt = 0; attempt < 30; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final viewport = tester.getRect(outerScroll);
    final beforeScroll = tester
        .state<ScrollableState>(outerScroll)
        .position
        .pixels;
    await tester.dragFrom(
      Offset(viewport.left + 6, viewport.center.dy),
      Offset(0, -delta),
    );
    if (diagnosticBoundary != null && attempt < 3) {
      final position = tester.state<ScrollableState>(outerScroll).position;
      debugPrint(
        'PRIVATE_SCROLL_AFTER_INPUT ${jsonEncode({'attempt': attempt + 1, 'requestedFingerDeltaDy': -delta, 'pixels': position.pixels, 'direction': position.userScrollDirection.name, 'focus': FocusManager.instance.primaryFocus?.hasFocus ?? false, ..._privateFocusLayoutState(tester)})}',
      );
    }
    if (diagnosticBoundary != null && attempt < 3) {
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
        debugPrint(
          'PRIVATE_SCROLL_FRAME ${jsonEncode({'attempt': attempt + 1, 'frame': frame + 1, 'pixels': tester.state<ScrollableState>(outerScroll).position.pixels, ..._privateFocusLayoutState(tester)})}',
        );
      }
    }
    await tester.pumpAndSettle();
    final afterScroll = tester
        .state<ScrollableState>(outerScroll)
        .position
        .pixels;
    expect(
      afterScroll,
      delta < 0
          ? lessThanOrEqualTo(beforeScroll)
          : greaterThanOrEqualTo(beforeScroll),
      reason:
          'A settled form must preserve the actual scroll toward the recipient action.',
    );
    if (diagnosticBoundary != null && [0, 2, 29].contains(attempt)) {
      await _diagnosePrivateScroll(
        tester,
        diagnosticBoundary,
        outerScroll,
        target,
        targetName,
        'after-${attempt + 1}',
      );
    }
  }
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: 'A real list-edge drag must reach the requested draft action.',
  );
}

Future<void> _diagnosePrivateScroll(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Finder outerScroll,
  Finder target,
  String targetName,
  String stage,
) async {
  Map<String, double>? rectOf(Finder finder) {
    if (finder.evaluate().isEmpty) return null;
    final rect = tester.getRect(finder.first);
    return {
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
    };
  }

  final state = tester.state<ScrollableState>(outerScroll);
  final position = state.position;
  final viewport = tester.getRect(outerScroll);
  final point = Offset(viewport.left + 6, viewport.center.dy);
  final details = <String, Object?>{
    'stage': stage,
    'target': targetName,
    ..._privateFocusLayoutState(tester),
    'axis': state.widget.axisDirection.name,
    'pixels': position.pixels,
    'min': position.minScrollExtent,
    'max': position.maxScrollExtent,
    'viewportDimension': position.viewportDimension,
    'list': rectOf(outerScroll),
    'header': rectOf(find.byType(AppBar)),
    'targetRect': rectOf(target),
    'body': rectOf(find.byKey(const Key('community-message-body'))),
    'subject': rectOf(find.byKey(const Key('community-message-subject'))),
    'targetBuilt': target.evaluate().length,
    'targetHit': target.hitTestable().evaluate().length,
    'touch': {'x': point.dx, 'y': point.dy},
    'hitPath': tester
        .hitTestOnBinding(point)
        .path
        .map((entry) => entry.target.runtimeType.toString())
        .toList(),
  };
  debugPrint('PRIVATE_SCROLL_DIAGNOSTIC ${jsonEncode(details)}');
  const output =
      'build/stage1-closure/visible-validation-20261013/private-message-scroll-diagnostics39';
  final renderBoundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    await Directory(output).create(recursive: true);
    await File(
      '$output/$targetName-$stage.json',
    ).writeAsString(jsonEncode(details));
    final image = await renderBoundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$output/$targetName-$stage.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _unmountPrivateScene(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void _expectSendFinish(WidgetTester tester, String language) {
  final send = find.byKey(const Key('community-chat-send'));
  expect(send.hitTestable(), findsOneWidget);
  final size = tester.getSize(send);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
  final icon = tester.widget<Icon>(
    find.descendant(
      of: send,
      matching: find.byIcon(Icons.arrow_upward_rounded),
    ),
  );
  expect(icon.color, CommunitySapphire.navy);
  final finish = tester.widget<DecoratedBox>(
    find.byKey(const Key('community-chat-send-finish')),
  );
  final gradient =
      (finish.decoration as BoxDecoration).gradient! as LinearGradient;
  for (final stop in gradient.colors) {
    expect(stop.a, 1);
    final contrast =
        (stop.computeLuminance() + .05) /
        (CommunitySapphire.navy.computeLuminance() + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
  }
  expect(
    tester.widget<IconButton>(send).tooltip,
    language == 'ar' ? 'إرسال الرسالة' : 'Send message',
  );
}

void _registerAdditionalPrivateCaptures(SupabaseClient Function() client) {
  for (final language in ['en', 'ar']) {
    for (final surface in ['chat', 'inbox', 'new']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'actual private $surface $language ${scale}x dark QA capture',
          (tester) async {
            final repo = _CaptureRepository(client(), language == 'ar');
            final boundary = GlobalKey();
            try {
              await _mountPrivateScene(
                tester,
                repo,
                boundary,
                surface,
                language,
                dark: true,
                scale: scale,
              );
              if (surface == 'new') {
                await _fillPrivateDraft(tester, language);
              }
              await _capture(
                tester,
                boundary,
                'private-$surface-$language-${scale.toInt()}x-dark',
              );
              expect(tester.takeException(), isNull);
              expect(
                find.byKey(const Key('community-safe-return')).hitTestable(),
                findsOneWidget,
              );
              if (surface == 'chat') {
                _expectSendFinish(tester, language);
              }
              expect(repo.sendCalls, 0);
            } finally {
              await _unmountPrivateScene(tester);
            }
          },
        );
      }
      for (final dark in [false, true]) {
        testWidgets(
          'actual private $surface $language 320 2x keyboard contrast reduced-motion dark=$dark',
          (tester) async {
            final repo = _CaptureRepository(client(), language == 'ar');
            final boundary = GlobalKey();
            final semantics = tester.ensureSemantics();
            try {
              await _mountPrivateScene(
                tester,
                repo,
                boundary,
                surface,
                language,
                dark: dark,
                contrast: true,
                keyboard: true,
              );
              if (surface == 'new') {
                await _fillPrivateDraft(tester, language);
              }
              if (surface == 'chat') {
                await tester.enterText(
                  find.byKey(const Key('community-message-composer')),
                  language == 'ar'
                      ? 'مسودة عربية طويلة واضحة مع لوحة المفاتيح'
                      : 'A readable draft with the keyboard open',
                );
                await tester.pumpAndSettle();
                _expectSendFinish(tester, language);
                expect(
                  find.descendant(
                    of: find.byKey(
                      const Key('community-chat-composer-surface'),
                    ),
                    matching: find.byType(BackdropFilter),
                  ),
                  findsNothing,
                );
                final buttonSemantics = tester.getSemantics(
                  find.byKey(const Key('community-chat-send')),
                );
                // Material 3 exposes IconButton's accessible name through
                // the actual SemanticsData tooltip, rather than its label.
                final buttonData = buttonSemantics.getSemanticsData();
                expect(
                  buttonData.tooltip,
                  language == 'ar' ? 'إرسال الرسالة' : 'Send message',
                );
                expect(buttonData.flagsCollection.isButton, isTrue);
                expect(
                  buttonData.flagsCollection.isEnabled,
                  ui.Tristate.isTrue,
                );
                expect(buttonData.hasAction(ui.SemanticsAction.tap), isTrue);
              }
              await _capture(
                tester,
                boundary,
                'private-$surface-$language-2x-${dark ? 'dark' : 'light'}-contrast-keyboard',
              );
              expect(tester.takeException(), isNull);
              expect(
                find.byKey(const Key('community-safe-return')).hitTestable(),
                findsOneWidget,
              );
              expect(repo.sendCalls, 0);
            } finally {
              semantics.dispose();
              await _unmountPrivateScene(tester);
            }
          },
        );
      }
    }
  }
}

void _registerPrivateMessageActions(SupabaseClient Function() client) {
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'actual pearl chat long invalid draft keeps actions reachable $language dark=$dark',
        (tester) async {
          final repo = _CaptureRepository(client(), language == 'ar');
          final boundary = GlobalKey();
          try {
            await _mountPrivateScene(
              tester,
              repo,
              boundary,
              'chat',
              language,
              dark: dark,
              contrast: true,
              keyboard: true,
            );
            final composer = find.byKey(
              const Key('community-message-composer'),
            );
            final body = List.filled(
              500,
              language == 'ar' ? 'كلمة ' : 'word ',
            ).join();
            await tester.enterText(composer, body);
            await tester.pumpAndSettle();
            _expectSendFinish(tester, language);
            expect(find.text('${body.runes.length}/2000'), findsOneWidget);
            await tester.tap(find.byKey(const Key('community-chat-send')));
            await tester.pumpAndSettle();
            expect(repo.sendCalls, 0);
            expect(tester.widget<TextField>(composer).controller!.text, body);
            expect(tester.takeException(), isNull);
          } finally {
            await _unmountPrivateScene(tester);
          }
        },
      );

      testWidgets(
        'actual pearl chat emoji send and receipt $language dark=$dark',
        (tester) async {
          final repo = _CaptureRepository(client(), language == 'ar');
          final boundary = GlobalKey();
          try {
            await _mountPrivateScene(
              tester,
              repo,
              boundary,
              'chat',
              language,
              dark: dark,
              keyboard: true,
            );
            _expectSendFinish(tester, language);
            final composer = find.byKey(
              const Key('community-message-composer'),
            );
            await tester.enterText(
              composer,
              language == 'ar' ? 'مسودة ' : 'Draft ',
            );
            final emoji = find.byKey(const Key('community-chat-emoji'));
            expect(emoji.hitTestable(), findsOneWidget);
            expect(tester.getSize(emoji).height, greaterThanOrEqualTo(48));
            await tester.tap(emoji);
            await tester.pumpAndSettle();
            await tester.tap(find.text('👋'));
            await tester.pumpAndSettle();
            final body = language == 'ar' ? 'مسودة 👋' : 'Draft 👋';
            expect(tester.widget<TextField>(composer).controller!.text, body);
            expect(find.text('${body.runes.length}/2000'), findsOneWidget);
            expect(repo.sendCalls, 0);
            await tester.tap(find.byKey(const Key('community-chat-send')));
            await tester.pumpAndSettle();
            expect(repo.sendCalls, 1);
            expect(repo.sentRecipients, [_peer]);
            expect(repo.sentBodies, [body]);
            expect(repo.requestIds.single, isNotEmpty);
            expect(repo.delivered.single.body, body);
            expect(
              tester.widget<TextField>(composer).controller!.text,
              isEmpty,
            );
            expect(
              find.byKey(
                ValueKey('community-message-text-${repo.requestIds.single}'),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          } finally {
            await _unmountPrivateScene(tester);
          }
        },
      );

      testWidgets(
        'actual pearl chat pending blocks duplicate and preserves new draft $language dark=$dark',
        (tester) async {
          final repo = _CaptureRepository(client(), language == 'ar')
            ..sendGate = Completer<void>();
          final boundary = GlobalKey();
          try {
            await _mountPrivateScene(
              tester,
              repo,
              boundary,
              'chat',
              language,
              dark: dark,
              keyboard: true,
            );
            final composer = find.byKey(
              const Key('community-message-composer'),
            );
            final send = find.byKey(const Key('community-chat-send'));
            await tester.enterText(composer, 'First request');
            await tester.tap(send);
            await tester.pump();
            expect(repo.sendCalls, 1);
            expect(tester.widget<IconButton>(send).onPressed, isNull);
            final spinner = tester.widget<BilFeatureWelcomeStatus>(
              find.descendant(
                of: send,
                matching: find.byType(BilFeatureWelcomeStatus),
              ),
            );
            expect(spinner.color, CommunitySapphire.navy);
            await tester.tap(send);
            await tester.pump();
            expect(repo.sendCalls, 1);
            await tester.enterText(composer, 'A newer draft');
            repo.sendGate!.complete();
            await tester.pumpAndSettle();
            expect(repo.sentBodies, ['First request']);
            expect(repo.delivered.length, 1);
            expect(
              tester.widget<TextField>(composer).controller!.text,
              'A newer draft',
            );
            _expectSendFinish(tester, language);
            expect(tester.takeException(), isNull);
          } finally {
            if (!repo.sendGate!.isCompleted) {
              repo.sendGate!.complete();
            }
            await _unmountPrivateScene(tester);
          }
        },
      );

      testWidgets(
        'actual new-message recipient cancel return and confirmed send $language dark=$dark',
        (tester) async {
          final repo = _CaptureRepository(client(), language == 'ar')
            ..sendGate = Completer<void>();
          final boundary = GlobalKey();
          try {
            final router = await _mountPrivateScene(
              tester,
              repo,
              boundary,
              'new',
              language,
              dark: dark,
              contrast: true,
              keyboard: true,
            );
            await _fillPrivateDraft(tester, language);
            final subject = find.byKey(const Key('community-message-subject'));
            final body = find.byKey(const Key('community-message-body'));
            final subjectController = tester
                .widget<TextField>(subject)
                .controller!;
            final bodyController = tester.widget<TextField>(body).controller!;
            final subjectText = subjectController.text;
            final bodyText = bodyController.text;
            final clear = find.byKey(
              const Key('community-message-recipient-clear'),
            );
            // The recipient row can be unbuilt after scrolling to the body.
            // Return to it with a real drag of the outer lazy list.
            await _scrollPrivateDraftTo(
              tester,
              clear,
              -120,
              targetName: 'clear',
              diagnosticBoundary: language == 'ar' && !dark ? boundary : null,
            );
            expect(clear.hitTestable(), findsOneWidget);
            expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
            await tester.tap(clear);
            await tester.pumpAndSettle();
            expect(repo.sendCalls, 0);
            expect(subjectController.text, subjectText);
            expect(bodyController.text, bodyText);
            final recipient = find.text(
              language == 'ar' ? 'عضو تجريبي' : 'Sample member',
            );
            await _scrollPrivateDraftTo(
              tester,
              recipient,
              -120,
              targetName: 'recipient',
              diagnosticBoundary: language == 'ar' && !dark ? boundary : null,
            );
            await tester.tap(recipient);
            await tester.pumpAndSettle();
            final send = find.byKey(const Key('community-message-send'));
            expect(send.hitTestable(), findsOneWidget);
            expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
            await tester.tap(send);
            await tester.pump();
            expect(repo.sendCalls, 1);
            expect(tester.widget<FilledButton>(send).onPressed, isNull);
            await tester.tap(send);
            await tester.pump();
            expect(repo.sendCalls, 1);
            expect(repo.sentBodies, [
              MessageBodyContract.compose(subject: subjectText, body: bodyText),
            ]);
            repo.sendGate!.complete();
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/community/messages');
            expect(repo.delivered.length, 1);
            expect(repo.sentRecipients, [_peer]);
            expect(tester.takeException(), isNull);
            // A separate untouched draft can be canceled through the actual back control.
            unawaited(router.push('/community/messages/new'));
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/community/messages/new');
            expect(find.byType(NewCommunityMessagePage), findsOneWidget);
            await _fillPrivateDraft(tester, language);
            await tester.tap(find.byKey(const Key('community-safe-return')));
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/community/messages');
            expect(repo.sendCalls, 1);
            expect(tester.takeException(), isNull);
          } finally {
            if (!repo.sendGate!.isCompleted) {
              repo.sendGate!.complete();
            }
            await _unmountPrivateScene(tester);
          }
        },
      );

      testWidgets(
        'actual inbox peer tap read acknowledgement and unread semantics $language dark=$dark',
        (tester) async {
          final repo = _CaptureRepository(client(), language == 'ar');
          final boundary = GlobalKey();
          final semantics = tester.ensureSemantics();
          try {
            final router = await _mountPrivateScene(
              tester,
              repo,
              boundary,
              'inbox',
              language,
              dark: dark,
              scale: 1,
            );
            final unreadLabel = language == 'ar'
                ? '1 الرسائل غير المقروءة'
                : '1 Unread messages';
            final unreadSemantics = find.semantics.byLabel(
              RegExp(r'(^|\n)' + RegExp.escape(unreadLabel) + r'($|\n)'),
            );
            expect(unreadSemantics.evaluate(), isNotEmpty);
            final thread = find.byKey(
              const ValueKey(
                'community-inbox-55555555-5555-4555-8555-555555555555',
              ),
            );
            expect(thread.hitTestable(), findsOneWidget);
            expect(tester.getSize(thread).height, greaterThanOrEqualTo(48));
            await tester.tap(thread);
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 800));
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/community/chat/$_peer');
            final chatPage = find.byType(CommunityChatPage);
            expect(chatPage, findsOneWidget);
            expect(tester.widget<CommunityChatPage>(chatPage).userId, _peer);
            expect(
              repo.readIds,
              contains('55555555-5555-4555-8555-555555555555'),
            );
            expect(
              repo.readIds,
              isNot(contains('66666666-6666-4666-8666-666666666666')),
            );
            await tester.tap(find.byKey(const Key('community-safe-return')));
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/community/messages');
            expect(unreadSemantics.evaluate(), isEmpty);
            expect(repo.sendCalls, 0);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            await _unmountPrivateScene(tester);
          }
        },
      );
    }
  }
}

void _registerPrivateHeaderBounds(SupabaseClient Function() client) {
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'actual new-message full title bounds and send 320 2x $language dark=$dark',
        (tester) async {
          final repo = _CaptureRepository(client(), language == 'ar')
            ..sendGate = Completer<void>();
          final boundary = GlobalKey();
          final semantics = tester.ensureSemantics();
          try {
            final router = await _mountPrivateScene(
              tester,
              repo,
              boundary,
              'new',
              language,
              dark: dark,
              contrast: true,
              keyboard: true,
            );
            await _fillPrivateDraft(tester, language);
            final appBar = find.byType(AppBar);
            final fullTitle = language == 'ar' ? 'رسالة جديدة' : 'New message';
            // Match the baseline title too; a new key alone cannot prove
            // that its original production paragraph was truncated.
            final title = find.descendant(
              of: appBar,
              matching: find.text(fullTitle),
            );
            expect(title, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(title);
            final fullLayout = TextPainter(
              text: paragraph.text,
              textDirection: paragraph.textDirection,
              textScaler: paragraph.textScaler,
              locale: paragraph.locale,
              strutStyle: paragraph.strutStyle,
              textWidthBasis: paragraph.textWidthBasis,
              textHeightBehavior: paragraph.textHeightBehavior,
            )..layout(maxWidth: paragraph.size.width);
            try {
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: 'The full title must be painted without ellipsis.',
              );
              expect(
                paragraph.size.height + .5,
                greaterThanOrEqualTo(fullLayout.height),
                reason: 'Reserve the full scaled paragraph in the toolbar.',
              );
            } finally {
              fullLayout.dispose();
            }
            final titleRect = tester.getRect(title);
            final barRect = tester.getRect(appBar);
            final back = find.byKey(const Key('community-safe-return'));
            final send = find.byKey(const Key('community-message-send'));
            expect(titleRect.left, greaterThanOrEqualTo(barRect.left));
            expect(titleRect.right, lessThanOrEqualTo(barRect.right));
            expect(titleRect.top, greaterThanOrEqualTo(barRect.top));
            expect(titleRect.bottom, lessThanOrEqualTo(barRect.bottom));
            expect(titleRect.overlaps(tester.getRect(back)), isFalse);
            expect(titleRect.overlaps(tester.getRect(send)), isFalse);
            expect(
              tester.getSemantics(title).getSemanticsData().label,
              contains(fullTitle),
            );
            expect(send.hitTestable(), findsOneWidget);
            expect(back.hitTestable(), findsOneWidget);
            expect(tester.getSize(send).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
            final sendName = language == 'ar'
                ? 'إرسال رسالة'
                : 'Send a message';
            expect(find.byTooltip(sendName), findsOneWidget);
            final sendData = tester.getSemantics(send).getSemanticsData();
            expect(sendData.flagsCollection.isButton, isTrue);
            expect(sendData.flagsCollection.isEnabled, ui.Tristate.isTrue);
            expect(sendData.hasAction(ui.SemanticsAction.tap), isTrue);
            await _capture(
              tester,
              boundary,
              'private-new-full-title-$language-2x-${dark ? 'dark' : 'light'}-keyboard',
            );
            // Retain the actual owner-guarded callback and receipt, including
            // the pending double-tap guard and existing return route.
            await tester.tap(send);
            await tester.pump();
            expect(repo.sendCalls, 1);
            expect(tester.widget<FilledButton>(send).onPressed, isNull);
            await tester.tap(send);
            await tester.pump();
            expect(repo.sendCalls, 1);
            repo.sendGate!.complete();
            await tester.pumpAndSettle();
            expect(repo.delivered.length, 1);
            expect(repo.sentRecipients, [_peer]);
            expect(router.state.uri.path, '/community/messages');
            expect(tester.takeException(), isNull);
          } finally {
            if (!repo.sendGate!.isCompleted) repo.sendGate!.complete();
            semantics.dispose();
            await _unmountPrivateScene(tester);
          }
        },
      );
    }
  }
}
