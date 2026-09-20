import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

final class _Gateway implements ConnectedHealthGateway {
  _Gateway(this.snapshot);
  ConnectedHealthSnapshot snapshot;

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}

ConnectedHealthSnapshot _snapshot(
  ConnectedHealthStatus status, {
  String platformSource = 'Health Connect',
}) => ConnectedHealthSnapshot(
  status: status,
  platformSource: platformSource,
  availableSources: [platformSource],
  signals: const [],
  importedCount: 0,
  lastSyncAt: null,
  failureCode: null,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    ConnectedHealthStatus status, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          connectedHealthGatewayProvider.overrideWithValue(
            _Gateway(
              _snapshot(
                status,
                platformSource: platform == TargetPlatform.iOS
                    ? 'Apple Health'
                    : 'Health Connect',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ConnectedHealthPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('permission denial is explicit and never shows connected', (
    tester,
  ) async {
    await pump(tester, ConnectedHealthStatus.permissionDenied);
    expect(
      find.byKey(const Key('connected-health-source-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('connected-health-live-watch-card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('connected-health-signals-card')),
      findsNothing,
    );
    expect(find.textContaining('Permission was denied'), findsOneWidget);
    expect(find.text('Connected and synchronized.'), findsNothing);
    expect(find.text('Grant health access'), findsOneWidget);
    await disposePage(tester);
  });

  testWidgets('provider update requirement and compatibility are reachable', (
    tester,
  ) async {
    await pump(tester, ConnectedHealthStatus.updateRequired);
    expect(find.textContaining('must be installed or updated'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-device-compatibility')),
      300,
    );
    expect(find.text('Supported connections'), findsOneWidget);
    expect(find.text('Health Connect'), findsWidgets);
    expect(find.textContaining('physical-device verification'), findsNothing);
    expect(find.textContaining('GATT'), findsNothing);
    await disposePage(tester);
  });

  testWidgets('Android never advertises Apple-only health paths', (
    tester,
  ) async {
    await pump(tester, ConnectedHealthStatus.permissionDenied);
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-device-compatibility')),
      300,
    );
    expect(find.text('Health Connect'), findsWidgets);
    expect(find.text('Apple Health'), findsNothing);
    expect(find.textContaining('Apple Watch data comes through'), findsNothing);
    await disposePage(tester);
  });

  testWidgets('Android restored authorization state never shows Apple help', (
    tester,
  ) async {
    await pump(tester, ConnectedHealthStatus.authorizationRequested);
    expect(
      find.textContaining('Apple Health does not reveal read permission'),
      findsNothing,
    );
    await disposePage(tester);
  });

  testWidgets('iOS never advertises Android-only health paths', (tester) async {
    await pump(
      tester,
      ConnectedHealthStatus.permissionDenied,
      platform: TargetPlatform.iOS,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-device-compatibility')),
      300,
    );
    expect(find.text('Apple Health'), findsWidgets);
    expect(find.text('Health Connect'), findsNothing);
    expect(
      find.textContaining('Apple Watch data comes through'),
      findsOneWidget,
    );
    await disposePage(tester);
  });
}
