import 'dart:io';
import 'dart:ui' as ui;
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/presentation/community_report_sheet.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['ar', 'en']) {
    for (final target in CommunityReportTarget.values) {
      testWidgets(
        'actual BIL community report $language $target has its own copy and reachable actions',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final boundary = GlobalKey();
          CommunityReportDraft? receipt;
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
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
                home: CommunitySurface(
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => FilledButton(
                        onPressed: () async {
                          receipt = await showCommunityReportSheet(
                            context,
                            target: target,
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final titles = language == 'ar'
              ? [
                  'الإبلاغ عن المنشور',
                  'الإبلاغ عن التعليق',
                  'الإبلاغ عن الرد',
                  'الإبلاغ عن العضو',
                  'الإبلاغ عن هذه الرسالة',
                  'الإبلاغ عن الدائرة',
                ]
              : [
                  'Report post',
                  'Report comment',
                  'Report reply',
                  'Report member',
                  'Report this message',
                  'Report circle',
                ];
          expect(find.text(titles[target.index]), findsOneWidget);
          expect(find.textContaining('AI Coach'), findsNothing);
          expect(find.textContaining('إجابة'), findsNothing);
          expect(find.textContaining('Your question'), findsNothing);
          await tester.tap(
            find.byKey(const Key('community-report-reason-tap-harassment')),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final png =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final bytes = await png.toByteData(format: ui.ImageByteFormat.png);
            final output = File(
              'build/community-policy-repair-20261019/report-visuals/report-$language-${target.name}.png',
            );
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes!.buffer.asUint8List());
            png.dispose();
          });
          final send = find.byKey(const Key('community-report-submit'));
          await tester.ensureVisible(send);
          await tester.pumpAndSettle();
          expect(send.hitTestable(), findsOneWidget);
          await tester.tap(send);
          await tester.pumpAndSettle();
          expect(receipt?.category, 'harassment');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
