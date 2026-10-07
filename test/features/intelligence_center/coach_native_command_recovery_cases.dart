part of 'coach_native_command_behavior_test.dart';

const _recoveryInputs = {
  'log_water': ('addWater', <String, Object?>{'amountMl': 250}),
  'log_weight': (
    'addWeight',
    <String, Object?>{'weightKg': 82.4, 'date': '2026-10-06'},
  ),
  'update_goal': ('updateGoal', <String, Object?>{'targetWeightKg': 79}),
  'save_measurements': (
    'saveMeasurements',
    <String, Object?>{'waistCm': 87, 'date': '2026-10-06'},
  ),
  'save_memory': (
    'saveMemory',
    <String, Object?>{'text': 'Evening workouts', 'kind': 'routine'},
  ),
};
const _recoveryMemory = <String, Object?>{
  'id': 'recovery-existing-memory',
  'text': 'Evening workouts',
  'kind': 'preference',
  'status': 'confirmed',
  'confidence': 1.0,
  'savedAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-01T09:00:00.000Z',
  'source': 'explicit_user_confirmation',
};

void _nativeRecoveryCases() {
  for (final entry in _recoveryInputs.entries) {
    testWidgets('native recovery restores ${entry.key} Undo without replay', (
      tester,
    ) async {
      await _withCoach(
        tester,
        [_tool(entry.key, entry.value.$2)],
        (fixture) async {
          await _openNativeAction(tester, entry.value.$1, entry.key);
          await _confirmNative(tester);
          await _waitNativeReceipts(tester, fixture, 1);
          final original = (await fixture.receipts()).single;
          final before = await _nativeRecoverySnapshot(fixture);
          await _remountNativeCoach(tester, fixture);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
          expect(await _nativeRecoverySnapshot(fixture), before);
          expect(fixture.gateway.calls, 1);
          await _undoNative(tester);
          await _waitNativeReceipts(tester, fixture, 2);
          final undone = (await fixture.receipts()).last;
          expect(undone['operation_id'], original['operation_id']);
          expect(undone['tool_id'], original['tool_id']);
          expect(undone['entity_id'], original['entity_id']);
          expect(undone['verified'], isTrue);
          expect(undone['undone_at'], isNotNull);
          expect(undone['undoable'], isFalse);
          await _expectNativeCompensation(fixture, entry.key);
          final compensated = await _nativeRecoverySnapshot(fixture);
          await _remountNativeCoach(tester, fixture);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(await _nativeRecoverySnapshot(fixture), compensated);
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        seed: _seedNativeRecovery,
        ownerId: 'owner-a',
      );
    });
  }

  for (final invalid in [
    'wrong digest',
    'wrong tool',
    'wrong entity',
    'wrong entity kind',
    'not committed',
    'not verified',
    'already undone',
    'user message',
    'missing journal',
    'corrupt journal',
    'stale row',
  ]) {
    testWidgets('native recovery rejects $invalid without touching data', (
      tester,
    ) async {
      await _withCoach(
        tester,
        [
          _tool('log_water', {'amountMl': 250}),
        ],
        (fixture) async {
          await _openNativeAction(tester, 'addWater', 'log_water');
          await _confirmNative(tester);
          await _waitNativeReceipts(tester, fixture, 1);
          await _unmountNativeCoach(tester);
          final preferences = PreferencesRepository(fixture.database);
          final messages =
              jsonDecode((await preferences.get('intelligenceConversationV1'))!)
                  as List;
          for (final message in messages.whereType<Map>()) {
            final evidence = message['evidence'];
            if (evidence is! List) continue;
            for (var i = 0; i < evidence.length; i++) {
              final raw = evidence[i];
              if (raw is! String || !raw.startsWith('{')) continue;
              final receipt = jsonDecode(raw) as Map;
              if (receipt['committed'] != true) continue;
              switch (invalid) {
                case 'wrong digest':
                  (receipt['after'] as Map)['arguments_digest'] = '0' * 64;
                case 'wrong tool':
                  receipt['tool_id'] = 'log_weight';
                case 'wrong entity':
                  receipt['entity_id'] = '999999';
                case 'wrong entity kind':
                  receipt['entity_type'] = 'weight_entry';
                case 'not committed':
                  receipt['committed'] = false;
                case 'not verified':
                  receipt['verified'] = false;
                case 'already undone':
                  receipt['undone_at'] = '2026-10-06T12:00:00.000Z';
                case 'user message':
                  message['role'] = 'user';
              }
              evidence[i] = jsonEncode(receipt);
            }
          }
          await preferences.set(
            'intelligenceConversationV1',
            jsonEncode(messages),
          );
          final rows = await fixture.database
              .select(fixture.database.preferences)
              .get();
          final journal = rows.singleWhere(
            (row) => row.key.startsWith('coachNativeOperationV1.'),
          );
          if (invalid == 'missing journal') {
            await (fixture.database.delete(
              fixture.database.preferences,
            )..where((row) => row.key.equals(journal.key))).go();
          } else if (invalid == 'corrupt journal') {
            await preferences.set(journal.key, '{broken journal');
          } else if (invalid == 'stale row') {
            await _reviseRecoveryWater(fixture);
          }
          final before = await _nativeRecoverySnapshot(fixture);
          await tester.pumpWidget(_nativeCoachApp(fixture));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(await _nativeRecoverySnapshot(fixture), before);
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
      );
    });
  }

  for (final invalid in ['later row edit', 'A B A', 'sign out and back']) {
    testWidgets('native recovered callback refuses $invalid', (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_water', {'amountMl': 250}),
        ],
        (fixture) async {
          await _openNativeAction(tester, 'addWater', 'log_water');
          await _confirmNative(tester);
          await _waitNativeReceipts(tester, fixture, 1);
          await _remountNativeCoach(tester, fixture);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
          if (invalid == 'later row edit') {
            await _reviseRecoveryWater(fixture);
          } else {
            fixture.owner = invalid == 'A B A' ? 'owner-b' : null;
            fixture.owners.add(fixture.owner);
            fixture.owner = 'owner-a';
            fixture.owners.add(fixture.owner);
          }
          final before = await _nativeRecoverySnapshot(fixture);
          await _undoNative(tester);
          expect(await _nativeRecoverySnapshot(fixture), before);
          expect(
            (await fixture.receipts()).where((r) => r['undone_at'] != null),
            isEmpty,
          );
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
      );
    });
  }
}

Future<void> _unmountNativeCoach(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(Duration.zero);
}

Future<void> _remountNativeCoach(
  WidgetTester tester,
  _NativeFixture fixture,
) async {
  await _unmountNativeCoach(tester);
  await tester.pumpWidget(_nativeCoachApp(fixture));
  await tester.pumpAndSettle();
}

Future<void> _waitNativeReceipts(
  WidgetTester tester,
  _NativeFixture fixture,
  int count,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if ((await fixture.receipts()).length >= count) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect((await fixture.receipts()).length, greaterThanOrEqualTo(count));
}

Future<void> _seedNativeRecovery(_NativeFixture fixture) async {
  await fixture.seedProfile();
  await WeightRepository(fixture.database).addWeight(90, date: _day);
  await BodyMeasurementRepository(
    fixture.database,
  ).saveForDay(date: _day, neckCm: 38, waistCm: 90, chestCm: 101);
  await PreferencesRepository(
    fixture.database,
  ).set(CoachMemoryRepository.storageKey, jsonEncode([_recoveryMemory]));
}

Future<void> _expectNativeCompensation(
  _NativeFixture fixture,
  String tool,
) async {
  switch (tool) {
    case 'log_water':
      expect(
        (await fixture.database
                .select(fixture.database.waterEntries)
                .getSingle())
            .deletedAt,
        isNotNull,
      );
    case 'log_weight':
      expect(
        (await WeightRepository(fixture.database).getForDay(_day))!.weight,
        90,
      );
    case 'update_goal':
      expect(
        (await UserProfileRepository(
          fixture.database,
        ).getProfile())!.targetWeight,
        82,
      );
      expect(await GoalRepository(fixture.database).getActive(), isNull);
    case 'save_measurements':
      final row = (await BodyMeasurementRepository(
        fixture.database,
      ).getForDay(_day))!;
      expect(row.waistCm, 90);
      expect(row.neckCm, 38);
      expect(row.chestCm, 101);
    case 'save_memory':
      expect(
        jsonDecode(
          (await PreferencesRepository(
            fixture.database,
          ).get(CoachMemoryRepository.storageKey))!,
        ),
        [_recoveryMemory],
      );
  }
}

Future<void> _reviseRecoveryWater(_NativeFixture fixture) async {
  final row = await fixture.database
      .select(fixture.database.waterEntries)
      .getSingle();
  await (fixture.database.update(
    fixture.database.waterEntries,
  )..where((value) => value.id.equals(row.id))).write(
    WaterEntriesCompanion(
      amountMl: const Value(777),
      revision: Value(row.revision + 1),
    ),
  );
}

Future<Map<String, Object?>> _nativeRecoverySnapshot(
  _NativeFixture fixture,
) async {
  final db = fixture.database;
  return {
    'water': (await db.select(db.waterEntries).get())
        .map((r) => r.toJson())
        .toList(),
    'weights': (await db.select(db.weightEntries).get())
        .map((r) => r.toJson())
        .toList(),
    'goals': (await db.select(db.goals).get()).map((r) => r.toJson()).toList(),
    'measurements': (await db.select(db.bodyMeasurementEntries).get())
        .map((r) => r.toJson())
        .toList(),
    'profile': (await db.select(db.userProfile).get())
        .map((r) => r.toJson())
        .toList(),
    'journals': (await db.select(db.preferences).get())
        .where(
          (r) =>
              r.key.startsWith('coachNativeOperationV1.') ||
              r.key == CoachMemoryRepository.storageKey,
        )
        .map((r) => r.toJson())
        .toList(),
  };
}
