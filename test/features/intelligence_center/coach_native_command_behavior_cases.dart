part of 'coach_native_command_behavior_test.dart';

void _nativeCommandCases() {
  testWidgets(
    'analytics disabled keeps the confirmed current weight card without any previous history',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_weight', {'weightKg': 82.4, 'date': '2026-10-06'}),
        ],
        (fixture) async {
          await _openNativeAction(tester, 'addWeight', 'log_weight');
          await _confirmNative(tester);
          final saved = (await WeightRepository(
            fixture.database,
          ).getForDay(_day))!;
          expect(saved.weight, 82.4);
          expect(await fixture.receipts(), hasLength(1));
          expect(find.byType(CoachMessagePresentationView), findsOneWidget);
          final visual = tester
              .widget<CoachMessagePresentationView>(
                find.byType(CoachMessagePresentationView),
              )
              .presentation;
          expect(visual.weightPoints.single.kg, 82.4);
          expect(visual.weightPoints.single.dayKey, '2026-10-06');
          expect(visual.notes, ['Weight saved.']);
          expect(find.textContaining('Oct 4, 2026'), findsNothing);
          expect(find.textContaining('-1.6 kg'), findsNothing);
          expect(
            await WeightRepository(fixture.database).getAll(),
            hasLength(2),
          );
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
        seed: (fixture) async {
          await PreferencesRepository(fixture.database).set(
            CoachContextPreferences.storageKey,
            const CoachContextPreferences(
              focuses: <CoachContextFocus>{},
            ).encode(),
          );
          final weights = WeightRepository(fixture.database);
          await weights.addWeight(
            84,
            date: DateTime(2026, 10, 4),
            measurementContext: 'morning',
          );
          await weights.addWeight(
            90,
            date: _day,
            measurementContext: 'morning',
          );
        },
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'confirmed weight body shows saved date and chronological prior without rewriting a same-day record',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_weight', {'weightKg': 82.4, 'date': '2026-10-06'}),
        ],
        (fixture) async {
          final weights = WeightRepository(fixture.database);
          final before = (await weights.getForDay(_day))!;
          await _openNativeAction(tester, 'addWeight', 'log_weight');
          await _confirmNative(tester);
          final saved = (await weights.getForDay(_day))!;
          expect(saved.id, before.id);
          expect(saved.weight, 82.4);
          expect(saved.revision, before.revision + 1);
          expect(await weights.getAll(), hasLength(2));
          expect(await fixture.receipts(), hasLength(1));
          // A genuine negative before enrichment: the write above is proven,
          // but current source still displays only its short plain receipt.
          expect(find.byType(CoachMessagePresentationView), findsOneWidget);
          final visual = tester
              .widget<CoachMessagePresentationView>(
                find.byType(CoachMessagePresentationView),
              )
              .presentation;
          expect(visual.weightPoints.single.dayKey, '2026-10-06');
          expect(visual.weightPoints.single.kg, 82.4);
          expect(find.text('82.4 kg'), findsOneWidget);
          expect(find.text('Weight saved.'), findsOneWidget);
          expect(visual.notes.join('\n'), contains('Oct 4, 2026'));
          expect(visual.notes.join('\n'), contains('-1.6 kg'));
          expect(visual.notes.join('\n'), isNot(contains('-7.6 kg')));
          expect(
            find.byKey(const ValueKey('coach-weight-timeline')),
            findsNothing,
          );
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
        seed: (fixture) async {
          final weights = WeightRepository(fixture.database);
          await weights.addWeight(
            84,
            date: DateTime(2026, 10, 4),
            measurementContext: 'morning',
          );
          await weights.addWeight(
            90,
            date: _day,
            measurementContext: 'morning',
          );
        },
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
  testWidgets(
    'confirmed measurements body shows saved fields and only known prior differences',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('save_measurements', {'waistCm': 87, 'date': '2026-10-06'}),
        ],
        (fixture) async {
          final measurements = BodyMeasurementRepository(fixture.database);
          final before = (await measurements.getForDay(_day))!;
          await _openNativeAction(
            tester,
            'saveMeasurements',
            'save_measurements',
          );
          await _confirmNative(tester);
          final saved = (await measurements.getForDay(_day))!;
          expect(saved.uuid, before.uuid);
          expect(saved.waistCm, 87);
          expect(saved.neckCm, 38);
          expect(saved.chestCm, 101);
          expect(saved.hipsCm, isNull);
          expect(saved.revision, before.revision + 1);
          expect(await fixture.receipts(), hasLength(1));
          expect(find.byType(CoachMessagePresentationView), findsOneWidget);
          final visual = tester
              .widget<CoachMessagePresentationView>(
                find.byType(CoachMessagePresentationView),
              )
              .presentation;
          expect(visual.columns.single.dayKey, '2026-10-06');
          expect(
            visual.columns.single.metrics
                .singleWhere((x) => x.id == 'hips')
                .knownSubtotal,
            isNull,
          );
          expect(find.text('87 cm'), findsOneWidget);
          expect(find.text('Body measurements saved.'), findsOneWidget);
          expect(visual.notes.join('\n'), contains('Oct 4, 2026'));
          expect(visual.notes.join('\n'), contains('Waist: -2 cm'));
          expect(visual.notes.join('\n'), isNot(contains('Neck:')));
          expect(visual.notes.join('\n'), isNot(contains('Chest:')));
          expect(
            find.byKey(const ValueKey('coach-weight-timeline')),
            findsNothing,
          );
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
        seed: (fixture) async {
          final measurements = BodyMeasurementRepository(fixture.database);
          await measurements.saveForDay(
            date: DateTime(2026, 10, 4),
            waistCm: 89,
          );
          await measurements.saveForDay(
            date: _day,
            neckCm: 38,
            waistCm: 90,
            chestCm: 101,
          );
        },
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
  testWidgets('water confirmation rejects delivered owner A B A', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('log_water', {'amountMl': 250}),
      ],
      (fixture) async {
        await _openNativeAction(tester, 'addWater', 'log_water');
        fixture.owner = 'owner-b';
        fixture.owners.add('owner-b');
        fixture.owner = 'owner-a';
        fixture.owners.add('owner-a');
        await _confirmNative(tester);
        expect(
          await fixture.database.select(fixture.database.waterEntries).get(),
          isEmpty,
        );
        expect(await fixture.receipts(), isEmpty);
        expect(fixture.gateway.calls, 1);
      },
      ownerId: 'owner-a',
    );
  });

  testWidgets('weight changed during confirmation is preserved', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('log_weight', {'weightKg': 82.4, 'date': '2026-10-06'}),
      ],
      (fixture) async {
        await _openNativeAction(tester, 'addWeight', 'log_weight');
        await WeightRepository(fixture.database).addWeight(95, date: _day);
        await _confirmNative(tester);
        expect(
          (await WeightRepository(fixture.database).getForDay(_day))!.weight,
          95,
        );
        expect(await fixture.receipts(), isEmpty);
      },
      seed: (fixture) async {
        await WeightRepository(fixture.database).addWeight(90, date: _day);
      },
    );
  });

  testWidgets('water Undo preserves a later revision of its row', (
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
        await _undoNative(tester);
        final current = await fixture.database
            .select(fixture.database.waterEntries)
            .getSingle();
        expect(current.deletedAt, isNull);
        expect(current.amountMl, 777);
        expect(
          (await fixture.receipts()).where(
            (receipt) => receipt['undone_at'] != null,
          ),
          isEmpty,
        );
      },
    );
  });

  testWidgets('weight Undo preserves a later check-in revision', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('log_weight', {'weightKg': 82.4, 'date': '2026-10-06'}),
      ],
      (fixture) async {
        await _openNativeAction(tester, 'addWeight', 'log_weight');
        await _confirmNative(tester);
        await WeightRepository(fixture.database).addWeight(95, date: _day);
        await _undoNative(tester);
        expect(
          (await WeightRepository(fixture.database).getForDay(_day))!.weight,
          95,
        );
        expect(
          (await fixture.receipts()).where(
            (receipt) => receipt['undone_at'] != null,
          ),
          isEmpty,
        );
      },
      seed: (fixture) async {
        await WeightRepository(fixture.database).addWeight(90, date: _day);
      },
    );
  });

  testWidgets('goal Undo preserves later profile changes atomically', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('update_goal', {'targetWeightKg': 79}),
      ],
      (fixture) async {
        await _openNativeAction(tester, 'updateGoal', 'update_goal');
        await _confirmNative(tester);
        await fixture.seedProfile(target: 83, waist: 97);
        await _undoNative(tester);
        final profile = (await UserProfileRepository(
          fixture.database,
        ).getProfile())!;
        expect(profile.targetWeight, 83);
        expect(profile.waist, 97);
        expect(
          (await GoalRepository(fixture.database).getActive())!.targetWeight,
          79,
        );
        expect(
          (await fixture.receipts()).where(
            (receipt) => receipt['undone_at'] != null,
          ),
          isEmpty,
        );
      },
      seed: (fixture) => fixture.seedProfile(),
    );
  });

  testWidgets('measurement receipt includes the committed preserved fields', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('save_measurements', {'waistCm': 87, 'date': '2026-10-06'}),
      ],
      (fixture) async {
        await _openNativeAction(
          tester,
          'saveMeasurements',
          'save_measurements',
        );
        await _confirmNative(tester);
        final row = (await BodyMeasurementRepository(
          fixture.database,
        ).getForDay(_day))!;
        final receipt = (await fixture.receipts()).single;
        final after = receipt['after'] as Map;
        expect(after['neckCm'], row.neckCm);
        expect(after['chestCm'], row.chestCm);
        expect(after['waistCm'], 87);
        expect(after['uuid'], row.uuid);
        expect(after['revision'], row.revision);
      },
      seed: (fixture) => BodyMeasurementRepository(
        fixture.database,
      ).saveForDay(date: _day, neckCm: 38, waistCm: 90, chestCm: 101),
    );
  });

  testWidgets('measurement Undo preserves a later partial edit', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('save_measurements', {'waistCm': 87, 'date': '2026-10-06'}),
      ],
      (fixture) async {
        await _openNativeAction(
          tester,
          'saveMeasurements',
          'save_measurements',
        );
        await _confirmNative(tester);
        await BodyMeasurementRepository(
          fixture.database,
        ).saveForDay(date: _day, chestCm: 104, preserveExistingValues: true);
        await _undoNative(tester);
        final row = (await BodyMeasurementRepository(
          fixture.database,
        ).getForDay(_day))!;
        expect(row.waistCm, 87);
        expect(row.chestCm, 104);
        expect(
          (await fixture.receipts()).where(
            (receipt) => receipt['undone_at'] != null,
          ),
          isEmpty,
        );
      },
      seed: (fixture) => BodyMeasurementRepository(
        fixture.database,
      ).saveForDay(date: _day, waistCm: 90, chestCm: 101),
    );
  });

  testWidgets('memory Undo restores a deduplicated pre-existing memory', (
    tester,
  ) async {
    final original = <String, Object?>{
      'id': 'existing-memory',
      'text': 'I prefer evening workouts',
      'kind': 'preference',
      'status': 'confirmed',
      'confidence': 1.0,
      'savedAt': '2026-10-01T09:00:00.000Z',
      'updatedAt': '2026-10-01T09:00:00.000Z',
      'source': 'explicit_user_confirmation',
    };
    await _withCoach(
      tester,
      [
        _tool('save_memory', {
          'text': 'I prefer evening workouts',
          'kind': 'routine',
        }),
      ],
      (fixture) async {
        await _openNativeAction(tester, 'saveMemory', 'save_memory');
        await _confirmNative(tester);
        expect(
          ((await fixture.receipts()).single['before'] as Map)['exists'],
          isTrue,
        );
        await _undoNative(tester);
        final entries = await CoachMemoryRepository(
          preferences: PreferencesRepository(fixture.database),
        ).readLocal();
        expect(entries, [original]);
      },
      seed: (fixture) => PreferencesRepository(
        fixture.database,
      ).set(CoachMemoryRepository.storageKey, jsonEncode([original])),
    );
  });
}
