part of 'health_coach_ui_test.dart';

final _healthDay = DateTime(2026, 10, 6);
final _healthNow = DateTime(2026, 10, 7, 12);
const _privateHealthNote =
    'Private diary text must stay out of activity receipts.';

Future<void> _withHealthCoach(
  WidgetTester tester,
  Future<void> Function(_HealthUiFixture fixture) body, {
  List<Map<String, Object?>> tools = const [],
  Future<void> Function(_HealthUiFixture fixture)? seed,
  bool forbidFullContext = true,
  Locale locale = const Locale('en'),
  Size surfaceSize = const Size(430, 932),
  double textScale = 1,
  bool enableSemantics = false,
  PreferencesRepository Function(AppDatabase)? preferencesFactory,
}) async {
  final fixture = _HealthUiFixture(
    tools,
    forbidFullContext: forbidFullContext,
    locale: locale,
    textScale: textScale,
    preferencesFactory: preferencesFactory,
  );
  addTearDown(fixture.database.close);
  addTearDown(fixture.owners.close);
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  if (seed != null) await seed(fixture);
  final semantics = enableSemantics ? tester.ensureSemantics() : null;
  try {
    await tester.pumpWidget(_healthCoachApp(fixture));
    await tester.pumpAndSettle();
    await body(fixture);
    expect(tester.takeException(), isNull);
  } finally {
    try {
      await _unmountHealthCoach(tester);
    } finally {
      semantics?.dispose();
    }
  }
}

Widget _healthCoachApp(_HealthUiFixture fixture) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(fixture.database),
    preferencesRepositoryProvider.overrideWithValue(fixture.preferences),
    dailyLogRepositoryProvider.overrideWithValue(fixture.daily),
    nutritionGoalScheduleRepositoryProvider.overrideWithValue(fixture.schedule),
    dietPlanRepositoryProvider.overrideWithValue(fixture.planRepository),
    dietPlanCommandProvider.overrideWithValue(fixture.planCommand),
    appSettingsServiceProvider.overrideWithValue(fixture.settings),
    intelligenceCenterModelGatewayProvider.overrideWithValue(fixture.gateway),
    intelligenceConversationClockProvider.overrideWithValue(() => _healthNow),
    fastingNotificationServiceProvider.overrideWithValue(fixture.notifications),
    coachActionPermissionModeProvider.overrideWith(
      (ref) => CoachActionPermissionMode.writeAllowed,
    ),
    coachNativeOwnerWitnessProvider.overrideWithValue(
      CoachNativeOwnerWitness(
        readOwner: () => fixture.owner,
        changes: fixture.owners.stream,
      ),
    ),
    coachContextSnapshotProvider.overrideWith((ref) async {
      fixture.fullContextCalls += 1;
      if (fixture.forbidFullContext) {
        throw StateError(
          'A local health command must not assemble full context',
        );
      }
      return CoachContextSnapshot.empty();
    }),
    intelligenceHealthContextProvider.overrideWith(
      (ref) async => const IntelligenceHealthContext(
        primaryMessage: '',
        explanation: [],
        confidence: 1,
        evidence: [],
        missingData: [],
      ),
    ),
  ],
  child: MaterialApp(
    locale: fixture.locale,
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
      ).copyWith(textScaler: TextScaler.linear(fixture.textScale)),
      child: child!,
    ),
    home: const IntelligenceCenterPage(),
  ),
);

Map<String, Object?> _healthTool(String name, Map<String, Object?> arguments) =>
    {'name': name, 'arguments': arguments};

Future<void> _sendHealthPrompt(WidgetTester tester, String text) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(IntelligenceCenterPage)),
  ).clearSnackBars();
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    text,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  await tester.pump();
}

Future<void> _expectHealthDialog(WidgetTester tester) async {
  final dialog = find.byType(AlertDialog);
  for (var attempt = 0; attempt < 80 && dialog.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(dialog, findsOneWidget);
  // Preparing the proposal is complete while human review is pending. The
  // chat should be able to settle behind the confirmation dialog.
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> _openModelHealthAction(WidgetTester tester, String toolId) async {
  await _sendHealthPrompt(tester, 'Execute the prepared BIL operation');
  final action = find.byKey(Key('ai-coach-action-sheet-healthCommand-$toolId'));
  for (var attempt = 0; attempt < 80 && action.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(action, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  expect(action.hitTestable(), findsOneWidget);
  await tester.tap(action);
  await _expectHealthDialog(tester);
}

Future<void> _confirmHealthDialog(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Continue');
  await Scrollable.ensureVisible(tester.element(button), alignment: .5);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _cancelHealthDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
}

Future<void> _undoHealthAction(WidgetTester tester) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(IntelligenceCenterPage)),
  ).clearSnackBars();
  final undo = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('ai-coach-undo-'),
  );
  for (var attempt = 0; attempt < 80 && undo.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(undo, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(undo), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  expect(undo.hitTestable(), findsOneWidget);
  await tester.tap(undo);
  await tester.pumpAndSettle();
}

Future<void> _waitHealthReceipts(
  WidgetTester tester,
  _HealthUiFixture fixture,
  int count,
) => _waitHealthEvidence(tester, fixture.receipts, count);

Future<void> _waitHealthReads(
  WidgetTester tester,
  _HealthUiFixture fixture,
  int count,
) => _waitHealthEvidence(tester, fixture.healthReads, count);

Future<void> _waitHealthEvidence(
  WidgetTester tester,
  Future<List<Map<String, Object?>>> Function() read,
  int count,
) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    if ((await read()).length >= count) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect((await read()).length, greaterThanOrEqualTo(count));
}

Future<void> _unmountHealthCoach(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(Duration.zero);
}

Future<void> _remountHealthCoach(
  WidgetTester tester,
  _HealthUiFixture fixture,
) async {
  await _unmountHealthCoach(tester);
  await tester.pumpWidget(_healthCoachApp(fixture));
  await tester.pumpAndSettle();
}

Future<void> _seedHealthDaily(_HealthUiFixture fixture) => fixture.daily.save(
  date: _healthDay,
  sleepHours: 6,
  notes: _privateHealthNote,
  steps: 4321,
);

Future<void> _waitForInitialFastingReconciliation(
  WidgetTester tester,
  _HealthUiFixture fixture,
) async {
  for (
    var attempt = 0;
    attempt < 30 && fixture.notifications.pendingReads == 0;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(fixture.notifications.pendingReads, greaterThan(0));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _expectSavedDailyValue(
  _HealthUiFixture fixture,
  String toolId,
) async {
  final row = (await fixture.daily.getForDay(_healthDay))!;
  expect(row.notes, _privateHealthNote);
  expect(row.steps, 4321);
  if (toolId == 'log_sleep') {
    expect(row.sleepHours, 7);
    expect(row.exerciseNotes, isNull);
  } else {
    expect(row.sleepHours, 6);
    final exercise = jsonDecode(row.exerciseNotes!) as Map;
    expect(exercise.keys.toSet(), {'id', 'name', 'minutes', 'recordedAt'});
    expect(exercise['id'], 'walk');
    expect(exercise['name'], 'Brisk walk');
    expect(exercise['minutes'], 20);
  }
}

class _HealthUiFixture {
  _HealthUiFixture(
    List<Map<String, Object?>> tools, {
    required this.forbidFullContext,
    required this.locale,
    required this.textScale,
    PreferencesRepository Function(AppDatabase)? preferencesFactory,
  }) : database = AppDatabase.forTesting(
         NativeDatabase.memory(),
         localOwnerId: 'owner-a',
       ),
       gateway = _HealthUiGateway(tools) {
    preferences =
        preferencesFactory?.call(database) ?? PreferencesRepository(database);
    daily = _TrackingHealthDailyLogs(database);
    schedule = NutritionGoalScheduleRepository(preferences);
    planRepository = DietPlanRepository(
      preferences: preferences,
      schedule: schedule,
    );
    planCommand = DietPlanCommand(
      repository: planRepository,
      verifiedSubscription: () async {
        subscriptionCalls += 1;
        return SubscriptionState(
          plan: CommercePlan.premium,
          entitlements: const {CommerceEntitlement.premiumPrograms},
          authority: EntitlementAuthority.verifiedServer,
          isPurchasable: false,
          canRestorePurchases: true,
        );
      },
    );
  }

  final AppDatabase database;
  final _HealthUiGateway gateway;
  final bool forbidFullContext;
  final Locale locale;
  final double textScale;
  final settings = AppSettingsService(store: _HealthUiSettings());
  final notifications = _HealthUiNotifications();
  final owners = StreamController<String?>.broadcast(sync: true);
  String? owner = 'owner-a';
  int fullContextCalls = 0;
  int subscriptionCalls = 0;
  late final PreferencesRepository preferences;
  late final _TrackingHealthDailyLogs daily;
  late final NutritionGoalScheduleRepository schedule;
  late final DietPlanRepository planRepository;
  late final DietPlanCommand planCommand;

  Future<List<Map<String, Object?>>> messages() async {
    final raw = await preferences.get('intelligenceConversationV1');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((message) => Map<String, Object?>.from(message))
        .toList();
  }

  Future<List<Map<String, Object?>>> _evidence() async {
    final result = <Map<String, Object?>>[];
    for (final message in await messages()) {
      final evidence = message['evidence'];
      if (evidence is! List) continue;
      for (final item in evidence.whereType<String>()) {
        if (!item.startsWith('{')) continue;
        final value = jsonDecode(item);
        if (value is Map) result.add(Map<String, Object?>.from(value));
      }
    }
    return result;
  }

  Future<List<Map<String, Object?>>> receipts() async =>
      (await _evidence()).where((value) => value['committed'] == true).toList();

  Future<List<Map<String, Object?>>> healthReads() async => (await _evidence())
      .where((value) => value['source'] == 'verified_local_health_read')
      .toList();

  Future<List<Map<String, Object?>>> nativeJournals() async => [
    for (final row in await database.select(database.preferences).get())
      if (row.key.startsWith('coachNativeOperationV1.'))
        Map<String, Object?>.from(jsonDecode(row.value) as Map),
  ];

  /// Conversation persistence is expected for both accepted and cancelled UI
  /// input. Compare the actual health tables, plan values and native journal.
  Future<Map<String, Object?>> healthSnapshot() async => {
    'daily': [
      for (final row in await database.select(database.dailyLogs).get())
        row.toJson(),
    ],
    'water': [
      for (final row in await database.select(database.waterEntries).get())
        row.toJson(),
    ],
    'weights': [
      for (final row in await database.select(database.weightEntries).get())
        row.toJson(),
    ],
    'meals': [
      for (final row in await database.select(database.meals).get())
        row.toJson(),
    ],
    'healthPreferences': {
      for (final row in await database.select(database.preferences).get())
        if (row.key == 'activeNutritionPathway' ||
            row.key == 'goals.nutritionSchedule.v1' ||
            row.key.startsWith('nutrition.dietDraft.v1.') ||
            row.key.startsWith('wellness_fasting_') ||
            row.key.startsWith('coachNativeOperationV1.'))
          row.key: row.toJson(),
    },
  };
}

class _TrackingHealthDailyLogs extends DailyLogRepository {
  _TrackingHealthDailyLogs(super.database);
  final requestedDays = <DateTime>[];
  int fullHistoryCalls = 0;

  @override
  Future<DailyLog?> getForDay(DateTime date) {
    requestedDays.add(date);
    return super.getForDay(date);
  }

  @override
  Future<List<DailyLog>> getAll() async {
    fullHistoryCalls += 1;
    throw StateError(
      'Unbounded daily history must not be read by local Coach commands',
    );
  }
}

class _HealthUiGateway implements LocalModelGateway {
  _HealthUiGateway(this.tools);
  final List<Map<String, Object?>> tools;
  int calls = 0;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    final index = calls++;
    if (index >= tools.length) {
      throw StateError('Unexpected model call for a local health request');
    }
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: 'The action is ready for review.',
        action: tools[index],
      ),
    );
  }
}

class _HealthUiSettings implements SettingsStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
}

enum _HealthUiReadbackFault { unavailable, paused }

/// The native journal write is the last repository call inside commit's
/// mutation transaction. Its next get is the separate postcommit readback.
/// Prepare, apply and the atomic journal write retain their real behavior.
class _HealthUiPostCommitPreferences extends PreferencesRepository {
  _HealthUiPostCommitPreferences(super.database, {required this.mode});

  final _HealthUiReadbackFault mode;
  final reachedReadback = Completer<void>();
  final _resumeReadback = Completer<void>();
  final reachedReceiptSave = Completer<void>();
  Completer<void>? _resumeReceiptSave;
  String? _journalKey;
  bool _enabled = true;
  int interceptions = 0;
  Map<String, Object?>? observedJournal;

  /// Pause before the conversation write opens a database transaction, so the
  /// test can inspect the real journal and transcript while persistence waits.
  void pauseReceiptSave() => _resumeReceiptSave = Completer<void>();

  @override
  Future<void> setMany(Map<String, String> values) async {
    final gate = _resumeReceiptSave;
    final conversation = values['intelligenceConversationV1'];
    if (gate != null && conversation != null) {
      final hasReceipt = (jsonDecode(conversation) as List)
          .whereType<Map>()
          .any((message) {
            final evidence = message['evidence'];
            if (evidence is! List) return false;
            return evidence.whereType<String>().any((item) {
              if (!item.startsWith('{')) return false;
              final value = jsonDecode(item);
              return value is Map && value['committed'] == true;
            });
          });
      if (hasReceipt) {
        if (!reachedReceiptSave.isCompleted) reachedReceiptSave.complete();
        await gate.future;
      }
    }
    await super.setMany(values);
  }

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    for (final key in values.keys) {
      if (key.startsWith('coachNativeOperationV1.')) _journalKey ??= key;
    }
  }

  @override
  Future<String?> get(String key) async {
    final stored = await super.get(key);
    if (_enabled && key == _journalKey && stored != null) {
      observedJournal = Map<String, Object?>.from(jsonDecode(stored) as Map);
      interceptions += 1;
      if (!reachedReadback.isCompleted) reachedReadback.complete();
      if (mode == _HealthUiReadbackFault.unavailable) {
        throw StateError(
          'Synthetic failure of separate postcommit journal readback',
        );
      }
      await _resumeReadback.future;
    }
    return stored;
  }

  void release() {
    _enabled = false;
    if (!_resumeReadback.isCompleted) _resumeReadback.complete();
  }

  void releaseReceiptSave() {
    final gate = _resumeReceiptSave;
    _resumeReceiptSave = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

Future<void> _waitForHealthPostCommitReadback(
  WidgetTester tester,
  _HealthUiPostCommitPreferences preferences,
) async {
  for (
    var attempt = 0;
    attempt < 30 && !preferences.reachedReadback.isCompleted;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(preferences.reachedReadback.isCompleted, isTrue);
  expect(preferences.observedJournal, isNotNull);
}

void _expectHealthRecoveryMetadata(
  Map<String, Object?> journal, {
  required bool acknowledged,
  required String conversationId,
}) {
  expect(journal['healthReceiptRecovery'], {
    'conversationId': conversationId,
    'receiptAcknowledged': acknowledged,
  });
}

Future<void> _waitHealthReceiptAcknowledged(
  WidgetTester tester,
  _HealthUiFixture fixture, {
  required String conversationId,
  required Map<String, Object?> receipt,
}) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    final journal = (await fixture.nativeJournals()).single;
    if ((journal['healthReceiptRecovery'] as Map)['receiptAcknowledged'] ==
        true) {
      // Read the actual durable conversation, not the rendered bubble or an
      // in-memory receipt, before treating the journal acknowledgement as valid.
      expect((await fixture.receipts()).single, receipt);
      expect(
        await fixture.preferences.get('intelligenceConversationActiveIdV1'),
        conversationId,
      );
      _expectHealthRecoveryMetadata(
        journal,
        acknowledged: true,
        conversationId: conversationId,
      );
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('The exact persisted health receipt was not acknowledged');
}

void _expectRecoveredHealthReceipt(
  Map<String, Object?> receipt,
  Map<String, Object?> journal,
) {
  final command = journal['command'] as Map;
  final operationId = command['operationId'];
  expect(receipt['operation_id'], operationId);
  expect(receipt['entity_id'], operationId);
  expect(receipt['entity_type'], 'health_record');
  expect(receipt['tool_id'], command['toolId']);
  expect(receipt['verified'], isTrue);
  expect(receipt['undoable'], isTrue);
  expect(
    receipt['completed_at'],
    DateTime.parse(journal['committedAt'] as String).toUtc().toIso8601String(),
  );
  expect(
    receipt['before'],
    ((command['before'] as Map)['health'] as Map)['receipt'],
  );
  expect(receipt['after'], {
    ...Map<String, Object?>.from(
      ((journal['after'] as Map)['health'] as Map)['receipt'] as Map,
    ),
    'state': 'committed',
    'arguments_digest': journal['argumentsDigest'],
  });
  expect(jsonEncode(receipt), isNot(contains(_privateHealthNote)));
}

class _HealthUiNotifications extends BilNotificationService {
  _HealthUiNotifications() : super(FlutterLocalNotificationsPlugin());

  int cancellationCalls = 0;
  int pendingReads = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int schedulingCalls = 0;
  Completer<void>? cancellationGate;
  bool cancellationWaiting = false;

  @override
  Future<BilNotificationPermissionState> permissionState() async {
    permissionChecks += 1;
    return BilNotificationPermissionState.denied;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    pendingReads += 1;
    return {};
  }

  @override
  Future<void> cancelFastingSessionNotifications() async {
    cancellationCalls += 1;
    if (cancellationGate case final gate?) {
      cancellationWaiting = true;
      try {
        await gate.future;
      } finally {
        cancellationWaiting = false;
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return false;
  }

  @override
  Future<void> showFastingOngoing({
    required DateTime target,
    required String languageCode,
  }) async {
    schedulingCalls += 1;
  }

  @override
  Future<void> scheduleFastingHydration({
    required DateTime startedAt,
    required DateTime target,
    required String languageCode,
  }) async {
    schedulingCalls += 1;
  }

  @override
  Future<void> scheduleFastingTarget({
    required DateTime target,
    required String languageCode,
  }) async {
    schedulingCalls += 1;
  }
}
