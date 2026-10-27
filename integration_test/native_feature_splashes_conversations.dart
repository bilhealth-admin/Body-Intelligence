part of 'native_feature_splashes_test.dart';

// Real DM/checkout widgets and native typography. Repository boundaries are
// synthetic; this entrypoint cannot authenticate, charge, or reach a backend.
class _NativeDmRepository extends CommunityRepository {
  _NativeDmRepository(super.client);
  static const peer = '22222222-2222-4222-8222-222222222222';
  final changes = StreamController<void>.broadcast(sync: true);
  final rows = <CommunityMessage>[];
  int sends = 0;
  @override
  String get currentUserId => _owner;
  @override
  Stream<void> watchConversationChanges(String id) => changes.stream;
  @override
  Future<List<CommunityMessage>> loadMessages(String id) async => [...rows];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async => ids.length;
  @override
  Future<Set<String>> loadReadMessageIds(String peer, List<String> ids) async =>
      ids.toSet();
  @override
  Future<void> sendMessageOperation(
    String recipientId,
    String body, {
    required String requestId,
  }) async {
    sends++;
    rows.add(
      CommunityMessage(
        id: 'sent-$sends',
        senderId: _owner,
        recipientId: recipientId,
        body: body,
        createdAt: DateTime(2026, 10, 26, 12, sends),
      ),
    );
  }

  void incoming(String body) {
    rows.add(
      CommunityMessage(
        id: 'new-incoming',
        senderId: peer,
        recipientId: _owner,
        body: body,
        createdAt: DateTime(2026, 10, 26, 11),
      ),
    );
    changes.add(null);
  }
}

Future<void> _waitNativeDmLayout(WidgetTester tester) async {
  final watch = Stopwatch()..start();
  while (watch.elapsedMilliseconds < 8000) {
    await tester.pump(const Duration(milliseconds: 32));
    final viewport = tester.getRect(
      find.byKey(const Key('community-message-history')),
    );
    final states = tester
        .stateList<CoachNativeMarkdownState>(find.byType(CoachNativeMarkdown))
        .where(
          (state) =>
              tester.getRect(find.byWidget(state.widget)).overlaps(viewport),
        )
        .toList();
    if (!Platform.isIOS ||
        states.isNotEmpty && states.every((state) => state.nativeLayoutReady)) {
      return;
    }
  }
  _diagnoseNativeViews(tester, 'community-native-timeout');
  fail(
    'Visible Community text never reached real native layout readiness; fallback is not native acceptance.',
  );
}

Widget _nativeConversationApp(
  Widget child, {
  required String language,
  required bool dark,
  required double scale,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark
      ? BilFlagshipTheme.dark(isArabic: language == 'ar')
      : BilFlagshipTheme.light(isArabic: language == 'ar'),
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: scale == 2,
    ),
    child: child!,
  ),
  home: child,
);

void _registerNativeConversationsAndStoreActivity(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  if (_coachOnly || _sceneFilter.isNotEmpty) {
    return;
  }
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        final name =
            'bil39-community-$language-${dark ? 'dark' : 'light'}-${scale.toInt()}x';
        testWidgets(
          'native $name actual conversation and accepted send',
          (tester) async {
            expect(_isExpectedNativeQaTarget(), isTrue);
            expect(AppEnvironment.useSupabase, isFalse);
            final transport = _NoCloudTransport();
            final client = SupabaseClient(
              'https://native-dm.invalid',
              'synthetic-not-a-key',
              httpClient: transport,
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            );
            final repository = _NativeDmRepository(client);
            final output = await _output();
            for (var index = 0; index < 24; index++) {
              repository.rows.add(
                CommunityMessage(
                  id: 'history-$index',
                  senderId: _NativeDmRepository.peer,
                  recipientId: _owner,
                  body: language == 'ar'
                      ? 'رسالة سابقة محلية $index، لا تخص حسابًا حقيقيًا.'
                      : 'Synthetic local history $index, unrelated to a real account.',
                  createdAt: DateTime(2026, 10, 25, 8, index),
                ),
              );
            }
            try {
              await tester.pumpWidget(
                _nativeConversationApp(
                  CommunityChatPage(
                    userId: _NativeDmRepository.peer,
                    displayName: language == 'ar'
                        ? 'محادثة اختبار محلية'
                        : 'Synthetic local chat',
                    repository: repository,
                  ),
                  language: language,
                  dark: dark,
                  scale: scale,
                ),
              );
              await _nativeSettle(tester);
              await _waitNativeDmLayout(tester);
              if (Platform.isAndroid) {
                await binding.convertFlutterSurfaceToImage();
              }
              final answer = language == 'ar'
                  ? '## تمرين اليوم\n\nهذه **رسالة محلية** لا تسجّل أي نشاط.\n\n- راجع الخطة أولًا.\n- استرح عند الحاجة.\n\n| اليوم | الحالة |\n|---|---|\n| الاثنين | مخطط |\n\nMixed units: 3 × 12، 60 kg.'
                  : '## Today’s session\n\nThis **local message** records no activity.\n\n- Review your plan first.\n- Rest when needed.\n\n| Day | State |\n|---|---|\n| Monday | Planned |\n\nMixed units: 3 × 12، 60 kg.';
              repository.incoming(answer);
              await _nativeSettle(tester);
              await _waitNativeDmLayout(tester);
              await _nativeSettle(tester);
              final history = find.byKey(
                const Key('community-message-history'),
              );
              final controller = tester.widget<ListView>(history).controller!;
              expect(
                controller.offset,
                closeTo(controller.position.minScrollExtent, 1),
              );
              expect(
                find.byKey(
                  const ValueKey('community-message-body-new-incoming'),
                ),
                findsOneWidget,
              );
              await _capture(binding, '$name-reply', output);
              final outgoing = language == 'ar'
                  ? 'وصلتني الخطة، هذه رسالة اختبار فقط.'
                  : 'Received the plan; this is a local test message.';
              await tester.enterText(
                find.byKey(const Key('community-message-composer')),
                outgoing,
              );
              await tester.tap(find.byKey(const Key('community-chat-send')));
              await _nativeSettle(tester);
              await _waitNativeDmLayout(tester);
              await _nativeSettle(tester);
              expect(repository.sends, 1);
              expect(find.text(outgoing), findsOneWidget);
              expect(
                tester
                    .widget<TextField>(
                      find.byKey(const Key('community-message-composer')),
                    )
                    .controller!
                    .text,
                '',
              );
              await nativeQaDismissKeyboard(tester);
              await _nativeSettle(tester);
              await _capture(binding, '$name-sent', output);
              expect(transport.sends, 0);
              expect(_dartNetworkDeny.blockedClientCreations, 0);
              expect(tester.takeException(), isNull);
              final reports =
                  (binding.reportData!['community_conversations_native'] ??=
                          <Map<String, Object?>>[])
                      as List<Map<String, Object?>>;
              reports.add({
                'name': name,
                'completed': true,
                'source_head': _head,
                'source_fingerprint': _fingerprint,
                'native_platform': Platform.operatingSystem,
                'actual_page': 'CommunityChatPage',
                'native_text_required': Platform.isIOS,
                'one_send': repository.sends == 1,
                'network_requests': transport.sends,
              });
            } finally {
              _diagnoseNativeViews(tester, name);
              await tester.pumpWidget(const SizedBox.shrink());
              await repository.changes.close();
              await client.dispose();
              transport.close();
            }
          },
          timeout: const Timeout(Duration(seconds: 90)),
        );
      }
      final name = 'bil39-store-$language-${dark ? 'dark' : 'light'}-2x';
      testWidgets(
        'native $name one waiting indicator outside checkout',
        (tester) async {
          expect(_isExpectedNativeQaTarget(), isTrue);
          var launches = 0;
          final status = BilStoreCopy.text(language, 'restore_checking');
          await tester.pumpWidget(
            _nativeConversationApp(
              Scaffold(
                body: BilDynamicStoreOffers(
                  locale: language,
                  offers: const [
                    BilStoreOfferMetadata(
                      productId: 'native.qa.monthly',
                      kind: BilStoreProductKind.premiumSubscription,
                      localizedTitle: 'Premium',
                      localizedPrice: r'$2.49',
                      currencyCode: 'USD',
                      priceMicros: 2490000,
                      billingPeriodIso8601: 'P1M',
                    ),
                  ],
                  restoreInProgress: true,
                  purchaseStatusMessage: status,
                  onPurchaseRequested: (_) => launches++,
                  onRestore: () {},
                  onManage: () {},
                ),
              ),
              language: language,
              dark: dark,
              scale: 2,
            ),
          );
          await _nativeSettle(tester);
          final cta = find.byKey(const ValueKey('store-purchase-cta'));
          expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
          expect(
            find.descendant(
              of: cta,
              matching: find.byType(CupertinoActivityIndicator),
            ),
            findsNothing,
          );
          expect(tester.widget<InkWell>(cta).onTap, isNull);
          expect(find.text(status), findsWidgets);
          expect(launches, 0);
          if (Platform.isAndroid) {
            await binding.convertFlutterSurfaceToImage();
          }
          final output = await _output();
          await _capture(binding, '$name-pending', output);
          expect(tester.takeException(), isNull);
          final reports =
              (binding.reportData!['store_activity_native'] ??=
                      <Map<String, Object?>>[])
                  as List<Map<String, Object?>>;
          reports.add({
            'name': name,
            'completed': true,
            'source_head': _head,
            'source_fingerprint': _fingerprint,
            'one_indicator_above_cta': true,
            'purchase_requests': launches,
          });
          await tester.pumpWidget(const SizedBox.shrink());
        },
        timeout: const Timeout(Duration(seconds: 90)),
      );
    }
  }
}
