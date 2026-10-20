// CONTROL-ONLY PROPOSAL: NOT COMPILED OR EXECUTED. NEVER SHIP.
// Temporary untracked entrypoint for exact application source below.
// Full shipping main/router/iOS theme; fictional LOCAL onboarding fixture.
// No provider overrides, entitlement grants, credentials or pixel generation.
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/main.dart' as app;
import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_completion_service.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _source = '5da21a5660b26e59e9ead7b0927d4ed7cf2c3996';
const _controller = String.fromEnvironment('BIL_STORE_CAPTURE_CONTROLLER');
const _run = String.fromEnvironment('BIL_STORE_CAPTURE_RUN');
const _device = String.fromEnvironment('BIL_STORE_CAPTURE_DEVICE_CLASS');
const _fixture = bool.fromEnvironment('BIL_STORE_CAPTURE_SYNTHETIC_GUEST');
const _catalogTestAccess = bool.fromEnvironment('BIL_ENABLE_CATALOG_TEST_ACCESS');
const _integrity = bool.fromEnvironment('BIL_MOBILE_INTEGRITY_REQUIRED');
const _route = '/wellness/workouts';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('shipping workout ready for external native capture', (tester) async {
    expect(Platform.isIOS, isTrue);
    expect(_fixture, isTrue);
    expect(RegExp(r'^[a-f0-9]{40}$').hasMatch(_controller), isTrue);
    expect(RegExp(r'^[0-9]+-[0-9]+$').hasMatch(_run), isTrue);
    expect(AppEnvironment.profile, EnvironmentProfile.production);
    expect(AppEnvironment.paymentsEnabled, isTrue);
    expect(AppEnvironment.adsEnabled, isFalse);
    expect(AppEnvironment.adProviderReady, isFalse);
    expect(AppEnvironment.cloudConfigured, isTrue);
    expect(_catalogTestAccess, isFalse);
    expect(_integrity, isFalse);
    final expectedPixels = switch (_device) {
      'iphone67' => const Size(1290, 2796),
      'ipad129' => const Size(2064, 2752),
      _ => throw StateError('Unexpected capture device class'),
    };
    expect(tester.view.physicalSize, expectedPixels);
    final testErrorHandler = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    HttpClient? publicClient;
    try {
      await app.main();
      final productionErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        productionErrorHandler?.call(details);
      };
      await _until(tester, () =>
        find.byType(app.BILApp).evaluate().length == 1,
        'Protected native bootstrap did not reach BILApp', errors);
      await _until(tester, () =>
        AppRouter.router.state.uri.path == '/account-gateway',
        'Clean guest startup did not reach account choice', errors);
      expect(AppEnvironment.supabaseRuntimeReady, isTrue);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.BILApp)), listen: false);
      final preferences = container.read(preferencesRepositoryProvider);
      final profiles = container.read(userProfileRepositoryProvider);
      expect(await tester.runAsync(() => profiles.getProfile()), isNull,
        reason: 'Never overwrite an existing real account/profile');

      // Genuine atomic onboarding writer, fictional adult state only.
      // This seeds consent CHOICES for a disposable fixture, not a user consent
      // receipt; onboarding/permission/consent UI acceptance is not tested.
      await tester.runAsync(() async {
        final service = OnboardingCompletionService(
          database: container.read(databaseProvider),
          profiles: profiles,
          weights: container.read(weightRepositoryProvider),
          goals: container.read(goalRepositoryProvider),
          measurements: container.read(bodyMeasurementRepositoryProvider),
          plans: container.read(planRepositoryProvider),
          preferences: preferences,
          dietaryPreferences: container.read(dietaryPreferencesRepositoryProvider),
          drafts: container.read(onboardingDraftRepositoryProvider),
        );
        await service.commit(draft: OnboardingDraft(
          preferredName: 'Alex',
          goals: const {OnboardingGoal.maintainWeight,
            OnboardingGoal.activityFitness},
          activity: 'moderate', regularExercise: true,
          birthDate: DateTime(1990, 6, 15), sex: 'male',
          countryRegion: 'US', localeTag: 'en',
          heightCm: 180, currentWeightKg: 80, targetWeightKg: 80,
          weeklyPaceKg: 0, estimatesAcknowledged: true,
          remoteAiConsent: OnboardingRemoteAiConsent.declined,
          healthPermission: OnboardingPermissionStatus.notRequested,
          notificationPermission: OnboardingPermissionStatus.notRequested,
        ));
        // Same key written by ordinary Continue locally, not a paid grant.
        await preferences.set('accountGatewayReviewed', 'true');
        await container.read(appSettingsProvider.notifier).setLocale('en');
        await container.read(appSettingsProvider.notifier).setThemeMode('light');
      });
      container.invalidate(userProfileProvider);
      container.invalidate(forceOnboardingProvider);
      container.invalidate(accountGatewayReviewedProvider);
      container.invalidate(dailyCheckInDueProvider);
      AppRouter.router.go('/startup');
      await tester.pump();
      await _until(tester, () =>
        AppRouter.router.state.uri.path == '/dashboard',
        'Real startup did not accept canonical fictional adult state', errors);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(await tester.runAsync(() =>
        preferences.get('onboarding.remoteAiConsent')), 'declined');
      expect(await tester.runAsync(() =>
        preferences.get('onboarding.permission.health')), 'notRequested');
      expect(await tester.runAsync(() =>
        preferences.get('onboarding.permission.notifications')), 'notRequested');

      // Actual public HTTPS manifest GET and actual bundled catalog, no install.
      final uri = Uri.parse(WellnessContentPackManager.manifestUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'workouts.bilhealth.com');
      expect(uri.path.startsWith('/v2/manifest/'), isTrue);
      expect(uri.hasQuery || uri.hasFragment, isFalse);
      publicClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final manager = WellnessContentPackManager(client: publicClient);
      final packs = await tester.runAsync(() =>
        manager.fetchCatalog().timeout(const Duration(seconds: 25)));
      final workouts = packs!.where((pack) =>
        pack.type == WellnessContentType.workouts).toList();
      expect(workouts.map((pack) => pack.id).toSet(),
        WorkoutDiscoveryCatalogRepository.releasePackVersions.keys.toSet());
      for (final pack in workouts) {
        expect(pack.version,
          WorkoutDiscoveryCatalogRepository.releasePackVersions[pack.id]);
        expect(pack.itemCount,
          WorkoutDiscoveryCatalogRepository.releasePackItemCounts[pack.id]);
      }
      final catalog = await tester.runAsync(() =>
        manager.loadWorkoutLibraryItems(locale: 'en')
          .timeout(const Duration(seconds: 25)));
      expect(catalog, hasLength(WorkoutDiscoveryCatalogRepository.itemCount));
      final acceptedIds = catalog!.map((item) => item.stableId).toSet();

      AppRouter.router.go(_route);
      await tester.pump();
      await _until(tester, () =>
        AppRouter.router.state.uri.path == _route &&
        find.byType(BilWorkoutRoutinesPage).evaluate().length == 1 &&
        find.byKey(const ValueKey('workout-video-library-header'))
          .evaluate().isNotEmpty && !_loadingOrError(),
        'Actual workout library did not become ready', errors);
      expect(tester.widget<Text>(find.byKey(
        const ValueKey('workout-videos-routines-title'))).data,
        'Workout Videos & Routines');
      expect(find.text('Professional workouts'), findsNothing);
      expect(find.text('Workout library preview'), findsNothing);
      expect(find.byKey(const ValueKey('workout-metadata-preview-cardio')),
        findsNothing);
      expect(find.byKey(const ValueKey('workout-metadata-preview-strength')),
        findsNothing);
      for (var attempt = 0; attempt < 6; attempt++) {
        if (_visibleCards(tester).isNotEmpty) break;
        await tester.drag(find.byKey(
          const ValueKey('workout-library-tab-0')), const Offset(0, -160));
        await _frames(tester, const Duration(milliseconds: 700), errors);
      }
      await _frames(tester, const Duration(seconds: 3), errors);
      final visibleIds = _visibleCards(tester);
      expect(visibleIds, isNotEmpty);
      expect(visibleIds.every(acceptedIds.contains), isTrue);
      expect(_loadingOrError(), isFalse);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      final access = container.read(verifiedSubscriptionAccessProvider);
      expect(access.value?.plan == null ||
        access.value!.plan == CommercePlan.free, isTrue);

      final documents = await tester.runAsync(getApplicationDocumentsDirectory);
      final directory = Directory(
        documents!.path + '/bil-store-capture-control');
      await directory.create(recursive: true);
      final ack = File(directory.path + '/ack.json');
      if (await ack.exists()) await ack.delete();
      final readyFile = File(directory.path + '/ready.json');
      final ready = <String, Object?>{
        'schema': 1, 'run': _run, 'applicationSource': _source,
        'controllerSource': _controller,
        'status': 'READY_FOR_EXTERNAL_NATIVE_SIMCTL_CAPTURE',
        'route': _route, 'title': 'Workout Videos & Routines',
        'deviceClass': _device,
        'physicalWidth': tester.view.physicalSize.width.round(),
        'physicalHeight': tester.view.physicalSize.height.round(),
        'devicePixelRatio': tester.view.devicePixelRatio,
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'locale': 'en', 'themePreference': 'light',
        'fixtureMode': 'synthetic_local_adult_shipping_onboarding_commit',
        'onboardingUiTested': false, 'remoteAiConsentFixture': 'declined',
        'healthPermissionFixture': 'notRequested',
        'notificationPermissionFixture': 'notRequested',
        'authenticated': false, 'entitlementOverride': false,
        'paidAccessClaimed': false,
        'entitlementPlanObserved': access.value?.plan.name,
        'entitlementAuthorityObserved': access.value?.authority.name,
        'catalogItems': catalog.length,
        'visibleCatalogStableIds': visibleIds,
        'publicManifestUrl': uri.toString(),
        'publicManifestPackIds': workouts.map((pack) => pack.id).toList(),
        'installedPaidPacks': 0, 'videoPlaybackClaimed': false,
        'simulatorIntegrityRequired': false,
        'signedPhysicalAcceptanceClaimed': false,
        'storeAcceptanceClaimed': false,
      };
      final temporary = File(readyFile.path + '.tmp');
      await temporary.writeAsString(jsonEncode(ready), flush: true);
      await temporary.rename(readyFile.path);
      debugPrint('BIL_STORE_CAPTURE_READY:workouts ' + _run + ' ' + _device);
      await _until(tester, () => ack.existsSync(),
        'Native host did not acknowledge capture', errors,
        limit: const Duration(seconds: 90));
      final ackBytes = await ack.readAsBytes();
      expect(ackBytes.length, lessThan(2048));
      final received = jsonDecode(utf8.decode(ackBytes))
        as Map<String, dynamic>;
      expect(received['run'], _run);
      expect(received['applicationSource'], _source);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(
        received['nativePngSha256'] as String? ?? ''), isTrue);
      expect(AppRouter.router.state.uri.path, _route);
      expect(_loadingOrError(), isFalse);
      expect(errors, isEmpty);
      binding.reportData = {
        'capture_control': ready, 'native_host_acknowledged': true};
      debugPrint('BIL_STORE_CAPTURE_ACKNOWLEDGED ' + _run + ' ' + _device);
    } finally {
      publicClient?.close(force: true);
      FlutterError.onError = testErrorHandler;
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

bool _loadingOrError() =>
  find.byType(ErrorWidget).evaluate().isNotEmpty ||
  find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
  find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
  find.byWidgetPredicate((widget) => const {
    '_WorkoutLibraryLoading', '_WorkoutLibraryError', '_WorkoutLibraryEmpty',
  }.contains(widget.runtimeType.toString())).evaluate().isNotEmpty;

List<String> _visibleCards(WidgetTester tester) {
  final viewport = Offset.zero &
    (tester.view.physicalSize / tester.view.devicePixelRatio);
  final ids = <String>[];
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
      key.value.startsWith('workout-card-');
  }).evaluate()) {
    final box = element.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = rect.intersect(viewport);
    if (visible.width < 100 || visible.height < 140) continue;
    final key = element.widget.key! as ValueKey<String>;
    ids.add(key.value.substring('workout-card-'.length));
  }
  return ids;
}

Future<void> _until(WidgetTester tester, bool Function() condition,
  String failure, List<FlutterErrorDetails> errors, {
  Duration limit = const Duration(seconds: 75),
}) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (errors.isNotEmpty) throw StateError('Flutter runtime error');
    if (clock.elapsed >= limit) throw StateError(failure);
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (errors.isNotEmpty) throw StateError('Flutter runtime error');
}

Future<void> _frames(WidgetTester tester, Duration duration,
  List<FlutterErrorDetails> errors) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < duration) {
    if (errors.isNotEmpty) throw StateError('Flutter runtime error');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

