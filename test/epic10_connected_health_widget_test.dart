import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
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

ConnectedHealthSnapshot _snapshot(ConnectedHealthStatus status) =>
    ConnectedHealthSnapshot(
      status: status,
      platformSource: 'Health Connect',
      availableSources: const ['Health Connect'],
      signals: const [],
      importedCount: 0,
      lastSyncAt: null,
      failureCode: null,
    );

void main() {
  Future<void> pump(WidgetTester tester, ConnectedHealthStatus status) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          connectedHealthGatewayProvider.overrideWithValue(
            _Gateway(_snapshot(status)),
          ),
        ],
        child: const MaterialApp(home: ConnectedHealthPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('permission denial is explicit and never shows connected', (
    tester,
  ) async {
    await pump(tester, ConnectedHealthStatus.permissionDenied);
    expect(find.textContaining('Permission was denied'), findsOneWidget);
    expect(find.text('Connected and synchronized.'), findsNothing);
    expect(find.text('Grant health access'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
