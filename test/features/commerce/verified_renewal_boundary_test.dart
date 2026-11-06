import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late DateTime boundary;
  late String owner;
  late ServerEntitlementRepository repository;
  var serial = 0;
  var mirrorReads = 0;
  var offline = false;
  var adminOffline = false;
  var grantOffline = false;
  Object? adminGrant;
  Map<String, Object?>? row;
  final secure = <String, String>{};

  Map<String, Object?> period({
    DateTime? start,
    DateTime? end,
    int revision = 1,
    String plan = 'premium',
    String lifecycle = 'active',
    String? rowOwner,
  }) => {
    'owner_id': rowOwner ?? owner,
    'provider': 'apple',
    'original_transaction_id': 'synthetic-chain-$owner',
    'plan_id': plan,
    'lifecycle': lifecycle,
    'started_at': (start ?? now.subtract(const Duration(days: 1)))
        .toIso8601String(),
    'expires_at': (end ?? boundary).toIso8601String(),
    'verified_at': now.toIso8601String(),
    'revision': revision,
  };

  Future<void> signIn(String id) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-renewal-token',
        'token_type': 'bearer',
        'user': {
          'id': id,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async {
          final args = Map<String, Object?>.from(call.arguments as Map);
          final key = args['key'] as String;
          switch (call.method) {
            case 'read':
              return secure[key];
            case 'write':
              secure[key] = args['value'] as String;
              return null;
            case 'delete':
              secure.remove(key);
              return null;
            default:
              throw StateError('Unexpected storage operation');
          }
        });
    await Supabase.initialize(
      url: 'https://verified-renewal-fixture.invalid',
      publishableKey: 'synthetic-fixture-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        Object? response;
        switch (request.url.path) {
          case '/rest/v1/bil_ai_closed_test_grants':
            if (grantOffline) return http.Response('unavailable', 503);
            response = const [];
            break;
          case '/rest/v1/bil_subscriptions':
            mirrorReads++;
            expect(request.url.queryParameters['owner_id'], 'eq.$owner');
            if (offline) return http.Response('unavailable', 503);
            response = row == null ? const [] : [row];
            break;
          case '/rest/v1/rpc/bil_get_my_admin_subscription':
            if (adminOffline) return http.Response('unavailable', 503);
            response = adminGrant;
            break;
          default:
            throw StateError('Unexpected fixture request');
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, null);
  });

  setUp(() async {
    now = DateTime.utc(2026, 11, 6, 4, 3, 50);
    boundary = now.add(const Duration(seconds: 10));
    owner = '88000000-0000-4000-8000-${(++serial).toString().padLeft(12, '0')}';
    offline = adminOffline = grantOffline = false;
    adminGrant = null;
    mirrorReads = 0;
    secure.clear();
    row = period();
    repository = ServerEntitlementRepository(clock: () => now);
    await signIn(owner);
  });

  Future<SubscriptionState> stageRenewal({
    Duration gap = Duration.zero,
    int revision = 2,
    String? rowOwner,
    String plan = 'premium',
  }) async {
    final paid = await repository.current();
    expect(paid.plan, CommercePlan.premium);
    row = period(
      start: boundary.add(gap),
      end: boundary.add(const Duration(minutes: 2)),
      revision: revision,
      rowOwner: rowOwner,
      plan: plan,
    );
    return repository.current();
  }

  testWidgets(
    'real repository preserves a contiguous verified renewal at T, including offline',
    (tester) async {
      final staged = await stageRenewal(plan: 'premium_ai_coach');
      expect(staged.currentPeriodEndsAt, boundary);
      expect(staged.verifiedNextPeriod?.startedAt, boundary);
      expect(staged.verifiedNextPeriod?.serverRevision, 2);
      expect(staged.plan, CommercePlan.premium);
      expect(
        staged.verifiedNextPeriod?.plan,
        CommercePlan.premiumAiCoach,
        reason: 'the future tier must never replace current access early',
      );
      final newEnd = boundary.add(const Duration(minutes: 2));
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(() {
            loads++;
            return repository.current();
          }),
          verifiedEntitlementOwnerSeedProvider.overrideWithValue(owner),
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value(owner),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const _Probe()),
      );
      await tester.pump();
      await tester.pump();
      final before = container
          .read(verifiedSubscriptionAccessProvider)
          .requireValue;
      expect(before.currentPeriodEndsAt, boundary);
      expect(before.startedAt!.isBefore(now), isTrue);
      final readsBeforeBoundary = mirrorReads;
      final loadsBeforeBoundary = loads;
      offline = true;
      now = boundary;
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      await tester.pump();
      final renewed = container
          .read(verifiedSubscriptionAccessProvider)
          .requireValue;
      expect(renewed.plan, CommercePlan.premiumAiCoach);
      expect(renewed.startedAt, boundary);
      expect(renewed.currentPeriodEndsAt, newEnd);
      expect(renewed.grants(CommerceEntitlement.advancedIntelligence), isTrue);
      expect(mirrorReads, readsBeforeBoundary + 1);
      expect(loads, loadsBeforeBoundary + 1);
      // Pinned Postgrest retries GET 503 at 1/2/4 seconds within the same load.
      // Drain those retries before checking both bounds or disposing timers.
      for (final seconds in [1, 2, 4]) {
        await tester.pump(Duration(seconds: seconds));
        await tester.pump();
      }
      await container.read(verifiedSubscriptionStateProvider.future);
      await tester.pump();
      expect(mirrorReads, readsBeforeBoundary + 4);
      expect(loads, loadsBeforeBoundary + 1);
      await tester.pump(const Duration(seconds: 3));
      expect(
        mirrorReads,
        readsBeforeBoundary + 4,
        reason: 'SDK attempts stay bounded',
      );
      expect(
        loads,
        loadsBeforeBoundary + 1,
        reason: 'one boundary load, no loop',
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    },
  );

  for (final offlineAtBoundary in [false, true]) {
    testWidgets(
      'no future proof locks at T and reads once (offline=$offlineAtBoundary)',
      (tester) async {
        var loads = 0;
        final container = ProviderContainer(
          overrides: [
            verifiedEntitlementClockProvider.overrideWithValue(() => now),
            verifiedEntitlementLoaderProvider.overrideWithValue(() {
              loads++;
              return repository.current();
            }),
            verifiedEntitlementOwnerSeedProvider.overrideWithValue(owner),
            verifiedEntitlementOwnerProvider.overrideWith(
              (_) => Stream.value(owner),
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _Probe(),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.premium,
        );
        offline = offlineAtBoundary;
        final reads = mirrorReads;
        final loadsBeforeBoundary = loads;
        now = boundary;
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        await tester.pump();
        final access = container.read(verifiedSubscriptionAccessProvider);
        expect(access.value?.plan, CommercePlan.free);
        expect(
          access.value?.grants(CommerceEntitlement.advancedIntelligence),
          isFalse,
        );
        expect(mirrorReads, reads + 1);
        expect(loads, loadsBeforeBoundary + 1);
        if (offlineAtBoundary) {
          for (final seconds in [1, 2, 4]) {
            await tester.pump(Duration(seconds: seconds));
            await tester.pump();
          }
          await container.read(verifiedSubscriptionStateProvider.future);
          await tester.pump();
        }
        final maximumAttempts = offlineAtBoundary ? 4 : 1;
        expect(mirrorReads, reads + maximumAttempts);
        await tester.pump(const Duration(seconds: 3));
        expect(mirrorReads, reads + maximumAttempts);
        expect(loads, loadsBeforeBoundary + 1);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  for (final invalid in ['gap', 'stale', 'cross-owner', 'invalid-end']) {
    test('future $invalid cannot bridge the old paid boundary', () async {
      if (invalid == 'stale') row = period(revision: 3);
      final staged = await stageRenewal(
        gap: invalid == 'gap' ? const Duration(seconds: 10) : Duration.zero,
        revision: 2,
        rowOwner: invalid == 'cross-owner' ? 'another-owner' : null,
      );
      if (invalid == 'invalid-end') {
        row!['expires_at'] = boundary
            .subtract(const Duration(seconds: 1))
            .toIso8601String();
        final invalidState = await repository.current();
        expect(invalidState.verifiedNextPeriod, isNull);
      } else {
        expect(staged.verifiedNextPeriod, isNull);
      }
      offline = true;
      now = boundary;
      final expired = await repository.current();
      expect(expired.plan, CommercePlan.free);
      expect(expired.grants(CommerceEntitlement.advancedIntelligence), isFalse);
    });
  }

  for (final denial in ['free', 'revoked']) {
    test(
      'new verified $denial retires pending proof even if admin/grant read fails',
      () async {
        expect((await stageRenewal()).verifiedNextPeriod, isNotNull);
        now = now.add(const Duration(seconds: 1));
        row = period(
          revision: 3,
          plan: denial == 'free' ? 'free' : 'premium',
          lifecycle: denial == 'free' ? 'inactive' : 'revoked',
        );
        adminOffline = grantOffline = true;
        final denied = await repository.current();
        expect(denied.plan, CommercePlan.free);
        offline = true;
        now = boundary;
        expect((await repository.current()).plan, CommercePlan.free);
        // A lower revision cannot resurrect the scheduled period after denial.
        offline = adminOffline = grantOffline = false;
        row = period(
          start: boundary,
          end: boundary.add(const Duration(minutes: 2)),
          revision: 2,
        );
        expect((await repository.current()).plan, CommercePlan.free);
      },
    );
  }

  test('owner transition retires pending renewal for A -> B -> A', () async {
    expect((await stageRenewal()).verifiedNextPeriod, isNotNull);
    final originalOwner = owner;
    owner = '88000000-0000-4000-8000-999999999999';
    await signIn(owner);
    row = period(plan: 'free', lifecycle: 'inactive');
    expect((await repository.current()).plan, CommercePlan.free);
    owner = originalOwner;
    await signIn(owner);
    offline = true;
    now = boundary;
    expect((await repository.current()).plan, CommercePlan.free);
  });

  test(
    'delivered A -> B -> A retires pending proof without a B repository read',
    () async {
      expect((await stageRenewal()).verifiedNextPeriod, isNotNull);
      await signIn('88000000-0000-4000-8000-888888888888');
      await signIn(owner);
      offline = true;
      now = boundary;
      expect((await repository.current()).plan, CommercePlan.free);
    },
  );

  test(
    'restored encrypted revision fences the first stale active response',
    () async {
      secure['bil.verified-entitlement.v1.$owner'] = jsonEncode({
        'owner_id': owner,
        'plan_id': 'premium',
        'lifecycle': 'active',
        'provider': 'apple',
        'cached_at': now.toIso8601String(),
        'started_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'access_until': boundary.toIso8601String(),
        'verified_at': now.toIso8601String(),
        'server_revision': 10,
        'original_transaction_id': 'synthetic-chain-$owner',
      });
      expect((await repository.current()).serverRevision, 10);
      expect(mirrorReads, 0);
      row = period(plan: 'premium_ai_coach', revision: 9);
      final next = await repository.current();
      expect(next.plan, CommercePlan.premium);
      expect(next.serverRevision, 10);
      expect(mirrorReads, 1);
    },
  );

  for (final futureStore in [false, true]) {
    test(
      'startup selects valid persisted proofs (future store=$futureStore)',
      () async {
        final adminUntil = now.add(const Duration(minutes: 1));
        secure['bil.verified-entitlement.v1.$owner'] = jsonEncode({
          'owner_id': owner,
          'plan_id': 'premium_ai_coach',
          'lifecycle': 'active',
          'provider': 'apple',
          'cached_at': now.toIso8601String(),
          'started_at':
              (futureStore
                      ? now.add(const Duration(seconds: 30))
                      : now.subtract(const Duration(days: 1)))
                  .toIso8601String(),
          'access_until':
              (futureStore ? now.add(const Duration(minutes: 2)) : boundary)
                  .toIso8601String(),
          'verified_at': now.toIso8601String(),
          'server_revision': 10,
          'original_transaction_id': 'synthetic-chain-$owner',
        });
        secure['bil.admin-entitlement-lease.v1.$owner'] = jsonEncode({
          'owner_id': owner,
          'plan_id': 'premium',
          'started_at': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'verified_at': now.toIso8601String(),
          'access_until': adminUntil.toIso8601String(),
        });
        final result = await repository.current();
        expect(
          result.plan,
          futureStore ? CommercePlan.premium : CommercePlan.premiumAiCoach,
        );
        expect(result.provider?.name, futureStore ? isNull : 'apple');
        expect(
          result.currentPeriodEndsAt,
          futureStore ? adminUntil : boundary,
          reason:
              'select a currently valid proof and preserve its own exact boundary',
        );
        expect(mirrorReads, 0);
      },
    );
  }

  for (final storePlan in ['premium_ai_coach', 'premium']) {
    test(
      'independent admin Premium lease survives denial of $storePlan plus RPC outage',
      () async {
        final adminUntil = now.add(const Duration(minutes: 1));
        adminGrant = {
          'owner_id': owner,
          'plan_id': 'premium',
          'created_at': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'access_until': adminUntil.toIso8601String(),
          'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
        };
        row = period(plan: storePlan);
        expect((await repository.current()).plan.id, storePlan);
        now = now.add(const Duration(seconds: 1));
        row = period(plan: 'free', lifecycle: 'inactive', revision: 2);
        adminOffline = true;
        final continued = await repository.current();
        expect(continued.plan, CommercePlan.premium);
        expect(continued.provider, isNull);
        expect(continued.currentPeriodEndsAt, adminUntil);
        offline = true;
        final offlineLease = await repository.current();
        expect(offlineLease.plan, CommercePlan.premium);
        expect(offlineLease.currentPeriodEndsAt, adminUntil);
        now = adminUntil;
        expect((await repository.current()).plan, CommercePlan.free);
      },
    );
  }

  for (final upgrade in [true, false]) {
    testWidgets(
      'verified same-lineage overlap ${upgrade ? 'upgrade' : 'downgrade'} activates then expires without replaying old rights',
      (tester) async {
        boundary = now.add(const Duration(seconds: 30));
        final initial = now;
        final replacementStart = now.add(const Duration(seconds: 10));
        final replacementEnd = now.add(const Duration(seconds: 20));
        final oldPlan = upgrade ? 'premium' : 'premium_ai_coach';
        final newPlan = upgrade ? 'premium_ai_coach' : 'premium';
        row = period(plan: oldPlan);
        await repository.current();
        row = period(
          plan: newPlan,
          start: replacementStart,
          end: replacementEnd,
          revision: 2,
        );
        final staged = await repository.current();
        expect(staged.plan.id, oldPlan);
        expect(staged.verifiedNextPeriod?.plan.id, newPlan);
        final stored = jsonDecode(secure.values.single) as Map;
        expect(
          DateTime.parse(stored['access_until'] as String),
          replacementStart,
          reason: 'only same-lineage replacement caps old encrypted continuity',
        );
        var loads = 0;
        final container = ProviderContainer(
          overrides: [
            verifiedEntitlementClockProvider.overrideWithValue(() => now),
            verifiedEntitlementOwnerSeedProvider.overrideWithValue(owner),
            verifiedEntitlementOwnerProvider.overrideWith(
              (_) => Stream.value(owner),
            ),
            verifiedEntitlementLoaderProvider.overrideWithValue(() {
              loads++;
              return repository.current();
            }),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _Probe(),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          container.read(verifiedSubscriptionAccessProvider).value?.plan.id,
          oldPlan,
        );
        offline = true;
        now = replacementStart;
        await tester.pump(replacementStart.difference(initial));
        await tester.pump();
        expect(
          container.read(verifiedSubscriptionAccessProvider).value?.plan.id,
          newPlan,
        );
        for (final seconds in [1, 2, 4]) {
          now = now.add(Duration(seconds: seconds));
          await tester.pump(Duration(seconds: seconds));
          await tester.pump();
        }
        await container.read(verifiedSubscriptionStateProvider.future);
        await tester.pump();
        final untilExpiry = replacementEnd.difference(now);
        now = replacementEnd;
        await tester.pump(untilExpiry);
        await tester.pump();
        expect(
          container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        for (final seconds in [1, 2, 4]) {
          now = now.add(Duration(seconds: seconds));
          await tester.pump(Duration(seconds: seconds));
          await tester.pump();
        }
        await container.read(verifiedSubscriptionStateProvider.future);
        await tester.pump();
        expect(
          container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(
          loads,
          3,
          reason: 'initial + one start refresh + one expiry refresh',
        );
        expect(
          mirrorReads,
          11,
          reason: 'two setup, one initial, two bounded SDK retry groups',
        );
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  for (final inverse in [false, true]) {
    test(
      'independent store lineage preserves highest valid tier (inverse=$inverse)',
      () async {
        boundary = now.add(const Duration(seconds: 30));
        final start = now.add(const Duration(seconds: 10));
        final end = now.add(const Duration(seconds: 20));
        row = period(plan: inverse ? 'premium_ai_coach' : 'premium');
        await repository.current();
        row = period(
          plan: inverse ? 'premium' : 'premium_ai_coach',
          start: start,
          end: end,
          revision: 2,
        );
        row!['original_transaction_id'] = 'independent-synthetic-chain';
        final staged = await repository.current();
        expect(staged.verifiedNextPeriod, isNotNull);
        expect(
          identical(
            verifiedSubscriptionPeriodAt(
              staged,
              start.subtract(const Duration(microseconds: 1)),
            ),
            staged,
          ),
          isTrue,
          reason: 'an independent future period cannot grant its tier early',
        );
        final atStart = verifiedSubscriptionPeriodAt(staged, start);
        expect(
          atStart.plan,
          CommercePlan.premiumAiCoach,
          reason:
              'independent periods compose the highest currently valid tier',
        );
        expect(
          atStart.currentPeriodEndsAt,
          inverse ? boundary : end,
          reason: 'the selected tier keeps its own exact verified boundary',
        );
        expect(
          atStart.storeOriginalTransactionId,
          inverse
              ? staged.storeOriginalTransactionId
              : 'independent-synthetic-chain',
        );
        final stored = jsonDecode(secure.values.single) as Map;
        expect(DateTime.parse(stored['access_until'] as String), boundary);
        offline = true;
        now = start;
        expect((await repository.current()).plan, CommercePlan.premiumAiCoach);
        now = end;
        expect(
          (await repository.current()).plan,
          inverse ? CommercePlan.premiumAiCoach : CommercePlan.premium,
          reason: 'independent prior chain still has its own verified interval',
        );
      },
    );
  }

  test(
    'new projection revision may select proof with older verification time',
    () async {
      await repository.current();
      row = period(
        start: boundary,
        end: boundary.add(const Duration(minutes: 2)),
        revision: 2,
      );
      row!['verified_at'] = now
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
      expect((await repository.current()).verifiedNextPeriod, isNotNull);
    },
  );
}

class _Probe extends ConsumerWidget {
  const _Probe();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifiedSubscriptionAccessProvider);
    return MaterialApp(home: Text(state.value?.plan.name ?? 'checking'));
  }
}
