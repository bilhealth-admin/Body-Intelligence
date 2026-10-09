import 'package:body_intelligence_log/app/theme/bil_flat_icon.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/shared/widgets/bil_native_settings_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      testWidgets('Flat ${platform.name}/${brightness.name}', (tester) async {
        final spec = BilSemanticIcons.spec(BilSemanticIconKind.health);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform, brightness: brightness),
            home: const Scaffold(
              body: BilFlatIcon(
                key: Key('quality-flat-icon'),
                kind: BilSemanticIconKind.health,
                size: 44,
                iconSize: 24,
              ),
            ),
          ),
        );
        final flat = find.byKey(const Key('quality-flat-icon'));
        expect(tester.getSize(flat), const Size(44, 44));
        final glyph = tester.widget<Icon>(
          find.descendant(of: flat, matching: find.byType(Icon)),
        );
        expect(glyph.icon, spec.iconFor(platform));
        expect(glyph.color, spec.accent(brightness));
        expect(
          find.descendant(of: flat, matching: find.byType(DecoratedBox)),
          findsNothing,
        );
        expect(
          find.descendant(of: flat, matching: find.byType(ShaderMask)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Native Settings flat mode keeps the native symbol footprint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BilNativeSettingsIcon(
            key: Key('quality-flat-native'),
            kind: BilSemanticIconKind.notifications,
            flat: true,
          ),
        ),
      ),
    );
    final target = find.byKey(const Key('quality-flat-native'));
    expect(tester.getSize(target), const Size(29, 29));
    expect(
      find.descendant(of: target, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: target, matching: find.byType(Icon)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Legacy semantic badge remains unchanged for protected pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BilSemanticIconBadge(
            key: Key('quality-legacy-badge'),
            kind: BilSemanticIconKind.water,
          ),
        ),
      ),
    );
    final decorations = find.descendant(
      of: find.byKey(const Key('quality-legacy-badge')),
      matching: find.byType(DecoratedBox),
    );
    final decoration = tester.widget<DecoratedBox>(decorations.first).decoration;
    expect(decoration, isA<BoxDecoration>());
    expect((decoration as BoxDecoration).gradient, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
