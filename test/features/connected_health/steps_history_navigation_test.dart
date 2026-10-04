import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/steps_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every measured steps entry opens dedicated daily step history', () {
    final settings = File(
      'lib/features/connected_health/steps_settings_page.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_components.dart',
    ).readAsStringSync();
    final dailyLog = File(
      'lib/features/daily_log/presentation/daily_log_today_sections.dart',
    ).readAsStringSync();
    final route = [
      File('lib/app/router/app_router.dart').readAsStringSync(),
      File('lib/app/router/app_community_routes.dart').readAsStringSync(),
    ].join('\n');

    expect(settings, contains("context.go('/connected-health/steps/history')"));
    expect(
      dashboard,
      contains("context.push('/connected-health/steps/history')"),
    );
    expect(
      dailyLog,
      contains("context.push('/connected-health/steps/history')"),
    );
    expect(route, contains("path: '/connected-health/steps/history'"));
    expect(settings, isNot(contains("context.go('/history')")));
  });

  testWidgets('step history renders HealthKit daily totals and no fake days', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final snapshot = const ConnectedHealthSnapshot.unavailable().copyWith(
      status: ConnectedHealthStatus.synchronized,
      platformSource: 'Apple Health',
      deviceVerified: true,
      stepHistory: [
        ConnectedHealthSignalView(
          key: 'steps',
          value: 5678,
          unit: 'count',
          source: 'healthkit.statistics',
          observedAt: today,
          confidence: 1,
        ),
        ConnectedHealthSignalView(
          key: 'steps',
          value: 1234,
          unit: 'count',
          source: 'healthkit.statistics',
          observedAt: today.subtract(const Duration(days: 2)),
          confidence: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectedHealthGatewayProvider.overrideWithValue(
            _HistoryGateway(snapshot),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StepsHistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5,678 steps'), findsNWidgets(2));
    expect(find.text('1,234 steps'), findsOneWidget);
    expect(find.byKey(const Key('steps-history-empty')), findsNothing);
    expect(find.byKey(ValueKey('steps-history-$today')), findsOneWidget);
    expect(
      find.byKey(
        ValueKey('steps-history-${today.subtract(const Duration(days: 2))}'),
      ),
      findsOneWidget,
    );
  });
}

final class _HistoryGateway implements ConnectedHealthGateway {
  const _HistoryGateway(this.snapshot);
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
