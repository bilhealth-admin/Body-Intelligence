import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/health_hub_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snapshot = ConnectedHealthSnapshot.unavailable();

  Future<void> pumpEmptyState(
    WidgetTester tester, {
    required double textScale,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(800, 1280),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  // Mirrors the usable rail on an sw800 tablet in portrait.
                  child: SizedBox(
                    width: 720,
                    child: HealthHubEmptyState(
                      snapshot: snapshot,
                      languageCode: 'en',
                      compact: false,
                      onConnect: _ignore,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sw800 portrait lets the vertical Health Hub grow naturally', (
    tester,
  ) async {
    await pumpEmptyState(tester, textScale: 1);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('health-hub-empty-state'))).height,
      greaterThan(404),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('sw800 portrait remains overflow-free with enlarged text', (
    tester,
  ) async {
    await pumpEmptyState(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('health-hub-connect-button')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

void _ignore() {}
