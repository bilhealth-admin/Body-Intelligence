import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/providers/fitness_device_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/ble_fitness_device_platform.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/fitness_ble_release_policy.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/native_ble_fitness_bridge.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:body_intelligence_log/features/global_platform/product/global_product_coordinators.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const _peripheral = BlePeripheral(
  id: 'fixture-scale',
  name: 'Fixture scale',
  profiles: {BleFitnessProfile.weightScale},
  firmwareVersion: 'fixture',
  manufacturer: 'fixture',
);

final class _Gateway implements ConnectedHealthGateway {
  _Gateway(this.platform);
  final TargetPlatform platform;

  ConnectedHealthSnapshot get snapshot => ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.permissionDenied,
    platformSource: platform == TargetPlatform.iOS
        ? 'Apple Health'
        : 'Health Connect',
    availableSources: const [],
    signals: const [],
    importedCount: 0,
    lastSyncAt: null,
    failureCode: null,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;
  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil.global/fitness_ble');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('release BLE is iOS-only and never enabled on web', () {
    for (final platform in TargetPlatform.values) {
      expect(
        fitnessBleAvailableForPlatform(platform),
        platform == TargetPlatform.iOS,
      );
      expect(fitnessBleAvailableForPlatform(platform, isWeb: true), isFalse);
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '${platform.name} runtime registers only released fitness providers',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final host = GlobalNativeIntegrationHost.instance;
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
        try {
          await host.initialize(
            database: sqlite3.openInMemory(),
            configuration: const GlobalProductRuntimeConfiguration(
              localeCatalogs: [],
            ),
          );
          final flows = host.productFlows!;
          final ios = platform == TargetPlatform.iOS;
          expect(
            flows.fitness.providers.map((provider) => provider.id),
            ios ? ['ble-fitness'] : isEmpty,
          );
          expect(
            flows.capabilities['fitness']!.status,
            ios
                ? GlobalProductCapabilityStatus.available
                : GlobalProductCapabilityStatus.unavailable,
          );
          expect(host.healthConnect, isNotNull);
          if (!ios) {
            expect(
              await flows.fitness.ingest(DateTime.utc(2026, 11, 6)),
              isEmpty,
            );
          }
          expect(calls, isEmpty);
        } finally {
          await host.close();
        }
      },
    );
  }

  test(
    'Android direct bridge operations cannot invoke a native channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      final bridge = MethodChannelBleFitnessBridge();
      final operations = <Future<Object?> Function()>[
        bridge.requestPermissions,
        () => bridge.discover(const Duration(seconds: 1)),
        () => bridge.pair(_peripheral.id),
        () => bridge.deviceStatus(_peripheral.id),
        () => bridge.readMeasurements(
          peripheral: _peripheral,
          asOf: DateTime.utc(2026),
        ),
        () => bridge.disconnect(_peripheral.id),
        () => bridge.forget(_peripheral.id),
      ];
      for (final operation in operations) {
        await expectLater(
          operation(),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'fitness_ble_unavailable',
            ),
          ),
        );
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'Android controller ignores saved devices and direct action attempts',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      final store = InMemoryGlobalStore();
      const saved = <String, Object?>{
        'id': 'fixture-scale',
        'profiles': ['weightScale'],
        'name': 'Saved scale',
      };
      await store.put('connected_fitness_devices', _peripheral.id, saved);
      final controller = FitnessDeviceController(
        MethodChannelBleFitnessBridge(),
        store: store,
      );
      addTearDown(controller.dispose);
      await controller.scan();
      await controller.connect(_peripheral);
      await controller.refreshMeasurements(_peripheral);
      await controller.disconnect();
      await controller.removeDevice(_peripheral.id);
      expect(
        controller.state.status,
        FitnessDeviceConnectionStatus.unavailable,
      );
      expect(controller.state.devices, isEmpty);
      expect(controller.state.measurements, isEmpty);
      expect(controller.state.connectedDeviceId, isNull);
      expect(calls, isEmpty);
      expect(
        await store.get('connected_fitness_devices', _peripheral.id),
        saved,
      );
    },
  );

  test(
    'iOS retains permission, discovery, GATT payload parsing and lifecycle calls',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'discover' => [
            {
              'id': _peripheral.id,
              'name': _peripheral.name,
              'profiles': ['181D'],
            },
          ],
          'deviceStatus' => {'connected': true, 'batteryPercent': null},
          'readMeasurements' => [
            {
              'peripheralId': _peripheral.id,
              'characteristic': '2A9D',
              'packet': base64Encode([0, 0xb0, 0x36]),
              'receivedAt': '2026-11-06T00:00:00Z',
            },
          ],
          _ => null,
        };
      });
      final bridge = MethodChannelBleFitnessBridge();
      await bridge.requestPermissions();
      final devices = await bridge.discover(const Duration(seconds: 1));
      expect(devices.single.profiles, {BleFitnessProfile.weightScale});
      await bridge.pair(_peripheral.id);
      expect(
        await bridge.deviceStatus(_peripheral.id),
        containsPair('connected', true),
      );
      final readings = await bridge.readMeasurements(
        peripheral: devices.single,
        asOf: DateTime.utc(2026, 11, 6),
      );
      expect(readings.single['kind'], 'weight');
      expect(readings.single['value'], 70);
      expect(readings.single['unit'], 'kg');
      await bridge.disconnect(_peripheral.id);
      await bridge.forget(_peripheral.id);
      expect(calls, [
        'requestPermissions',
        'discover',
        'pair',
        'deviceStatus',
        'readMeasurements',
        'disconnect',
        'forget',
      ]);
    },
  );

  for (final (platform, locale) in [
    (TargetPlatform.android, const Locale('en')),
    (TargetPlatform.android, const Locale('ar')),
    (TargetPlatform.iOS, const Locale('en')),
  ]) {
    testWidgets(
      '${platform.name}/${locale.languageCode} exposes only released device journeys',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                connectedHealthGatewayProvider.overrideWithValue(
                  _Gateway(platform),
                ),
                verifiedSubscriptionStateProvider.overrideWithValue(
                  AsyncData(
                    SubscriptionState(
                      plan: CommercePlan.free,
                      entitlements: FreePlan.createState().entitlements,
                      authority: EntitlementAuthority.verifiedServer,
                      isPurchasable: true,
                      canRestorePurchases: true,
                    ),
                  ),
                ),
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
                home: const ConnectedHealthPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final ios = platform == TargetPlatform.iOS;
          expect(
            find.byKey(const Key('fitness-bluetooth-section')),
            ios ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const Key('scan-fitness-devices-button')),
            ios ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const Key('connected-health-source-card')),
            findsOneWidget,
          );
          await tester.tap(
            find.byTooltip(
              locale.languageCode == 'ar'
                  ? 'بحث في الاتصالات'
                  : 'Search connections',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Health Connect'),
            ios ? findsNothing : findsWidgets,
          );
          expect(
            find.text('Bluetooth fitness devices'),
            ios ? findsWidgets : findsNothing,
          );
          expect(find.text('أجهزة اللياقة عبر البلوتوث'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
