import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
var _serial = 100;

class _Write extends Intent {
  const _Write();
}

class _ProtectedChild extends ConsumerStatefulWidget {
  const _ProtectedChild(this.h);
  final _Harness h;
  @override
  ConsumerState<_ProtectedChild> createState() => _ProtectedChildState();
}

class _ProtectedChildState extends ConsumerState<_ProtectedChild> {
  @override
  void initState() {
    super.initState();
    widget.h.mounts++;
  }

  @override
  void dispose() {
    widget.h.unmounts++;
    super.dispose();
  }

  void write() {
    widget.h.attempts++;
    final access = ref.read(verifiedSubscriptionAccessProvider);
    if (!access.isLoading &&
        !access.hasError &&
        access.value?.authority == EntitlementAuthority.verifiedServer &&
        access.value?.plan != CommercePlan.free) {
      widget.h.writes++;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Existing owned plan')),
    body: Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.keyW): _Write()},
      child: Actions(
        actions: {
          _Write: CallbackAction<_Write>(
            onInvoke: (_) {
              write();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: ElevatedButton(
            key: const Key('protected-plan-write'),
            onPressed: write,
            child: const Text('Protected write'),
          ),
        ),
      ),
    ),
  );
}

class _Harness {
  late String owner;
  DateTime now = DateTime.utc(2026, 11, 18, 10);
  late DateTime boundary;
  late Map<String, Object?> row;
  late ServerEntitlementRepository repository;
  late ProviderContainer container;
  int loads = 0, reads = 0, mounts = 0, unmounts = 0, attempts = 0, writes = 0;
  bool offline = false;
  Completer<void>? hold;

  static Future<_Harness> open(
    WidgetTester tester, {
    String provider = 'google',
  }) async {
    final h = _Harness();
    h.owner =
        '00000000-0000-4000-8000-${(++_serial).toString().padLeft(12, '0')}';
    h.boundary = h.now.add(const Duration(seconds: 5));
    h.row = h.period(provider: provider);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, (_) async => null);
    await tester.runAsync(() async {
      await Supabase.initialize(
        url: 'https://renewal-retention-test.invalid',
        publishableKey: 'synthetic-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: MockClient((request) async {
          Object? body;
          if (request.url.path.endsWith('/bil_subscriptions')) {
            h.reads++;
            await h.hold?.future;
            if (h.offline) throw StateError('synthetic read failure');
            body = [h.row];
          } else if (request.url.path.endsWith('/bil_ai_closed_test_grants')) {
            body = [];
          } else if (request.url.path.endsWith(
            '/bil_get_my_admin_subscription',
          )) {
            body = null;
          } else {
            throw StateError('Unexpected synthetic REST route');
          }
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await h.signIn(h.owner);
    });
    h.repository = ServerEntitlementRepository(clock: () => h.now);
    final initial = (await tester.runAsync(h.repository.current))!;
    expect(initial.plan, CommercePlan.premium);
    h.container = ProviderContainer(
      overrides: [
        verifiedEntitlementClockProvider.overrideWithValue(() => h.now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() {
          h.loads++;
          return h.loads == 1 ? Future.value(initial) : h.repository.current();
        }),
        storefrontTargetPlanProvider.overrideWith(
          (_) async => CommercePlan.premium,
        ),
      ],
    );
    return h;
  }

  Map<String, Object?> period({String provider = 'google', DateTime? end}) => {
    'owner_id': owner,
    'provider': provider,
    'plan_id': 'premium',
    'lifecycle': 'active',
    'auto_renews': true,
    'started_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    'expires_at': (end ?? boundary).toIso8601String(),
    'verified_at': now.toIso8601String(),
    'revision': 1,
    'original_transaction_id': 'synthetic-lineage-$owner',
  };

  Future<void> signIn(String value) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-token',
        'token_type': 'bearer',
        'user': {
          'id': value,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumRouteGlassGate(
            feature: PremiumGateFeature.personalPlan,
            child: _ProtectedChild(this),
          ),
        ),
      ),
    );
    await flush(tester);
    expect(mounts, 1);
  }

  Future<void> tick(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await flush(tester);
  }

  Future<void> close(WidgetTester tester) async {
    if (hold != null && !hold!.isCompleted) hold!.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
    await tester.runAsync(() => Supabase.instance.dispose());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null);
  }
}

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'Google expiry blocks writes but retains the already-authorized child without Plans',
    (tester) async {
      final h = await _Harness.open(tester);
      try {
        await h.mount(tester);
        await tester.tap(find.byKey(const Key('protected-plan-write')));
        expect(h.writes, 1);
        await h.tick(tester, const Duration(seconds: 5));
        final access = h.container.read(verifiedSubscriptionAccessProvider);
        expect(access.value?.plan, CommercePlan.free);
        expect(
          h.unmounts,
          0,
          reason: 'Display retention never extends write authority.',
        );
        expect(find.text('Existing owned plan'), findsOneWidget);
        expect(find.text('Plans'), findsNothing);
        final before = h.attempts;
        await tester.tap(
          find.byKey(const Key('protected-plan-write')),
          warnIfMissed: false,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await flush(tester);
        expect(
          h.attempts,
          before,
          reason: 'Pointer and shortcuts are blocked at cutoff.',
        );
        expect(h.writes, 1);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'Google eight-second renewal lag heals silently without child remount or tap',
    (tester) async {
      final h = await _Harness.open(tester);
      try {
        await h.mount(tester);
        await h.tick(tester, const Duration(seconds: 5));
        await h.tick(tester, const Duration(seconds: 2));
        await h.tick(tester, const Duration(seconds: 3));
        await h.tick(tester, const Duration(seconds: 3));
        h.row = h.period(end: h.boundary.add(const Duration(minutes: 5)))
          ..['started_at'] = h.boundary.toIso8601String()
          ..['revision'] = 2;
        await h.tick(tester, const Duration(seconds: 2));
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.premium,
        );
        expect(h.mounts, 1);
        expect(h.unmounts, 0);
        expect(find.text('Plans'), findsNothing);
        await tester.tap(find.byKey(const Key('protected-plan-write')));
        expect(h.writes, 1);
      } finally {
        await h.close(tester);
      }
    },
  );

  for (final networkFailure in [false, true]) {
    testWidgets(
      'Google ambiguous stale renewal times out neutrally; network=$networkFailure',
      (tester) async {
        final h = await _Harness.open(tester);
        try {
          await h.mount(tester);
          await h.tick(tester, const Duration(seconds: 5));
          h.offline = networkFailure;
          for (final seconds in [2, 3, 5, 10, 5]) {
            await h.tick(tester, Duration(seconds: seconds));
          }
          expect(h.unmounts, 0);
          expect(
            h.container.read(verifiedSubscriptionAccessProvider).value?.plan ==
                CommercePlan.premium,
            isFalse,
          );
          expect(find.text('Plans'), findsNothing);
          expect(find.text('Try again'), findsOneWidget);
          expect(h.loads, lessThanOrEqualTo(7));
          final before = h.loads;
          await h.tick(tester, const Duration(seconds: 2));
          expect(
            h.loads,
            before,
            reason: 'The same owner/period cannot restart its burst.',
          );
        } finally {
          await h.close(tester);
        }
      },
    );
  }

  for (final provider in ['google', 'apple']) {
    testWidgets(
      '$provider definitive expired nonrenewing proof keeps the normal Plans gate',
      (tester) async {
        final h = await _Harness.open(tester, provider: provider);
        try {
          await h.mount(tester);
          h.row['lifecycle'] = 'expired';
          h.row['auto_renews'] = false;
          h.row['verified_at'] = h.now
              .add(const Duration(seconds: 5))
              .toIso8601String();
          await h.tick(tester, const Duration(seconds: 5));
          expect(
            h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
            CommercePlan.free,
          );
          expect(find.text('Plans'), findsOneWidget);
          expect(h.unmounts, 1);
        } finally {
          await h.close(tester);
        }
      },
    );
  }
}
