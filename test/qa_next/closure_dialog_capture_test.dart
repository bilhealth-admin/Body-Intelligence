import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/bil_meal_voice_capture_dialog.dart';
import 'package:flutter/material.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../visual_closure/visual_evidence_font.dart';
import '../visual_closure/closure_surface_capture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final surface in ['voice', 'menu']) {
    testWidgets('actual $surface Arabic dark surface capture', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final editor = TextEditingController(text: 'فول مدمس مع طحينة 80 غرامًا');
      addTearDown(editor.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            BilFlagshipTheme.dark(isArabic: true),
            fontFamily: 'NotoArabicEvidence',
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('closure-dialog-root'),
              child: surface == 'voice'
                  ? BilMealVoiceCaptureDialog(
                      title: 'قل اسم الطعام',
                      instructions:
                          'راجع النص قبل استخدامه للبحث. لن يسجل شيء تلقائيًا.',
                      transcript: editor.text,
                      editor: editor,
                      editing: false,
                      cancelLabel: 'إلغاء',
                      useLabel: 'استخدامها في بحث الطعام',
                      onEdit: () {},
                      onCancel: () {},
                      onUse: () {},
                    )
                  : buildCoachMenuEvidenceSurface(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await captureClosureSurface(
        tester,
        find.byKey(const Key('closure-dialog-root')),
        '$surface-ar-dark',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
