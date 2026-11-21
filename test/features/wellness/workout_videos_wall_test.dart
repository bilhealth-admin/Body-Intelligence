import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_collection_item_gate.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/gym_six_month_plan.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_free_preview_policy.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_release_catalog_item.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/gym_six_month_plan_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<WellnessContentItem> discovery;
  late GymSixMonthPlan plan;

  setUpAll(() {
    final release = _approvedRelease();
    discovery = const WorkoutDiscoveryCatalogRepository().parse(
      File(WorkoutDiscoveryCatalogRepository.assetPath).readAsStringSync(),
      release,
    );
    plan = const GymSixMonthPlanRepository().parse(
      File(GymSixMonthPlanRepository.artifactPath).readAsStringSync(),
      releaseManifestBytes: File(
        GymSixMonthPlanRepository.releaseManifestPath,
      ).readAsBytesSync(),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('discovery wall canonicalizes every exact video payload', () {
    final canonical = canonicalWorkoutVideoPayloads(discovery);
    final payloads = canonical
        .map((item) => item.videoMedia?.sha256)
        .whereType<String>()
        .toSet();

    expect(
      canonical,
      hasLength(WorkoutReleaseCatalogRepository.uniquePayloadCount),
    );
    expect(payloads, hasLength(canonical.length));
    final sidePlank = canonical.where(
      (item) => item.id == 'core-stability-side-plank-technique',
    );
    expect(sidePlank, hasLength(1));
    expect(sidePlank.single.releaseBundleId, 'gym-six-month');
  });

  test(
    'section distribution claims each payload globally and omits empty sections',
    () {
      final byPayload = <String, List<WellnessContentItem>>{};
      for (final item in discovery) {
        byPayload
            .putIfAbsent(workoutVideoPayloadIdentity(item), () => [])
            .add(item);
      }
      final duplicate = byPayload.values.firstWhere(
        (items) => items.length > 1,
      );
      final unique = discovery.firstWhere(
        (item) =>
            workoutVideoPayloadIdentity(item) !=
            workoutVideoPayloadIdentity(duplicate.first),
      );
      final identityOnly = _identityOnlyWorkout('identity-only');

      final distributed = distributeUniqueWorkoutVideoPayloads([
        [duplicate.first, identityOnly],
        [duplicate.last],
        [unique],
      ]);

      expect(distributed.map((entry) => entry.sourceIndex), [0, 2]);
      expect(distributed.first.items, [duplicate.first, identityOnly]);
      expect(distributed.last.items, [unique]);
      final visibleIdentities = distributed
          .expand((entry) => entry.items)
          .map(workoutVideoPayloadIdentity)
          .toList();
      expect(visibleIdentities.toSet(), hasLength(visibleIdentities.length));
      expect(
        workoutVideoPayloadIdentity(identityOnly),
        'identity:identity-only',
      );
    },
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final size in const [Size(390, 844), Size(428, 926)]) {
      for (final textScale in const [1.0, 1.3]) {
        testWidgets(
          'workout section edges respect ${locale.languageCode} '
          '${size.width.toInt()}px at $textScale text scale',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              _app(
                discovery,
                plan,
                _NoTransferMediaCache(),
                locale: locale,
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();

            final viewport = Offset.zero & size;
            final rtl = locale.languageCode == 'ar';
            double leadingMargin(Rect bounds) => rtl
                ? viewport.right - bounds.right
                : bounds.left - viewport.left;
            double trailingMargin(Rect bounds) => rtl
                ? bounds.left - viewport.left
                : viewport.right - bounds.right;

            // Videos and Gym exercise the two library section surfaces.
            for (final tabIndex in const [0, 1]) {
              if (tabIndex != 0) {
                await tester.tap(find.byType(Tab).at(tabIndex));
                await tester.pumpAndSettle();
              }
              final sectionLists = tester
                  .widgetList<ListView>(find.byType(ListView))
                  .where((list) {
                    return list.scrollDirection == Axis.horizontal &&
                        find.descendant(
                          of: find.byWidget(list),
                          matching: find.byType(PremiumCollectionItemGate),
                        ).evaluate().isNotEmpty;
                  })
                  .toList();
              expect(sectionLists, isNotEmpty);
              final listFinder = find.byWidget(sectionLists.first);
              final sectionFinder = find.ancestor(
                of: listFinder,
                matching: find.byType(Column),
              ).first;
              final titleFinder = find.descendant(
                of: sectionFinder,
                matching: find.byType(Text),
              ).first;
              expect(titleFinder, findsOneWidget);
              final cardFinder = find.descendant(
                of: listFinder,
                matching: find.byType(PremiumCollectionItemGate),
              ).first;
              expect(cardFinder, findsOneWidget);
              expect(
                Directionality.of(tester.element(cardFinder)),
                rtl ? TextDirection.rtl : TextDirection.ltr,
              );

              final titleBounds = tester.getRect(titleFinder);
              final cardBounds = tester.getRect(cardFinder);
              final reason = '${locale.languageCode}, $size, '
                  'scale $textScale, tab $tabIndex';
              expect(
                leadingMargin(titleBounds),
                closeTo(20, 0.1),
                reason: reason,
              );
              expect(
                trailingMargin(titleBounds),
                greaterThanOrEqualTo(19.9),
                reason: reason,
              );
              expect(
                leadingMargin(cardBounds),
                closeTo(20, 0.1),
                reason: reason,
              );
              expect(cardBounds.width, closeTo(304, 0.1), reason: reason);
              expect(cardBounds.left, greaterThanOrEqualTo(viewport.left));
              expect(cardBounds.right, lessThanOrEqualTo(viewport.right));
              expect(tester.takeException(), isNull, reason: reason);
            }
          },
        );
      }
    }
  }

  testWidgets('Videos is first and visible unique sections stay safely gated', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cache = _NoTransferMediaCache();

    await tester.pumpWidget(_app(discovery, plan, cache));
    await tester.pumpAndSettle();

    final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();
    expect(tabs.map((tab) => tab.text), ['Videos', 'Gym', 'Home', 'My plans']);
    expect(find.byKey(const ValueKey('workout-videos-wall')), findsOneWidget);
    expect(_visibleSectionLists(tester).length, lessThan(23));
    expect(cache.posterOnlineResolutions, inInclusiveRange(1, 15));
    _expectSectionPreviewContract(
      tester,
      expectedSections: null,
      allowNoFreePreview: true,
    );
    expect(cache.videoOnlineResolutions, 0);
  });

  testWidgets(
    'paid-only search remains stable and does not invent a free card',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paid = canonicalWorkoutVideoPayloads(
        discovery,
      ).firstWhere((item) => !WorkoutFreePreviewPolicy.isPreview(item));

      await tester.pumpWidget(_app(discovery, plan, _NoTransferMediaCache()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, paid.title);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(paid.title), findsWidgets);
      final matchingGates = find.byKey(
        ValueKey('workout-premium-gate-${paid.stableId}'),
      );
      final gates = tester
          .widgetList<PremiumCollectionItemGate>(matchingGates)
          .toList();
      expect(gates, isNotEmpty);
      expect(gates.every((gate) => gate.locked), isTrue);
    },
  );

  testWidgets(
    'presenter filter may hide a section preview without crashing or unlocking paid cards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(discovery, plan, _NoTransferMediaCache()));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workout-presenter-filter-women')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      _expectSectionPreviewContract(
        tester,
        expectedSections: null,
        allowNoFreePreview: true,
      );
    },
  );
}

void _expectSectionPreviewContract(
  WidgetTester tester, {
  required int? expectedSections,
  bool allowNoFreePreview = false,
}) {
  final sectionLists = tester.widgetList<ListView>(find.byType(ListView)).where(
    (list) {
      final key = list.key;
      return key is ValueKey<String> &&
          key.value.startsWith('workout-category-');
    },
  ).toList();
  if (expectedSections != null) {
    expect(sectionLists, hasLength(expectedSections));
  } else {
    expect(sectionLists, isNotEmpty);
  }
  for (final list in sectionLists) {
    final gates = tester
        .widgetList<PremiumCollectionItemGate>(
          find.descendant(
            of: find.byWidget(list),
            matching: find.byType(PremiumCollectionItemGate),
          ),
        )
        .toList();
    expect(gates, isNotEmpty, reason: '${list.key}');
    final unlocked = gates.indexed
        .where((entry) => !entry.$2.locked)
        .map((entry) => entry.$1)
        .toList();
    if (allowNoFreePreview) {
      expect(unlocked.length, lessThanOrEqualTo(1), reason: '${list.key}');
      if (unlocked.isNotEmpty) {
        expect(unlocked.single, 0, reason: '${list.key}');
      }
    } else {
      expect(unlocked, [0], reason: '${list.key}');
    }
  }
  final sectionLabels = tester
      .widgetList<PremiumLabelBadge>(find.byType(PremiumLabelBadge))
      .where((badge) {
        final key = badge.key;
        return key is ValueKey<String> &&
            key.value.startsWith('workout-section-premium-');
      });
  expect(sectionLabels.length, sectionLists.length);
}

Widget _app(
  List<WellnessContentItem> discovery,
  GymSixMonthPlan plan,
  WellnessMediaCache cache, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    verifiedSubscriptionStateProvider.overrideWith(
      (ref) async => FreePlan.createState(),
    ),
  ],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: BilWorkoutRoutinesPage(
      loader: (_) async => discovery,
      gymPlanLoader: () async => plan,
      mediaCache: cache,
    ),
  ),
);

List<WorkoutReleaseCatalogItem> _approvedRelease() => [
  ...WorkoutReleaseCatalogRepository.parseBundleManifest(
    File(
      'artifacts/workout_media/workout_release_bundle_home_v1.json',
    ).readAsStringSync(),
    expectedBundleId: 'home-training',
    expectedContentPackId: 'bil-workouts-home-v1',
    expectedRecordCount: WorkoutReleaseCatalogRepository.homeRecordCount,
  ),
  ...WorkoutReleaseCatalogRepository.parseBundleManifest(
    File(
      'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json',
    ).readAsStringSync(),
    expectedBundleId: 'gym-six-month',
    expectedContentPackId: 'bil-workouts-gym-six-month-v1',
    expectedRecordCount: WorkoutReleaseCatalogRepository.gymRecordCount,
  ),
];

final class _NoTransferMediaCache extends WellnessMediaCache {
  int posterOnlineResolutions = 0;
  int videoOnlineResolutions = 0;

  @override
  Future<WellnessMediaCacheResult> resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) async {
    if (online && asset.mimeType.startsWith('image/')) {
      posterOnlineResolutions += 1;
    }
    if (online && asset.mimeType.startsWith('video/')) {
      videoOnlineResolutions += 1;
    }
    return const WellnessMediaCacheResult.unavailableOffline();
  }
}

List<ListView> _visibleSectionLists(WidgetTester tester) =>
    tester.widgetList<ListView>(find.byType(ListView)).where((list) {
      final key = list.key;
      return key is ValueKey<String> &&
          key.value.startsWith('workout-category-');
    }).toList();

WellnessContentItem _identityOnlyWorkout(String id) => WellnessContentItem(
  id: id,
  type: WellnessContentType.workouts,
  locale: 'en',
  title: id,
  description: 'Identity fallback contract item.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/$id'),
  licenseName: 'BIL licensed original',
  verified: true,
);
