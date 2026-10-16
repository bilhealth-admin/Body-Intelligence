import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/ai_coach_report_confirmation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);

  for (final language in ['ar', 'en']) {
    testWidgets('captures the real AI Coach report sheet in $language', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundaryKey = GlobalKey();
      final submitted = <AiCoachAnswerReportDraft>[];
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: visualEvidenceTheme(
              BilFlagshipTheme.light(isArabic: language == 'ar'),
              fontFamily: language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    key: const Key('open-report-sheet-capture'),
                    onPressed: () =>
                        showAiCoachAnswerReportSheet(context, submitted.add),
                    child: const Text('Open report sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-report-sheet-capture')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('ai-coach-report-reason-unsafe')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai-coach-report-reason-medical_accuracy')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai-coach-report-reason-offensive')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai-coach-report-reason-other')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-coach-confirm-report')), findsOneWidget);
      expect(
        find.text('Inaccurate or misleading information'),
        language == 'en' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('معلومة غير دقيقة أو مضللة'),
        language == 'ar' ? findsOneWidget : findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('ai-coach-confirm-report')),
            )
            .onPressed,
        isNull,
        reason: 'The report must not be submittable before reason and consent.',
      );
      final submitButton = find.byKey(const Key('ai-coach-confirm-report'));
      final submitLabelFinder = find.descendant(
        of: submitButton,
        matching: find.byType(Text),
      );
      final disabledSubmitLabel = tester.widget<Text>(submitLabelFinder);
      expect(
        disabledSubmitLabel.style?.color,
        Theme.of(tester.element(submitButton)).colorScheme.onSurface,
      );
      await tester.tap(
        find.byKey(const Key('ai-coach-report-privacy-details')),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.textContaining('Your question, other messages'),
        language == 'en' ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('لا يُرسل سؤالك'),
        language == 'ar' ? findsOneWidget : findsNothing,
      );
      await tester.tap(
        find.byKey(const Key('ai-coach-report-privacy-details')),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.tap(
        find.byKey(const Key('ai-coach-report-reason-tap-medical_accuracy')),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('ai-coach-confirm-report')),
            )
            .onPressed,
        isNull,
        reason: 'A reason alone must not grant consent.',
      );
      await tester.tap(find.byKey(const Key('ai-coach-report-consent')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('ai-coach-confirm-report')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('ai-coach-report-consent')))
            .value,
        isTrue,
      );
      final submitLabel = tester.widget<Text>(submitLabelFinder);
      expect(submitLabel.style?.color, isNotNull);
      expect(
        submitLabel.style?.color,
        Theme.of(tester.element(submitButton)).colorScheme.onPrimary,
      );
      expect(tester.takeException(), isNull);

      if (Platform.environment['BIL_CAPTURE_COACH_RELEASE'] != '0') {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory(
              'build/stage1-closure/ai-coach-safety-report-captures',
            );
            await directory.create(recursive: true);
            await File(
              '${directory.path}/report-sheet-$language-light.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        await tester.ensureVisible(
          find.byKey(const Key('ai-coach-confirm-report')),
        );
      }

      await tester.tap(find.byKey(const Key('ai-coach-confirm-report')));
      await tester.pumpAndSettle();
      expect(submitted, hasLength(1));
      expect(submitted.single.reason, 'medical_accuracy');
      expect(submitted.single.explicitConsentAccepted, isTrue);
      expect(submitted.single.optionalNote, isNull);
    });
  }

  testWidgets('Other accepts an optional note and empty note stays optional', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    AiCoachAnswerReportDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: visualEvidenceTheme(BilFlagshipTheme.light()),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-report-sheet-capture'),
                onPressed: () => showAiCoachAnswerReportSheet(
                  context,
                  (value) => submitted = value,
                ),
                child: const Text('Open report sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-report-sheet-capture')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('ai-coach-report-reason-tap-other')));
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      find.byKey(const Key('ai-coach-report-optional-note')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-coach-report-consent')));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.ensureVisible(
      find.byKey(const Key('ai-coach-confirm-report')),
    );
    await tester.tap(find.byKey(const Key('ai-coach-confirm-report')));
    await tester.pumpAndSettle();
    expect(submitted?.reason, 'other');
    expect(submitted?.explicitConsentAccepted, isTrue);
    expect(submitted?.optionalNote, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Other forwards an optional note when provided', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    AiCoachAnswerReportDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: visualEvidenceTheme(BilFlagshipTheme.light()),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-report-sheet-capture'),
                onPressed: () => showAiCoachAnswerReportSheet(
                  context,
                  (value) => submitted = value,
                ),
                child: const Text('Open report sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-report-sheet-capture')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-coach-report-reason-tap-other')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-coach-report-optional-note')),
      'Please review only this sentence.',
    );
    await tester.tap(find.byKey(const Key('ai-coach-report-consent')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('ai-coach-confirm-report')),
    );
    await tester.tap(find.byKey(const Key('ai-coach-confirm-report')));
    await tester.pumpAndSettle();
    expect(submitted?.reason, 'other');
    expect(submitted?.optionalNote, 'Please review only this sentence.');
    expect(submitted?.explicitConsentAccepted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel closes the report sheet without sending', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final submitted = <AiCoachAnswerReportDraft>[];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: visualEvidenceTheme(BilFlagshipTheme.light()),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-report-sheet-capture'),
                onPressed: () =>
                    showAiCoachAnswerReportSheet(context, submitted.add),
                child: const Text('Open report sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-report-sheet-capture')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-coach-cancel-report')));
    await tester.tap(find.byKey(const Key('ai-coach-cancel-report')));
    await tester.pumpAndSettle();
    expect(submitted, isEmpty);
    expect(find.byKey(const Key('ai-coach-confirm-report')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dark pearl report sheet remains scrollable at 2x text on 320px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(BilFlagshipTheme.dark(isArabic: true)),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const Key('open-report-sheet-capture'),
                  onPressed: () =>
                      showAiCoachAnswerReportSheet(context, (_) {}),
                  child: const Text('Open report sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-report-sheet-capture')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const Key('ai-coach-report-reason-unsafe')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-coach-cancel-report')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
