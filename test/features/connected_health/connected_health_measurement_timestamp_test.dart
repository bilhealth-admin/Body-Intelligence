import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/providers/fitness_device_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/native_ble_fitness_bridge.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 22, 1, 17);
final _observed = DateTime(2026, 11, 21, 23, 55);

class _Preferences implements PreferencesRepository {
  @override
  Stream<String?> watch(String key) => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway implements ConnectedHealthGateway {
  int permissionRequests = 0;
  int synchronizations = 0;

  ConnectedHealthSnapshot get snapshot => ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Apple Health',
    availableSources: const ['Apple Health'],
    signals: [
      ConnectedHealthSignalView(
        key: 'steps',
        value: 1081,
        unit: 'count',
        source: 'iPhone',
        observedAt: _observed,
        confidence: 1,
      ),
    ],
    importedCount: 1,
    lastSyncAt: _now,
    failureCode: null,
    deviceVerified: true,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> synchronize() async {
    synchronizations++;
    return snapshot;
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async {
    permissionRequests++;
    return snapshot;
  }

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;
  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final large in [false, true]) {
      testWidgets('historical synced readings show their own measurement time '
          '${locale.languageCode} large=$large', (tester) async {
        tester.view.physicalSize = Size(large ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final gateway = _Gateway();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesRepositoryProvider.overrideWithValue(_Preferences()),
              connectedHealthGatewayProvider.overrideWithValue(gateway),
              fitnessDeviceProvider.overrideWith(
                (ref) =>
                    FitnessDeviceController(MethodChannelBleFitnessBridge()),
              ),
              verifiedSubscriptionStateProvider.overrideWith(
                (ref) async => SubscriptionState(
                  plan: CommercePlan.free,
                  entitlements: FreePlan.createState().entitlements,
                  authority: EntitlementAuthority.verifiedServer,
                  isPurchasable: true,
                  canRestorePurchases: true,
                ),
              ),
              liveHealthNowProvider.overrideWithValue(() => _now),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                child: child!,
              ),
              home: const ConnectedHealthPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final stamp = find.byKey(
          const Key('connected-health-signal-measured-steps'),
        );
        await tester.ensureVisible(stamp);
        await tester.pumpAndSettle();

        final context = tester.element(stamp);
        final date = MaterialLocalizations.of(
          context,
        ).formatFullDate(_observed);
        final time = TimeOfDay.fromDateTime(_observed).format(context);
        final text = tester.widget<Text>(stamp).data!;
        expect(text, contains(date));
        expect(text, contains(time));
        expect(
          text,
          isNot(
            contains(MaterialLocalizations.of(context).formatFullDate(_now)),
          ),
        );
        expect(find.byKey(const Key('watch-metric-steps')), findsNothing);
        expect(
          find.byKey(const Key('watch-no-recent-readings')),
          findsOneWidget,
        );
        expect(gateway.permissionRequests, 0);
        expect(gateway.synchronizations, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
