import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
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
    Widget harness(Widget page) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        profileAuthIdentityProvider.overrideWith(
          (ref) => Stream.value(identity),
        ),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.free,
              entitlements: const {},
              authority: EntitlementAuthority.localDefault,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BilFlagshipTheme.light(
          isArabic: true,
        ).copyWith(platform: platform),
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
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
    await _capture(binding, 'profile-ar-${platform.name}');

    await tester.pumpWidget(harness(const ReferenceSettingsHomePage()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const Key('settings-symbol-preview-fallback')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _capture(binding, 'settings-ar-${platform.name}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final root = Platform.isAndroid
      ? (await getExternalStorageDirectory())!
      : await getApplicationDocumentsDirectory();
  final directory = Directory('${root.path}/platform-polish');
  await directory.create(recursive: true);
  await File('${directory.path}/$name.png').writeAsBytes(bytes, flush: true);
}
