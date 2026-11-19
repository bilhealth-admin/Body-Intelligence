import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
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

class RenewalProtectedChild extends ConsumerStatefulWidget {
  const RenewalProtectedChild(this.h, {super.key});
  final RenewalUiHarness h;
  @override
  ConsumerState<RenewalProtectedChild> createState() =>
      RenewalProtectedChildState();
}

class RenewalProtectedChildState extends ConsumerState<RenewalProtectedChild> {
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
    if (widget.h.feature == PremiumGateFeature.aiCoach) {
      final quota = ref.read(aiCoachCreditAccessProvider);
      if (!quota.isLoading && !quota.hasError && quota.value == true) {
        widget.h.writes++;
      }
      return;
    }
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

class RenewalUiHarness {
  late String owner;
  DateTime now = DateTime.utc(2026, 11, 18, 10);
  late DateTime boundary;
  late Map<String, Object?> row;
  late ServerEntitlementRepository repository;
  late ProviderContainer container;
  int loads = 0, reads = 0, mounts = 0, unmounts = 0, attempts = 0, writes = 0;
  bool offline = false;
  bool usageOffline = false;
  int usageReads = 0, usageFailures = 0;
  PremiumGateFeature feature = PremiumGateFeature.personalPlan;
  Object? usage = {
    'plan': 'ai_coach',
    'credits': {'total_remaining': 2466},
  };
  int refreshCalls = 0;
  Completer<void>? hold;
  Completer<void>? holdNextUsageRead;
  Completer<void>? nextUsageReadEntered;

  static Future<RenewalUiHarness> open(
    WidgetTester tester, {
    String provider = 'google',
    PremiumGateFeature feature = PremiumGateFeature.personalPlan,
    Future<void> Function()? refreshSubscription,
  }) async {
    final h = RenewalUiHarness()..feature = feature;
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
          } else if (request.url.path.endsWith('/bil_get_ai_usage_status')) {
            h.usageReads++;
            // Hold only the next read and capture its old server snapshot
            // BEFORE the hold. Later reads continue normally.
            final held = h.holdNextUsageRead;
            h.holdNextUsageRead = null;
            final capturedUsage = jsonDecode(jsonEncode(h.usage));
            if (held != null) {
              h.nextUsageReadEntered?.complete();
              await held.future;
            }
            if (h.usageOffline) {
              h.usageFailures++;
              throw StateError('synthetic usage RPC outage');
            }
            body = capturedUsage;
          } else if (request.url.path.endsWith('/verify-store-purchase')) {
            h.refreshCalls++;
            body = {'refresh_status': 'checking'};
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
    expect(
      initial.plan,
      feature == PremiumGateFeature.aiCoach
          ? CommercePlan.premiumAiCoach
          : CommercePlan.premium,
    );
    h.container = ProviderContainer(
      overrides: [
        if (refreshSubscription != null)
          ownSubscriptionRefreshProvider.overrideWithValue(refreshSubscription),
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
    'plan_id': feature == PremiumGateFeature.aiCoach
        ? 'premium_ai_coach'
        : 'premium',
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
            feature: feature,
            child: RenewalProtectedChild(this),
          ),
        ),
      ),
    );
    await renewalFlush(tester);
    expect(mounts, 1);
  }

  Future<void> tick(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await renewalFlush(tester);
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

Future<void> renewalFlush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}
