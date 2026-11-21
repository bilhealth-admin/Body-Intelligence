import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
var _ordinal = 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'strict empty snapshot is verified Free from all three network sources',
    () async {
      final h = await _Harness.open();
      try {
        final result = await h.repo.currentForExplicitCheckoutRecovery();
        expect(result.plan, CommercePlan.free);
        expect(result.authority, EntitlementAuthority.verifiedServer);
        expect(h.seen, [_closedPath, _storePath, _adminPath]);
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );

  for (final provider in ['apple', 'google']) {
    test(
      '$provider keeps a confirmed Free display through a completed outage',
      () async {
        final h = await _Harness.open();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(h.owner),
            verifiedEntitlementClockProvider.overrideWithValue(() => h.now),
            verifiedEntitlementLoaderProvider.overrideWithValue(h.repo.current),
          ],
        );
        final display = container.listen(
          verifiedSubscriptionPresentationProvider,
          (_, _) {},
        );
        try {
          final confirmed = await container.read(
            verifiedSubscriptionStateProvider.future,
          );
          expect(confirmed.plan, CommercePlan.free);
          expect(confirmed.authority, EntitlementAuthority.verifiedServer);
          expect(confirmed.provider, isNull);
          expect(display.read().requireValue, same(confirmed));

          h.failAdmin = true;
          final unavailable = await container.refresh(
            verifiedSubscriptionStateProvider.future,
          );
          expect(unavailable.authority, EntitlementAuthority.localDefault);
          expect(
            container.read(verifiedSubscriptionAccessProvider).requireValue,
            same(unavailable),
          );
          expect(display.read().requireValue, same(confirmed));

          h.failAdmin = false;
          h.failClosed = true;
          h.storeRows = [
            h.paidRow(provider: provider)
              ..['plan_id'] = 'free'
              ..['lifecycle'] = 'revoked'
              ..['revision'] = 9,
          ];
          final partial = await container.refresh(
            verifiedSubscriptionStateProvider.future,
          );
          expect(partial.authority, EntitlementAuthority.localDefault);
          expect(partial.serverRevision, 9);
          expect(
            container
                .read(verifiedSubscriptionAccessProvider)
                .requireValue
                .authority,
            EntitlementAuthority.localDefault,
          );
          expect(display.read().requireValue, same(confirmed));

          h.failClosed = false;
          h.storeRows = [h.paidRow(provider: provider)];
          final paid = await container.refresh(
            verifiedSubscriptionStateProvider.future,
          );
          expect(paid.plan, CommercePlan.premiumAiCoach);
          expect(display.read().requireValue.plan, paid.plan);

          h.storeRows = [
            h.paidRow(provider: provider)
              ..['lifecycle'] = 'refunded'
              ..['revision'] = 11,
          ];
          await container.refresh(verifiedSubscriptionStateProvider.future);
          expect(
            container
                .read(verifiedSubscriptionAccessProvider)
                .requireValue
                .plan,
            CommercePlan.free,
          );
          expect(display.read().requireValue.plan, CommercePlan.free);
        } finally {
          display.close();
          container.dispose();
          await h.close();
        }
      },
    );
  }

  for (final item in <({String id, String provider, CommercePlan plan})>[
    (id: 'premium', provider: 'google', plan: CommercePlan.premium),
    (
      id: 'premium_ai_coach',
      provider: 'apple',
      plan: CommercePlan.premiumAiCoach,
    ),
    (id: 'plus', provider: 'google', plan: CommercePlan.plus),
  ]) {
    test(
      'strict fresh ${item.id} is allowed; verified_at need not be new',
      () async {
        final h = await _Harness.open();
        try {
          h.storeRows = [
            h.paidRow(plan: item.id, provider: item.provider)
              ..['verified_at'] = h.now
                  .subtract(const Duration(days: 7))
                  .toIso8601String(),
          ];
          final result = await h.repo.currentForExplicitCheckoutRecovery();
          expect(result.plan, item.plan);
          expect(result.authority, EntitlementAuthority.verifiedServer);
          expect(result.verifiedAt, h.now.subtract(const Duration(days: 7)));
          expect(h.seen, [_closedPath, _storePath, _adminPath]);
          expect(h.storageOperations, isEmpty);
        } finally {
          await h.close();
        }
      },
    );
  }

  test(
    'fresh independent admin grant is verified after complete store read',
    () async {
      final h = await _Harness.open();
      try {
        h.adminBody = h.adminGrant();
        final result = await h.repo.currentForExplicitCheckoutRecovery();
        expect(result.plan, CommercePlan.premium);
        expect(result.authority, EntitlementAuthority.verifiedServer);
        expect(h.seen, [_closedPath, _storePath, _adminPath]);
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );

  test(
    'fresh closed-test grant still requires actual store and admin reads',
    () async {
      final h = await _Harness.open();
      try {
        h.closedRows = [h.closedGrant()];
        final result = await h.repo.currentForExplicitCheckoutRecovery();
        expect(result.plan, CommercePlan.premiumAiCoach);
        expect(result.authority, EntitlementAuthority.verifiedServer);
        expect(h.seen, [_closedPath, _storePath, _adminPath]);
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );

  for (final admin in [false, true]) {
    test(
      'passive malformed grant keeps only its proven lease: admin=$admin',
      () async {
        final h = await _Harness.open();
        try {
          if (admin) {
            h.adminBody = h.adminGrant();
          } else {
            h.closedRows = [h.closedGrant()];
          }
          final first = await h.repo.current();
          final tier = admin
              ? CommercePlan.premium
              : CommercePlan.premiumAiCoach;
          expect(first.plan, tier);
          final cutoff = h.now.add(const Duration(minutes: 5));
          h.now = h.now.add(const Duration(seconds: 30));
          if (admin) {
            h.adminBody = {'owner_id': h.owner, 'plan_id': 'premium'};
          } else {
            h.closedRows = [
              {'active': 'true', 'expires_at': 'unknown'},
            ];
          }
          final second = await h.repo.current();
          expect(second.plan, tier);
          expect(second.authority, EntitlementAuthority.verifiedServer);
          expect(second.currentPeriodEndsAt, cutoff);
          h.now = cutoff;
          final expired = await h.repo.current();
          expect(expired.plan, CommercePlan.free);
          expect(expired.authority, EntitlementAuthority.localDefault);
          h.adminBody = null;
          h.closedRows = [];
          final denied = await h.repo.current();
          expect(denied.plan, CommercePlan.free);
          expect(denied.authority, EntitlementAuthority.verifiedServer);
        } finally {
          await h.close();
        }
      },
    );
  }

  for (final latestPaid in [false, true]) {
    test(
      'a late admin response cannot reverse the newer decision: paid=$latestPaid',
      () async {
        final h = await _Harness.open();
        try {
          final pending = Completer<Object?>();
          h.holdNextAdmin = pending;
          h.adminEntered = Completer<void>();
          final older = h.repo.current();
          await h.adminEntered!.future.timeout(const Duration(seconds: 5));
          final grant = h.adminGrant();
          h.adminBody = latestPaid ? grant : null;
          final newest = await h.repo.current();
          final expected = latestPaid
              ? CommercePlan.premium
              : CommercePlan.free;
          expect(newest.plan, expected);
          pending.complete(latestPaid ? null : grant);
          final late = await older;
          expect(late.plan, expected);
          h.failAdmin = true;
          expect((await h.repo.current()).plan, expected);
        } finally {
          await h.close();
        }
      },
    );
  }

  test(
    'invalid admin read cleanup cannot erase a newer accepted secure lease',
    () async {
      final h = await _Harness.open();
      final secure = _HeldAdminSecureStore();
      final store = AdminEntitlementContinuityStore(secureStore: secure);
      final repo = ServerEntitlementRepository(
        adminContinuityStore: store,
        clock: () => h.now,
      );
      final key = 'bil.admin-entitlement-lease.v1.${h.owner}';
      secure.saved[key] = jsonEncode({
        'owner_id': h.owner,
        'plan_id': 'premium',
        'verified_at': h.now
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
        'started_at': h.now
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'access_until': h.now
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      });
      final grant = h.adminGrant();
      final accessUntil = DateTime.parse(grant['access_until']! as String);
      final adminReply = Completer<Object?>();
      try {
        // The first cold read captures an expired slot, then pauses before
        // read() can validate it and delete it.
        final older = repo.current();
        await secure.readEntered.future.timeout(const Duration(seconds: 5));
        h.holdNextAdmin = adminReply;
        h.adminEntered = Completer<void>();
        final newer = repo.current();
        await h.adminEntered!.future.timeout(const Duration(seconds: 5));
        adminReply.complete(grant);
        // Drain the in-memory HTTP response chain. On the old implementation
        // the new grant is already written; the fixed queue holds that write.
        await Future<void>.delayed(Duration.zero);
        secure.releaseRead.complete();
        final results = await Future.wait([
          older,
          newer,
        ]).timeout(const Duration(seconds: 5));
        for (final result in results) {
          expect(result.plan, CommercePlan.premium);
          expect(result.authority, EntitlementAuthority.verifiedServer);
          expect(result.currentPeriodEndsAt, accessUntil);
        }
        // Prove both the invalid-read deletion and the newer write occurred.
        // Persisted proof is then read through the unchanged security validator.
        expect(
          secure.operations.where((value) => value == 'delete'),
          hasLength(1),
        );
        expect(
          secure.operations.where((value) => value == 'write'),
          hasLength(1),
        );
        final restored = await store.read(ownerId: h.owner, now: h.now);
        expect(
          restored?.plan,
          CommercePlan.premium,
          reason:
              'older invalid-read cleanup must not delete the newer secure lease',
        );
        expect(restored?.currentPeriodEndsAt, accessUntil);
      } finally {
        if (!secure.releaseRead.isCompleted) secure.releaseRead.complete();
        if (!adminReply.isCompleted) adminReply.complete(grant);
        await h.close();
      }
    },
  );

  test(
    'verified store denial cannot decide an unreadable independent admin grant',
    () async {
      final h = await _Harness.open();
      try {
        await h.primePaid();
        h.storeRows = [
          h.paidRow()..addAll({
            'plan_id': 'free',
            'lifecycle': 'inactive',
            'revision': 11,
          }),
        ];
        h.adminBody = {'owner_id': h.owner, 'plan_id': 'premium'};
        final partial = await h.repo.current();
        expect(partial.plan, CommercePlan.free);
        expect(partial.authority, EntitlementAuthority.localDefault);
        expect(partial.serverRevision, 11);
        expect(partial.storeRenewalDefinitivelyInactive, isTrue);
        h.adminBody = null;
        final complete = await h.repo.current();
        expect(complete.plan, CommercePlan.free);
        expect(complete.authority, EntitlementAuthority.verifiedServer);
      } finally {
        await h.close();
      }
    },
  );

  final failures = <String, void Function(_Harness)>{
    'mirror transport failure cannot reuse verified paid cache': (h) =>
        h.failStore = true,
    'malformed timestamp cannot reuse verified paid cache': (h) =>
        h.storeRows.single['verified_at'] = 'invalid',
    'wrong owner row cannot reuse verified paid cache': (h) =>
        h.storeRows.single['owner_id'] = _otherOwner,
    'unknown provider cannot reuse verified paid cache': (h) =>
        h.storeRows.single['provider'] = 'unknown',
    'malformed paid revision cannot reuse verified paid cache': (h) =>
        h.storeRows.single['revision'] = 'bad',
    'future period cannot borrow cached current paid period': (h) {
      h.storeRows.single['started_at'] = h.now
          .add(const Duration(days: 1))
          .toIso8601String();
    },
    'failed independent closed-test read remains unverified': (h) =>
        h.failClosed = true,
    'malformed independent closed-test row remains unverified': (h) {
      h.closedRows = [
        {
          'active': 'true',
          'expires_at': h.now.add(const Duration(days: 1)).toIso8601String(),
        },
      ];
    },
    'failed admin read cannot use old admin or store authority': (h) =>
        h.failAdmin = true,
    'malformed non-null admin response is not a null grant': (h) {
      h.adminBody = h.adminGrant()..['owner_id'] = _otherOwner;
    },
    'fresh closed-test grant cannot hide a failed store source': (h) {
      h.closedRows = [h.closedGrant()];
      h.failStore = true;
    },
    'duplicate store rows are not a complete canonical snapshot': (h) {
      h.storeRows = [h.paidRow(), h.paidRow()];
    },
  };
  for (final entry in failures.entries) {
    test(
      'strict: ${entry.key}; normal paid continuity remains intact',
      () async {
        final h = await _Harness.open();
        try {
          await h.primePaid();
          final savedBefore = Map<String, String>.from(h.saved);
          h.seen.clear();
          h.storageOperations.clear();
          entry.value(h);
          final result = await h.repo.currentForExplicitCheckoutRecovery();
          expect(result.authority, EntitlementAuthority.localDefault);
          expect(h.seen, contains(_closedPath));
          expect(h.seen, contains(_storePath));
          expect(h.storageOperations, isEmpty);
          expect(h.saved, savedBefore);
          // The strict proof is never published as a new UI/access entitlement.
          h.failClosed = true;
          h.failStore = true;
          h.failAdmin = true;
          final normal = await h.repo.current();
          expect(normal.plan, CommercePlan.premiumAiCoach);
          expect(normal.authority, EntitlementAuthority.verifiedServer);
        } finally {
          await h.close();
        }
      },
    );
  }

  test(
    'fresh empty snapshot proves Free without deleting an old paid lease',
    () async {
      final h = await _Harness.open();
      try {
        await h.primePaid();
        final before = Map<String, String>.from(h.saved);
        h.storeRows = [];
        h.seen.clear();
        h.storageOperations.clear();
        final result = await h.repo.currentForExplicitCheckoutRecovery();
        expect(result.plan, CommercePlan.free);
        expect(result.authority, EntitlementAuthority.verifiedServer);
        expect(h.seen, [_closedPath, _storePath, _adminPath]);
        expect(h.saved, before);
        expect(h.storageOperations, isEmpty);
        h.failClosed = true;
        h.failStore = true;
        h.failAdmin = true;
        expect((await h.repo.current()).plan, CommercePlan.premiumAiCoach);
      } finally {
        await h.close();
      }
    },
  );

  test(
    'a newer closed-test observation retires strict read held at admin',
    () async {
      final h = await _Harness.open();
      try {
        await h.primePaid();
        final entered = Completer<void>();
        final held = Completer<Object?>();
        h.adminEntered = entered;
        h.holdNextAdmin = held;
        final pending = h.repo.currentForExplicitCheckoutRecovery();
        await entered.future.timeout(const Duration(seconds: 5));
        h.storeRows = [h.paidRow()..['plan_id'] = 'free'];
        final newer = await h.repo.current();
        expect(newer.plan, CommercePlan.free);
        expect(newer.authority, EntitlementAuthority.verifiedServer);
        final savedAfterNewer = Map<String, String>.from(h.saved);
        h.storageOperations.clear();
        held.complete(null);
        expect(
          (await pending.timeout(const Duration(seconds: 5))).authority,
          EntitlementAuthority.localDefault,
        );
        expect(h.saved, savedAfterNewer);
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );

  test(
    'newer ordinary revocation retires held strict read even when closed lookup fails',
    () async {
      final h = await _Harness.open();
      final held = Completer<Object?>();
      try {
        await h.primePaid();
        h.adminEntered = Completer<void>();
        h.holdNextAdmin = held;
        final old = h.repo.currentForExplicitCheckoutRecovery();
        await h.adminEntered!.future.timeout(const Duration(seconds: 5));
        h.failClosed = true;
        h.storeRows = [
          h.paidRow()
            ..['plan_id'] = 'free'
            ..['lifecycle'] = 'revoked'
            ..['revision'] = 11,
        ];
        final newer = await h.repo.current();
        expect(newer.plan, CommercePlan.free);
        final savedAfterNewer = Map<String, String>.from(h.saved);
        h.storageOperations.clear();
        held.complete(null);
        final retired = await old.timeout(const Duration(seconds: 5));
        expect(retired.authority, EntitlementAuthority.localDefault);
        expect(h.saved, savedAfterNewer);
        expect(h.storageOperations, isEmpty);
        expect(h.seen.where((path) => path == _storePath).length, 3);
      } finally {
        if (!held.isCompleted) held.complete(null);
        await h.close();
      }
    },
  );

  test(
    'paid lease crossing expiry during admin await cannot certify strict snapshot',
    () async {
      final h = await _Harness.open();
      final held = Completer<Object?>();
      try {
        await h.primePaid();
        h.storeRows = [
          h.paidRow()
            ..['expires_at'] = h.now
                .add(const Duration(seconds: 1))
                .toIso8601String(),
        ];
        final before = Map<String, String>.from(h.saved);
        h.adminEntered = Completer<void>();
        h.holdNextAdmin = held;
        h.storageOperations.clear();
        final pending = h.repo.currentForExplicitCheckoutRecovery();
        await h.adminEntered!.future.timeout(const Duration(seconds: 5));
        h.now = h.now.add(const Duration(seconds: 2));
        held.complete(null);
        expect(
          (await pending.timeout(const Duration(seconds: 5))).authority,
          EntitlementAuthority.localDefault,
        );
        expect(h.saved, before);
        expect(h.storageOperations, isEmpty);
      } finally {
        if (!held.isCompleted) held.complete(null);
        await h.close();
      }
    },
  );

  for (final negativePlan in ['free', 'terminal']) {
    for (final field in ['provider', 'lifecycle', 'revision']) {
      test(
        'strict malformed $negativePlan $field is not canonical negative proof',
        () async {
          final h = await _Harness.open();
          try {
            await h.primePaid();
            final row = h.paidRow()
              ..['plan_id'] = negativePlan == 'free'
                  ? 'free'
                  : 'premium_ai_coach'
              ..['lifecycle'] = 'revoked';
            row[field] = field == 'revision' ? 'bad' : 'unknown';
            h.storeRows = [row];
            final before = Map<String, String>.from(h.saved);
            h.storageOperations.clear();
            expect(
              (await h.repo.currentForExplicitCheckoutRecovery()).authority,
              EntitlementAuthority.localDefault,
            );
            expect(h.saved, before);
            expect(h.storageOperations, isEmpty);
          } finally {
            await h.close();
          }
        },
      );
    }
  }
  test(
    'strict malformed optional terminal timestamp remains unresolved',
    () async {
      final h = await _Harness.open();
      try {
        h.storeRows = [
          h.paidRow()
            ..['lifecycle'] = 'revoked'
            ..['expires_at'] = 'invalid',
        ];
        expect(
          (await h.repo.currentForExplicitCheckoutRecovery()).authority,
          EntitlementAuthority.localDefault,
        );
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );
  for (final shape in ['absent', 'null', 'invalid']) {
    test(
      'inactive closed grant requires schema-valid expiry: $shape',
      () async {
        final h = await _Harness.open();
        try {
          final row = <String, Object?>{'active': false};
          if (shape != 'absent') {
            row['expires_at'] = shape == 'null' ? null : 'invalid';
          }
          h.closedRows = [row];
          expect(
            (await h.repo.currentForExplicitCheckoutRecovery()).authority,
            EntitlementAuthority.localDefault,
          );
          expect(h.storageOperations, isEmpty);
        } finally {
          await h.close();
        }
      },
    );
  }
  test(
    'schema-valid inactive expired grant is a complete negative source',
    () async {
      final h = await _Harness.open();
      try {
        h.closedRows = [
          {
            'active': false,
            'expires_at': h.now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          },
        ];
        final state = await h.repo.currentForExplicitCheckoutRecovery();
        expect(state.authority, EntitlementAuthority.verifiedServer);
        expect(state.plan, CommercePlan.free);
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );
  test(
    'valid Free terminal row permits nullable optional dates without inventing a paid period',
    () async {
      final h = await _Harness.open();
      try {
        h.storeRows = [
          h.paidRow()
            ..['plan_id'] = 'free'
            ..['lifecycle'] = 'revoked'
            ..['started_at'] = null
            ..['expires_at'] = null
            ..['grace_period_ends_at'] = null,
        ];
        final state = await h.repo.currentForExplicitCheckoutRecovery();
        expect(state.authority, EntitlementAuthority.verifiedServer);
        expect(state.plan, CommercePlan.free);
        expect(h.storageOperations, isEmpty);
      } finally {
        await h.close();
      }
    },
  );

  test('actual A to B to A auth delivery retires strict owner read', () async {
    final h = await _Harness.open();
    try {
      final entered = Completer<void>();
      final held = Completer<Object?>();
      h.closedEntered = entered;
      h.holdNextClosed = held;
      final pending = h.repo.currentForExplicitCheckoutRecovery();
      await entered.future.timeout(const Duration(seconds: 5));
      await h.setOwner(_otherOwner);
      await Future<void>.delayed(Duration.zero);
      await h.setOwner(h.owner);
      await Future<void>.delayed(Duration.zero);
      held.complete([]);
      expect(
        (await pending.timeout(const Duration(seconds: 5))).authority,
        EntitlementAuthority.localDefault,
      );
      expect(h.seen, [_closedPath]);
      expect(h.storageOperations, isEmpty);
    } finally {
      await h.close();
    }
  });
}

const _closedPath = '/rest/v1/bil_ai_closed_test_grants';
const _storePath = '/rest/v1/bil_subscriptions';
const _adminPath = '/rest/v1/rpc/bil_get_my_admin_subscription';
const _otherOwner = '69999999-0000-4000-8000-000000000999';

final class _Harness {
  _Harness()
    : owner =
          '69999999-0000-4000-8000-${(++_ordinal).toString().padLeft(12, '0')}';
  final String owner;
  var now = DateTime.utc(2026, 11, 17, 12);
  final saved = <String, String>{};
  final storageOperations = <String>[];
  final seen = <String>[];
  final requests = <({String method, String path, String? ownerFilter})>[];
  List<Map<String, Object?>> closedRows = [];
  List<Map<String, Object?>> storeRows = [];
  Object? adminBody;
  bool failClosed = false, failStore = false, failAdmin = false;
  Completer<Object?>? holdNextClosed, holdNextAdmin;
  Completer<void>? closedEntered, adminEntered;
  late final ServerEntitlementRepository repo;
  late final MockClient transport;

  static Future<_Harness> open() async {
    final h = _Harness();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async {
          h.storageOperations.add(call.method);
          final args = Map<String, Object?>.from(call.arguments as Map);
          final key = args['key'] as String?;
          if (call.method == 'read') return h.saved[key];
          if (call.method == 'write') {
            h.saved[key!] = args['value']! as String;
            return null;
          }
          if (call.method == 'delete') {
            h.saved.remove(key);
            return null;
          }
          throw StateError('Unexpected storage operation');
        });
    h.transport = MockClient(h.respond);
    await Supabase.initialize(
      url: 'https://strict-checkout-test.invalid',
      publishableKey: 'synthetic-public-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: h.transport,
    );
    await h.setOwner(h.owner);
    h.repo = ServerEntitlementRepository(clock: () => h.now);
    h.storageOperations.clear();
    return h;
  }

  Future<void> setOwner(String id) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-test-token',
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

  Map<String, Object?> paidRow({
    String plan = 'premium_ai_coach',
    String provider = 'google',
  }) => {
    'owner_id': owner,
    'provider': provider,
    'plan_id': plan,
    'lifecycle': 'active',
    'started_at': now.subtract(const Duration(days: 10)).toIso8601String(),
    'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
    'verified_at': now.toIso8601String(),
    'revision': 10,
  };
  Map<String, Object?> closedGrant() => {
    'active': true,
    'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
  };
  Map<String, Object?> adminGrant() => {
    'owner_id': owner,
    'plan_id': 'premium',
    'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
    'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
    'access_until': now.add(const Duration(minutes: 5)).toIso8601String(),
  };

  Future<void> primePaid() async {
    storeRows = [paidRow()];
    final seeded = await repo.current();
    expect(seeded.plan, CommercePlan.premiumAiCoach);
    expect(seeded.authority, EntitlementAuthority.verifiedServer);
  }

  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    seen.add(path);
    requests.add((
      method: request.method,
      path: path,
      ownerFilter: request.url.queryParameters['owner_id'],
    ));
    Object? body;
    if (path == _closedPath) {
      if (failClosed) {
        throw http.ClientException('synthetic closed-test outage');
      }
      final held = holdNextClosed;
      holdNextClosed = null;
      if (held != null) {
        closedEntered!.complete();
        body = await held.future;
      } else {
        body = closedRows;
      }
    } else if (path == _storePath) {
      if (failStore) throw http.ClientException('synthetic mirror outage');
      body = storeRows;
    } else if (path == _adminPath) {
      if (failAdmin) {
        return http.Response(
          '{"code":"synthetic_outage"}',
          503,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      final held = holdNextAdmin;
      holdNextAdmin = null;
      if (held != null) {
        adminEntered!.complete();
        body = await held.future;
      } else {
        body = adminBody;
      }
    } else {
      throw StateError(
        'Unexpected endpoint; no Boost/credit or write endpoints permitted',
      );
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Future<void> close() async {
    try {
      // Assert outside the mocked transport: repository failure handling must
      // not swallow a TestFailure and accidentally pass a negative case.
      for (final request in requests) {
        expect(request.path, isIn([_closedPath, _storePath, _adminPath]));
        if (request.path == _adminPath) {
          expect(request.method, 'POST');
        } else {
          expect(request.method, 'GET');
          expect(request.ownerFilter, 'eq.$owner');
        }
      }
    } finally {
      await Supabase.instance.dispose();
      transport.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_storage, null);
    }
  }
}

final class _HeldAdminSecureStore implements AdminEntitlementSecureStore {
  final saved = <String, String>{};
  final operations = <String>[];
  final readEntered = Completer<void>();
  final releaseRead = Completer<void>();
  bool _holdFirstRead = true;

  @override
  Future<String?> read(String key) async {
    operations.add('read');
    final captured = saved[key];
    if (_holdFirstRead) {
      _holdFirstRead = false;
      readEntered.complete();
      await releaseRead.future;
    }
    return captured;
  }

  @override
  Future<void> write(String key, String value) async {
    operations.add('write');
    saved[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    operations.add('delete');
    saved.remove(key);
  }
}
