import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_benefit_delivery.dart';
import 'package:body_intelligence_log/features/commerce/services/store_confirmation_journal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PreferencesRepository prefs;
  late StoreConfirmationJournal journal;
  var visit = 0;
  var now = DateTime.utc(2026, 10, 17, 18);
  StoreBenefitDelivery event({
    String key = 'a',
    String environment = 'sandbox',
    bool active = true,
  }) => StoreBenefitDelivery(
    ownerId: 'fixture-A',
    store: 'app_store',
    environment: environment,
    eventKey: List.filled(64, key).join(),
    productId: 'bil_ai_boost',
    verifiedAt: DateTime.now().toUtc(),
    active: active,
    isBoost: true,
    quantity: active ? 730 : 0,
    creditedNow: true,
    finishPending: false,
  );
  setUp(() async {
    visit = 0;
    now = DateTime.utc(2026, 10, 17, 18);
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'fixture-A',
    );
    prefs = PreferencesRepository(db);
    journal = StoreConfirmationJournal(
      prefs,
      () => visit == 0,
      clock: () => now,
      processSession: 'first-process',
    );
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() => db.close());
  test(
    'two simultaneous deliveries and reservations commit one visual event',
    () async {
      final e = event();
      final queued = await Future.wait([
        journal.enqueue(e, userInitiated: true),
        journal.enqueue(e, userInitiated: true),
      ]);
      expect(queued.where((value) => value), hasLength(1));
      final claims = await Future.wait([
        journal.reserve(e),
        journal.reserve(e),
      ]);
      expect(claims.where((value) => value), hasLength(1));
      expect(await journal.painted(e), isTrue);
      expect(await journal.enqueue(e, userInitiated: true), isFalse);
      expect(jsonDecode((await prefs.get(journal.key(e)))!)['state'], 'shown');
    },
  );
  test(
    'waiting resumes; unpainted reserved event recovers once after process restart',
    () async {
      final e = event();
      expect(await journal.enqueue(e, userInitiated: true), isTrue);
      final sameProcess = StoreConfirmationJournal(
        prefs,
        () => true,
        clock: () => now,
        processSession: 'first-process',
      );
      expect(await sameProcess.enqueue(e, userInitiated: false), isTrue);
      expect(await sameProcess.reserve(e), isTrue);
      expect(await sameProcess.enqueue(e, userInitiated: false), isFalse);

      final restarted = StoreConfirmationJournal(
        prefs,
        () => true,
        clock: () => now,
        processSession: 'second-process',
      );
      expect(await restarted.enqueue(e, userInitiated: false), isTrue);
      expect(await restarted.reserve(e), isTrue);
      expect(await restarted.painted(e), isTrue);
      expect(await restarted.enqueue(e, userInitiated: false), isFalse);
      expect(jsonDecode((await prefs.get(journal.key(e)))!)['state'], 'shown');
    },
  );
  test(
    'competing process recoveries cannot duplicate the celebration',
    () async {
      final e = event();
      await journal.enqueue(e, userInitiated: true);
      await journal.reserve(e);
      final resumed = StoreConfirmationJournal(
        prefs,
        () => true,
        clock: () => now,
        processSession: 'resumed-process',
      );
      final other = StoreConfirmationJournal(
        prefs,
        () => true,
        clock: () => now,
        processSession: 'other-process',
      );
      final attempts = await Future.wait([
        resumed.enqueue(e, userInitiated: false),
        other.enqueue(e, userInitiated: false),
      ]);
      expect(attempts.where((approved) => approved), hasLength(1));
      expect(await resumed.enqueue(e, userInitiated: false), isTrue);
      expect(await resumed.reserve(e), isTrue);
      expect(await other.enqueue(e, userInitiated: false), isFalse);
      expect(
        await other.enqueue(
          event(environment: 'production'),
          userInitiated: true,
        ),
        isFalse,
      );
      expect(await resumed.cancel(e), isTrue);
      expect(await resumed.enqueue(e, userInitiated: false), isFalse);
    },
  );
  test(
    'historical, refunded and other environments cannot acquire a celebration',
    () async {
      expect(await journal.enqueue(event(), userInitiated: false), isFalse);
      expect(
        await journal.enqueue(event(active: false), userInitiated: true),
        isFalse,
      );
      final e = event();
      await journal.enqueue(e, userInitiated: true);
      expect(
        await journal.enqueue(
          event(environment: 'production'),
          userInitiated: true,
        ),
        isFalse,
      );
      expect(await journal.reserve(event(environment: 'production')), isFalse);
    },
  );
  test(
    'retired account visit cannot reserve, mark shown or write a new event',
    () async {
      final e = event();
      await journal.enqueue(e, userInitiated: true);
      visit = 2; // A→B→A, UID may be A again but this visit is retired.
      expect(await journal.reserve(e), isFalse);
      expect(await journal.painted(e), isFalse);
      expect(
        await journal.enqueue(event(key: 'b'), userInitiated: true),
        isFalse,
      );
      expect(
        jsonDecode((await prefs.get(journal.key(e)))!)['state'],
        'waiting',
      );
    },
  );
  test(
    'cancellation is separate from rights and retains unknown archive data',
    () async {
      final e = event();
      await journal.enqueue(e, userInitiated: true);
      final row = jsonDecode((await prefs.get(journal.key(e)))!) as Map;
      await prefs.set(
        journal.key(e),
        jsonEncode({
          ...row,
          'future_data': {'receipt': 'fixture-safe'},
        }),
      );
      expect(await journal.cancel(e), isTrue);
      final saved = jsonDecode((await prefs.get(journal.key(e)))!) as Map;
      expect(saved['state'], 'cancelled');
      expect(saved['future_data'], {'receipt': 'fixture-safe'});
      expect(await journal.enqueue(e, userInitiated: true), isFalse);
      expect(
        await db
            .customSelect('SELECT COUNT(*) AS n FROM meal_items')
            .getSingle()
            .then((r) => r.read<int>('n')),
        0,
      );
    },
  );
}
