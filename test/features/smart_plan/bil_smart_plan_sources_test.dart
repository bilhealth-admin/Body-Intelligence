import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/core/health_evidence/health_evidence_catalog.dart';
import 'package:body_intelligence_log/features/settings/health_information_sources_page.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_sources.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _book = ValueKey('sources-test-book');
const _capture = ValueKey('sources-test-capture');

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  test(
    'Home references exactly project the hash-checked prescription document',
    () async {
      final source =
          jsonDecode(
                await rootBundle.loadString(
                  BilSmartPlanPrescriptions.homeAssetPath,
                ),
              )
              as Map<String, dynamic>;
      final metadata = await const BilSmartPlanPrescriptions().homeSources();
      final expected = source['sources'] as List;
      expect(metadata, hasLength(4));
      for (var i = 0; i < expected.length; i++) {
        expect(metadata[i].publisher, expected[i]['publisher']);
        expect(metadata[i].title, expected[i]['title']);
        expect(metadata[i].url.toString(), expected[i]['url']);
        expect(metadata[i].url.scheme, 'https');
      }
    },
  );

  test(
    'the two existing plan references have Arabic notes and unchanged English',
    () {
      for (final id in [
        HealthEvidenceIds.activityGuidelines,
        HealthEvidenceIds.healthyEating,
      ]) {
        final source = HealthEvidenceCatalog.byId(id)!;
        for (final english in [
          source.shortDescription,
          source.methodologyNote,
        ]) {
          final arabic = RuntimeCopy.resolve(english, 'ar');
          expect(arabic, isNotNull);
          expect(RegExp(r'[\u0600-\u06ff]').hasMatch(arabic!), isTrue);
          expect(AppLocalizations(const Locale('en')).text(english), english);
        }
      }
      expect(
        HealthEvidenceCatalog.byId(
          HealthEvidenceIds.activityGuidelines,
        )!.url.toString(),
        'https://health.gov/our-work/nutrition-physical-activity/physical-activity-guidelines/current-guidelines',
      );
      expect(
        HealthEvidenceCatalog.byId(
          HealthEvidenceIds.healthyEating,
        )!.url.toString(),
        'https://www.cdc.gov/healthy-weight-growth/healthy-eating/index.html',
      );
    },
  );

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final large in [false, true]) {
        testWidgets(
          'book $language dark=$dark large=$large opens exact references, original methodology and returns safely',
          (tester) async {
            final diagnostics = <String>[];
            final originalDebugPrint = debugPrint;
            debugPrint = (message, {wrapWidth}) {
              diagnostics.add(message ?? '');
              originalDebugPrint(message, wrapWidth: wrapWidth);
            };
            addTearDown(() => debugPrint = originalDebugPrint);
            try {
              final previous = UrlLauncherPlatform.instance;
              final launcher = _Launcher();
              UrlLauncherPlatform.instance = launcher;
              addTearDown(() => UrlLauncherPlatform.instance = previous);
              tester.view.physicalSize = Size(large ? 320 : 390, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final router = GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, _) => Scaffold(
                      appBar: AppBar(
                        title: Text(language == 'ar' ? 'خطتي' : 'My Plan'),
                        actions: [
                          BilSmartPlanBookButton(
                            key: _book,
                            label: language == 'ar'
                                ? 'مصادر الخطة'
                                : 'Plan sources',
                            onPressed: () =>
                                showBilSmartPlanSources(context, home: true),
                          ),
                        ],
                      ),
                      body: const Text('saved-plan-anchor'),
                    ),
                  ),
                  GoRoute(
                    path: '/health-information-sources',
                    builder: (_, state) => HealthInformationSourcesPage(
                      sourceIds: state.uri.queryParameters['sources']!.split(
                        ',',
                      ),
                    ),
                  ),
                ],
              );
              addTearDown(router.dispose);
              final font = language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence';
              await tester.pumpWidget(
                MaterialApp.router(
                  routerConfig: router,
                  theme: visualEvidenceTheme(
                    dark
                        ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                        : BilFlagshipTheme.light(isArabic: language == 'ar'),
                    fontFamily: font,
                  ),
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  builder: (context, child) => RepaintBoundary(
                    key: _capture,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        disableAnimations: true,
                        textScaler: TextScaler.linear(large ? 2 : 1),
                      ),
                      child: visualEvidenceTextSurface(child, fontFamily: font),
                    ),
                  ),
                ),
              );
              await _frames(tester);
              await tester.tap(find.byKey(_book));
              await _frames(tester);
              expect(find.byType(BilSmartPlanSourcesPanel), findsOneWidget);
              expect(
                Directionality.of(
                  tester.element(find.byType(BilSmartPlanSourcesPanel)),
                ),
                language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              );
              final captureName =
                  'plan-sources-$language-${dark ? 'dark' : 'light'}-${large ? '320-200pct' : '390-100pct'}';
              await _captureIfRequested(tester, '$captureName-top');
              final metadata = await const BilSmartPlanPrescriptions()
                  .homeSources();
              final scroll = find.descendant(
                of: find.byType(BilSmartPlanSourcesPanel),
                matching: find.byType(Scrollable),
              );
              for (final item in metadata) {
                final label = find.text('${item.publisher} · ${item.title}');
                await tester.scrollUntilVisible(label, 180, scrollable: scroll);
                await _frames(tester);
                await tester.tap(label);
                await _frames(tester);
                expect(launcher.urls.last, item.url.toString());
                expect(
                  launcher.modes.last,
                  PreferredLaunchMode.externalApplication,
                );
                expect(tester.takeException(), isNull);
              }
              final methodology = find.byKey(
                const ValueKey('bil-smart-plan-health-methodology'),
              );
              await tester.scrollUntilVisible(
                methodology,
                180,
                scrollable: scroll,
              );
              await _frames(tester);
              expect(methodology.hitTestable(), findsOneWidget);
              await _captureIfRequested(tester, '$captureName-footer');
              await tester.tap(methodology);
              await _frames(tester);
              expect(find.byType(BilSmartPlanSourcesPanel), findsNothing);
              expect(find.byType(HealthInformationSourcesPage), findsOneWidget);
              expect(
                tester
                    .widget<HealthInformationSourcesPage>(
                      find.byType(HealthInformationSourcesPage),
                    )
                    .sourceIds,
                containsAll([
                  HealthEvidenceIds.activityGuidelines,
                  HealthEvidenceIds.dietaryReferenceIntakes,
                  HealthEvidenceIds.fdaDailyValues,
                  HealthEvidenceIds.healthyEating,
                ]),
              );
              final featured = find.byKey(
                const ValueKey(
                  'health-source-${HealthEvidenceIds.activityGuidelines}',
                ),
              );
              await tester.scrollUntilVisible(featured, 180);
              expect(featured, findsOneWidget);
              router.pop();
              await _frames(tester);
              expect(find.text('saved-plan-anchor'), findsOneWidget);
              // Page routes may own a transparent ModalBarrier. Prove that no
              // stranded sheet blocks interaction by reopening the real action.
              expect(find.byType(BottomSheet), findsNothing);
              expect(find.byKey(_book).hitTestable(), findsOneWidget);
              await tester.tap(find.byKey(_book));
              await _frames(tester);
              expect(find.byType(BilSmartPlanSourcesPanel), findsOneWidget);
              expect(tester.takeException(), isNull);
              expect(
                diagnostics.where(
                  (line) =>
                      line.contains('Missing reviewed runtime translation'),
                ),
                isEmpty,
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await _frames(tester);
            } finally {
              // The framework checks foundation globals before addTearDown.
              debugPrint = originalDebugPrint;
            }
          },
        );
      }
    }
  }
}

Future<void> _captureIfRequested(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('BIL_DASHBOARD_CAPTURE_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('No rendered PNG');
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}

class _Launcher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;
  final urls = <String>[];
  final modes = <PreferredLaunchMode>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    modes.add(options.mode);
    return true;
  }
}
