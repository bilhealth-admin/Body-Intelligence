part of 'native_feature_splashes_test.dart';

class _NativeHeldGateway implements LocalModelGateway {
  final replies = <Completer<LocalModelResult>>[];
  final questions = <String>[];
  final locales = <String>[];
  int calls = 0;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) {
    calls++;
    questions.add(question);
    locales.add(locale);
    final pending = Completer<LocalModelResult>();
    replies.add(pending);
    return pending.future;
  }

  void finish(String text) => replies.single.complete(
    LocalModelResult.answer(
      LocalModelAnswer(text: text, action: null, processedOnDevice: true),
    ),
  );
  void cancelPending() {
    for (final pending in replies) {
      if (!pending.isCompleted) {
        pending.complete(
          const LocalModelResult.answer(
            LocalModelAnswer(
              text: 'Synthetic native fixture cancelled.',
              action: null,
            ),
          ),
        );
      }
    }
  }
}

Future<GoRouter> _mountNativeCoach(
  WidgetTester tester,
  AppDatabase db,
  _NativeHeldGateway gateway, {
  required String language,
  required bool reduced,
  required bool history,
}) async {
  if (history) {
    await PreferencesRepository(db).set(
      'intelligenceConversationV1',
      jsonEncode(
        List.generate(
          35,
          (i) => IntelligenceMessage(
            id: 'native-history-$i',
            role: i.isEven
                ? IntelligenceMessageRole.user
                : IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: language == 'ar'
                ? 'سجل محلي تركيبي $i: رسالة مقروءة لا تنتمي لأي حساب حقيقي.'
                : 'Synthetic local history $i: a readable message unrelated to any real account.',
            createdAt: DateTime(2026, 10, 13, 8, i),
          ).toJson(),
        ),
      ),
    );
  }
  final router = GoRouter(
    initialLocation: '/native-origin',
    routes: [
      GoRoute(
        path: '/native-origin',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('native-open-coach-reveal'),
              onPressed: () => context.push('/intelligence-center'),
              child: const Text('Isolated native Coach QA'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/intelligence-center',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const IntelligenceCenterPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('QA fallback')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        coachContextSnapshotProvider.overrideWith(
          (ref) async => CoachContextSnapshot.empty(),
        ),
        coachHealthBriefProvider.overrideWith(
          (ref) async => CoachContextSnapshot.empty(),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
        intelligenceHealthContextProvider.overrideWith(
          (ref) async => const IntelligenceHealthContext(
            primaryMessage: '',
            explanation: [],
            confidence: 1,
            evidence: [],
            missingData: [],
          ),
        ),
        verifiedSubscriptionStateProvider.overrideWith(
          (ref) async => SubscriptionState(
            plan: CommercePlan.premiumAiCoach,
            entitlements: const {},
            authority: EntitlementAuthority.verifiedServer,
            currentPeriodEndsAt: DateTime(2030),
            isPurchasable: false,
            canRestorePurchases: false,
          ),
        ),
        storefrontTargetPlanProvider.overrideWith(
          (ref) async => CommercePlan.premiumAiCoach,
        ),
        verifiedEntitlementOwnerProvider.overrideWith(
          (ref) => Stream.value(_owner),
        ),
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(_owner),
        aiCoachCreditAccessProvider.overrideWith((ref) async => true),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(
          () async => <String, Object?>{
            'credits': <String, Object?>{'total_remaining': 1000},
          },
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: BilFlagshipTheme.light(
          isArabic: language == 'ar',
        ).copyWith(platform: TargetPlatform.android),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await _nativeSettle(tester);
  await tester.tap(find.byKey(const ValueKey('native-open-coach-reveal')));
  await tester.pump();
  final entryWatch = Stopwatch()..start();
  while (find
          .byKey(const Key('ai-coach-entry-welcome'))
          .evaluate()
          .isNotEmpty &&
      entryWatch.elapsedMilliseconds < 4500) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  // Static reduced-motion spinners do not schedule frames: settling alone
  // would return before the independent 2.2s hold Timer completes.
  expect(find.byKey(const Key('ai-coach-entry-welcome')), findsNothing);
  await _nativeSettle(tester);
  // Follow the approved Overview default through the actual member action.
  // This does not override initial state, entitlement, consent or the model.
  expect(find.byKey(const Key('coach-reference-workspace')), findsOneWidget);
  final openChat = find.byKey(const Key('coach-workspace-open-chat'));
  await tester.ensureVisible(openChat);
  await _nativeSettle(tester);
  await tester.tap(openChat);
  await _nativeSettle(tester);
  expect(
    find.byKey(const Key('ai-coach-question-field')).hitTestable(),
    findsOneWidget,
  );
  if (Platform.isAndroid) {
    await IntegrationTestWidgetsFlutterBinding.ensureInitialized()
        .convertFlutterSurfaceToImage();
  }
  await tester.pump();
  return router;
}

Future<void> _sendNativeCoach(
  WidgetTester tester,
  _NativeHeldGateway gateway,
  String language,
) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    language == 'ar' ? 'مرحبا' : 'Hello',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  final wait = Stopwatch()..start();
  while (gateway.calls == 0 && wait.elapsedMilliseconds < 5000) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    gateway.calls,
    1,
    reason: 'One real page send reaches only the held synthetic boundary.',
  );
  expect(gateway.questions.single, language == 'ar' ? 'مرحبا' : 'hello');
  expect(gateway.locales.single, language);
}

Future<void> _captureReply(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
  Directory output,
  _NativeReplyFrameTrace trace,
  Map<String, Object?> metadata,
) async {
  final before = nativeQaReplyGeometry(
    tester,
    trace.reply,
    trace.watch,
    anchor: trace.anchor,
  );
  await _capture(binding, name, output);
  final after = nativeQaReplyGeometry(
    tester,
    trace.reply,
    trace.watch,
    anchor: trace.anchor,
  );
  (metadata['capture_windows'] as List).add({
    'name': name,
    'before': before,
    'after': after,
  });
}

Future<Finder> nativeQaEnterOlderHistory(
  WidgetTester tester, {
  required String language,
  required Map<String, Object?> metadata,
  int maximumDrags = 16,
}) async {
  final viewport = find.byType(ChatHistoryViewport);
  final controller = tester.widget<ChatHistoryViewport>(viewport).controller;
  final attempts = <Map<String, Object?>>[];
  metadata['history_anchor_search'] = attempts;
  for (var attempt = 0; attempt < maximumDrags; attempt++) {
    final before = controller.offset;
    final distance = (tester.getSize(viewport).height * .55)
        .clamp(96.0, 400.0)
        .toDouble();
    await tester.drag(viewport, Offset(0, distance));
    // Pointer delivery can finish before the next layout/ballistic frame.
    // Always observe one frame before inspecting visibility or scroll state.
    await tester.pump(const Duration(milliseconds: 16));
    for (
      var frame = 0;
      frame < 80 && controller.position.isScrollingNotifier.value;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final bounds = tester.getRect(viewport);
    final candidates = find.byType(CoachMessageText).evaluate().where((
      element,
    ) {
      final widget = element.widget as CoachMessageText;
      if (widget.key == null ||
          !widget.text.startsWith(
            language == 'ar' ? 'سجل محلي تركيبي' : 'Synthetic local history',
          )) {
        return false;
      }
      final overlap = tester.getRect(find.byKey(widget.key!)).intersect(bounds);
      return overlap.width > 0 && overlap.height >= 20;
    }).toList();
    attempts.add({
      'drag_index': attempt + 1,
      'requested_drag_dy': distance,
      'pixels_before_drag': before,
      'scroll_pixels': controller.offset,
      'min_scroll_extent': controller.position.minScrollExtent,
      'max_scroll_extent': controller.position.maxScrollExtent,
      'viewport_height': bounds.height,
      'axis_direction': controller.position.axisDirection.name,
      'distance_from_newest':
          controller.offset - controller.position.minScrollExtent,
      'visible_history_candidates': candidates.length,
      'mounted_history_rows': find.byType(CoachMessageText).evaluate().map((e) {
        final row = e.widget as CoachMessageText;
        if (row.key == null) return <String, Object?>{'key': null};
        final rectangle = tester.getRect(find.byKey(row.key!));
        return {
          'key': row.key.toString(),
          'matches_language_prefix': row.text.startsWith(
            language == 'ar' ? 'سجل محلي تركيبي' : 'Synthetic local history',
          ),
          'top': rectangle.top,
          'height': rectangle.height,
          'visible_height': rectangle.intersect(bounds).height,
        };
      }).toList(),
      'scrolling': controller.position.isScrollingNotifier.value,
    });
    if (candidates.isEmpty ||
        controller.position.isScrollingNotifier.value ||
        controller.offset - controller.position.minScrollExtent <= 72) {
      continue;
    }
    final anchor = find.byKey(candidates.first.widget.key!);
    await _settleHistoryAnchor(tester, anchor);
    final overlap = tester.getRect(anchor).intersect(tester.getRect(viewport));
    if (overlap.width > 0 && overlap.height >= 20) {
      metadata['history_anchor_key'] = candidates.first.widget.key.toString();
      return anchor;
    }
  }
  throw StateError(
    'native_history_anchor_unavailable_after_progressive_drags: '
    '${jsonEncode(attempts)}',
  );
}

void _registerNativeCoachReveal(IntegrationTestWidgetsFlutterBinding binding) {
  if (_conversationOnly) return;
  for (final language in ['ar', 'en']) {
    for (final reduced in [false, true]) {
      final scene = '$language-light-${reduced ? 'reduced' : 'normal'}';
      if (_sceneFilter.isNotEmpty && scene != _sceneFilter) continue;
      for (final history in [false, true]) {
        final mode = history ? 'history' : 'reveal';
        testWidgets(
          'native Coach $mode $scene 2x real fonts and frames',
          (tester) async {
            expect(Platform.isAndroid || Platform.isIOS, isTrue);
            expect(_isExpectedNativeQaTarget(), isTrue);
            expect(AppEnvironment.profile, EnvironmentProfile.testing);
            expect(
              AppEnvironment.useSupabase ||
                  AppEnvironment.paymentsEnabled ||
                  AppEnvironment.pushEnabled ||
                  AppEnvironment.adsEnabled,
              isFalse,
            );
            expect(_head.isNotEmpty && _fingerprint.isNotEmpty, isTrue);
            final output = await _output();
            final db = AppDatabase.forTesting(
              NativeDatabase.memory(),
              localOwnerId: _owner,
            );
            final gateway = _NativeHeldGateway();
            final reply = List.generate(
              26,
              (i) => language == 'ar'
                  ? 'فقرة تركيبية $i: هذه قراءة محلية واضحة لا تحفظ طعامًا ولا تغيّر حسابًا.'
                  : 'Synthetic paragraph $i: this readable reply performs no food write or account change.',
            ).join('\n');
            final metadata = <String, Object?>{
              'classification':
                  'native ${Platform.operatingSystem} QA production Coach page / held synthetic model, not AI-quality E2E',
              'platform': Platform.operatingSystem,
              'source_head': _head,
              'source_fingerprint': _fingerprint,
              'scene': scene,
              'mode': mode,
              'text_scale': 2.0,
              'reduced_motion_fixture': reduced,
              'native_reduce_motion':
                  binding.platformDispatcher.accessibilityFeatures.reduceMotion,
              'fonts':
                  'actual platform theme and bundled BIL fonts; no Evidence override',
              'physical_size':
                  '${tester.view.physicalSize.width}x${tester.view.physicalSize.height}',
              'device_pixel_ratio': tester.view.devicePixelRatio,
              'capture_windows': <Object?>[],
              'completed': false,
            };
            GoRouter? router;
            _NativeReplyFrameTrace? trace;
            try {
              router = await _mountNativeCoach(
                tester,
                db,
                gateway,
                language: language,
                reduced: reduced,
                history: history,
              );
              await _sendNativeCoach(tester, gateway, language);
              Finder? anchor;
              double? anchorBefore, offsetBefore;
              if (history) {
                final viewport = find.byType(ChatHistoryViewport);
                // Drag until a real older row is visible on this viewport/font,
                // rather than assuming 220 px always clears the newest turn.
                anchor = await nativeQaEnterOlderHistory(
                  tester,
                  language: language,
                  metadata: metadata,
                );
                final controller = tester
                    .widget<ChatHistoryViewport>(viewport)
                    .controller;
                expect(controller.position.isScrollingNotifier.value, isFalse);
                expect(
                  controller.offset - controller.position.minScrollExtent,
                  greaterThan(72),
                  reason:
                      'History condition must actually leave the newest-end follow zone.',
                );
                anchorBefore = tester.getTopLeft(anchor).dy;
                offsetBefore = controller.offset;
                metadata.addAll({
                  'history_anchor_top_before': anchorBefore,
                  'scroll_pixels_before': offsetBefore,
                });
              }
              trace = _NativeReplyFrameTrace(tester, reply, anchor: anchor)
                ..start();
              if (history) {
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-reading',
                  output,
                  trace,
                  metadata,
                );
              }
              final replyReleasedAt = trace.watch.elapsedMilliseconds;
              metadata['held_reply_released_at_ms'] = replyReleasedAt;
              gateway.finish(reply);
              if (history) {
                for (var i = 0; i < 25; i++) {
                  await tester.pump(const Duration(milliseconds: 16));
                  expect(
                    tester.getTopLeft(anchor!).dy,
                    closeTo(anchorBefore!, .5),
                  );
                  final controller = tester
                      .widget<ChatHistoryViewport>(
                        find.byType(ChatHistoryViewport),
                      )
                      .controller;
                  expect(controller.offset, closeTo(offsetBefore!, .5));
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-mid',
                  output,
                  trace,
                  metadata,
                );
              } else {
                while (!trace.samples.any(
                      (sample) => (sample['reply_opacity'] as num? ?? 0) > 0,
                    ) &&
                    trace.watch.elapsedMilliseconds < 1500) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                final nonempty = trace.samples
                    .where(
                      (sample) => (sample['reply_opacity'] as num? ?? 0) > 0,
                    )
                    .toList();
                expect(
                  nonempty,
                  isNotEmpty,
                  reason:
                      'Real page must paint a nonempty reply within the recorded native observation budget.',
                );
                final first = nonempty.first;
                metadata['first_nonempty_native_frame'] = first;
                expect(
                  first[Platform.isIOS
                          ? 'first_content_visible_area'
                          : 'first_glyphs_visible_area']
                      as num,
                  greaterThan(0),
                  reason:
                      'First visible content must be inside the actual native viewport; SwiftUI reports its measured first block and Flutter reports glyph boxes.',
                );
                expect(
                  first['visible_graphemes'] as int,
                  greaterThanOrEqualTo(8),
                );
                expect(first['arrival_present'], isTrue);
                expect(first['visible_graphemes'], reply.characters.length);
                metadata['arrival_style'] =
                    'complete-reply opacity/position, 320ms';
                metadata['capture_limit'] =
                    'PNG driver IPC can outlast the entrance; frame trace records actual opacity.';
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-first',
                  output,
                  trace,
                  metadata,
                );
                while (trace.watch.elapsedMilliseconds < 1100) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                final mid = nativeQaReplyGeometry(tester, reply, trace.watch);
                expect(mid['visible_graphemes'], reply.characters.length);
                expect(mid['reply_opacity'], 1.0);
                final arrivalFrames = trace.samples
                    .where((frame) => frame['arrival_present'] == true)
                    .toList();
                if (reduced) {
                  expect(
                    arrivalFrames.every(
                      (frame) =>
                          frame['reply_opacity'] == 0.0 ||
                          frame['reply_opacity'] == 1.0,
                    ),
                    isTrue,
                  );
                  expect(arrivalFrames.last['reply_opacity'], 1.0);
                  metadata['reduced_motion_style'] =
                      'one layout gate, then immediate visibility; no fade';
                } else {
                  expect(arrivalFrames.first['reply_opacity'], 0.0);
                  expect(arrivalFrames.last['reply_opacity'], 1.0);
                  for (var i = 1; i < arrivalFrames.length; i++) {
                    expect(
                      arrivalFrames[i]['reply_opacity'] as num,
                      greaterThanOrEqualTo(
                        arrivalFrames[i - 1]['reply_opacity'] as num,
                      ),
                    );
                  }
                  metadata['entrance_intermediate_frame_observed'] =
                      arrivalFrames.any((frame) {
                        final opacity = frame['reply_opacity'] as num;
                        return opacity > 0 && opacity < 1;
                      });
                  // A native debug frame can outlast the 320ms entrance for
                  // this 26-paragraph/2x stress fixture. Preserve that limit;
                  // geometry completion is not a smoothness certification.
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-mid',
                  output,
                  trace,
                  metadata,
                );
              }
              while (trace.watch.elapsedMilliseconds - replyReleasedAt < 2800) {
                await tester.pump(const Duration(milliseconds: 16));
              }
              if (history) {
                expect(
                  tester.getTopLeft(anchor!).dy,
                  closeTo(anchorBefore!, .5),
                );
                final controller = tester
                    .widget<ChatHistoryViewport>(
                      find.byType(ChatHistoryViewport),
                    )
                    .controller;
                expect(controller.offset, closeTo(offsetBefore!, .5));
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-end',
                  output,
                  trace,
                  metadata,
                );
              } else {
                final row = _replyRow(reply);
                if (Platform.isIOS) {
                  expect(tester.widget<CoachNativeMarkdown>(row).text, reply);
                  final native = tester.state<CoachNativeMarkdownState>(row);
                  expect(native.nativeLayoutReady, isTrue);
                  expect(
                    find.descendant(of: row, matching: find.byType(UiKitView)),
                    findsOneWidget,
                  );
                } else {
                  expect(
                    tester
                        .widget<SelectableText>(
                          find.descendant(
                            of: row,
                            matching: find.byType(SelectableText),
                          ),
                        )
                        .data,
                    reply,
                  );
                }
                final painted = trace.samples
                    .where(
                      (sample) =>
                          (sample['visible_graphemes'] as int? ?? 0) > 0,
                    )
                    .toList();
                final height = (painted.first['message_height'] as num)
                    .toDouble();
                for (final sample in painted) {
                  expect(
                    (sample['message_height'] as num).toDouble(),
                    closeTo(height, .5),
                    reason:
                        'Complete reply typography stays reserved throughout the soft entrance.',
                  );
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-end',
                  output,
                  trace,
                  metadata,
                );
              }
              expect(gateway.calls, 1);
              expect(tester.takeException(), isNull);
              expect(_dartNetworkDeny.blockedClientCreations, 0);
              metadata['completed'] = true;
            } finally {
              trace?.stop();
              gateway.cancelPending();
              metadata['geometry_native_frames'] =
                  trace?.samples ?? <Object?>[];
              metadata['native_frame_timings'] =
                  trace?.nativeTimings ?? <Object?>[];
              metadata['synthetic_gateway_calls'] = gateway.calls;
              metadata['synthetic_gateway_questions'] = gateway.questions;
              metadata['synthetic_gateway_locales'] = gateway.locales;
              metadata['dart_network_client_creations_blocked'] =
                  _dartNetworkDeny.blockedClientCreations;
              metadata['real_model_calls'] = 0;
              metadata['real_credits_spent'] = 0;
              await File(
                '${output.path}/coach-$mode-$scene-metadata.json',
              ).writeAsString(
                const JsonEncoder.withIndent('  ').convert(metadata),
                flush: true,
              );
              binding.reportData ??= <String, dynamic>{};
              final reports =
                  (binding.reportData!['native_coach_$mode'] ??= <dynamic>[])
                      as List<dynamic>;
              reports.add(metadata);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              router?.dispose();
              await db.close();
            }
          },
          timeout: const Timeout(Duration(seconds: 90)),
        );
      }
    }
  }
}
