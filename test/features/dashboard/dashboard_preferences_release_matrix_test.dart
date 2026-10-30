import '../../support/bil_waiting_indicators.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

part 'dashboard_preferences_fixture_lifecycle_cases.dart';
part 'dashboard_preferences_fixture_host.dart';
part 'dashboard_preferences_prepared_cases.dart';

// Host-widget evidence only. Entitlements are explicit dated fixtures, and
// destination anchors prove navigation, not purchases or reviewer access.
// Preference writes use the real repository and an on-disk SQLite database;
// no switch callback or persistence API is faked.
void main() {
  setUpAll(() async {
    _preparedPreferencesFixture = _PreparedPreferencesFixture.create();
    await _preparedPreferencesFixture!.initialize();
  });
  tearDownAll(() => _preparedPreferencesFixture?.dispose());
  if (const bool.fromEnvironment('BIL_PREFERENCES_DEADLINE_PROBE')) {
    _registerActualDeadlineProbe();
  } else {
    _registerPreferencesMatrix();
    _registerPreparedFixtureCases();
  }
}

void _registerPreferencesMatrix() {
  for (final language in const ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6, 2.0]) {
        for (final size in const [Size(320, 568), Size(430, 932)]) {
          final label =
              '$language ${brightness.name} ${(scale * 100).round()}% '
              '${size.width.round()}x${size.height.round()}';
          testWidgets(
            'preferences release matrix $label',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final taskDirectory = Directory.systemTemp.createTempSync(
                'bil-preferences-release-matrix-',
              );
              addTearDown(() {
                // This exact directory was created by this case, never a user
                // workspace, home directory, or computed broad deletion target.
                expect(
                  taskDirectory.parent.absolute.path,
                  Directory.systemTemp.absolute.path,
                );
                _deleteFixtureDirectory(taskDirectory);
              });
              final databaseFile = File(
                '${taskDirectory.path}/preferences.sqlite',
              );
              final expectedSections = <String, bool>{};
              var harness = await _PreferencesHarness.open(
                tester,
                databaseFile: databaseFile,
                language: language,
                brightness: brightness,
                scale: scale,
                subscription: FreePlan.createState(),
              );
              try {
                expect(DashboardSectionIds.all, hasLength(9));
                _assertNoFrameworkErrors(tester, '$label initial');
                _assertMeaning(tester, find.byType(DashboardPreferencesPage));
                _assertTouchTarget(
                  tester,
                  find.byKey(const Key('dashboard-preferences-done')),
                );

                // Match the actual editor order. The outer ListView lazily builds
                // its custom-card group, so first discover it by forward gestures.
                final sectionOrder = [
                  DashboardSectionIds.aiCoach,
                  ...DashboardSectionIds.all.where(
                    (section) => section != DashboardSectionIds.aiCoach,
                  ),
                ];
                for (final section in sectionOrder) {
                  final tile = find.byKey(Key('dashboard-section-$section'));
                  await _reach(tester, tile, _pageScrollable());
                  _assertMeaning(tester, tile);
                  _assertTouchTarget(tester, tile);
                  final switchControl = find.descendant(
                    of: tile,
                    matching: find.byType(Switch),
                  );
                  // The framework intentionally shrink-wraps the inner switch;
                  // the >=48px interactive/semantic target is the whole tile.
                  expect(switchControl.hitTestable(), findsOneWidget);
                  final before = tester.widget<SwitchListTile>(tile).value;
                  final tileTap = tester.getCenter(tile);
                  expect(
                    tester.getRect(switchControl).contains(tileTap),
                    isFalse,
                  );
                  await tester.tapAt(tileTap);
                  await _settle(tester, '$label switch $section');
                  expectedSections[section] = !before;
                  expect(tester.widget<SwitchListTile>(tile).value, !before);
                  expect(
                    await _fixtureRunAsync(
                      tester,
                      () =>
                          harness.preferences.get('dashboard.section.$section'),
                    ),
                    '${!before}',
                    reason: 'Actual gesture must commit the SQLite preference',
                  );
                  expect(
                    await _fixtureRunAsync(
                      tester,
                      () => harness.preferences.get('dashboard.preset'),
                    ),
                    'custom',
                  );
                }

                await _tapFooter(tester);
                expect(harness.path, '/dashboard');
                expect(
                  find.byKey(const Key('matrix-destination-dashboard')),
                  findsOneWidget,
                );
                await tester.tap(
                  find.byKey(const Key('matrix-reopen-preferences')),
                );
                await _settle(tester, '$label route re-entry');
                await _assertPersistedSections(tester, expectedSections);

                final goals = find.byKey(
                  const Key('dashboard-edit-nutrition-goals'),
                );
                await _reach(tester, goals, _pageScrollable());
                _assertMeaning(tester, goals);
                _assertTouchTarget(tester, goals);
                await tester.tap(goals);
                await _settle(tester, '$label goals navigation');
                expect(harness.path, '/settings/nutrition-goals');
                expect(
                  find.byKey(const Key('matrix-destination-goals')),
                  findsOneWidget,
                );
                _assertTouchTarget(tester, find.byType(BackButton));
                await tester.tap(find.byType(BackButton));
                await _settle(tester, '$label goals return');

                final nutrients = find.byKey(
                  const Key('dashboard-add-nutrient-goal-cards'),
                );
                await _reach(tester, nutrients, _pageScrollable());
                _assertMeaning(tester, nutrients);
                _assertTouchTarget(tester, nutrients);
                if (scale == 1) {
                  final tile = tester.widget<ListTile>(nutrients);
                  expect(tile.leading, isNotNull);
                  expect(tile.trailing, isNotNull);
                }
                await tester.tap(nutrients);
                await _settle(tester, '$label Free preview');
                expect(find.byType(BottomSheet), findsOneWidget);
                expect(find.byType(CheckboxListTile), findsNothing);
                _assertMeaning(tester, find.byType(BottomSheet));
                final previewScrollable = find.descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable && widget.axis == Axis.vertical,
                  ),
                );
                expect(previewScrollable, findsOneWidget);
                final previewChips = find.descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Chip),
                );
                expect(previewChips, findsNWidgets(6));
                for (var index = 0; index < 6; index++) {
                  await _reach(
                    tester,
                    previewChips.at(index),
                    previewScrollable,
                  );
                  _assertMeaning(tester, previewChips.at(index));
                }
                final continueButton = _sheetButton();
                await _reach(tester, continueButton, previewScrollable);
                _assertTouchTarget(tester, continueButton);
                await tester.tap(continueButton);
                await _settle(tester, '$label Free Plans route');
                expect(harness.path, '/plans');
                expect(
                  find.byKey(const Key('matrix-destination-plans')),
                  findsOneWidget,
                );
                expect(
                  await _fixtureRunAsync(
                    tester,
                    () =>
                        harness.preferences.get('dashboard.nutrientGoalCards'),
                  ),
                  isNull,
                );

                await harness.close(tester);
                harness = await _PreferencesHarness.open(
                  tester,
                  databaseFile: databaseFile,
                  language: language,
                  brightness: brightness,
                  scale: scale,
                  subscription: _verifiedPremiumFixture(),
                );
                await _assertPersistedSections(tester, expectedSections);
                await _reach(tester, nutrients, _pageScrollable());
                await tester.tap(nutrients);
                await _settle(tester, '$label Premium chooser');
                expect(harness.path, '/dashboard/preferences');
                expect(find.byType(BottomSheet), findsOneWidget);
                final chooserScrollable = find.descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable && widget.axis == Axis.vertical,
                  ),
                );
                expect(chooserScrollable, findsOneWidget);
                for (final nutrient
                    in DashboardNutrientGoalIds.dashboardCards) {
                  final checkbox = find.byKey(
                    Key('dashboard-nutrient-goal-$nutrient'),
                  );
                  await _reach(tester, checkbox, chooserScrollable);
                  _assertMeaning(tester, checkbox);
                  _assertTouchTarget(tester, checkbox);
                  expect(
                    tester.widget<CheckboxListTile>(checkbox).value,
                    isFalse,
                  );
                  if (nutrient == 'fat' || nutrient == 'fiber') {
                    await tester.tap(checkbox);
                    await _settle(tester, '$label select $nutrient');
                    expect(
                      tester.widget<CheckboxListTile>(checkbox).value,
                      isTrue,
                    );
                  }
                }
                _assertMeaning(tester, _sheetButton());
                _assertTouchTarget(tester, _sheetButton());
                await tester.tap(_sheetButton());
                await _settle(tester, '$label Save cards');
                expect(find.byType(BottomSheet), findsNothing);
                expect(harness.path, '/dashboard/preferences');
                expect(
                  await _fixtureRunAsync(
                    tester,
                    () =>
                        harness.preferences.get('dashboard.nutrientGoalCards'),
                  ),
                  'fat,fiber',
                );
                expect(
                  await _fixtureRunAsync(
                    tester,
                    () => harness.preferences.get('dashboard.preset'),
                  ),
                  'custom',
                );
                await _tapFooter(tester);
                expect(harness.path, '/dashboard');
              } catch (error, stack) {
                await _preserveFailureDuringCleanup(
                  error,
                  stack,
                  () => harness.close(tester),
                );
              }
              await harness.close(tester);

              final reopenedLease = _TrackedFixtureDatabase(databaseFile);
              final reopenedDatabase = reopenedLease.database;
              final reopenedCleanup = _FixtureCleanup();
              Future<void> closeReopened() => reopenedCleanup.run(
                () => _finishHost(
                  tester,
                  reopenedLease.close,
                  'close reopened SQLite database',
                ),
              );
              addTearDown(closeReopened);
              try {
                final readback = PreferencesRepository(reopenedDatabase);
                for (final entry in expectedSections.entries) {
                  expect(
                    await _fixtureRunAsync(
                      tester,
                      () => readback.get('dashboard.section.${entry.key}'),
                    ),
                    '${entry.value}',
                  );
                }
                expect(
                  await _fixtureRunAsync(
                    tester,
                    () => readback.get('dashboard.nutrientGoalCards'),
                  ),
                  'fat,fiber',
                );
                expect(
                  await _fixtureRunAsync(
                    tester,
                    () => readback.get('dashboard.preset'),
                  ),
                  'custom',
                );
              } catch (error, stack) {
                await _preserveFailureDuringCleanup(
                  error,
                  stack,
                  closeReopened,
                );
              }
              await closeReopened();
            },
            timeout: const Timeout(Duration(seconds: 30)),
          );
        }
      }
    }
  }
  _registerFixtureLifecycleCases();
}

SubscriptionState _verifiedPremiumFixture() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {CommerceEntitlement.advancedIntelligence},
  authority: EntitlementAuthority.verifiedServer,
  startedAt: DateTime.utc(2026, 10, 1),
  currentPeriodEndsAt: DateTime.utc(2026, 11, 1),
  isPurchasable: true,
  canRestorePurchases: true,
);

Finder _pageScrollable() => find.descendant(
  of: find.byType(DashboardPreferencesPage),
  matching: find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.axis == Axis.vertical,
  ),
);

Finder _sheetButton() => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

Future<void> _reach(
  WidgetTester tester,
  Finder target,
  Finder scrollable,
) async {
  final owner = _activePreferencesHarness[tester];
  expect(scrollable, findsOneWidget);
  // Both forward and backward navigation use real pointer drags. A programmatic
  // ensureVisible or callback invocation would not prove user reachability.
  for (var gesture = 0; gesture < 60; gesture++) {
    owner?._checkOpen();
    if (target.evaluate().isEmpty) {
      await tester.drag(scrollable, const Offset(0, -160));
      owner?._checkOpen();
      await _settle(tester, 'discover $target', owner: owner);
      continue;
    }
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    final viewport = tester.getRect(scrollable);
    if (rect.top >= viewport.top &&
        rect.bottom <= viewport.bottom &&
        target.hitTestable().evaluate().length == 1) {
      return;
    }
    // Coarse fixed160px moves oscillate when a large-text tile nearly fills the
    // viewport (the real383px goal tile fits its384px viewport). Adjust by the
    // measured remaining distance instead, preserving real drag recognition.
    final margin = ((viewport.height - rect.height) / 2).clamp(0.0, 4.0);
    final distance = rect.top < viewport.top
        ? viewport.top + margin - rect.top
        : viewport.bottom - margin - rect.bottom;
    final delta = distance.clamp(-140.0, 140.0);
    // Flutter's drag starts after its default20px slop; compensate that actual
    // pointer movement, never jumpTo or programmatically invoke onTap.
    await tester.drag(
      scrollable,
      Offset(0, delta + delta.sign * kDragSlopDefault),
    );
    owner?._checkOpen();
    await _settle(tester, 'scroll to $target', owner: owner);
  }
  fail(
    'Control was not fully reachable with 60 bounded pointer drags: $target; '
    'targetRect=${target.evaluate().isEmpty ? null : tester.getRect(target)}; '
    'viewport=${tester.getRect(scrollable)}; '
    'position=${tester.state<ScrollableState>(scrollable).position.pixels}; '
    'maxExtent=${tester.state<ScrollableState>(scrollable).position.maxScrollExtent}',
  );
}

Future<void> _settle(
  WidgetTester tester,
  String stage, {
  _PreferencesHarness? owner,
}) async {
  // Native SQLite/assets and Drift watched queries need the real event loop;
  // pumpAndSettle's repeated fake-clock frames starve that loop while a real
  // query is still pending and its indeterminate indicator schedules frames.
  // Alternate both clocks, bounded like the existing real-DB profile fixture.
  owner ??= _activePreferencesHarness[tester];
  final elapsed = Stopwatch()..start();
  var quietFrames = 0;
  for (var attempt = 0; attempt < 100; attempt++) {
    owner?._checkOpen();
    await _fixtureRunAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    // A test timeout does not cancel its async body. A retired fixture must
    // never resume pumping into the next case after its host wait completes.
    owner?._checkOpen();
    await tester.pump(const Duration(milliseconds: 50));
    owner?._checkOpen();
    _assertNoFrameworkErrors(tester, stage);
    final loading = bilWaitingIndicators().evaluate().isNotEmpty;
    quietFrames =
        !loading &&
            _providersHydrated(tester) &&
            !tester.binding.hasScheduledFrame
        ? quietFrames + 1
        : 0;
    if (quietFrames >= 2) {
      if (stage == 'mount real preferences page') {
        debugPrint(
          'PREFERENCES_FIXTURE stage=hydrate elapsed_ms=${elapsed.elapsedMilliseconds} '
          'attempts=${attempt + 1}',
        );
      }
      return;
    }
  }
  fail(
    'Real SQLite/UI hydration did not complete within the bounded fixture '
    'at $stage: circular='
    '${bilWaitingIndicators().evaluate().length}, linear='
    '${bilWaitingIndicators().evaluate().length}, scheduled='
    '${tester.binding.hasScheduledFrame}, providersHydrated='
    '${_providersHydrated(tester)}',
  );
}

bool _providersHydrated(WidgetTester tester) {
  final page = find.byType(DashboardPreferencesPage);
  if (page.evaluate().isEmpty) return true;
  final container = ProviderScope.containerOf(
    tester.element(page),
    listen: false,
  );
  // Inspect only providers actually created by the real page. Do not eagerly
  // prime off-screen providers or replace the repository's loading behavior.
  final states = [
    if (container.exists(dashboardSelectedPresetProvider))
      container.read(dashboardSelectedPresetProvider),
    if (container.exists(dashboardNutrientGoalCardsProvider))
      container.read(dashboardNutrientGoalCardsProvider),
    for (final section in DashboardSectionIds.all)
      if (container.exists(dashboardSectionVisibleProvider(section)))
        container.read(dashboardSectionVisibleProvider(section)),
  ];
  return states.every(
    (state) => state.hasValue && !state.isLoading && !state.hasError,
  );
}

Future<void> _finishHost(
  WidgetTester tester,
  Future<void> Function() operation,
  String stage,
) async {
  debugPrint('PREFERENCES_FIXTURE stage=$stage phase=start');
  final elapsed = Stopwatch()..start();
  var succeeded = false;
  try {
    var complete = false;
    Object? failure;
    StackTrace? failureStack;
    // Returning before completion lets widget-zone cancellation microtasks run.
    // Awaiting database.close directly in runAsync deadlocks Drift watchers whose
    // cancellation needs a fake-zone pump, masking the original test assertion.
    await _fixtureRunAsync(tester, () async {
      Future<void>.sync(operation).then<void>(
        (_) => complete = true,
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          complete = true;
        },
      );
    });
    for (var attempt = 0; !complete && attempt < 100; attempt++) {
      await _fixtureRunAsync(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      complete,
      isTrue,
      reason: 'Real SQLite host operation stalled: $stage',
    );
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    succeeded = true;
  } finally {
    debugPrint(
      'PREFERENCES_FIXTURE stage=$stage phase=end success=$succeeded '
      'elapsed_ms=${elapsed.elapsedMilliseconds}',
    );
  }
}

void _assertNoFrameworkErrors(WidgetTester tester, String stage) {
  expect(tester.takeException(), isNull, reason: stage);
}

void _assertTouchTarget(WidgetTester tester, Finder target) {
  expect(target.hitTestable(), findsOneWidget);
  final rect = tester.getRect(target);
  expect(
    rect.width,
    greaterThanOrEqualTo(48),
    reason: 'Minimum horizontal touch target: $target',
  );
  expect(
    rect.height,
    greaterThanOrEqualTo(48),
    reason: 'Minimum vertical touch target: $target',
  );
  final screen = Offset.zero & tester.view.physicalSize;
  expect(
    screen.contains(rect.topLeft),
    isTrue,
    reason: 'Target must begin inside viewport: $target',
  );
  expect(rect.right, lessThanOrEqualTo(screen.right));
  expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
}

void _assertMeaning(WidgetTester tester, Finder scope) {
  for (final element
      in find
          .descendant(of: scope, matching: find.byType(RichText))
          .evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached || render.size.isEmpty) {
      continue;
    }
    final rect = render.localToGlobal(Offset.zero) & render.size;
    final viewport = Offset.zero & tester.view.physicalSize;
    if (!rect.overlaps(viewport)) {
      continue;
    }
    // AppBar may compact its duplicate title; the page hero must expose its
    // full meaning. Action labels, modal copy, and body text may not truncate.
    if (element.findAncestorWidgetOfExactType<AppBar>() != null) {
      continue;
    }
    expect(
      render.didExceedMaxLines,
      isFalse,
      reason: 'Meaning must not be truncated: ${render.text.toPlainText()}',
    );
  }
}

Future<void> _tapFooter(WidgetTester tester) async {
  final footer = find.byKey(const Key('dashboard-preferences-done'));
  _assertMeaning(tester, footer);
  _assertTouchTarget(tester, footer);
  await tester.tap(footer);
  await _settle(tester, 'Done editing navigation');
}

Future<void> _assertPersistedSections(
  WidgetTester tester,
  Map<String, bool> expected,
) async {
  for (final entry in expected.entries) {
    final tile = find.byKey(Key('dashboard-section-${entry.key}'));
    await _reach(tester, tile, _pageScrollable());
    expect(tester.widget<SwitchListTile>(tile).value, entry.value);
    _assertMeaning(tester, tile);
  }
}

final _activePreferencesHarness = Expando<_PreferencesHarness>();

// Keep the first failure and every cleanup failure, including their stacks.
// Cleanup errors must not replace the assertion/warmup failure that caused it.
class _FixtureFailure implements Exception {
  _FixtureFailure(this.failures);
  final List<({String stage, Object error, StackTrace stack})> failures;

  @override
  String toString() => failures
      .map((failure) => '${failure.stage}: ${failure.error}\n${failure.stack}')
      .join('\n');
}

class _FixtureCleanup {
  Future<void>? _inFlight;
  bool _complete = false;
  Object? _failure;
  StackTrace? _failureStack;

  Future<void> run(Future<void> Function() operation) async {
    // A completed fake-zone Future cannot be awaited again by host-zone
    // tearDown: its scheduled continuation can stall without another pump.
    // Replay completion/failure in the caller's zone, preserving diagnostics.
    if (_complete) {
      if (_failure != null) {
        Error.throwWithStackTrace(_failure!, _failureStack!);
      }
      return;
    }
    await (_inFlight ??= _run(operation));
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stack) {
      _failure = error;
      _failureStack = stack;
      rethrow;
    } finally {
      _complete = true;
    }
  }
}

Future<Never> _preserveFailureDuringCleanup(
  Object error,
  StackTrace stack,
  Future<void> Function() cleanup,
) async {
  try {
    await cleanup();
  } catch (cleanupError, cleanupStack) {
    Error.throwWithStackTrace(
      _FixtureFailure([
        (stage: 'original', error: error, stack: stack),
        (stage: 'cleanup', error: cleanupError, stack: cleanupStack),
      ]),
      stack,
    );
  }
  Error.throwWithStackTrace(error, stack);
}

Future<void> _disposeFixtureResources(
  List<({String stage, Future<void> Function() dispose})> resources,
) async {
  final failures = <({String stage, Object error, StackTrace stack})>[];
  for (final resource in resources) {
    try {
      await resource.dispose();
    } catch (error, stack) {
      failures.add((stage: resource.stage, error: error, stack: stack));
    }
  }
  if (failures.length == 1) {
    Error.throwWithStackTrace(failures.single.error, failures.single.stack);
  }
  if (failures.isNotEmpty) throw _FixtureFailure(failures);
}

class _PreferencesHarness {
  _PreferencesHarness._(this.lease);
  final _TrackedFixtureDatabase lease;
  AppDatabase get database => lease.database;
  ProviderContainer? _container;
  GoRouter? _router;
  ProviderContainer get container => _container!;
  GoRouter get router => _router!;
  bool _retired = false;
  bool _mountAttempted = false;
  final _cleanup = _FixtureCleanup();
  PreferencesRepository get preferences => PreferencesRepository(database);
  // GoRouter intentionally restores the base browser URL after push(); use the
  // actual top route state, also asserted against the visible destination.
  String get path => router.state.uri.path;

  static Future<_PreferencesHarness> open(
    WidgetTester tester, {
    required File databaseFile,
    required String language,
    required Brightness brightness,
    required double scale,
    required SubscriptionState subscription,
    Future<void> Function(_PreferencesHarness)? afterWarmup,
  }) async {
    if (!databaseFile.existsSync()) {
      _preparedPreferencesFixture!.materialize(databaseFile);
    }
    final lease = _TrackedFixtureDatabase(databaseFile);
    final database = lease.database;
    final harness = _PreferencesHarness._(lease);
    _activePreferencesHarness[tester] = harness;
    // Ownership begins before the first real SQLite operation, not after mount.
    // LIFO teardown closes this resource before the caller deletes its directory.
    addTearDown(() => harness.close(tester));
    try {
      var elapsed = Stopwatch()..start();
      Object? warmupError;
      StackTrace? warmupStack;
      debugPrint('PREFERENCES_FIXTURE stage=warmup phase=start');
      try {
        // No providers/watchers exist yet, so native warmup needs no fake-clock
        // pump. Capture inside runAsync: otherwise it reports errors to the
        // binding and returns null, allowing a broken warmup to mount the page.
        // Keep the original overall30s budget; add no shorter migration limit.
        await _fixtureRunAsync(tester, () async {
          try {
            await database.customSelect('SELECT 1').get();
          } catch (error, stack) {
            warmupError = error;
            warmupStack = stack;
          }
        });
        if (warmupError != null) {
          Error.throwWithStackTrace(warmupError!, warmupStack!);
        }
      } finally {
        debugPrint(
          'PREFERENCES_FIXTURE stage=warmup phase=end '
          'success=${warmupError == null} elapsed_ms=${elapsed.elapsedMilliseconds}',
        );
      }
      harness._checkOpen();
      if (afterWarmup != null) await afterWarmup(harness);
      harness._checkOpen();
      final container = harness._container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(subscription),
          ),
          verifiedEntitlementClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 4),
          ),
        ],
      );
      final router = harness._router = GoRouter(
        initialLocation: '/dashboard/preferences',
        routes: [
          GoRoute(
            path: '/dashboard/preferences',
            builder: (_, _) => const DashboardPreferencesPage(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const _DestinationAnchor('dashboard'),
          ),
          GoRoute(
            path: '/settings/nutrition-goals',
            builder: (_, _) => const _DestinationAnchor('goals'),
          ),
          GoRoute(
            path: '/plans',
            builder: (_, _) => const _DestinationAnchor('plans'),
          ),
        ],
      );
      final arabic = language == 'ar';
      elapsed = Stopwatch()..start();
      harness._mountAttempted = true;
      debugPrint('PREFERENCES_FIXTURE stage=mount phase=start');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: brightness == Brightness.dark
                ? BilFlagshipTheme.dark(isArabic: arabic)
                : BilFlagshipTheme.light(isArabic: arabic),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      );
      harness._checkOpen();
      debugPrint(
        'PREFERENCES_FIXTURE stage=mount elapsed_ms=${elapsed.elapsedMilliseconds}',
      );
      await _settle(tester, 'mount real preferences page');
      expect(
        Directionality.of(
          tester.element(find.byType(DashboardPreferencesPage)),
        ),
        arabic ? TextDirection.rtl : TextDirection.ltr,
      );
      return harness;
    } catch (error, stack) {
      debugPrint('PREFERENCES_FIXTURE stage=open phase=failed error=$error');
      await _preserveFailureDuringCleanup(
        error,
        stack,
        () => harness.close(tester),
      );
    }
  }

  void _checkOpen() {
    if (_retired) throw StateError('Preferences fixture has been retired');
  }

  Future<void> _disposeOwned(WidgetTester tester) => _disposeFixtureResources([
    if (_mountAttempted)
      (
        stage: 'unmount',
        dispose: () async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          _assertNoFrameworkErrors(tester, 'unmount preferences fixture');
        },
      ),
    (stage: 'router', dispose: () async => _router?.dispose()),
    (stage: 'container', dispose: () async => _container?.dispose()),
    (
      stage: 'database',
      dispose: () =>
          _finishHost(tester, lease.close, 'close preferences SQLite'),
    ),
  ]);

  Future<void> close(WidgetTester tester) {
    _retired = true;
    return _cleanup.run(() async {
      final hosts = _fixtureHostTasks(tester);
      try {
        await hosts.drain();
      } catch (error, stack) {
        // If a blocked native call returned late, cleanup is now safe but the
        // budget failure stays visible. Truly pending work retains its path.
        if (hosts._pending != null) rethrow;
        await _preserveFailureDuringCleanup(
          error,
          stack,
          () => _disposeOwned(tester),
        );
      }
      await _disposeOwned(tester);
    });
  }
}

class _DestinationAnchor extends StatelessWidget {
  const _DestinationAnchor(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: name == 'dashboard' ? null : AppBar(leading: const BackButton()),
    body: SafeArea(
      child: Center(
        child: name == 'dashboard'
            ? FilledButton(
                key: const Key('matrix-reopen-preferences'),
                onPressed: () => context.push('/dashboard/preferences'),
                child: const Text('Open preferences'),
              )
            : Text('Host route anchor: $name'),
      ),
    ),
    key: Key('matrix-destination-$name'),
  );
}
