import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_release_catalog_item.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets(
    'warm installed reviewed equipment reaches the actual unlocked detail chip',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = (await tester.runAsync(_warmFixture))!;
      final cache = _OfflineEquipmentCache();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedEntitlementOwnerIdProvider.overrideWithValue(
                'synthetic-equipment-owner',
              ),
              verifiedSubscriptionAccessProvider.overrideWithValue(
                AsyncData(
                  SubscriptionState(
                    plan: CommercePlan.premium,
                    entitlements: const {},
                    authority: EntitlementAuthority.verifiedServer,
                    currentPeriodEndsAt: DateTime.utc(2099),
                    isPurchasable: false,
                    canRestorePurchases: false,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: BilWorkoutRoutineDetailsPage(
                item: fixture.item,
                initiallySaved: false,
                onToggleSaved: () async {},
                mediaCache: cache,
                offline: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BilWorkoutRoutineDetailsPage>(
                find.byType(BilWorkoutRoutineDetailsPage),
              )
              .item,
          same(fixture.item),
        );
        final equipment = find.text('Equipment');
        expect(equipment, findsOneWidget);
        await tester.ensureVisible(equipment);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(Chip, 'stable bench'), findsOneWidget);
        expect(find.widgetWithText(Chip, 'none'), findsNothing);
        expect(
          fixture.item.steps.first,
          contains('locked, non-slip flat bench'),
        );
        expect(
          fixture.item.videoMedia!.sha256,
          '99f5720291d81e33824d5bee9d035c70ad9782502350b390b6284674789389b4',
        );
        expect(
          fixture.item.imageMedia!.sha256,
          '758c2a531d023cf2fde4054f265479130adc1619787b4b0cc2f95102b44b67dc',
        );
        expect(
          fixture.item.rights!.mobile &&
              fixture.item.rights!.paid &&
              fixture.item.rights!.offline,
          isTrue,
        );
        expect(cache.onlineVideoRequests, 0);
        expect(fixture.client.requests, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        cache.dispose();
        await tester.runAsync(() async {
          expect(await fixture.pack.readAsBytes(), fixture.originalBytes);
          expect(await fixture.registry.readAsBytes(), fixture.registryBytes);
          await fixture.directory.delete(recursive: true);
        });
      }
    },
  );
}

Future<
  ({
    Directory directory,
    File pack,
    File registry,
    List<int> originalBytes,
    List<int> registryBytes,
    WellnessContentItem item,
    _NoEquipmentNetwork client,
  })
>
_warmFixture() async {
  final directory = await Directory.systemTemp.createTemp(
    'bil-equipment-real-detail-',
  );
  final originalBytes = await File(
    'artifacts/workout_media/cloudflare_runtime_v2/packs/bil-workouts-gym-six-month-v1-v1.json',
  ).readAsBytes();
  final pack = File(
    p.join(directory.path, 'bil-workouts-gym-six-month-v1-1.json'),
  );
  await pack.writeAsBytes(originalBytes);
  final registry = File(p.join(directory.path, 'installed.json'));
  await registry.writeAsString(
    jsonEncode([
      InstalledWellnessContentPack(
        id: 'bil-workouts-gym-six-month-v1',
        version: 1,
        path: p.basename(pack.path),
        installedAt: DateTime.utc(2026, 11, 1),
        minimumAccess: WellnessContentAccess.pro,
      ).toJson(),
    ]),
  );
  final release = <WorkoutReleaseCatalogItem>[];
  for (final bundle in const [
    ('home', 'home-training', 'bil-workouts-home-v1', 200),
    ('gym_six_month', 'gym-six-month', 'bil-workouts-gym-six-month-v1', 102),
  ]) {
    release.addAll(
      WorkoutReleaseCatalogRepository.parseBundleManifest(
        await File(
          'artifacts/workout_media/workout_release_bundle_${bundle.$1}_v1.json',
        ).readAsString(),
        expectedBundleId: bundle.$2,
        expectedContentPackId: bundle.$3,
        expectedRecordCount: bundle.$4,
      ),
    );
  }
  final discovery = const WorkoutDiscoveryCatalogRepository().parse(
    await File(WorkoutDiscoveryCatalogRepository.assetPath).readAsString(),
    release,
  );
  final client = _NoEquipmentNetwork();
  final manager = WellnessContentPackManager(
    client: client,
    packsDirectory: directory,
    workoutReleaseLoader: () async => release,
    workoutDiscoveryLoader: () async => discovery,
  );
  final item = (await manager.loadWorkoutLibraryItems(locale: 'en'))
      .singleWhere(
        (item) =>
            item.stableId ==
            'gym-six-month:resistance-upper-body-bench-push-up-technique',
      );
  return (
    directory: directory,
    pack: pack,
    registry: registry,
    originalBytes: originalBytes,
    registryBytes: await registry.readAsBytes(),
    item: item,
    client: client,
  );
}

class _OfflineEquipmentCache extends WellnessMediaCache {
  var onlineVideoRequests = 0;
  @override
  Future<WellnessMediaCacheResult> resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) async {
    if (online && asset.mimeType == 'video/mp4') onlineVideoRequests++;
    return const WellnessMediaCacheResult.unavailableOffline();
  }
}

class _NoEquipmentNetwork implements HttpClient {
  var requests = 0;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    throw StateError('No HTTP expected from warm equipment loader: $url');
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
