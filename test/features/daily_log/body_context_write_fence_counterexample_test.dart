import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_body_context_page.dart';
import 'package:body_intelligence_log/features/daily_log/domain/daily_body_context_codec.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _repository = StateProvider<DailyLogRepository>(
  (ref) => throw StateError('Provide a synthetic owner repository.'),
);
final _dayA = DateTime(2026, 11, 17);
final _dayB = DateTime(2026, 11, 16);
const _savedA = 'Synthetic saved body note A';
const _savedB = 'Synthetic saved body note B';
final _initialEncoded = DailyBodyContextCodec.encode(
  selected: const {'greatSleep', 'other'},
  note: _savedA,
  other: 'Synthetic detail A',
);
final _note = find.byKey(const Key('daily-log-note-field'));
final _save = find.byKey(const Key('daily-body-context-save-action'));

final class _ControlledRepository extends DailyLogRepository {
  // The real repository still reads/writes Drift. The gates control timing.
  _ControlledRepository(super.database, {bool gateSave = false})
    : saveGate = gateSave ? Completer<void>() : null;

  final Completer<void>? saveGate;
  final saveFinished = Completer<void>();
  final saveReceipts = <int, Completer<void>>{};
  final blockedDay = StreamController<DailyLog?>.broadcast();
  bool blockDayB = false;
  int saveCalls = 0;

  @override
  Stream<DailyLog?> watchForDay(DateTime date) {
    if (blockDayB && date == _dayB) return blockedDay.stream;
    return super.watchForDay(date);
  }

  @override
  Future<void> saveBodyContext({
    required DateTime date,
    String? notes,
    DailyLog? expectedRecord,
    bool expectAbsent = false,
    bool Function()? isCurrent,
  }) async {
    final call = ++saveCalls;
    final receipt = Completer<void>();
    saveReceipts[call] = receipt;
    try {
      // Only the already-issued first write is held. A later ordinary Save
      // really commits through the production repository before release.
      if (saveGate != null && call == 1) await saveGate!.future;
      await super.saveBodyContext(
        date: date,
        notes: notes,
        expectedRecord: expectedRecord,
        expectAbsent: expectAbsent,
        isCurrent: isCurrent,
      );
    } finally {
      if (!saveFinished.isCompleted) saveFinished.complete();
      receipt.complete();
    }
  }
}

final class _Fixture {
  _Fixture(this.databaseA, this.databaseB, this.repositoryA, this.repositoryB);
  final AppDatabase databaseA;
  final AppDatabase databaseB;
  final _ControlledRepository repositoryA;
  final DailyLogRepository repositoryB;
  late final ProviderContainer container;
  late final GoRouter router;

  static Future<_Fixture> mount(
    WidgetTester tester, {
    bool seedA = true,
    bool gateSave = false,
  }) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final databaseA = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'body-owner-a',
    );
    final databaseB = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'body-owner-b',
    );
    final a = _ControlledRepository(databaseA, gateSave: gateSave);
    final b = DailyLogRepository(databaseB);
    final fixture = _Fixture(databaseA, databaseB, a, b);
    await _hostOperation(tester, () async {
      if (seedA) {
        await DailyLogRepository(databaseA).save(
          date: _dayA,
          notes: _initialEncoded,
          sleepHours: 7.25,
          steps: 8123,
          exerciseNotes: 'Synthetic neighbour exercise bytes',
        );
      }
      await DailyLogRepository(
        databaseA,
      ).save(date: _dayB, notes: _savedB, steps: 4321);
      // Equal note/day bytes across owners expose date+notes-only identities.
      await b.saveBodyContext(date: _dayA, notes: _initialEncoded);
    });
    fixture.container = ProviderContainer(
      overrides: [
        _repository.overrideWith((ref) => a),
        dailyLogRepositoryProvider.overrideWith(
          (ref) => ref.watch(_repository),
        ),
        selectedLogDateProvider.overrideWith((ref) => _dayA),
      ],
    );
    fixture.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-body-context'),
                onPressed: () => context.push('/body'),
                child: const Text('Open synthetic body context'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/body',
          builder: (_, _) => const DailyBodyContextPage(returnPath: '/'),
        ),
      ],
    );
    final keepCached = fixture.container.listen(
      selectedDailyLogProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      fixture.router.dispose();
      keepCached.close();
      fixture.container.dispose();
      await a.blockedDay.close();
      await databaseA.close();
      await databaseB.close();
    });
    // The selected-day stream is deliberately fully cached BEFORE page entry.
    await _hostOperation(tester, () async {
      await fixture.container.read(selectedDailyLogProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp.router(
          routerConfig: fixture.router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fixture.open(tester);
    return fixture;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-body-context')));
    await tester.pumpAndSettle();
  }

  Future<void> ready(WidgetTester tester) async {
    await _hostOperation(tester, () async {
      await container.read(selectedDailyLogProvider.future);
    });
    await tester.pumpAndSettle();
  }

  Future<void> refreshed(WidgetTester tester, String? expectedNotes) async {
    await _hostOperation(tester, () async {
      for (var attempt = 0; attempt < 200; attempt++) {
        final value = container.read(selectedDailyLogProvider);
        if (!value.isLoading &&
            !value.hasError &&
            value.asData != null &&
            value.asData!.value?.notes == expectedNotes) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError('The actual selected-day stream did not refresh.');
    });
    await tester.pumpAndSettle();
  }

  Future<void> day(WidgetTester tester, DateTime value) async {
    container.read(selectedLogDateProvider.notifier).state = value;
    await tester.pump();
    await ready(tester);
  }

  Future<void> owner(WidgetTester tester, DailyLogRepository value) async {
    container.read(_repository.notifier).state = value;
    await tester.pump();
    await ready(tester);
  }
}

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

Future<void> _edit(WidgetTester tester, Finder field, String value) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _save,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(_save);
  await tester.pump();
}

void main() {
  for (final transition in ['day', 'owner']) {
    testWidgets(
      'retired $transition A to B to A save cannot overwrite a newer note',
      (tester) async {
        final f = await _Fixture.mount(tester, gateSave: true);
        await _edit(tester, _note, 'Synthetic older submitted note');
        await _tapSave(tester);
        expect(f.repositoryA.saveCalls, 1);
        if (transition == 'day') {
          await f.day(tester, _dayB);
          await f.day(tester, _dayA);
        } else {
          await f.owner(tester, f.repositoryB);
          await f.owner(tester, f.repositoryA);
        }
        await _edit(tester, _note, 'Synthetic newer confirmed note');
        await _tapSave(tester);
        expect(f.repositoryA.saveCalls, 2);
        await _hostOperation(
          tester,
          () => f.repositoryA.saveReceipts[2]!.future,
        );
        final committed = await _hostOperation(
          tester,
          () => f.repositoryA.getForDay(_dayA),
        );
        expect(
          DailyBodyContextCodec.decode(committed!.notes).note,
          'Synthetic newer confirmed note',
        );

        f.repositoryA.saveGate!.complete();
        await _hostOperation(
          tester,
          () => f.repositoryA.saveReceipts[1]!.future,
        );
        final finalRecord = await _hostOperation(
          tester,
          () => f.repositoryA.getForDay(_dayA),
        );
        expect(
          DailyBodyContextCodec.decode(finalRecord!.notes).note,
          'Synthetic newer confirmed note',
        );
        expect(
          (await _hostOperation(
            tester,
            () => f.repositoryB.getForDay(_dayA),
          ))!.notes,
          _initialEncoded,
        );
        expect(
          (await _hostOperation(
            tester,
            () => f.repositoryA.getForDay(_dayB),
          ))!.notes,
          _savedB,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'body context read failure exposes Retry and reloads the saved day',
    (tester) async {
      final f = await _Fixture.mount(tester);
      f.repositoryA.blockDayB = true;
      f.container.read(selectedLogDateProvider.notifier).state = _dayB;
      await tester.pump();
      await _hostOperation(tester, () async {
        f.repositoryA.blockedDay.addError(
          StateError('Synthetic local read failure'),
        );
      });
      await tester.pumpAndSettle();
      expect(f.container.read(selectedDailyLogProvider).hasError, isTrue);
      expect(_note, findsNothing);
      expect(tester.widget<FilledButton>(_save).onPressed, isNull);
      final retry = find.widgetWithText(FilledButton, 'Try again');
      expect(retry, findsOneWidget);
      f.repositoryA.blockDayB = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await f.ready(tester);
      expect(_text(tester, _note), _savedB);
      expect(f.repositoryA.saveCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<T> _hostOperation<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  var complete = false;
  T? result;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    Future<T>.sync(operation).then<void>(
      (value) {
        result = value;
        complete = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    );
  });
  final elapsed = Stopwatch()..start();
  while (!complete && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    complete,
    isTrue,
    reason: 'Synthetic body-context persistence did not finish',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return result as T;
}
