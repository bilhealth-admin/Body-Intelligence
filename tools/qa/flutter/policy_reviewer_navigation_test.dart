import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';

import '../../../test/visual_closure/visual_evidence_font.dart';

// A composite widget journey through the actual production route and editor.
// Auth and server receipts are injected synthetic fixtures, not store access.
final _receipt = StateProvider<Future<SubscriptionState>>(
  (_) => throw StateError('Synthetic receipt must be provided'),
);

SubscriptionState _paid() => SubscriptionState(
  plan: CommercePlan.premiumAiCoach,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(
    CommercePlan.premiumAiCoach,
  ),
  authority: EntitlementAuthority.verifiedServer,
  currentPeriodEndsAt: DateTime.now().toUtc().add(const Duration(days: 1)),
  isPurchasable: false,
  canRestorePurchases: false,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['BIL_POLICY_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.pump(); // Paint the current editor value before reading pixels.
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('policy-journey-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  for (final variant in [
    (language: 'en', dark: false),
    (language: 'ar', dark: false),
    (language: 'en', dark: true),
    (language: 'ar', dark: true),
  ]) {
    final language = variant.language;
    final prefix = '$language${variant.dark ? '-dark' : ''}';
    testWidgets(
      'reviewer navigation $prefix: loading paid Free reopen editor',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final preferences = PreferencesRepository(db);
        debugPrint('POLICY JOURNEY $language database ready');
        final pending = Completer<SubscriptionState>();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            preferencesRepositoryProvider.overrideWithValue(preferences),
            nutritionGoalDefaultsProvider.overrideWithValue(const {
              'goal.calories': 1800,
              'goal.carbsPercent': 45,
              'goal.proteinPercent': 30,
              'goal.fatPercent': 25,
            }),
            _receipt.overrideWith((_) => pending.future),
            verifiedSubscriptionStateProvider.overrideWith(
              (ref) => ref.watch(_receipt),
            ),
            storefrontTargetPlanProvider.overrideWith(
              (_) async => CommercePlan.premium,
            ),
          ],
        );
        final production = AppRouter.router.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((route) => route.path == '/settings/nutrition-goals');
        var plansVisits = 0;
        final router = GoRouter(
          initialLocation: '/origin',
          routes: [
            GoRoute(
              path: '/origin',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  key: const Key('open-real-goals'),
                  onPressed: () => context.push('/settings/nutrition-goals'),
                  child: const Text('Synthetic reviewer journey'),
                ),
              ),
            ),
            production,
            GoRoute(
              path: '/plans',
              builder: (_, _) {
                plansVisits++;
                return const Scaffold(body: Text('Plans boundary'));
              },
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: const Key('policy-journey-capture'),
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: visualEvidenceTheme(
                    variant.dark
                        ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                        : BilFlagshipTheme.light(isArabic: language == 'ar'),
                    fontFamily: language == 'ar'
                        ? 'NotoArabicEvidence'
                        : 'RobotoEvidence',
                  ),
                  builder: (_, child) => visualEvidenceTextSurface(
                    child,
                    fontFamily: language == 'ar'
                        ? 'NotoArabicEvidence'
                        : 'RobotoEvidence',
                  ),
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                ),
              ),
            ),
          );
          await _settle(tester);
          await tester.tap(find.byKey(const Key('open-real-goals')));
          await _settle(tester);
          expect(router.state.uri.path, '/settings/nutrition-goals');
          expect(plansVisits, 0);
          expect(find.byType(ReferenceNutritionGoalsPage), findsNothing);
          debugPrint('POLICY JOURNEY $language checking screen ready');
          await _capture(tester, '$prefix-checking');
          debugPrint('POLICY JOURNEY $language checking captured');

          pending.complete(_paid());
          debugPrint('POLICY JOURNEY $language receipt resolved');
          await _settle(tester);
          final calories = find
              .ancestor(
                of: find.text(language == 'ar' ? 'السعرات' : 'Calories'),
                matching: find.byType(ListTile),
              )
              .first;
          expect(calories, findsOneWidget);
          await tester.tap(calories);
          await _settle(tester);
          expect(find.byType(TextField), findsOneWidget);
          await tester.enterText(find.byType(TextField), '1875');
          await _capture(tester, '$prefix-paid-editor');
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(FilledButton).last.hitTestable(), findsOneWidget);
          await tester.tap(find.byType(FilledButton).last);
          tester.view.resetViewInsets();
          await _settle(tester);
          for (
            var frame = 0;
            frame < 120 && find.byType(AlertDialog).evaluate().isNotEmpty;
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 16));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
          }
          expect(find.byType(AlertDialog), findsNothing);
          debugPrint('POLICY JOURNEY $language editor saved');
          expect(
            await tester.runAsync(() => preferences.get('goal.calories')),
            '1875.0',
          );
          expect(plansVisits, 0);

          container.read(_receipt.notifier).state = Future.value(
            SubscriptionState(
              plan: CommercePlan.free,
              entitlements: FreePlan.entitlements,
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          );
          await _settle(tester);
          expect(find.byType(ReferenceNutritionGoalsPage), findsNothing);
          expect(find.text('BIL PREMIUM'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(plansVisits, 0);
          await _capture(tester, '$prefix-free-gate');

          container.read(_receipt.notifier).state = Future.value(_paid());
          await _settle(tester);
          expect(find.byType(ReferenceNutritionGoalsPage), findsOneWidget);
          router.pop();
          await _settle(tester);
          expect(router.state.uri.path, '/origin');
          await tester.tap(find.byKey(const Key('open-real-goals')));
          await _settle(tester);
          expect(find.text('1875'), findsOneWidget);
          expect(plansVisits, 0);
          expect(tester.takeException(), isNull);
          await _capture(tester, '$prefix-reopened-goals');
        } catch (error, stack) {
          debugPrint('POLICY JOURNEY $language body failure: $error\n$stack');
          rethrow;
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 300));
          router.dispose();
          container.dispose();
          await tester.pump(const Duration(seconds: 1));
          debugPrint('POLICY JOURNEY $language dispose');
          var closed = false;
          final closing = db.close().then((_) => closed = true);
          for (var step = 0; step < 80 && !closed; step++) {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
          }
          expect(
            closed,
            isTrue,
            reason: 'SQLite fixture must close after scope retirement',
          );
          await closing;
          debugPrint('POLICY JOURNEY $language complete');
        }
      },
    );
  }
}
