import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_signal_detail_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'heart detail shows one daily mean and preserves latest Watch value',
    (tester) async {
      final recent = DateTime(2026, 9, 27, 12, 5);
      final older = DateTime(2026, 9, 27, 11, 30);
      ConnectedHealthSignalView heart(double value, DateTime observedAt) =>
          ConnectedHealthSignalView(
            key: 'heartRate',
            value: value,
            unit: 'bpm',
            source: 'Kadem Apple Watch Series 9',
            observedAt: observedAt,
            confidence: 1,
            attributes: const {'wearableKind': 'apple_watch'},
          );
      final snapshot = const ConnectedHealthSnapshot.unavailable().copyWith(
        status: ConnectedHealthStatus.synchronized,
        platformSource: 'Apple Health',
        deviceVerified: true,
        signals: [heart(89, recent)],
        signalHistory: [heart(89, recent), heart(72, older)],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedHealthGatewayProvider.overrideWithValue(
              _SignalGateway(snapshot),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ConnectedHealthSignalDetailPage(
              keys: ['heartRate', 'restingHeartRate'],
              title: 'Heart rate',
              unitFallback: 'bpm',
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(connectedHealthProvider.notifier).refresh();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('connected-signal-measured')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('connected-signal-history')), findsOneWidget);
      expect(find.text('89 bpm'), findsOneWidget);
      expect(find.text('80.5 bpm'), findsOneWidget);
      expect(find.text('72 bpm'), findsNothing);
      expect(find.text('Apple Watch'), findsNWidgets(2));
      expect(find.textContaining('Kadem Apple Watch'), findsNothing);
    },
  );
}

final class _SignalGateway implements ConnectedHealthGateway {
  const _SignalGateway(this.snapshot);
  final ConnectedHealthSnapshot snapshot;

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;
  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}
