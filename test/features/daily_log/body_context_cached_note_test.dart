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
final _other = find.byKey(const Key('body-context-other-field'));
final _save = find.byKey(const Key('daily-body-context-save-action'));

final class _ControlledRepository extends DailyLogRepository {
  // The real repository still reads/writes Drift. The gates control timing.
  _ControlledRepository(super.database, {bool gateSave = false})
    : saveGate = gateSave ? Completer<void>() : null;

  final Completer<void>? saveGate;
  final saveFinished = Completer<void>();
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
    saveCalls++;
    try {
      if (saveGate != null) await saveGate!.future;
      await super.saveBodyContext(
        date: date,
        notes: notes,
        expectedRecord: expectedRecord,
        expectAbsent: expectAbsent,
        isCurrent: isCurrent,
      );
    } finally {
      // A deliberately retired write can reject; its completion still retires
      // the fixture gate without pretending that a database write committed.
      if (!saveFinished.isCompleted) saveFinished.complete();
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

Future<void> _waitForSaved(WidgetTester tester, _Fixture fixture) async {
  await _hostOperation(tester, () => fixture.repositoryA.saveFinished.future);
  final currentRepository = fixture.container.read(dailyLogRepositoryProvider);
  final currentDate = fixture.container.read(selectedLogDateProvider);
  final row = await _hostOperation(
    tester,
    () => currentRepository.getForDay(currentDate),
  );
  await fixture.refreshed(tester, row?.notes);
}

void main() {
  testWidgets(
    'cached AsyncData seeds a saved note and structured detail on entry',
    (tester) async {
      await _Fixture.mount(tester);
      expect(_text(tester, _note), _savedA);
      expect(_text(tester, _other), 'Synthetic detail A');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual save then cached reopen preserves body and neighbour fields',
    (tester) async {
      final f = await _Fixture.mount(tester);
      await _edit(tester, _note, 'Synthetic edited saved note');
      await _tapSave(tester);
      await _waitForSaved(tester, f);
      expect(find.byKey(const Key('open-body-context')), findsOneWidget);
      await f.open(tester);
      expect(_text(tester, _note), 'Synthetic edited saved note');
      expect(_text(tester, _other), 'Synthetic detail A');
      final row = await _hostOperation(
        tester,
        () => f.repositoryA.getForDay(_dayA),
      );
      final decoded = DailyBodyContextCodec.decode(row!.notes);
      expect(decoded.note, 'Synthetic edited saved note');
      expect(decoded.selected, {'greatSleep', 'other'});
      expect(row.sleepHours, 7.25);
      expect(row.steps, 8123);
      expect(row.exerciseNotes, 'Synthetic neighbour exercise bytes');
      final neighbour = await _hostOperation(
        tester,
        () => f.repositoryA.getForDay(_dayB),
      );
      expect(neighbour!.notes, _savedB);
      expect(neighbour.steps, 4321);
    },
  );

  testWidgets('cached no-row data permits a first ordinary save and reopen', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester, seedA: false);
    expect(_text(tester, _note), isEmpty);
    await _edit(tester, _note, 'Synthetic first body note');
    await _tapSave(tester);
    await _waitForSaved(tester, f);
    await f.open(tester);
    expect(_text(tester, _note), 'Synthetic first body note');
  });

  testWidgets('clean editor accepts a later saved body-context update', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester);
    await _hostOperation(
      tester,
      () => DailyLogRepository(
        f.databaseA,
      ).saveBodyContext(date: _dayA, notes: 'Synthetic updated stored note'),
    );
    await f.refreshed(tester, 'Synthetic updated stored note');
    expect(_text(tester, _note), 'Synthetic updated stored note');
    expect(_other, findsNothing);
  });

  testWidgets('dirty note detail and option survive a background row update', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester);
    await _edit(tester, _note, 'Synthetic unsaved local draft');
    await _edit(tester, _other, 'Synthetic unsaved detail');
    final option = find.byKey(const Key('body-context-poorSleep'));
    await Scrollable.ensureVisible(tester.element(option), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(option.hitTestable(), findsOneWidget);
    await tester.tap(option);
    await tester.pump();
    await _hostOperation(
      tester,
      () => DailyLogRepository(
        f.databaseA,
      ).saveBodyContext(date: _dayA, notes: 'Synthetic unrelated refresh'),
    );
    await f.refreshed(tester, 'Synthetic unrelated refresh');
    expect(_text(tester, _note), 'Synthetic unsaved local draft');
    expect(_text(tester, _other), 'Synthetic unsaved detail');
    await _tapSave(tester);
    await _waitForSaved(tester, f);
    final row = await _hostOperation(
      tester,
      () => f.repositoryA.getForDay(_dayA),
    );
    final decoded = DailyBodyContextCodec.decode(row!.notes);
    expect(decoded.note, 'Synthetic unsaved local draft');
    expect(decoded.other, 'Synthetic unsaved detail');
    expect(decoded.selected, containsAll({'greatSleep', 'other', 'poorSleep'}));
  });

  testWidgets('day A to B to A retires the unsaved draft', (tester) async {
    final f = await _Fixture.mount(tester);
    await _edit(tester, _note, 'Synthetic A draft must retire');
    await f.day(tester, _dayB);
    expect(_text(tester, _note), _savedB);
    await _edit(tester, _note, 'Synthetic B draft must retire');
    await f.day(tester, _dayA);
    expect(_text(tester, _note), _savedA);
    expect(_text(tester, _other), 'Synthetic detail A');
  });

  testWidgets(
    'owner A to B to A retires draft even with equal date and note bytes',
    (tester) async {
      final f = await _Fixture.mount(tester);
      await _edit(tester, _note, 'Synthetic owner A draft must retire');
      await f.owner(tester, f.repositoryB);
      expect(_text(tester, _note), _savedA);
      expect(_text(tester, _other), 'Synthetic detail A');
      await _edit(tester, _note, 'Synthetic owner B draft must retire');
      await f.owner(tester, f.repositoryA);
      expect(_text(tester, _note), _savedA);
      expect(_text(tester, _other), 'Synthetic detail A');
    },
  );

  testWidgets(
    'new day waits for fresh data and cannot save the prior day draft',
    (tester) async {
      final f = await _Fixture.mount(tester);
      await _edit(tester, _note, 'Synthetic A draft');
      f.repositoryA.blockDayB = true;
      f.container.read(selectedLogDateProvider.notifier).state = _dayB;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_note, findsNothing);
      await tester.scrollUntilVisible(
        _save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(_save).onPressed, isNull);
      expect(f.repositoryA.saveCalls, 0);
      final b = await _hostOperation(
        tester,
        () => f.repositoryA.getForDay(_dayB),
      );
      f.repositoryA.blockedDay.add(b);
      await f.ready(tester);
      expect(_text(tester, _note), _savedB);
    },
  );

  testWidgets('old save completion cannot navigate after day and owner ABA', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester, gateSave: true);
    await _edit(tester, _note, 'Synthetic submitted A note');
    await _tapSave(tester);
    expect(f.repositoryA.saveCalls, 1);
    await f.day(tester, _dayB);
    await f.day(tester, _dayA);
    await f.owner(tester, f.repositoryB);
    await f.owner(tester, f.repositoryA);
    f.repositoryA.saveGate!.complete();
    await _waitForSaved(tester, f);
    expect(find.byType(DailyBodyContextPage), findsOneWidget);
    expect(find.byKey(const Key('open-body-context')), findsNothing);
    final otherOwner = await _hostOperation(
      tester,
      () => f.repositoryB.getForDay(_dayA),
    );
    expect(otherOwner!.notes, _initialEncoded);
    final otherDay = await _hostOperation(
      tester,
      () => f.repositoryA.getForDay(_dayB),
    );
    expect(otherDay!.notes, _savedB);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new edits during a pending save remain available after completion',
    (tester) async {
      final f = await _Fixture.mount(tester, gateSave: true);
      await _edit(tester, _note, 'Synthetic submitted first draft');
      await _tapSave(tester);
      await _edit(tester, _note, 'Synthetic newer unsaved draft');
      f.repositoryA.saveGate!.complete();
      await _waitForSaved(tester, f);
      expect(find.byType(DailyBodyContextPage), findsOneWidget);
      expect(_text(tester, _note), 'Synthetic newer unsaved draft');
      final row = await _hostOperation(
        tester,
        () => f.repositoryA.getForDay(_dayA),
      );
      expect(
        DailyBodyContextCodec.decode(row!.notes).note,
        'Synthetic submitted first draft',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending completion after page disposal does not read WidgetRef',
    (tester) async {
      final f = await _Fixture.mount(tester, gateSave: true);
      await _edit(tester, _note, 'Synthetic submitted then left');
      await _tapSave(tester);
      f.router.pop();
      await tester.pumpAndSettle();
      f.repositoryA.saveGate!.complete();
      await _waitForSaved(tester, f);
      expect(find.byKey(const Key('open-body-context')), findsOneWidget);
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
