part of 'native_feature_splashes_test.dart';

// Per-history diagnostic checkpoints are small and non-qualifying. The
// existing native failure collector already copies this owned QA directory.
class _NativeHistoryStageTrace {
  _NativeHistoryStageTrace(this.metadata, this.file);
  final Map<String, Object?> metadata;
  final File file;
  final watch = Stopwatch()..start();
  final stages = <Map<String, Object?>>[];
  Future<void>? _writing;
  String? _latestPayload;
  bool _persistenceDisabled = false;
  int _writes = 0;
  int dropped = 0;

  void _persistenceError(String kind) {
    _persistenceDisabled = true;
    _latestPayload = null;
    metadata['diagnostic_stage_persistence_error'] = kind;
    debugPrint('BIL_NATIVE_HISTORY_STAGE_PERSISTENCE_ERROR $kind');
  }

  Future<void> _drain() async {
    try {
      while (_latestPayload != null && !_persistenceDisabled && _writes < 64) {
        final payload = _latestPayload!;
        _latestPayload = null;
        _writes++;
        try {
          await file
              .writeAsString(payload, flush: true)
              .timeout(const Duration(seconds: 2));
        } on FileSystemException {
          _persistenceError('filesystem_error');
        } on TimeoutException {
          _persistenceError('write_timeout');
        }
      }
      if (_latestPayload != null && _writes >= 64) {
        _persistenceError('bounded_write_limit');
      }
    } finally {
      _writing = null;
    }
  }

  void mark(String stage) {
    final row = <String, Object?>{
      'stage': stage,
      'elapsed_us': watch.elapsedMicroseconds,
      'utc': DateTime.now().toUtc().toIso8601String(),
    };
    if (stages.length < 64) {
      stages.add(row);
    } else {
      dropped++;
      stages[63] = row;
    }
    metadata['diagnostic_stages'] = stages;
    metadata['diagnostic_stages_dropped'] = dropped;
    debugPrint(
      'BIL_NATIVE_HISTORY_STAGE ${jsonEncode({'scene': metadata['scene'], ...row})}',
    );
    if (_persistenceDisabled) return;
    // At most one asynchronous write and one coalesced latest snapshot exist.
    // No file I/O is awaited inside an observation interval or native pump.
    _latestPayload = jsonEncode({
      'schema': 'bil.native.history-await-diagnostics.v1',
      'qualification': 'DIAGNOSTIC_ONLY_NOT_TEST_PASS',
      'source_head': metadata['source_head'],
      'source_fingerprint': metadata['source_fingerprint'],
      'scene': metadata['scene'],
      'mode': metadata['mode'],
      'stage_limit': 64,
      'dropped': dropped,
      'last_stage': row,
      'stages': stages,
    });
    _writing ??= _drain();
  }

  Future<void> flush() async {
    final writing = _writing;
    if (writing == null) return;
    try {
      await writing.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      _persistenceError('final_flush_timeout');
    }
  }
}

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

// Live native surfaces and caret/ambient paints can schedule frames without
// an application transition. Wait for the actual interaction precondition,
// within the same three-second setup budget, rather than global frame idleness.
Future<void> _nativeWaitForCoachComposer(WidgetTester tester) async {
  final watch = Stopwatch()..start();
  const budgetUs = 3000000;
  Rect? previousViewport;
  Rect? previousComposer;
  var stableComparisons = 0;
  bool sameRect(Rect first, Rect second) =>
      (first.left - second.left).abs() <= .5 &&
      (first.top - second.top).abs() <= .5 &&
      (first.width - second.width).abs() <= .5 &&
      (first.height - second.height).abs() <= .5;
  bool usable(Rect rect) =>
      [
        rect.left,
        rect.top,
        rect.width,
        rect.height,
      ].every((value) => value.isFinite) &&
      rect.width > 0 &&
      rect.height > 0;
  while (watch.elapsedMicroseconds < budgetUs) {
    await tester.pump(const Duration(milliseconds: 20));
    final exception = tester.takeException();
    if (exception != null) throw exception;
    if (watch.elapsedMicroseconds > budgetUs) break;
    final rawComposer = find.byKey(const Key('ai-coach-question-field'));
    final viewport = find.byType(ChatHistoryViewport);
    final composerBoxes = rawComposer
        .evaluate()
        .map((e) => e.findRenderObject())
        .toList();
    final viewportBoxes = viewport
        .evaluate()
        .map((e) => e.findRenderObject())
        .toList();
    bool laidOut(List<RenderObject?> boxes) =>
        boxes.length == 1 &&
        boxes.single is RenderBox &&
        boxes.single!.attached &&
        (boxes.single! as RenderBox).hasSize;
    final composer = rawComposer.hitTestable();
    if (!laidOut(composerBoxes) ||
        !laidOut(viewportBoxes) ||
        composer.evaluate().length != 1) {
      previousViewport = null;
      previousComposer = null;
      stableComparisons = 0;
      continue;
    }
    final viewRect = tester.getRect(viewport);
    final composerRect = tester.getRect(composer);
    if (!usable(viewRect) || !usable(composerRect)) {
      previousViewport = null;
      previousComposer = null;
      stableComparisons = 0;
      continue;
    }
    final stable =
        previousViewport != null &&
        previousComposer != null &&
        sameRect(previousViewport, viewRect) &&
        sameRect(previousComposer, composerRect);
    stableComparisons = stable ? stableComparisons + 1 : 0;
    previousViewport = viewRect;
    previousComposer = composerRect;
    // Count actual returned-frame/geometry work before accepting readiness.
    if (stableComparisons >= 2 && watch.elapsedMicroseconds <= budgetUs) return;
  }
  throw FlutterError(
    'Coach composer/viewport did not become interactable and stable within the original 3000ms setup budget.',
  );
}

Future<GoRouter> _mountNativeCoach(
  WidgetTester tester,
  AppDatabase db,
  _NativeHeldGateway gateway, {
  required String language,
  required bool reduced,
  required bool history,
  void Function(String)? onStage,
}) async {
  if (history) {
    onStage?.call('preseed_before');
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
    onStage?.call('preseed_after');
  }
  onStage?.call('router_create_before');
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
  onStage?.call('mount_pump_widget_before');
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
  onStage?.call('mount_pump_widget_after');
  onStage?.call('origin_settle_before');
  await _nativeSettle(tester);
  onStage?.call('origin_settle_after');
  onStage?.call('open_before');
  await tester.tap(find.byKey(const ValueKey('native-open-coach-reveal')));
  onStage?.call('open_after');
  onStage?.call('open_pump_before');
  await tester.pump();
  onStage?.call('open_pump_after');
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
  onStage?.call('entry_hold_complete');
  await _nativeSettle(tester);
  onStage?.call('released_settle_after');
  // Follow the approved Overview default through the actual member action.
  // This does not override initial state, entitlement, consent or the model.
  expect(find.byKey(const Key('coach-reference-workspace')), findsOneWidget);
  final openChat = find.byKey(const Key('coach-workspace-tab-coach'));
  onStage?.call('chat_ensure_visible_before');
  await tester.ensureVisible(openChat);
  onStage?.call('chat_ensure_visible_after');
  await _nativeSettle(tester);
  onStage?.call('chat_open_before');
  await tester.tap(openChat);
  onStage?.call('chat_open_after');
  onStage?.call('composer_wait_before');
  await _nativeWaitForCoachComposer(tester);
  onStage?.call('composer_wait_after');
  expect(
    find.byKey(const Key('ai-coach-question-field')).hitTestable(),
    findsOneWidget,
  );
  if (Platform.isAndroid) {
    await IntegrationTestWidgetsFlutterBinding.ensureInitialized()
        .convertFlutterSurfaceToImage();
  }
  onStage?.call('ready_pump_before');
  await tester.pump();
  onStage?.call('ready_pump_after');
  return router;
}

Future<void> _sendNativeCoach(
  WidgetTester tester,
  _NativeHeldGateway gateway,
  String language, {
  void Function(String)? onStage,
}) async {
  onStage?.call('send_enter_text_before');
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    language == 'ar' ? 'مرحبا' : 'Hello',
  );
  onStage?.call('send_enter_text_after');
  onStage?.call('send_pump_before');
  await tester.pump();
  onStage?.call('send_pump_after');
  onStage?.call('send_tap_before');
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  onStage?.call('send_tap_after');
  onStage?.call('send_gateway_wait_before');
  final wait = Stopwatch()..start();
  while (gateway.calls == 0 && wait.elapsedMilliseconds < 5000) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  onStage?.call('send_gateway_wait_after');
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

Future<void> _prepareNativeHistoryReading(
  WidgetTester tester,
  Finder viewport,
  ScrollController controller,
  List<Map<String, Object?>> preparations, {
  required int dragIndex,
}) async {
  final watch = Stopwatch()..start();
  final samples = <Map<String, Object?>>[];
  final diagnostic = <String, Object?>{
    'scope': 'post-drag setup only; original3500ms anchor guard starts later',
    'drag_index': dragIndex,
    'maximum_pumps': 80,
    'required_consecutive_viewport_comparisons': 2,
    'maximum_viewport_delta_exclusive': .1,
    'initial_viewport': _historyViewportStateSummary(tester, viewport),
    'samples': samples,
    'completed': false,
  };
  preparations.add(diagnostic);
  var previous = tester.getRect(viewport);
  var settled = 0;
  try {
    for (var frame = 0; frame < 80; frame++) {
      final sample = <String, Object?>{
        'index': frame,
        'before_pump_us': watch.elapsedMicroseconds,
        'completed_pump': false,
      };
      samples.add(sample);
      try {
        await tester.pump(const Duration(milliseconds: 16));
        sample['completed_pump'] = true;
      } finally {
        sample['after_pump_us'] = watch.elapsedMicroseconds;
        sample['pump_wall_us'] =
            watch.elapsedMicroseconds - (sample['before_pump_us'] as int);
      }
      final observerStart = watch.elapsedMicroseconds;
      final current = tester.getRect(viewport);
      final media = viewport
          .evaluate()
          .single
          .getInheritedWidgetOfExactType<MediaQuery>()
          ?.data;
      final nativeInset = tester.view.viewInsets.bottom;
      final mediaInset = media?.viewInsets.bottom;
      final scrolling = controller.position.isScrollingNotifier.value;
      final deltas = [
        current.left - previous.left,
        current.top - previous.top,
        current.right - previous.right,
        current.bottom - previous.bottom,
      ];
      if (!scrolling &&
          nativeInset == 0 &&
          mediaInset == 0 &&
          deltas.every((delta) => delta.isFinite && delta.abs() < .1)) {
        settled++;
      } else {
        settled = 0;
      }
      sample.addAll({
        'viewport': _historyViewportStateSummary(tester, viewport),
        'viewport_edge_deltas': deltas,
        'scrolling': scrolling,
        'native_keyboard_inset': nativeInset,
        'media_keyboard_inset': mediaInset,
        'settled_comparisons': settled,
        'observer_wall_us': watch.elapsedMicroseconds - observerStart,
      });
      previous = current;
      if (settled == 2) {
        diagnostic['completed'] = true;
        return;
      }
    }
    throw StateError(
      'native_history_drag_setup_not_ready_after_80_frames: '
      'drag=$dragIndex settled_comparisons=$settled '
      'last_viewport=${jsonEncode(samples.last['viewport'])}',
    );
  } catch (error) {
    diagnostic['error_type'] = error.runtimeType.toString();
    rethrow;
  } finally {
    diagnostic['elapsed_us'] = watch.elapsedMicroseconds;
    diagnostic['completed_pumps'] = samples
        .where((sample) => sample['completed_pump'] == true)
        .length;
    diagnostic['settled_comparisons_at_exit'] = settled;
  }
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
  final preparations = <Map<String, Object?>>[];
  metadata['history_anchor_search'] = attempts;
  metadata['history_drag_preparation'] = preparations;
  for (var attempt = 0; attempt < maximumDrags; attempt++) {
    final before = controller.offset;
    final distance = (tester.getSize(viewport).height * .55)
        .clamp(96.0, 400.0)
        .toDouble();
    await tester.drag(viewport, Offset(0, distance));
    // Pointer delivery can finish before the next layout/ballistic frame.
    // Always observe one frame before inspecting visibility or scroll state.
    await tester.pump(const Duration(milliseconds: 16));
    // An idle ScrollPosition can coexist with a dismissing native keyboard and
    // a not-yet-painted viewport resize. Establish the reading setup inside the
    // existing80-frame preparation cap before choosing the stability anchor.
    await _prepareNativeHistoryReading(
      tester,
      viewport,
      controller,
      preparations,
      dragIndex: attempt + 1,
    );
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
    await _settleHistoryAnchor(tester, anchor, metadata);
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
            debugPrint(
              'BIL_NATIVE_HISTORY_STAGE output_directory_before $mode $scene',
            );
            final output = await _output();
            debugPrint(
              'BIL_NATIVE_HISTORY_STAGE output_directory_after $mode $scene',
            );
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
            final stageTrace = _NativeHistoryStageTrace(
              metadata,
              File('${output.path}/coach-$mode-$scene-diagnostic-stages.json'),
            );
            stageTrace.mark('case_setup_ready');
            GoRouter? router;
            _NativeReplyFrameTrace? trace;
            try {
              stageTrace.mark('mount_before');
              router = await _mountNativeCoach(
                tester,
                db,
                gateway,
                language: language,
                reduced: reduced,
                history: history,
                onStage: stageTrace.mark,
              );
              stageTrace.mark('mount_after');
              stageTrace.mark('send_before');
              await _sendNativeCoach(
                tester,
                gateway,
                language,
                onStage: stageTrace.mark,
              );
              stageTrace.mark('send_after');
              Finder? anchor;
              double? anchorBefore, offsetBefore;
              if (history) {
                final viewport = find.byType(ChatHistoryViewport);
                // Drag until a real older row is visible on this viewport/font,
                // rather than assuming 220 px always clears the newest turn.
                stageTrace.mark('anchor_before');
                anchor = await nativeQaEnterOlderHistory(
                  tester,
                  language: language,
                  metadata: metadata,
                );
                stageTrace.mark('anchor_after');
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
                stageTrace.mark('capture_reading_before');
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-reading',
                  output,
                  trace,
                  metadata,
                );
                stageTrace.mark('capture_reading_after');
              }
              final replyReleasedAt = trace.watch.elapsedMilliseconds;
              metadata['held_reply_released_at_ms'] = replyReleasedAt;
              stageTrace.mark('reply_release_before');
              gateway.finish(reply);
              stageTrace.mark('reply_release_after');
              if (history) {
                stageTrace.mark('history_reply_frames_before');
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
                stageTrace.mark('history_reply_frames_after');
                stageTrace.mark('capture_mid_before');
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-mid',
                  output,
                  trace,
                  metadata,
                );
                stageTrace.mark('capture_mid_after');
              } else {
                stageTrace.mark('reveal_first_visible_wait_before');
                while (!trace.samples.any(
                      (sample) => (sample['reply_opacity'] as num? ?? 0) > 0,
                    ) &&
                    trace.watch.elapsedMilliseconds < 1500) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                stageTrace.mark('reveal_first_visible_wait_after');
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
                // A slow native pump can return after the loop's deadline.
                // Check the actual observed frame, not just entry into pump.
                expect(
                  (first['observed_at_ms'] as num) - replyReleasedAt,
                  lessThanOrEqualTo(1500),
                  reason:
                      'The actual first readable frame must meet the original 1500ms budget.',
                );
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
                stageTrace.mark('reveal_capture_first_before');
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-first',
                  output,
                  trace,
                  metadata,
                );
                stageTrace.mark('reveal_capture_first_after');
                stageTrace.mark('reveal_mid_wait_before');
                while (trace.watch.elapsedMilliseconds < 1100) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                stageTrace.mark('reveal_mid_wait_after');
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
                stageTrace.mark('reveal_capture_mid_before');
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-mid',
                  output,
                  trace,
                  metadata,
                );
                stageTrace.mark('reveal_capture_mid_after');
              }
              stageTrace.mark('observation_tail_before');
              while (trace.watch.elapsedMilliseconds - replyReleasedAt < 2800) {
                await tester.pump(const Duration(milliseconds: 16));
              }
              stageTrace.mark('observation_tail_after');
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
                stageTrace.mark('capture_end_before');
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-end',
                  output,
                  trace,
                  metadata,
                );
                stageTrace.mark('capture_end_after');
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
                stageTrace.mark('reveal_capture_end_before');
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-end',
                  output,
                  trace,
                  metadata,
                );
                stageTrace.mark('reveal_capture_end_after');
              }
              expect(gateway.calls, 1);
              expect(tester.takeException(), isNull);
              expect(_dartNetworkDeny.blockedClientCreations, 0);
              metadata['completed'] = true;
            } finally {
              stageTrace.mark('cleanup_before');
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
              stageTrace.mark('metadata_write_before');
              await File(
                '${output.path}/coach-$mode-$scene-metadata.json',
              ).writeAsString(
                const JsonEncoder.withIndent('  ').convert(metadata),
                flush: true,
              );
              stageTrace.mark('metadata_write_after');
              binding.reportData ??= <String, dynamic>{};
              final reports =
                  (binding.reportData!['native_coach_$mode'] ??= <dynamic>[])
                      as List<dynamic>;
              reports.add(metadata);
              stageTrace.mark('cleanup_unmount_before');
              await tester.pumpWidget(const SizedBox.shrink());
              stageTrace.mark('cleanup_unmount_after');
              await tester.pump();
              stageTrace.mark('cleanup_pump_after');
              router?.dispose();
              stageTrace.mark('cleanup_db_close_before');
              await db.close();
              stageTrace.mark('cleanup_db_close_after');
              await stageTrace.flush();
            }
          },
          timeout: const Timeout(Duration(seconds: 90)),
        );
      }
    }
  }
}
