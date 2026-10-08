import 'dart:io';

import 'package:body_intelligence_log/features/visual_2026/bil_calm_visual_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'visual scope derives an independent theme without changing the parent',
    () {
      final base = ThemeData.light(useMaterial3: true);
      final originalSize = base.textTheme.titleLarge!.fontSize;
      final scoped = BilCalmVisualScope.resolve(base, isArabic: false);

      expect(scoped.textTheme.titleLarge!.fontSize, 19);
      expect(scoped.textTheme.titleLarge!.fontWeight, FontWeight.w600);
      expect(scoped.iconTheme.size, BilCalmTokens.iconSize);
      expect(scoped.colorScheme.primary, base.colorScheme.primary);
      expect(base.textTheme.titleLarge!.fontSize, originalSize);
      expect(scoped.scaffoldBackgroundColor, BilCalmTokens.lightCanvas);
      expect(
        BilCalmVisualScope.resolve(
          ThemeData.dark(useMaterial3: true),
          isArabic: true,
        ).scaffoldBackgroundColor,
        BilCalmTokens.darkCanvas,
      );
    },
  );

  testWidgets(
    'subtree scope leaves sibling routes and large-text scaling intact',
    (tester) async {
      for (final width in <double>[320, 390, 430]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 844),
                textScaler: TextScaler.linear(1.8),
              ),
              child: Column(
                children: [
                  Builder(
                    builder: (outside) => Text(
                      'Protected sibling',
                      style: Theme.of(outside).textTheme.titleLarge,
                    ),
                  ),
                  BilCalmVisualScope(
                    builder: (inside) => Text(
                      'Scoped settings',
                      style: Theme.of(inside).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        final scoped = tester.widget<Text>(find.text('Scoped settings'));
        final sibling = tester.widget<Text>(find.text('Protected sibling'));
        expect(scoped.style!.fontSize, 19);
        expect(sibling.style!.fontSize, isNot(19));
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  test('protected Flutter feature trees never import the visual scope', () {
    for (final path in <String>[
      'lib/features/dashboard',
      'lib/features/community',
      'lib/features/intelligence_center',
    ]) {
      for (final file in Directory(path).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        expect(
          file.readAsStringSync(),
          isNot(contains('bil_calm_visual_scope.dart')),
          reason: 'Protected page imports scoped visual theme: ' + file.path,
        );
      }
    }
  });
}
