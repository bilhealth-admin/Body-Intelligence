import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bil_smart_plan_engine_test.dart' show buildRequest;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BilSmartPlanRepository repository;
  String? owner;
  final now = DateTime.utc(2026, 10, 23, 12);
  BilSmartPlan draft(String id) => BilSmartPlan.decode(
    jsonEncode(
      const BilSmartPlanEngine().generate(buildRequest(), now).toJson()
        ..['id'] = id,
    ),
  );
  setUp(() {
    owner = 'owner-123';
    db = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: owner);
    repository = BilSmartPlanRepository(
      preferences: PreferencesRepository(db),
      currentOwnerId: () => owner,
    );
  });
  tearDown(() => db.close());

  Future<BilSmartPlan> approved() async {
    final first = await repository.save(
      draft('first-plan'),
      expectedRevision: 0,
    );
    return repository.save(
      first.withStatus(BilPlanStatus.active, now),
      expectedRevision: 1,
    );
  }

  test(
    'new draft survives reopening without changing approved plan; activation archives exactly once',
    () async {
      final active = await approved();
      final proposed = await repository.stageDraft(
        draft('next-plan'),
        approved: active,
      );
      final reopened = BilSmartPlanRepository(
        preferences: PreferencesRepository(db),
        currentOwnerId: () => owner,
      );
      expect((await reopened.readFor(owner!))!.encode(), active.encode());
      expect((await reopened.readDraft(owner!))!.encode(), proposed.encode());
      final accepted = proposed.withStatus(
        BilPlanStatus.active,
        now.add(const Duration(minutes: 1)),
      );
      await reopened.activateDraft(accepted);
      expect((await reopened.readFor(owner!))!.encode(), accepted.encode());
      expect(
        (await reopened.readArchives(owner!)).single.encode(),
        active.encode(),
      );
      expect(await reopened.readDraft(owner!), isNull);
      await expectLater(reopened.activateDraft(accepted), throwsStateError);
      expect((await reopened.readArchives(owner!)).length, 1);
    },
  );
  test(
    'new local or remote revision blocks stale draft activation without losing either record',
    () async {
      final active = await approved();
      final proposed = await repository.stageDraft(
        draft('next-plan'),
        approved: active,
      );
      final updated = await repository.save(
        active.withStatus(BilPlanStatus.paused, now),
        expectedRevision: 2,
      );
      await expectLater(
        repository.activateDraft(
          proposed.withStatus(BilPlanStatus.active, now),
        ),
        throwsStateError,
      );
      expect((await repository.readFor(owner!))!.encode(), updated.encode());
      expect((await repository.readDraft(owner!))!.encode(), proposed.encode());
      expect(await repository.readArchives(owner!), isEmpty);
    },
  );
  test(
    'discarding pending draft preserves approved plan and rejects account switching',
    () async {
      final active = await approved();
      final proposed = await repository.stageDraft(
        draft('next-plan'),
        approved: active,
      );
      owner = 'owner-other';
      await expectLater(repository.readDraft('owner-123'), throwsStateError);
      await expectLater(
        repository.activateDraft(
          proposed.withStatus(BilPlanStatus.active, now),
        ),
        throwsStateError,
      );
      owner = 'owner-123';
      await repository.discardDraft(proposed);
      expect(await repository.readDraft(owner!), isNull);
      expect((await repository.readFor(owner!))!.encode(), active.encode());
    },
  );
  test(
    'tampered draft and owner archives cannot cross the local ownership boundary',
    () async {
      final active = await approved();
      final proposed = await repository.stageDraft(
        draft('next-plan'),
        approved: active,
      );
      final foreign = proposed.toJson()..['ownerId'] = 'owner-other';
      await repository.preferences.set(
        repository.draftKey(owner!),
        jsonEncode({'base': active.encode(), 'draft': jsonEncode(foreign)}),
      );
      await expectLater(repository.readDraft(owner!), throwsStateError);
      await repository.preferences.set(
        repository.archiveKey(owner!),
        jsonEncode([jsonEncode(foreign)]),
      );
      await expectLater(repository.readArchives(owner!), throwsStateError);
      expect((await repository.readFor(owner!))!.encode(), active.encode());
    },
  );
  test(
    'privacy deletion is CAS-bound and retains current plan and diary',
    () async {
      final active = await approved();
      final proposed = await repository.stageDraft(
        draft('next-plan'),
        approved: active,
      );
      await repository.activateDraft(
        proposed.withStatus(BilPlanStatus.active, now),
      );
      final current = (await repository.readFor(owner!))!;
      final archiveRaw = await repository.preferences.get(
        repository.archiveKey(owner!),
      );
      await expectLater(
        repository.deleteLocalPreviousPlans(
          owner: owner!,
          expectedArchives: 'stale',
          expectedDraft: null,
        ),
        throwsStateError,
      );
      expect((await repository.readArchives(owner!)).length, 1);
      await repository.deleteLocalPreviousPlans(
        owner: owner!,
        expectedArchives: archiveRaw,
        expectedDraft: null,
      );
      expect(await repository.readArchives(owner!), isEmpty);
      expect((await repository.readFor(owner!))!.encode(), current.encode());
    },
  );
}
