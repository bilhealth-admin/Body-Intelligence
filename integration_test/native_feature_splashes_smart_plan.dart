part of 'native_feature_splashes_test.dart';

// Real session widgets, source catalogs, artwork and platform fonts. The plan
// and owner are synthetic, and the routing boundary records IDs instead of
// opening a paid stream. No cloud request, purchase, diary write or AI call.
void _registerNativeSmartPlanSessions(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  if (_coachOnly || _conversationOnly || _sceneFilter.isNotEmpty) return;
  for (final environment in ['home', 'gym']) {
    for (final language in ['ar', 'en']) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          final name =
              'bil39-plan-$environment-$language-${dark ? 'dark' : 'light'}-${scale.toInt()}x';
          testWidgets(
            'native $name warmup and ordered session',
            (tester) async {
              expect(_isExpectedNativeQaTarget(), isTrue);
              expect(AppEnvironment.profile, EnvironmentProfile.testing);
              expect(AppEnvironment.useSupabase, isFalse);
              final catalog = const BilSmartPlanCatalog();
              final setup = BilPlanSetup(
                environment: environment == 'home'
                    ? BilPlanEnvironment.home
                    : BilPlanEnvironment.gym,
                experience: BilPlanExperience.beginner,
                sessionMinutes: environment == 'home' ? 25 : 35,
                equipment: environment == 'home'
                    ? const {'none'}
                    : const {'gym'},
              );
              final workouts = environment == 'home'
                  ? await catalog.homeSessions(setup)
                  : await catalog.gymSessions(sessionMinutes: 35);
              final now = DateTime(2026, 10, 23);
              final plan = const BilSmartPlanEngine()
                  .generate(
                    BilPlanCreationRequest(
                      ownerId: _owner,
                      planId: name,
                      startOn: now,
                      horizon: BilPlanHorizon.week,
                      focus: BilPlanFocus.training,
                      workoutsPerWeek: 3,
                      confirmedPreferences: true,
                      adultConfirmed: true,
                      workoutCatalog: workouts,
                      recipeCatalog: const [],
                      setup: environment == 'home' ? setup : null,
                    ),
                    now,
                  )
                  .withStatus(BilPlanStatus.active, now);
              final items = const WorkoutDiscoveryCatalogRepository().parse(
                await rootBundle.loadString(
                  WorkoutDiscoveryCatalogRepository.assetPath,
                ),
                await const WorkoutReleaseCatalogRepository().load(),
              );
              final localizer = WorkoutDiscoveryLocalizer.fromDiscovery(items);
              final opened = <String>[];
              expect(plan.ownerId, _owner);
              await tester.pumpWidget(
                ProviderScope(
                  key: ValueKey(name),
                  overrides: [
                    verifiedEntitlementOwnerIdProvider.overrideWithValue(
                      _owner,
                    ),
                  ],
                  child: MaterialApp(
                    locale: Locale(language),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      ...GlobalMaterialLocalizations.delegates,
                    ],
                    theme: dark
                        ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                        : BilFlagshipTheme.light(isArabic: language == 'ar'),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: BilSmartPlanSessionPage(
                      plan: plan,
                      day: plan.days.first,
                      checkAccess: () {
                        if (plan.ownerId != _owner) {
                          throw StateError('Native fixture owner mismatch');
                        }
                      },
                      loadItems: (_) async => language == 'ar'
                          ? items
                                .map((item) => localizer.localize(item, 'ar'))
                                .toList()
                          : items,
                      openExercise: (id) async => opened.add(id),
                    ),
                  ),
                ),
              );
              await _nativeSettle(tester);
              if (Platform.isAndroid) {
                await binding.convertFlutterSurfaceToImage();
                await tester.pump();
              }
              final output = await _output();
              final warmup = find.byKey(
                const ValueKey('bil-smart-plan-warmup-continue'),
              );
              // Native asset delivery can finish after a static reduced-motion
              // loading frame. Wait for the real async state, never replace it.
              final readiness = Stopwatch()..start();
              while (warmup.evaluate().isEmpty &&
                  readiness.elapsed < const Duration(seconds: 12)) {
                await tester.pump(const Duration(milliseconds: 20));
                if (find
                        .byKey(
                          const ValueKey(
                            'bil-smart-plan-session-access-changed',
                          ),
                        )
                        .evaluate()
                        .isNotEmpty ||
                    find
                        .text(
                          'The session could not be opened. Your plan and diary are unchanged.',
                        )
                        .evaluate()
                        .isNotEmpty ||
                    find
                        .text('تعذّر فتح الجلسة. لم تتغير خطتك أو سجلاتك.')
                        .evaluate()
                        .isNotEmpty) {
                  break;
                }
              }
              if (warmup.evaluate().isEmpty) {
                final loader = find.byWidgetPredicate(
                  (widget) =>
                      widget is FutureBuilder<List<WellnessContentItem>>,
                );
                if (loader.evaluate().length == 1) {
                  // Await the real page's loader so a native asset/contract
                  // failure reports its cause instead of only a missing button.
                  await tester
                      .widget<FutureBuilder<List<WellnessContentItem>>>(loader)
                      .future;
                }
                debugPrint(
                  'BIL39_NATIVE_SESSION_STATE=${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList()}',
                );
              }
              expect(warmup, findsOneWidget);
              await _capture(binding, '$name-warmup', output);
              await tester.ensureVisible(warmup);
              await _nativeSettle(tester);
              expect(warmup.hitTestable(), findsOneWidget);
              await tester.tap(warmup);
              await _nativeSettle(tester);
              final next = find.byKey(
                const ValueKey('bil-smart-plan-session-next'),
              );
              final previous = find.byKey(
                const ValueKey('bil-smart-plan-session-previous'),
              );
              await tester.ensureVisible(next);
              await _nativeSettle(tester);
              final nextRect = tester.getRect(next);
              final previousRect = tester.getRect(previous);
              expect(nextRect.top, closeTo(previousRect.top, .1));
              expect(nextRect.height, closeTo(previousRect.height, .1));
              expect(nextRect.width, closeTo(previousRect.width, .1));
              expect(nextRect.height, greaterThanOrEqualTo(48));
              final title = find.byKey(
                const ValueKey('bil-smart-plan-session-exercise'),
              );
              final firstTitle = tester.widget<Text>(title).data;
              await tester.tap(next);
              await _nativeSettle(tester);
              expect(tester.widget<Text>(title).data, isNot(firstTitle));
              await tester.ensureVisible(previous);
              await _nativeSettle(tester);
              expect(previous.hitTestable(), findsOneWidget);
              await tester.tap(previous);
              await _nativeSettle(tester);
              expect(tester.widget<Text>(title).data, firstTitle);
              await _capture(binding, '$name-session', output);
              expect(plan.days.first.workout!.completed, isFalse);
              expect(opened, isEmpty);
              expect(_dartNetworkDeny.blockedClientCreations, 0);
              expect(tester.takeException(), isNull);
              await File('${output.path}/$name-metadata.json').writeAsString(
                jsonEncode({
                  'source_head': _head,
                  'source_fingerprint': _fingerprint,
                  'native_platform': Platform.operatingSystem,
                  'native_fonts': true,
                  'plan_environment': environment,
                  'language': language,
                  'dark': dark,
                  'text_scale': scale,
                  'plan_owner_isolated': true,
                  'navigation_forward_and_back': 'PASS',
                  'completion_recorded': false,
                  'cloud_and_diary_writes': 'NOT_PERFORMED',
                }),
                flush: true,
              );
              final reports =
                  (binding.reportData!['smart_plan_native'] ??=
                          <Map<String, Object?>>[])
                      as List<Map<String, Object?>>;
              reports.add({
                'name': name,
                'source_head': _head,
                'source_fingerprint': _fingerprint,
                'completed': true,
                'navigation_forward_and_back': 'PASS',
                'completion_recorded': false,
              });
              await tester.pumpWidget(const SizedBox.shrink());
              await _nativeSettle(tester);
            },
            timeout: const Timeout(Duration(seconds: 90)),
          );
        }
      }
    }
  }
}
