import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/system_speech_disclosure.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:body_intelligence_log/shared/widgets/bil_native_settings_icon.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs production pages/native bridges using isolated in-memory QA data.
/// No real account, entitlement, purchase, health sync or Supabase write.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native symbols and Arabic single-line profile on device', (
    tester,
  ) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);
    final platform = Platform.isAndroid
        ? TargetPlatform.android
        : TargetPlatform.iOS;
    BilNativeSettingsSymbols.clearCache();
    for (final symbol in BilSettingsSymbol.values) {
      final bytes = await BilNativeSettingsSymbols.load(symbol, 66, platform);
      expect(
        bytes,
        isNotNull,
        reason: '${symbol.name} must be native, not a fallback',
      );
      expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    }
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'native-ui-test-only',
    );
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 35,
      height: 178,
      currentWeight: 85.8,
      targetWeight: 79,
      activityLevel: 'light',
      exercises: true,
    );
    await PreferencesRepository(
      database,
    ).set('displayName', 'عضو BIL التجريبي');
    const identity = ProfileAuthIdentity(
      ownerId: 'native-ui-test-only',
      email: 'long.profile.email.for.layout@example.invalid',
    );
    Widget harness(
      Widget page, {
      bool premiumFixture = false,
      bool dark = false,
      String language = 'ar',
    }) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        profileAuthIdentityProvider.overrideWith(
          (ref) => Stream.value(identity),
        ),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: premiumFixture
                  ? CommercePlan.premiumAiCoach
                  : CommercePlan.free,
              entitlements: premiumFixture
                  ? PaidPlanCatalog.composedEntitlementsFor(
                      CommercePlan.premiumAiCoach,
                    )
                  : const {},
              authority: premiumFixture
                  ? EntitlementAuthority.verifiedServer
                  : EntitlementAuthority.localDefault,
              currentPeriodEndsAt: premiumFixture
                  ? DateTime.now().toUtc().add(const Duration(days: 1))
                  : null,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
        nutritionGoalDefaultsProvider.overrideWithValue(const {
          'goal.calories': 1800,
          'goal.carbsPercent': 45,
          'goal.proteinPercent': 30,
          'goal.fatPercent': 25,
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme:
            (dark
                    ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                    : BilFlagshipTheme.light(isArabic: language == 'ar'))
                .copyWith(platform: platform),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpWidget(harness(const PremiumProfilePage()));
    await tester.pumpAndSettle();
    // Native image decoding may settle after the method channel response.
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const Key('native-settings-symbol-email')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings-symbol-preview-fallback')),
      findsNothing,
    );
    final email = tester.widget<Text>(find.text(identity.email!));
    expect(email.maxLines, 1);
    expect(email.overflow, TextOverflow.ellipsis);
    expect(email.semanticsLabel, identity.email);
    expect(tester.takeException(), isNull);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await _capture(binding, tester, 'profile-ar-${platform.name}');

    await tester.pumpWidget(harness(const ReferenceSettingsHomePage()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const Key('settings-symbol-preview-fallback')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _capture(binding, tester, 'settings-ar-${platform.name}');

    // Capture the production dialogs with the real platform font. The Widget
    // evidence loader intentionally uses Naskh; it must not stand in for this.
    final preferences = PreferencesRepository(database);
    final captures = <String>[];
    for (final language in ['ar', 'en']) {
      for (final dark in [false, true]) {
        await preferences.set('goal.calories', '1800');
        await tester.pumpWidget(
          harness(
            const ReferenceNutritionGoalsPage(),
            premiumFixture: true,
            language: language,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('nutrition-goal-goal.calories')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), '1875');
        expect(find.byType(FilledButton).last.hitTestable(), findsOneWidget);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final prefix = '$language-${dark ? 'dark-200' : 'light'}';
        final goalCapture = 'pearl-goal-$prefix-${platform.name}';
        await _capture(binding, tester, goalCapture);
        captures.add(goalCapture);
        await tester.tap(find.byType(FilledButton).last);
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(AlertDialog).evaluate().isEmpty) break;
        }
        expect(find.byType(AlertDialog), findsNothing);
        // MacroGoalAllocation persists doubles (1875.0); validate the saved
        // quantity, not an unrelated integer/string serialization choice.
        expect(
          double.tryParse(await preferences.get('goal.calories') ?? ''),
          1875,
        );
        expect(tester.takeException(), isNull);

        if (Platform.isAndroid) {
          final disclosure = BilSystemSpeechDisclosure();
          final context = tester.element(
            find.byType(ReferenceNutritionGoalsPage),
          );
          final decision = disclosure.authorize(
            context,
            use: BilSpeechUse.food,
          );
          await tester.pumpAndSettle();
          final decline = find.byKey(
            const Key('system-speech-disclosure-decline'),
          );
          expect(decline.hitTestable(), findsOneWidget);
          final voiceCapture = 'pearl-voice-$prefix-${platform.name}';
          await _capture(binding, tester, voiceCapture);
          captures.add(voiceCapture);
          await tester.tap(decline);
          await tester.pumpAndSettle();
          expect(await decision, isFalse);
          disclosure.resetLive();
          expect(tester.takeException(), isNull);
        }
      }
    }
    final root = Platform.isAndroid
        ? (await getExternalStorageDirectory())!
        : await getApplicationDocumentsDirectory();
    final metadata = File('${root.path}/platform-polish/pearl-native.json');
    await metadata.writeAsString(
      jsonEncode({
        'platform': Platform.operatingSystem,
        'source_head': const String.fromEnvironment('BIL_QA_SOURCE_HEAD'),
        'source_tree': const String.fromEnvironment(
          'BIL_QA_SOURCE_FINGERPRINT',
        ),
        'platform_font_unmodified': true,
        'synthetic_premium_fixture_only': true,
        'real_reviewer_account_tested': false,
        'microphone_or_cloud_called': false,
        'calorie_save_and_readback_variants': 4,
        'captures': captures,
      }),
      flush: true,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final bytes = await binding.takeScreenshot(name);
  final root = Platform.isAndroid
      ? (await getExternalStorageDirectory())!
      : await getApplicationDocumentsDirectory();
  final directory = Directory('${root.path}/platform-polish');
  await directory.create(recursive: true);
  await File('${directory.path}/$name.png').writeAsBytes(bytes, flush: true);
}
