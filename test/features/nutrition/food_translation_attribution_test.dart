import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/food_translation_attribution.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_presentation_localizer.dart';
import 'package:body_intelligence_log/features/settings/help_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const canonical = 'Synthetic specialty grain number 739';
const translated = 'Céréale spéciale 739';

void main() {
  setUp(() {
    FoodPresentationLocalizer.clearTrustedRuntimeTranslationsForTesting();
    FoodPresentationLocalizer.registerTrustedRuntimeTranslation(
      canonicalName: canonical,
      localeTag: 'fr',
      localizedName: translated,
    );
  });
  tearDown(FoodPresentationLocalizer.clearTrustedRuntimeTranslationsForTesting);

  test('unattributed domain strings retain canonical identity', () {
    expect(
      FoodPresentationLocalizer.foodName(name: canonical, localeTag: 'fr'),
      canonical,
    );
    expect(
      FoodPresentationLocalizer.foodName(
        name: canonical,
        localeTag: 'fr',
        allowCloudTranslation: true,
      ),
      translated,
    );
    expect(
      FoodPresentationLocalizer.foodName(
        name: canonical,
        localeTag: 'fr',
        isCustom: true,
        allowCloudTranslation: true,
      ),
      canonical,
    );
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'cloud label has complete badge at320 $brightness scale$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const Scaffold(
                  body: ListTile(
                    title: GoogleFoodNameText(
                      name: canonical,
                      localeTag: 'fr',
                      maxLines: 2,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(translated), findsOneWidget);
          final image = tester.widget<Image>(find.byType(Image));
          expect(
            (image.image as AssetImage).assetName,
            brightness == Brightness.dark
                ? 'assets/branding/google_translate_white.png'
                : 'assets/branding/google_translate_color.png',
          );
          expect(image.semanticLabel, 'Powered by Google Translate');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('Arabic cloud badge fits320 at2x $brightness', (tester) async {
      FoodPresentationLocalizer.registerTrustedRuntimeTranslation(
        canonicalName: canonical,
        localeTag: 'ar',
        localizedName: 'حبوب خاصة ٧٣٩',
      );
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: ListTile(
                  title: GoogleFoodNameText(
                    name: canonical,
                    localeTag: 'ar',
                    maxLines: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('حبوب خاصة ٧٣٩'), findsOneWidget);
      final badge = find.byKey(
        const Key('food-google-translation-attribution'),
      );
      expect(badge, findsOneWidget);
      expect(tester.getRect(badge).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(badge).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reviewed names do not incorrectly claim Google attribution', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoogleFoodNameText(name: 'Apple', localeTag: 'fr'),
        ),
      ),
    );
    expect(find.text('Pomme'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('actual Help opens processor explanation and warranty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: HelpCenterPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Google Translate'), 400);
    await tester.tap(find.text('Google Translate'));
    await tester.pumpAndSettle();
    expect(find.text(googleTranslationWarrantyNotice), findsOneWidget);
    expect(find.textContaining('Google Cloud Translation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
