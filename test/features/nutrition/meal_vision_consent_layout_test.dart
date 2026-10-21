import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_consent_gate.dart';
import 'package:body_intelligence_log/shared/widgets/bil_premium_trust_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['en', 'ar']) {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final scale in [1.0, 2.5]) {
        testWidgets('meal-photo consent $language ${platform.name} ${scale}x '
            'keeps both decisions visible without nesting cards', (
          tester,
        ) async {
          final size = scale == 1 ? const Size(430, 932) : const Size(320, 568);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final decisions = <bool?>[];
          const capture = Key('meal-photo-review-boundary');
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: visualEvidenceTheme(
                (platform == TargetPlatform.iOS
                        ? BilFlagshipTheme.light(isArabic: language == 'ar')
                        : BilFlagshipTheme.dark(isArabic: language == 'ar'))
                    .copyWith(platform: platform),
                fontFamily: language == 'ar'
                    ? 'NotoArabicEvidence'
                    : 'RobotoEvidence',
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  viewPadding: const EdgeInsets.symmetric(vertical: 24),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: capture, child: child!),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const Key('open'),
                      onPressed: () async {
                        decisions.add(
                          await showMealVisionConsentDisclosure(context),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          final allow = find.byKey(const Key('meal-vision-consent-accept'));
          final decline = find.byKey(const Key('meal-vision-consent-decline'));
          for (final decision in [false, true]) {
            await tester.tap(find.byKey(const Key('open')));
            await tester.pumpAndSettle();
            expect(
              decisions,
              decision ? [false] : isEmpty,
              reason: 'Reading is not an affirmative consent decision.',
            );
            expect(find.byType(BilPremiumTrustSurface), findsNothing);
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.textContaining('Google Gemini'), findsNWidgets(2));
            expect(
              Directionality.of(tester.element(allow)),
              language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
            for (final action in [allow, decline]) {
              expect(action.hitTestable(), findsOneWidget);
              final rect = tester.getRect(action);
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
              expect(rect.top, greaterThanOrEqualTo(24));
              expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
            }
            expect(tester.takeException(), isNull);
            if (!decision &&
                scale == 1 &&
                platform == TargetPlatform.iOS &&
                const bool.fromEnvironment('BIL_CAPTURE_CONSENT_REVIEW')) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(capture),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/consent-layout-review/meal-photo-$language.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.tap(decision ? allow : decline);
            await tester.pumpAndSettle();
            expect(decisions.last, decision);
          }
          await tester.tap(find.byKey(const Key('open')));
          await tester.pumpAndSettle();
          unawaited(tester.binding.handlePopRoute());
          await tester.pumpAndSettle();
          expect(decisions, [false, true, null]);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
