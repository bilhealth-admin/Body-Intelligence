part of '../coach_page_lifecycle_regression_test.dart';

Future<void> _tapRecoveryRetry(WidgetTester tester) async {
  final retry = find.byKey(const Key('ai-coach-retry'));
  await tester.ensureVisible(retry);
  await tester.pumpAndSettle();
  if (retry.hitTestable().evaluate().isEmpty) {
    await tester.drag(find.byType(CoachAnchoredHistory), const Offset(0, -100));
    await tester.pumpAndSettle();
  }
  expect(retry.hitTestable(), findsOneWidget);
  await tester.tap(retry);
  await tester.pumpAndSettle();
}

Future<void> _sendRecoveryLocal(WidgetTester tester, String question) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    question,
  );
  await tester
      .pump(); // Rebuild the actual enabled send control from the typed draft.
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  await tester.pumpAndSettle();
}

class _UnavailableContextStream extends PreferencesRepository {
  _UnavailableContextStream(super.database);
  @override
  Stream<String?> watch(String key) => key == CoachContextPreferences.storageKey
      ? Stream<String?>.error(StateError('synthetic storage failure'))
      : super.watch(key);
}

void registerCoachRecoveryCases() {
  for (final arabic in [false, true]) {
    testWidgets(
      'terminal refund Check is read-only until a separate explicit Retry tap Arabic=$arabic',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _ReceiptStatusGateway()..receiptState = 'refunded';
        try {
          await _mount(tester, database: db, gateway: gateway, arabic: arabic);
          await _send(tester, gateway, question: 'Explain balanced nutrition');
          await tester.pumpAndSettle();
          expect(
            find.text(arabic ? 'التحقق من حالة الطلب' : 'Check request status'),
            findsOneWidget,
          );
          final original = gateway.boundRequests.single.requestId;
          await _tapRecoveryRetry(tester);
          expect(
            gateway.calls,
            1,
            reason: 'A status tap must not invoke the provider again.',
          );
          expect(gateway.boundRequests, hasLength(1));
          expect(gateway.receiptRequestIds, [original]);
          expect(
            find.text(arabic ? 'إعادة إرسال الطلب' : 'Retry request'),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              arabic
                  ? 'أُعيد رصيد الطلب السابق'
                  : 'previous request was refunded',
              findRichText: true,
            ),
            findsOneWidget,
          );
          await _tapRecoveryRetry(tester);
          expect(gateway.calls, 2);
          expect(gateway.boundRequests, hasLength(2));
          expect(gateway.boundRequests.last.requestId, isNot(original));
          expect(gateway.receiptRequestIds, [original]);
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester);
          await tester.runAsync(db.close);
        }
      },
    );
  }

  for (final arabic in [false, true]) {
    for (final scenario in [
      ('show lunch today', 'Nutrition and meals'),
      ('show activity history 2 days', 'Training and activity'),
      ('show sleep history 2 days', 'Sleep, fasting and habits'),
      ('show progress 2 days', 'Progress analytics'),
    ]) {
      testWidgets(
        'only the denied context category is offered in Coach settings ${scenario.$2} Arabic=$arabic',
        (tester) async {
          const owner = '11111111-1111-4111-8111-111111111111';
          final db = AppDatabase.forTesting(
            NativeDatabase.memory(),
            localOwnerId: owner,
          );
          final preferences = PreferencesRepository(db);
          final gateway = _HeldGateway();
          try {
            await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
            await preferences.set(
              CoachContextPreferences.storageKey,
              const CoachContextPreferences(focuses: {}).encode(),
            );
            final before = await preferences.get(
              CoachContextPreferences.storageKey,
            );
            await _mount(
              tester,
              database: db,
              preferences: preferences,
              gateway: gateway,
              arabic: arabic,
              size: const Size(320, 700),
              textScale: arabic ? 2 : 1,
              messageOwnerWitness: CoachNativeOwnerWitness(
                readOwner: () => owner,
                changes: const Stream.empty(),
              ),
            );
            await _sendRecoveryLocal(tester, scenario.$1);
            final action = find.widgetWithText(
              SnackBarAction,
              arabic ? 'إعدادات المدرب' : 'Coach settings',
            );
            expect(action, findsOneWidget);
            const labels = <String, String>{
              'Nutrition and meals': 'التغذية والوجبات',
              'Training and activity': 'التدريب والنشاط',
              'Sleep, fasting and habits': 'النوم والصيام والعادات',
              'Progress analytics': 'تحليلات التقدم',
            };
            expect(
              tester
                  .widget<Text>(
                    find.byKey(const Key('coach-permission-guidance-body')),
                  )
                  .data,
              contains(arabic ? labels[scenario.$2] : scenario.$2),
            );
            for (final entry in labels.entries) {
              if (entry.key != scenario.$2) {
                expect(
                  tester
                      .widget<Text>(
                        find.byKey(const Key('coach-permission-guidance-body')),
                      )
                      .data,
                  isNot(contains(arabic ? entry.value : entry.key)),
                );
              }
            }
            expect(gateway.calls, 0);
            expect(
              await preferences.get(CoachContextPreferences.storageKey),
              before,
            );
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(
              find.text('Audit Coach settings destination'),
              findsOneWidget,
            );
            expect(
              await preferences.get(CoachContextPreferences.storageKey),
              before,
            );
            expect(gateway.calls, 0);
            expect(tester.takeException(), isNull);
          } finally {
            await _unmount(tester);
            await tester.runAsync(db.close);
          }
        },
      );
    }
  }

  testWidgets(
    'context stream failure remains technical and never offers category permission',
    (tester) async {
      const owner = '11111111-1111-4111-8111-111111111111';
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final preferences = _UnavailableContextStream(db);
      final gateway = _HeldGateway();
      try {
        await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
        await _mount(
          tester,
          database: db,
          preferences: preferences,
          gateway: gateway,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => owner,
            changes: const Stream.empty(),
          ),
        );
        await _sendRecoveryLocal(tester, 'show lunch today');
        expect(
          find.widgetWithText(SnackBarAction, 'Coach settings'),
          findsNothing,
        );
        expect(
          find.textContaining('Nutrition is disabled', findRichText: true),
          findsNothing,
        );
        expect(gateway.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester);
        await tester.runAsync(db.close);
      }
    },
  );

  testWidgets(
    'technical unverified_action_claim is not presented as missing context permission',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = _ReceiptStatusGateway()
        ..failureDiagnostic = 'unverified_action_claim';
      try {
        await _mount(tester, database: db, gateway: gateway);
        await _send(tester, gateway, question: 'Explain balanced nutrition');
        await tester.pumpAndSettle();
        expect(gateway.calls, 1);
        expect(
          find.widgetWithText(SnackBarAction, 'Coach settings'),
          findsNothing,
        );
        expect(
          find.textContaining('This request needs access to'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester);
        await tester.runAsync(db.close);
      }
    },
  );

  testWidgets('old settings guidance cannot navigate after owner A-B-A', (
    tester,
  ) async {
    const firstOwner = '11111111-1111-4111-8111-111111111111';
    var owner = firstOwner;
    final owners = StreamController<String?>.broadcast(sync: true);
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: firstOwner,
    );
    final preferences = PreferencesRepository(db);
    final gateway = _HeldGateway();
    try {
      await LocalDataAccountBoundary(db).bindAuthenticatedOwner(firstOwner);
      await preferences.set(
        CoachContextPreferences.storageKey,
        const CoachContextPreferences(focuses: {}).encode(),
      );
      await _mount(
        tester,
        database: db,
        preferences: preferences,
        gateway: gateway,
        messageOwnerWitness: CoachNativeOwnerWitness(
          readOwner: () => owner,
          changes: owners.stream,
        ),
      );
      await _sendRecoveryLocal(tester, 'show lunch today');
      expect(
        find.widgetWithText(SnackBarAction, 'Coach settings'),
        findsOneWidget,
      );
      owner = '22222222-2222-4222-8222-222222222222';
      owners.add(owner);
      owner = firstOwner;
      owners.add(owner);
      await tester.pump();
      final oldLink = find.widgetWithText(SnackBarAction, 'Coach settings');
      if (oldLink.evaluate().isNotEmpty) await tester.tap(oldLink);
      await tester.pumpAndSettle();
      expect(find.text('Audit Coach settings destination'), findsNothing);
      expect(gateway.calls, 0);
      expect(
        await preferences.get(CoachContextPreferences.storageKey),
        const CoachContextPreferences(focuses: {}).encode(),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester);
      await owners.close();
      await tester.runAsync(db.close);
    }
  });

  testWidgets('unknown status remains status-only through repeated checks', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = _ReceiptStatusGateway()..receiptState = 'unknown';
    try {
      await _mount(tester, database: db, gateway: gateway);
      await _send(tester, gateway, question: 'Explain balanced nutrition');
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await _tapRecoveryRetry(tester);
        expect(gateway.calls, 1);
        expect(gateway.boundRequests, hasLength(1));
        expect(find.text('Check request status'), findsOneWidget);
        expect(find.text('Retry request'), findsNothing);
      }
      expect(gateway.receiptRequestIds, hasLength(2));
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester);
      await tester.runAsync(db.close);
    }
  });

  testWidgets(
    'owner A-B-A during held refunded status cannot expose retry or start another generation',
    (tester) async {
      const firstOwner = '11111111-1111-4111-8111-111111111111';
      const otherOwner = '22222222-2222-4222-8222-222222222222';
      var owner = firstOwner;
      final owners = StreamController<String?>.broadcast(sync: true);
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: firstOwner,
      );
      final gateway = _ReceiptStatusGateway()
        ..receiptState = 'refunded'
        ..statusHold = Completer<void>()
        ..statusEntered = Completer<void>();
      try {
        await LocalDataAccountBoundary(db).bindAuthenticatedOwner(firstOwner);
        await _mount(
          tester,
          database: db,
          gateway: gateway,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => owner,
            changes: owners.stream,
          ),
        );
        await _send(tester, gateway, question: 'Explain balanced nutrition');
        await tester.pumpAndSettle();
        final retry = find.byKey(const Key('ai-coach-retry'));
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        await tester.tap(retry);
        await tester.pump();
        for (var i = 0; i < 20 && !gateway.statusEntered!.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(gateway.statusEntered!.isCompleted, isTrue);
        owner = otherOwner;
        owners.add(owner);
        owner = firstOwner;
        owners.add(owner);
        gateway.statusHold!.complete();
        // The retired owner visit intentionally keeps a privacy/loading surface
        // until a real account boundary replaces it. Observe a bounded frame
        // window rather than waiting for that continuous indicator to settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(gateway.calls, 1);
        expect(gateway.boundRequests, hasLength(1));
        expect(find.text('Retry request'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gateway.statusHold!.isCompleted) gateway.statusHold!.complete();
        await _unmount(tester);
        await owners.close();
        await tester.runAsync(db.close);
      }
    },
  );
}
