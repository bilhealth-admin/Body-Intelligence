part of 'coach_native_command_behavior_test.dart';

void _nativeUndoPermissionCases() {
  for (final entry in _recoveryInputs.entries) {
    for (final restored in [false, true]) {
      testWidgets(
        'read only preserves ${entry.key} on Undo restored=$restored',
        (tester) async {
          await _withCoach(
            tester,
            [_tool(entry.key, entry.value.$2)],
            (fixture) async {
              await _openNativeAction(tester, entry.value.$1, entry.key);
              await _confirmNative(tester);
              await _waitNativeReceipts(tester, fixture, 1);
              if (restored) await _remountNativeCoach(tester, fixture);
              final container = ProviderScope.containerOf(
                tester.element(find.byType(IntelligenceCenterPage)),
              );
              container.read(coachActionPermissionModeProvider.notifier).state =
                  CoachActionPermissionMode.readOnly;
              await tester.pump();
              final before = await _nativeRecoverySnapshot(fixture);
              final receipts = await fixture.receipts();
              await _undoNative(tester);
              expect(await _nativeRecoverySnapshot(fixture), before);
              expect(await fixture.receipts(), receipts);
              expect(
                find.widgetWithText(OutlinedButton, 'Undo'),
                findsOneWidget,
              );
              container.read(coachActionPermissionModeProvider.notifier).state =
                  CoachActionPermissionMode.askBeforeWrite;
              await tester.pump();
              await _undoNative(tester);
              await _waitNativeReceipts(tester, fixture, 2);
              await _expectNativeCompensation(fixture, entry.key);
              expect(fixture.gateway.calls, 1);
              expect(tester.takeException(), isNull);
            },
            seed: _seedNativeRecovery,
            ownerId: 'owner-a',
          );
        },
      );
    }
  }

  for (final boundary in ['journal read', 'journal write']) {
    for (final grantAgain in [false, true]) {
      testWidgets(
        'Undo revoked during $boundary stays cancelled grantAgain=$grantAgain',
        (tester) async {
          await _withCoach(
            tester,
            [
              _tool('log_water', {'amountMl': 250}),
            ],
            (fixture) async {
              await _saveRecoveryWater(tester, fixture);
              await _unmountNativeCoach(tester);
              final before = await _nativeRecoverySnapshot(fixture);
              final preferences = _UndoPermissionPausePreferences(
                fixture.database,
                pauseWrite: boundary == 'journal write',
              );
              fixture.recoveryPreferences = preferences;
              await tester.pumpWidget(_nativeCoachApp(fixture));
              await tester.pumpAndSettle();
              final container = ProviderScope.containerOf(
                tester.element(find.byType(IntelligenceCenterPage)),
              );
              preferences.arm();
              final button = find.widgetWithText(OutlinedButton, 'Undo');
              await Scrollable.ensureVisible(
                tester.element(button),
                alignment: .5,
              );
              await tester.pump(const Duration(milliseconds: 350));
              await tester.tap(button);
              for (
                var attempt = 0;
                attempt < 30 && !preferences.started!.isCompleted;
                attempt++
              ) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(preferences.started!.isCompleted, isTrue);
              container.read(coachActionPermissionModeProvider.notifier).state =
                  CoachActionPermissionMode.readOnly;
              if (grantAgain) {
                container
                        .read(coachActionPermissionModeProvider.notifier)
                        .state =
                    CoachActionPermissionMode.writeAllowed;
              }
              preferences.release();
              await tester.pumpAndSettle();
              expect(await _nativeRecoverySnapshot(fixture), before);
              expect(
                (await fixture.receipts()).where((r) => r['undone_at'] != null),
                isEmpty,
              );
              expect(
                find.widgetWithText(OutlinedButton, 'Undo'),
                findsOneWidget,
              );
              container.read(coachActionPermissionModeProvider.notifier).state =
                  CoachActionPermissionMode.askBeforeWrite;
              await tester.pump();
              await _undoNative(tester);
              await _waitNativeReceipts(tester, fixture, 2);
              final water = await fixture.database
                  .select(fixture.database.waterEntries)
                  .getSingle();
              expect(water.revision, 2);
              expect(water.deletedAt, isNotNull);
              expect(fixture.gateway.calls, 1);
              expect(tester.takeException(), isNull);
            },
            ownerId: 'owner-a',
          );
        },
      );
    }
  }
}

class _UndoPermissionPausePreferences extends _PausedNativeRecoveryPreferences {
  _UndoPermissionPausePreferences(this.database, {required this.pauseWrite})
    : super(database);
  final AppDatabase database;
  final bool pauseWrite;
  @override
  Future<String?> get(String key) async {
    if (!pauseWrite) return super.get(key);
    return PreferencesRepository(database).get(key);
  }

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (pauseWrite &&
        values.keys.any((k) => k.startsWith('coachNativeOperationV1.')) &&
        pending != null &&
        !pending!.isCompleted) {
      if (!started!.isCompleted) started!.complete();
      await pending!.future;
    }
  }
}
