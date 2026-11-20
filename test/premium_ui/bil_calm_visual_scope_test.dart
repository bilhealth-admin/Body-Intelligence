import 'dart:io';
import 'package:body_intelligence_log/shared/widgets/bil_page_heading.dart';

import 'package:body_intelligence_log/features/visual_2026/bil_calm_visual_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      expect(scoped.scaffoldBackgroundColor, Colors.transparent);
      expect(
        scoped.colorScheme.surfaceContainerLowest,
        BilCalmTokens.lightCanvas,
      );
      expect(
        BilCalmVisualScope.resolve(
          ThemeData.dark(useMaterial3: true),
          isArabic: true,
        ).colorScheme.surfaceContainerLowest,
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

  testWidgets(
    '24 locale, theme, width and text scale combinations stay scoped',
    (tester) async {
      for (final width in <double>[320, 390, 430]) {
        for (final locale in <Locale>[const Locale('ar'), const Locale('en')]) {
          for (final dark in <bool>[false, true]) {
            for (final scale in <double>[1.0, 2.0]) {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              await tester.pumpWidget(
                MaterialApp(
                  locale: locale,
                  supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                  ],
                  theme: dark
                      ? ThemeData.dark(useMaterial3: true)
                      : ThemeData.light(useMaterial3: true),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 844),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: BilCalmVisualScope(
                      builder: (inside) => Scaffold(
                        body: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Health · الصحة',
                              style: Theme.of(inside).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final scoped = tester.widget<Text>(find.text('Health · الصحة'));
              expect(scoped.style?.fontSize, 16);
              expect(
                scoped.style?.letterSpacing,
                locale.languageCode == 'ar' ? 0 : -0.15,
              );
              final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
              expect(scaffold.backgroundColor, isNull);
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('embedded route opt-out uses original theme', (tester) async {
    final original = ThemeData.light(useMaterial3: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: original,
        home: BilCalmVisualScope(
          enabled: false,
          builder: (inside) => Text(
            'Embedded protected region',
            style: Theme.of(inside).textTheme.titleLarge,
          ),
        ),
      ),
    );
    final finder = find.text('Embedded protected region');
    final value = tester.widget<Text>(finder);
    // MaterialApp resolves its platform defaults; ThemeData.light().textTheme
    // alone does not include every resolved font size.
    final inherited = Theme.of(tester.element(finder));
    expect(value.style?.fontSize, inherited.textTheme.titleLarge?.fontSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual inherited AppBar matches active canonical heading without resizing body typography',
    (tester) async {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData.light(useMaterial3: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: BilCalmVisualScope(
                builder: (inside) => Scaffold(
                  appBar: AppBar(
                    title: Text(
                      locale.languageCode == 'ar' ? 'عنوان' : 'Title',
                      key: const Key('canonical-inherited-appbar'),
                    ),
                  ),
                  body: Text(
                    'Explicit heading',
                    key: const Key('canonical-explicit-heading'),
                    style: bilPageHeadingStyle(inside),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final bar = find.byKey(const Key('canonical-inherited-appbar'));
          final explicit = find.byKey(const Key('canonical-explicit-heading'));
          final barStyle = DefaultTextStyle.of(tester.element(bar)).style;
          final explicitStyle = tester.widget<Text>(explicit).style!;
          expect(barStyle.fontWeight, FontWeight.w800);
          expect(barStyle.fontSize, explicitStyle.fontSize);
          expect(barStyle.fontFamily, explicitStyle.fontFamily);
          expect(barStyle.height, explicitStyle.height);
          expect(
            Theme.of(tester.element(explicit)).textTheme.titleLarge!.fontWeight,
            FontWeight.w600,
            reason:
                'Only page chrome is standardized; existing card/body typography is preserved.',
          );
          // Flutter's native AppBar title applies its existing internal scale
          // cap. The visual scope must preserve the OS scaler before that
          // framework boundary and for normal page/sheet heading content.
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(AppBar)),
            ).scale(10),
            closeTo(scale * 10, .001),
          );
          expect(
            MediaQuery.textScalerOf(tester.element(explicit)).scale(10),
            closeTo(scale * 10, .001),
          );
          expect(tester.takeException(), isNull);
        }
      }
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
          reason: 'Protected page imports scoped visual theme: ${file.path}',
        );
      }
    }
  });
}
