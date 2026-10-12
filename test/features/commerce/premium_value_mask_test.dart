import 'dart:ui' as ui;
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_value_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  testWidgets('locked pixels never reveal values or charts', (tester) async {
    Future<List<int>> pixels(Color secret, bool locked) async {
      await tester.pumpWidget(
        _app(
          child: RepaintBoundary(
            key: const Key('mask-pixels'),
            child: SizedBox(
              width: 240,
              height: 140,
              child: PremiumValueMask(
                locked: locked,
                onUpgrade: () {},
                child: ColoredBox(
                  color: secret,
                  child: const Center(child: Text('963.27 private value')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('mask-pixels')),
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List().toList();
        } finally {
          image.dispose();
        }
      }))!;
    }

    expect(await pixels(Colors.red, true), await pixels(Colors.blue, true));
    expect(
      await pixels(Colors.red, false),
      isNot(await pixels(Colors.blue, false)),
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final arabic in [false, true]) {
      testWidgets(
        'public names and free actions stay outside lock ${dark ? 'dark' : 'light'} ${arabic ? 'ar' : 'en'} 320 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1024);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final focus = FocusNode();
          addTearDown(focus.dispose);
          var freeActions = 0, paidActions = 0, upgrades = 0;
          await tester.pumpWidget(
            _app(
              dark: dark,
              arabic: arabic,
              child: RepaintBoundary(
                key: const Key('named-mask-capture'),
                child: ColoredBox(
                  color: dark
                      ? const Color(0xFF10202E)
                      : const Color(0xFFF3F8FC),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            arabic
                                ? 'معلومات المغذيات والأجهزة الصحية المتصلة'
                                : 'Connected health and nutrient information',
                            key: const Key('public-heading'),
                          ),
                          Text(
                            arabic ? 'البوتاسيوم · mg' : 'Potassium · mg',
                            key: const Key('public-field'),
                          ),
                          const SizedBox(height: 8),
                          PremiumValueMask(
                            locked: true,
                            actionKey: const Key('upgrade'),
                            onUpgrade: () => upgrades++,
                            child: SizedBox(
                              height: 160,
                              child: Semantics(
                                label: 'private source confidence 97 percent',
                                child: Column(
                                  children: [
                                    const Text('492.6 mg'),
                                    const LinearProgressIndicator(value: .97),
                                    Tooltip(
                                      message: 'private tooltip 492.6',
                                      child: TextButton(
                                        focusNode: focus,
                                        onPressed: () => paidActions++,
                                        child: const Text('paid action'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('free-action'),
                            onPressed: () => freeActions++,
                            child: Text(
                              arabic ? 'المصدر والمساعدة' : 'Source and help',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final titleRect = tester.getRect(
            find.byKey(const Key('public-heading')),
          );
          final fieldRect = tester.getRect(
            find.byKey(const Key('public-field')),
          );
          final lockRect = tester.getRect(find.byType(PremiumValueMask));
          expect(titleRect.overlaps(lockRect), isFalse);
          expect(fieldRect.overlaps(lockRect), isFalse);
          expect(
            find.bySemanticsLabel('private source confidence 97 percent'),
            findsNothing,
          );
          expect(find.bySemanticsLabel('492.6 mg'), findsNothing);
          focus.requestFocus();
          await tester.pump();
          expect(focus.hasFocus, isFalse);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(paidActions, 0);
          await tester.tap(find.byKey(const Key('free-action')));
          expect(freeActions, 1);
          expect(upgrades, 0);
          await tester.tap(find.byKey(const Key('upgrade')));
          expect(upgrades, 1);
          expect(paidActions, 0);
          expect(tester.takeException(), isNull);
          await captureClosureSurface(
            tester,
            find.byKey(const Key('named-mask-capture')),
            'premium-mask-${dark ? 'dark' : 'light'}-${arabic ? 'ar' : 'en'}-320-2x',
          );
          semantics.dispose();
        },
      );
    }
  }

  testWidgets('checking and error do not offer an upgrade or leak focus', (
    tester,
  ) async {
    var upgrades = 0, retries = 0;
    await tester.pumpWidget(
      _app(
        child: PremiumValueMask(
          locked: false,
          checking: true,
          onUpgrade: () => upgrades++,
          child: const SizedBox(height: 120, child: Text('private value')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Premium'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    await tester.pumpWidget(
      _app(
        child: PremiumValueMask(
          locked: false,
          onRetry: () => retries++,
          onUpgrade: () => upgrades++,
          actionKey: const Key('retry'),
          child: const SizedBox(height: 120, child: Text('private value')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retry')));
    expect(retries, 1);
    expect(upgrades, 0);
    expect(find.text('Premium'), findsNothing);
  });
}

Widget _app({required Widget child, bool dark = false, bool arabic = false}) =>
    MaterialApp(
      locale: Locale(arabic ? 'ar' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: visualEvidenceTheme(
        dark
            ? BilFlagshipTheme.dark(isArabic: arabic)
            : BilFlagshipTheme.light(isArabic: arabic),
        fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          highContrast: true,
          accessibleNavigation: true,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    );
