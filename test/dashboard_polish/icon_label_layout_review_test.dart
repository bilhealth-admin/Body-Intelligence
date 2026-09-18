import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(
    () => loadVisualEvidenceFontWhenCapturing('BIL_CAPTURE_ICON_POLISH'),
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final width in [320.0, 390.0, 430.0, 600.0]) {
        for (final scale in [1.0, 1.6]) {
          final description = '${platform.name} $locale $width text $scale';
          final capture =
              Platform.environment['BIL_CAPTURE_ICON_POLISH'] == '1' &&
              platform == TargetPlatform.iOS &&
              width == 430 &&
              scale == 1;

          testWidgets('Customize Today icon spacing: $description', (
            tester,
          ) async {
            _setSurface(tester, width);
            final database = AppDatabase.forTesting(NativeDatabase.memory());
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
              await database.close();
            });
            await tester.pumpWidget(
              _subject(
                database: database,
                locale: locale,
                scale: scale,
                platform: platform,
                home: const DashboardPreferencesPage(),
              ),
            );
            await tester.pumpAndSettle();

            final carousel = find.byKey(const Key('dashboard-preset-carousel'));
            final carouselScroll = find.descendant(
              of: carousel,
              matching: find.byType(Scrollable),
            );
            for (final id in [
              'calorie',
              'macros',
              'heart',
              'low_carb',
              'custom',
            ]) {
              final preset = find.byKey(Key('dashboard-preset-$id'));
              await tester.scrollUntilVisible(
                preset,
                250,
                scrollable: carouselScroll,
              );
              await tester.pumpAndSettle();
              final tile = tester.widget<ListTile>(preset);
              _expectBadgeGap(tester, preset, find.byWidget(tile.title!), 32);
              final title = tester.getRect(find.byWidget(tile.title!));
              final subtitle = tester.getRect(find.byWidget(tile.subtitle!));
              final card = tester.getRect(preset);
              expect(title.top, greaterThanOrEqualTo(card.top));
              expect(subtitle.bottom, lessThanOrEqualTo(card.bottom));
              expect(tester.takeException(), isNull, reason: id);
            }
            tester.state<ScrollableState>(carouselScroll).position.jumpTo(0);
            await tester.pumpAndSettle();
            if (capture) {
              await _capture(tester, 'customize-${locale.languageCode}');
            }

            final pageScroll = find.byType(Scrollable).first;
            for (final id in DashboardSectionIds.all) {
              final section = find.byKey(Key('dashboard-section-$id'));
              await tester.scrollUntilVisible(
                section,
                250,
                scrollable: pageScroll,
              );
              await tester.ensureVisible(section);
              await tester.pumpAndSettle();
              final tile = tester.widget<SwitchListTile>(section);
              final title = find.byWidget(tile.title!);
              _expectBadgeGap(tester, section, title, 30);
              final paragraph = tester.renderObject<RenderParagraph>(title);
              expect(paragraph.didExceedMaxLines, isFalse);
              final titleRect = tester.getRect(title);
              final tileRect = tester.getRect(section);
              expect(tileRect.height, greaterThanOrEqualTo(48));
              expect(titleRect.top, greaterThanOrEqualTo(tileRect.top));
              expect(titleRect.bottom, lessThanOrEqualTo(tileRect.bottom));
              final controlRect = tester.getRect(
                find.descendant(of: section, matching: find.byType(Switch)),
              );
              final direction = Directionality.of(tester.element(section));
              expect(
                direction == TextDirection.ltr
                    ? controlRect.left - titleRect.right
                    : titleRect.left - controlRect.right,
                greaterThanOrEqualTo(12),
              );
              // Tapping the unchanged native tile still updates the saved
              // preference; smaller decoration does not shrink the hit area.
              final previous = tile.value;
              await tester.tap(title);
              await tester.pumpAndSettle();
              expect(tester.widget<SwitchListTile>(section).value, !previous);
              final container = ProviderScope.containerOf(
                tester.element(section),
              );
              expect(
                await container
                    .read(preferencesRepositoryProvider)
                    .get('dashboard.section.$id'),
                (!previous).toString(),
              );
              expect(tester.takeException(), isNull, reason: id);
            }
            if (capture) {
              await _capture(tester, 'custom-cards-${locale.languageCode}');
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });

          testWidgets('Body context icon spacing and route: $description', (
            tester,
          ) async {
            _setSurface(tester, width);
            final database = AppDatabase.forTesting(NativeDatabase.memory());
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
              await database.close();
            });
            final router = GoRouter(
              initialLocation: '/daily-log',
              routes: [
                GoRoute(
                  path: '/daily-log',
                  builder: (_, _) => const DailyLogPage(),
                ),
                GoRoute(
                  path: '/daily-log/body-context',
                  builder: (_, _) =>
                      const Scaffold(body: Text('body-context-destination')),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              _subject(
                database: database,
                locale: locale,
                scale: scale,
                platform: platform,
                router: router,
              ),
            );
            await tester.pumpAndSettle();
            final bodyContext = find.byKey(
              const Key('daily-log-body-context-link'),
            );
            await tester.scrollUntilVisible(
              bodyContext,
              350,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(bodyContext);
            await tester.pumpAndSettle();
            final tile = tester.widget<ListTile>(
              find.descendant(of: bodyContext, matching: find.byType(ListTile)),
            );
            _expectBadgeGap(
              tester,
              bodyContext,
              find.byWidget(tile.title!),
              32,
            );
            _expectBadgeGap(
              tester,
              bodyContext,
              find.byWidget(tile.subtitle!),
              32,
            );
            expect(tester.takeException(), isNull);
            if (capture) {
              await _capture(tester, 'body-context-${locale.languageCode}');
            }
            await tester.tap(find.byWidget(tile.title!));
            await tester.pumpAndSettle();
            expect(find.text('body-context-destination'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
        }
      }
    }
  }
}

void _setSurface(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _subject({
  required AppDatabase database,
  required Locale locale,
  required double scale,
  required TargetPlatform platform,
  Widget? home,
  GoRouter? router,
}) {
  final arabic = locale.languageCode == 'ar';
  final theme = visualEvidenceTheme(
    BilFlagshipTheme.light(isArabic: arabic).copyWith(platform: platform),
    fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
  );
  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(
      key: const Key('icon-polish-capture'),
      child: child!,
    ),
  );
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      verifiedSubscriptionStateProvider.overrideWithValue(
        AsyncData(FreePlan.createState()),
      ),
      userProfileProvider.overrideWithValue(const AsyncData(null)),
      seedCatalogProvider.overrideWith((_) async {}),
      foodsProvider.overrideWithValue(const AsyncData(<Food>[])),
      selectedDailyLogProvider.overrideWithValue(const AsyncData(null)),
      measurementSystemProvider.overrideWithValue(
        const AsyncData(MeasurementSystem.metric),
      ),
    ],
    child: router == null
        ? MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: theme,
            builder: builder,
            home: home,
          )
        : MaterialApp.router(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: theme,
            builder: builder,
            routerConfig: router,
          ),
  );
}

void _expectBadgeGap(
  WidgetTester tester,
  Finder tile,
  Finder text,
  double size,
) {
  final badge = find.descendant(
    of: tile,
    matching: find.byType(BilSemanticIconBadge),
  );
  expect(badge, findsOneWidget);
  expect(tester.getSize(badge), Size.square(size));
  expect(tester.widget<BilSemanticIconBadge>(badge).iconSize, 18);
  final badgeRect = tester.getRect(badge);
  final textRect = tester.getRect(text);
  final direction = Directionality.of(tester.element(tile));
  expect(
    direction == TextDirection.ltr
        ? textRect.left - badgeRect.right
        : badgeRect.left - textRect.right,
    greaterThanOrEqualTo(12),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('icon-polish-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/dashboard_polish_review/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
