import '../../support/bil_waiting_indicators.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_clock.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_prescriptions.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'smart_plan_contrast_review.dart';

class _LoadingPreferences extends PreferencesRepository {
  _LoadingPreferences(super.database);
  final pending = Completer<String?>();
  @override
  Future<String?> get(String key) =>
      key.startsWith('bil.smart-plan.owner.') ? pending.future : super.get(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BilSmartPlan plan;
  final now = DateTime(2026, 10, 23, 12);
  setUpAll(() async {
    await loadVisualEvidenceFont();
    const catalog = BilSmartPlanCatalog();
    plan = const BilSmartPlanEngine()
        .generate(
          BilPlanCreationRequest(
            ownerId: 'visual-owner',
            planId: 'visual-plan',
            startOn: now,
            horizon: BilPlanHorizon.month,
            focus: BilPlanFocus.combined,
            workoutsPerWeek: 3,
            confirmedPreferences: true,
            adultConfirmed: true,
            workoutCatalog: await catalog.gymSessions(sessionMinutes: 30),
            recipeCatalog: await catalog.sourcedRecipes(
              dietary: const DietaryPreferences(),
            ),
            phases: await const BilSmartPlanPrescriptions().phases(),
            setup: BilPlanSetup(
              environment: BilPlanEnvironment.gym,
              experience: BilPlanExperience.beginner,
              sessionMinutes: 30,
              equipment: const ['gym'],
            ),
          ),
          now,
        )
        .withStatus(BilPlanStatus.active, now);
  });
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final state in [
        'empty',
        'loading',
        'error',
        'schedule',
        'progress',
        'creation',
      ]) {
        testWidgets(
          '$state real $language ${dark ? 'dark' : 'light'} state renders accessibly and preserves local data',
          (tester) async {
            final db = AppDatabase.forTesting(
              NativeDatabase.memory(),
              localOwnerId: plan.ownerId,
            );
            var closed = false;
            addTearDown(() async {
              if (!closed) await db.close();
            });
            final saved = PreferencesRepository(db);
            final repository = BilSmartPlanRepository(
              preferences: saved,
              currentOwnerId: () => plan.ownerId,
            );
            final key = repository.storageKey(plan.ownerId);
            final loading = state == 'loading' ? _LoadingPreferences(db) : null;
            await tester.runAsync(() async {
              if (state == 'error') await saved.set(key, '{');
              if (state == 'schedule' || state == 'progress') {
                await saved.set(key, plan.encode());
              }
            });
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final ar = language == 'ar';
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  databaseProvider.overrideWithValue(db),
                  preferencesRepositoryProvider.overrideWithValue(
                    loading ?? saved,
                  ),
                  verifiedEntitlementOwnerIdProvider.overrideWithValue(
                    plan.ownerId,
                  ),
                  verifiedSubscriptionAccessProvider.overrideWithValue(
                    AsyncData(
                      SubscriptionState(
                        plan: CommercePlan.premium,
                        entitlements: const {},
                        authority: EntitlementAuthority.verifiedServer,
                        isPurchasable: false,
                        canRestorePurchases: false,
                        currentPeriodEndsAt: DateTime(2027),
                      ),
                    ),
                  ),
                  bilSmartPlanClockProvider.overrideWithValue(() => now),
                ],
                child: MaterialApp(
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  theme: visualEvidenceTheme(
                    dark
                        ? BilFlagshipTheme.dark(isArabic: ar)
                        : BilFlagshipTheme.light(isArabic: ar),
                    fontFamily: ar ? 'NotoArabicEvidence' : 'RobotoEvidence',
                  ),
                  builder: (_, child) => RepaintBoundary(
                    key: const ValueKey('state-capture'),
                    child: child!,
                  ),
                  home: const BilSmartPlanPage(),
                ),
              ),
            );
            if (state == 'loading') {
              for (var frame = 0; frame < 10; frame++) {
                await tester.pump(const Duration(milliseconds: 20));
              }
              expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
              expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
              final indicator = tester.widget<CupertinoActivityIndicator>(
                find.descendant(
                  of: find.byType(BilFeatureWelcomeStatus),
                  matching: find.byType(CupertinoActivityIndicator),
                ),
              );
              expect(indicator.radius, 12);
              expect(
                indicator.color,
                dark ? const Color(0xFFBBC4CD) : const Color(0xFF697178),
              );
              expect(
                find.byKey(const ValueKey('bil-smart-plan-create')),
                findsNothing,
              );
            } else {
              await tester.runAsync(() async {
                final until = DateTime.now().add(const Duration(seconds: 10));
                while (DateTime.now().isBefore(until)) {
                  await tester.pump(const Duration(milliseconds: 20));
                  if (bilWaitingIndicators().evaluate().isEmpty &&
                      find.byType(BilSmartPlanPage).evaluate().isNotEmpty) {
                    break;
                  }
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                }
              });
              await tester.pumpAndSettle();
              if (state == 'error') {
                expect(
                  find.byKey(const ValueKey('bil-smart-plan-error')),
                  findsOneWidget,
                );
                final recoveryText = tester.widget<Text>(
                  find.byKey(const ValueKey('bil-smart-plan-error')),
                );
                expect(
                  recoveryText.data,
                  contains(
                    ar
                        ? 'تعذّر فتح بيانات الخطة المحفوظة بأمان.'
                        : 'The saved plan data could not be opened safely.',
                  ),
                );
                expect(recoveryText.data, isNot(contains('FormatException')));
                expect(
                  find.byKey(const ValueKey('bil-smart-plan-retry')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const ValueKey('bil-smart-plan-create')),
                  findsNothing,
                );
                expect(await tester.runAsync(() => saved.get(key)), '{');
              }
              if (state == 'empty' || state == 'creation') {
                expect(
                  find.byKey(const ValueKey('bil-smart-plan-create')),
                  findsOneWidget,
                );
                if (state == 'creation') {
                  await tester.tap(
                    find.byKey(const ValueKey('bil-smart-plan-create')),
                  );
                  await tester.pumpAndSettle();
                  expect(
                    find.byType(DropdownButtonFormField<BilPlanHorizon>),
                    findsOneWidget,
                  );
                }
              }
              if (state == 'schedule' || state == 'progress') {
                await tester.tap(
                  find.byKey(
                    ValueKey(
                      'bil-smart-plan-tab-${state == 'schedule' ? 1 : 2}',
                    ),
                  ),
                );
                await tester.pumpAndSettle();
              }
            }
            expect(tester.takeException(), isNull);
            final capture = find.byKey(const ValueKey('state-capture'));
            await settleVisualAssetImages(tester);
            if (Platform.environment['BIL_CAPTURE_SMART_PLAN_GOLDENS'] != '0') {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                capture,
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final out = File(
                  'build/release-ios38-android33/visual-states/${state}_${language}_${dark ? 'dark' : 'light'}.png',
                );
                await out.parent.create(recursive: true);
                await out.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            final semantics = tester.ensureSemantics();
            try {
              expect(
                await smartPlanTextContrastFailures(tester, capture),
                isEmpty,
              );
              await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            } finally {
              semantics.dispose();
            }
            if (Platform.environment['BIL_CAPTURE_SMART_PLAN_GOLDENS'] != '0') {
              await expectLater(
                capture,
                matchesGoldenFile(
                  'goldens/smart_plan_${state}_${language}_${dark ? 'dark' : 'light'}.png',
                ),
              );
            }
            if (state == 'error') {
              await tester.runAsync(() => saved.set(key, plan.encode()));
              await tester.tap(
                find.byKey(const ValueKey('bil-smart-plan-retry')),
              );
              await tester.runAsync(() async {
                final until = DateTime.now().add(const Duration(seconds: 10));
                while (find
                        .byKey(const ValueKey('bil-smart-plan-tabs'))
                        .evaluate()
                        .isEmpty &&
                    DateTime.now().isBefore(until)) {
                  await tester.pump(const Duration(milliseconds: 20));
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                }
              });
              expect(
                find.byKey(const ValueKey('bil-smart-plan-tabs')),
                findsOneWidget,
              );
              expect(
                (await tester.runAsync(
                  () => repository.readFor(plan.ownerId),
                ))!.encode(),
                plan.encode(),
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
            if (loading != null) loading.pending.complete(null);
            await tester.runAsync(db.close);
            closed = true;
          },
        );
      }
    }
  }
}
