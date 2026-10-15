import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/services/system_speech_disclosure.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test/visual_closure/visual_evidence_font.dart';

// Real disclosure route, approved theme and app typography. Synthetic host only;
// this does not initialize a recognizer or claim signed-device reviewer access.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'pearl voice $language ${dark ? 'dark 200% small' : 'light'} remains readable and dismissible',
        (tester) async {
          final compact = dark;
          final font = language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence';
          tester.view.physicalSize = compact
              ? const Size(320, 640)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            late BuildContext host;
            const captureKey = Key('pearl-dialog-visual-capture');
            await tester.pumpWidget(
              RepaintBoundary(
                key: captureKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: visualEvidenceTheme(
                    dark
                        ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                        : BilFlagshipTheme.light(isArabic: language == 'ar'),
                    fontFamily: font,
                  ),
                  locale: Locale(language),
                  supportedLocales: const [Locale('ar'), Locale('en')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  builder: (context, child) => visualEvidenceTextSurface(
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(compact ? 2 : 1),
                      ),
                      child: child!,
                    ),
                    fontFamily: font,
                  ),
                  home: Builder(
                    builder: (context) {
                      host = context;
                      return const Scaffold();
                    },
                  ),
                ),
              ),
            );
            if (!host.mounted) {
              throw StateError('Disclosure host unmounted before decision');
            }
            final consent = BilSystemSpeechDisclosure();
            final decision = consent.authorize(host, use: BilSpeechUse.food);
            await tester.pumpAndSettle();
            final decline = find.byKey(
              const Key('system-speech-disclosure-decline'),
            );
            final allow = find.byKey(
              const Key('system-speech-disclosure-allow'),
            );
            expect(decline.hitTestable(), findsOneWidget);
            expect(allow.hitTestable(), findsOneWidget);
            expect(tester.getSemantics(decline).label, isNotEmpty);
            expect(tester.takeException(), isNull);
            final directory = Platform.environment['BIL_POLICY_CAPTURE_DIR'];
            if (directory != null) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(captureKey),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                try {
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(directory).create(recursive: true);
                  await File(
                    '$directory/$language-voice-${dark ? 'dark-200-small' : 'light'}.png',
                  ).writeAsBytes(png!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
            await tester.tap(decline);
            await tester.pumpAndSettle();
            expect(await decision, isFalse);
            expect(find.byType(AlertDialog), findsNothing);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
