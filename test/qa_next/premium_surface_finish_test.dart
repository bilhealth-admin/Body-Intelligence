import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/shared/widgets/bil_surface.dart';
import 'package:body_intelligence_log/shared/widgets/premium_surface.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/bil_meal_voice_capture_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:body_intelligence_log/features/visual_2026/bil_calm_visual_scope.dart';
import '../visual_closure/closure_surface_capture.dart';
import '../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  testWidgets(
    'secondary pearl page never reveals text from the previous route',
    (tester) async {
      Future<List<int>> render(String underlying) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: const Key('owned-page-pixels'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Text(
                    underlying,
                    style: const TextStyle(color: Colors.red, fontSize: 50),
                  ),
                  BilCalmVisualScope(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('Same visible page')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('owned-page-pixels')),
        );
        return (await tester.runAsync(() async {
          final rendered = await boundary.toImage();
          try {
            return (await rendered.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List().toList();
          } finally {
            rendered.dispose();
          }
        }))!;
      }

      expect(
        await render('PRIVATE ACCOUNT A'),
        await render('OTHER ACCOUNT B — DIFFERENT TEXT'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    for (final ar in [false, true]) {
      for (final width in [320.0, 430.0, 768.0]) {
        testWidgets(
          'shared premium surfaces ${dark ? 'dark' : 'light'} ${ar ? 'ar' : 'en'} $width',
          (tester) async {
            tester.view.physicalSize = Size(width, 1024);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var pressed = 0;
            final editor = TextEditingController(
              text: ar
                  ? 'فول مدمس مع طحينة 80 غرامًا'
                  : 'Fava beans with tahini, 80 grams',
            );
            addTearDown(editor.dispose);
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(ar ? 'ar' : 'en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: visualEvidenceTheme(
                  dark
                      ? BilFlagshipTheme.dark(isArabic: ar)
                      : BilFlagshipTheme.light(isArabic: ar),
                  fontFamily: ar ? 'NotoArabicEvidence' : 'RobotoEvidence',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  appBar: AppBar(
                    title: Text(ar ? 'مراجعة الطعام' : 'Food review'),
                  ),
                  body: RepaintBoundary(
                    key: const Key('premium-evidence-root'),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        BilSurface.glass(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ar ? 'القيمة الغذائية' : 'Nutrition summary',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                ar
                                    ? 'المغذيات غير المعروفة تبقى غير متوفرة.'
                                    : 'Unknown nutrients remain unavailable.',
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => pressed++,
                                child: Text(ar ? 'مراجعة' : 'Review'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        PremiumSurface(
                          child: Text(
                            ar
                                ? 'وجباتي ووصفاتي — محتوى اختبار واضح'
                                : 'My meals and recipes — explicit test content',
                          ),
                        ),
                        const SizedBox(height: 16),
                        BilMealVoiceCaptureDialog(
                          title: ar ? 'البحث بالصوت' : 'Voice search',
                          instructions: ar
                              ? 'راجع النص قبل البحث.'
                              : 'Review the text before searching.',
                          transcript: editor.text,
                          editor: editor,
                          editing: true,
                          cancelLabel: ar ? 'إلغاء' : 'Cancel',
                          useLabel: ar
                              ? 'استخدام النص للبحث عن الطعام'
                              : 'Use text to search food',
                          onEdit: () {},
                          onCancel: () {},
                          onUse: () => pressed++,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final action = find.widgetWithText(
              FilledButton,
              ar ? 'مراجعة' : 'Review',
            );
            await tester.ensureVisible(action);
            await tester.tap(action);
            expect(pressed, 1);
            expect(tester.takeException(), isNull);
            if (width == 430) {
              await captureClosureSurface(
                tester,
                find.byType(Scaffold).first,
                'shared-${dark ? 'dark' : 'light'}-${ar ? 'ar' : 'en'}',
              );
            }
          },
        );
      }
    }
  }
}
