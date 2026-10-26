import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoThemeData;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final brightness in Brightness.values) {
      for (final direct in [false, true]) {
        testWidgets('Settings back returns to More: ${locale.languageCode} '
            '${direct ? 'direct' : 'pushed'} ${brightness.name}', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          try {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final router = GoRouter(
              initialLocation: direct ? '/settings/preferences' : '/settings',
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, _) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        key: const Key('more-settings-entry'),
                        onPressed: () => context.push('/settings/preferences'),
                        child: const Text('More origin'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/settings/preferences',
                  builder: (_, _) => const ReferenceSettingsHomePage(),
                ),
              ],
            );
            addTearDown(router.dispose);
            final evidenceFamily = locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence';
            final cupertino = CupertinoThemeData(brightness: brightness);
            final nativeText = cupertino.textTheme;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  profileAuthIdentityProvider.overrideWith(
                    (_) => Stream.value(const ProfileAuthIdentity.local()),
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
                child: MaterialApp.router(
                  routerConfig: router,
                  theme: visualEvidenceTheme(
                    ThemeData(
                      brightness: brightness,
                      platform: TargetPlatform.iOS,
                      // The Windows test engine has no iOS system fonts.
                      // Use the registered evidence faces for readable captures;
                      // native SF typography parity remains a simulator gate.
                      cupertinoOverrideTheme: cupertino.copyWith(
                        textTheme: nativeText.copyWith(
                          textStyle: nativeText.textStyle.copyWith(
                            fontFamily: evidenceFamily,
                          ),
                          navTitleTextStyle: nativeText.navTitleTextStyle
                              .copyWith(fontFamily: evidenceFamily),
                          navActionTextStyle: nativeText.navActionTextStyle
                              .copyWith(fontFamily: evidenceFamily),
                        ),
                      ),
                    ),
                    fontFamily: evidenceFamily,
                  ),
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (!direct) {
              await tester.tap(find.byKey(const Key('more-settings-entry')));
              await tester.pumpAndSettle();
            }
            final back = find.byKey(const Key('reference-settings-back'));
            expect(back, findsOneWidget);
            expect(
              find.descendant(of: back, matching: find.byType(BilCrystalArrow)),
              findsOneWidget,
            );
            expect(tester.getRect(back).width, greaterThanOrEqualTo(44));
            expect(tester.getRect(back).height, greaterThanOrEqualTo(44));
            expect(tester.getSemantics(back).label, isNotEmpty);
            await captureClosureSurface(
              tester,
              find.byType(ReferenceSettingsHomePage),
              'settings_back_${locale.languageCode}_${brightness.name}_${direct ? 'direct' : 'pushed'}',
            );
            await tester.tap(back);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('more-settings-entry')),
              findsOneWidget,
            );
            expect(router.routeInformationProvider.value.uri.path, '/settings');
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
