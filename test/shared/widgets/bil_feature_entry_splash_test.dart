import 'package:body_intelligence_log/shared/widgets/bil_feature_entry_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in BilFeatureEntryKind.values) {
    testWidgets(
      '${kind.name} entry splash is bounded and releases destination',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2),
              ),
              child: BilFeatureEntrySplashGate(
                kind: kind,
                child: const Scaffold(
                  body: Center(
                    child: Text('destination', key: Key('destination')),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('destination')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pump();
        expect(
          find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
          findsNothing,
        );
        expect(find.byKey(const Key('destination')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
