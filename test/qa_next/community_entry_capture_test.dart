import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/community/community_entry_flow_test.dart'
    show EntryRepositoryFixture;
import '../visual_closure/visual_evidence_font.dart';

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['BIL_ENTRY_CAPTURE_DIR'];
  if (output == null) return;
  final box = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await box.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'actual name-only entry, error and successful save $language dark=$dark',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final repo = EntryRepositoryFixture()..failCode = true;
          addTearDown(repo.communitySocialClient.dispose);
          final key = GlobalKey();
          final router = GoRouter(
            initialLocation: '/community',
            routes: [
              GoRoute(
                path: '/community',
                builder: (_, _) => CommunityEntryGate(
                  repository: repo,
                  child: const Scaffold(
                    body: Text('Verified member destination'),
                  ),
                ),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const Scaffold(body: Text('Dashboard')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                routerConfig: router,
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: visualEvidenceTheme(
                  dark
                      ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                      : BilFlagshipTheme.light(isArabic: language == 'ar'),
                  fontFamily: language == 'ar'
                      ? 'NotoArabicEvidence'
                      : 'RobotoEvidence',
                ),
                builder: (context, child) => RepaintBoundary(
                  key: key,
                  child: visualEvidenceTextSurface(child),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await settleVisualAssetImages(tester);
          await tester.pumpAndSettle();
          final suffix = '$language-${dark ? 'dark' : 'light'}';
          expect(find.byType(TextField), findsOneWidget);
          expect(repo.writes, isEmpty);
          await _capture(tester, key, 'entry-$suffix');
          final field = find.byKey(const Key('community-entry-name'));
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(
            field,
            language == 'ar' ? 'عضو تجريبي' : 'Sample member',
          );
          final save = find.byKey(const Key('community-entry-save'));
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('community-entry-error')),
            findsOneWidget,
          );
          await _capture(tester, key, 'entry-retry-$suffix');
          repo.failCode = false;
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text('Verified member destination'), findsOneWidget);
          expect(repo.writes, hasLength(1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
