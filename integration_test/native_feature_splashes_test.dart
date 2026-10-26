import 'dart:async';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_native_markdown.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_localizer.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:body_intelligence_log/shared/widgets/bil_feature_entry_splash.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../tools/qa/flutter/native_hold_observer.dart';
import '../tools/qa/flutter/native_capture_manifest.dart';

part 'native_feature_capture.dart';
part 'native_feature_splashes_coach.dart';
part 'native_feature_splashes_observer.dart';
part 'native_feature_splashes_warmup.dart';
part 'native_feature_splashes_smart_plan.dart';
part 'native_feature_splashes_conversations.dart';

// Standalone QA entrypoint. Does not call lib/main.dart or initialize cloud,
// Firebase, purchases, ads, production Auth, First Use, or startup animations.
// Native fonts are deliberately untouched: no FontLoader/Evidence theme.
const _owner = '11111111-1111-4111-8111-111111111111';
const _head = String.fromEnvironment('BIL_QA_SOURCE_HEAD');
const _fingerprint = String.fromEnvironment('BIL_QA_SOURCE_FINGERPRINT');
const _androidQaEnabled = bool.fromEnvironment('BIL_QA_ANDROID_EMULATOR');
const _iosQaEnabled = bool.fromEnvironment('BIL_QA_IOS_SIMULATOR');
const _sceneFilter = String.fromEnvironment('BIL_QA_NATIVE_SCENE');
const _coachOnly = bool.fromEnvironment('BIL_QA_NATIVE_COACH_ONLY');
const _conversationOnly = bool.fromEnvironment(
  'BIL_QA_NATIVE_CONVERSATIONS_ONLY',
);
const _kinds = ['recipes', 'videos', 'sleep', 'diet', 'coach', 'community'];
const _scenes = [
  (language: 'ar', reduced: false, scale: 1.0),
  (language: 'en', reduced: false, scale: 1.0),
  (language: 'ar', reduced: true, scale: 2.0),
  (language: 'en', reduced: true, scale: 2.0),
];

bool _isExpectedNativeQaTarget() =>
    (Platform.isAndroid && _androidQaEnabled) ||
    (Platform.isIOS && _iosQaEnabled);

// This guards Dart HttpClient creation only. Raw/native sockets are not covered;
// the fixture also injects transports that forbid cloud requests.
class _NativeDartNetworkDeny extends HttpOverrides {
  int blockedClientCreations = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    blockedClientCreations++;
    throw StateError('Native synthetic QA denies Dart network client creation');
  }
}

final _dartNetworkDeny = _NativeDartNetworkDeny();

// IntegrationTestWidgetsFlutterBinding uses the platform IME rather than the
// registered TestTextInput stub. Exercise the real dismissal path on devices.
Future<void> nativeQaDismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump();
}

Future<void> _nativeSettle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 20),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } on FlutterError {
    debugPrint(
      'BIL_NATIVE_IDLE_FAILURE callbacks=${tester.binding.transientCallbackCount} '
      'scheduled=${tester.binding.hasScheduledFrame} phase=${tester.binding.schedulerPhase}',
    );
    debugDumpApp();
    rethrow;
  }
}

class _NoCloudTransport extends http.BaseClient {
  int sends = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends++;
    throw StateError('Native splash fixture forbids cloud traffic');
  }
}

class _CommunityEntryFixture extends CommunityRepository {
  _CommunityEntryFixture(super.client);
  int profileReads = 0, codeReads = 0, writes = 0;
  @override
  String get currentUserId => _owner;
  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileReads++;
    return const CommunityProfile(
      userId: _owner,
      displayName: 'Synthetic native member',
      localeCode: 'en',
      discoverable: false,
      visibility: CommunityProfileVisibility.private,
      allowFriendRequests: false,
      allowFollows: false,
      allowMessagesFrom: CommunityMessagePermission.nobody,
    );
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codeReads++;
    const code = 'aabbccddaabbccddaabbccddaabbccdd';
    return CommunityPublicCode(
      code: code,
      uri: Uri.parse('bil://community/member/$code'),
      handle: 'native_qa',
    );
  }

  @override
  Future<void> createMyCommunityEntryProfile({
    required String displayName,
    required String localeCode,
    required String expectedOwnerId,
  }) async {
    writes++;
    throw StateError('Native splash fixture must never write a profile');
  }
}

class _NoModelGateway implements LocalModelGateway {
  int calls = 0;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    calls++;
    throw StateError('Native splash fixture must never ask AI or spend tokens');
  }
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.child, required this.onMount});
  final Widget child;
  final VoidCallback onMount;
  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DestinationProbe extends StatelessWidget {
  const _DestinationProbe(this.kind, this.onMount);
  final String kind;
  final VoidCallback onMount;
  @override
  Widget build(BuildContext context) => _MountProbe(
    onMount: onMount,
    child: Scaffold(
      key: ValueKey('native-destination-$kind'),
      appBar: AppBar(
        title: Text('QA $kind'),
        leading: BackButton(
          key: const Key('qa-native-return'),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(child: Text('Synthetic destination $kind')),
    ),
  );
}

Finder _welcome(String kind) => find.byKey(
  kind == 'coach'
      ? const Key('ai-coach-entry-welcome')
      : kind == 'community'
      ? const Key('community-welcome-loading')
      : ValueKey('feature-entry-splash-$kind'),
);
Map<String, Object?> _welcomeFrameDetails(String kind) {
  final indicators = find
      .descendant(
        of: _welcome(kind),
        matching: find.byType(CupertinoActivityIndicator),
      )
      .evaluate();
  final indicator = indicators.single.widget as CupertinoActivityIndicator;
  return {
    'indicator_animating': indicator.animating,
    'indicator_radius': indicator.radius,
  };
}

String _location(String kind) => switch (kind) {
  'diet' => '/nutrition-plans',
  'coach' => '/intelligence-center',
  'community' => '/community',
  _ => '/native/$kind',
};

Future<Directory> _output() =>
    nativeQaCaptureDirectory(android: Platform.isAndroid);

// Keep every native scene on the same platform-owned output root. The optional
// creation switch lets host tests exercise genuine path-provider selection and
// the transport's unchanged path guard without writing to a device-style path.
Future<Directory> nativeQaCaptureDirectory({
  required bool android,
  bool create = true,
}) async {
  final root = android
      ? await getExternalStorageDirectory()
      : await getApplicationDocumentsDirectory();
  if (root == null) {
    throw StateError('Native QA app documents directory unavailable');
  }
  final directory = Directory('${root.path}/feature-splashes-native');
  if (create) await directory.create(recursive: true);
  return directory;
}

Future<void> _returnToNativeOrigin(
  WidgetTester tester,
  GoRouter router,
  String kind,
) async {
  final Finder back;
  if (kind == 'diet') {
    back = find.byKey(const Key('nutrition-pathways-back'));
  } else if (kind == 'coach') {
    final page = tester.element(find.byType(IntelligenceCenterPage));
    back = find.byTooltip(MaterialLocalizations.of(page).backButtonTooltip);
  } else {
    back = find.byKey(const Key('qa-native-return'));
  }
  expect(back.hitTestable(), findsOneWidget);
  await tester.tap(back);
  await _nativeSettle(tester);
  expect(router.state.uri.path, '/native-origin');
  expect(find.text('Isolated native QA'), findsOneWidget);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final priorHttpOverrides = HttpOverrides.current;
  HttpOverrides.global = _dartNetworkDeny;
  setUp(() => _dartNetworkDeny.blockedClientCreations = 0);
  tearDownAll(() => HttpOverrides.global = priorHttpOverrides);
  binding.reportData = {
    'native_scope': _coachOnly
        ? 'coach-only'
        : _conversationOnly
        ? 'conversations-only'
        : 'all',
    'smart_plan_native_expected':
        !_coachOnly && !_conversationOnly && _sceneFilter.isEmpty ? 16 : 0,
    'community_conversations_expected': !_coachOnly && _sceneFilter.isEmpty
        ? 8
        : 0,
    'store_activity_expected': !_coachOnly && _sceneFilter.isEmpty ? 4 : 0,
    'native_scenes': [
      for (final scene in _scenes)
        if (_sceneFilter.isEmpty ||
            _sceneFilter ==
                '${scene.language}-light-${scene.reduced ? 'reduced' : 'normal'}')
          '${scene.language}-light-${scene.reduced ? 'reduced' : 'normal'}',
    ],
  };
  for (final scene in _scenes) {
    if (_coachOnly || _conversationOnly) break;
    final name =
        '${scene.language}-light-${scene.reduced ? 'reduced' : 'normal'}';
    if (_sceneFilter.isNotEmpty && name != _sceneFilter) continue;
    testWidgets(
      'native six feature entries $name with real platform fonts',
      (tester) async {
        expect(
          Platform.isAndroid || Platform.isIOS,
          isTrue,
          reason: 'This QA fixture requires an Android or iOS native target',
        );
        expect(_isExpectedNativeQaTarget(), isTrue);
        expect(AppEnvironment.profile, EnvironmentProfile.testing);
        expect(AppEnvironment.useSupabase, isFalse);
        expect(
          AppEnvironment.paymentsEnabled ||
              AppEnvironment.pushEnabled ||
              AppEnvironment.adsEnabled,
          isFalse,
        );
        expect(AppEnvironment.supabaseRuntimeReady, isFalse);
        expect(
          _head.isNotEmpty && _fingerprint.isNotEmpty,
          isTrue,
          reason:
              'Record the source actually used, including dirty-tree fingerprint',
        );
        final output = await _output();
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'native-feature-splashes-only',
        );
        await db.customSelect('SELECT 1').get();
        final transport = _NoCloudTransport();
        final client = SupabaseClient(
          'https://native-splash.invalid',
          'synthetic-unused-key',
          httpClient: transport,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        final community = _CommunityEntryFixture(client);
        final gateway = _NoModelGateway();
        final timings = <Map<String, Object?>>[];
        final source = <String, Object?>{
          'classification':
              'native ${Platform.operatingSystem} Flutter debug QA entrypoint',
          'platform': Platform.operatingSystem,
          'source_head': _head,
          'source_fingerprint': _fingerprint,
          'scene': name,
          'platform_version': Platform.operatingSystemVersion,
          'device_name': const String.fromEnvironment('BIL_QA_DEVICE_NAME'),
          'fonts':
              'actual platform theme; production BILDisplay/BILArabic overrides retained',
          'text_scale': scene.scale,
          'reduce_motion_source': 'controlled MediaQuery fixture override',
          'physical_size':
              '${tester.view.physicalSize.width}x${tester.view.physicalSize.height}',
          'device_pixel_ratio': tester.view.devicePixelRatio,
          'native_reduce_motion':
              binding.platformDispatcher.accessibilityFeatures.reduceMotion,
          'sample_size_per_entry_condition': 1,
          'timings': timings,
        };
        final holdObservers = <String, NativeHoldObserver>{};
        final warmupTraces = <_NativeEntryWarmupTrace>[];
        final mounted = <String, int>{};
        final destinationMounts = <String, int>{};
        Widget entry(String kind, GoRouterState state, BuildContext context) {
          final Widget child;
          if (kind == 'diet') {
            final production = AppRouter.router.configuration.routes
                .whereType<GoRoute>()
                .singleWhere((route) => route.path == '/nutrition-plans');
            // Production uses a NoTransitionPage so its real entry splash does
            // not jump during navigation. Reuse that exact page composition.
            final page = production.pageBuilder?.call(context, state);
            if (page is NoTransitionPage) {
              child = page.child;
            } else if (production.builder != null) {
              child = production.builder!(context, state);
            } else {
              throw StateError('Unsupported production diet page composition');
            }
          } else if (kind == 'coach') {
            child = const IntelligenceCenterPage();
          } else if (kind == 'community') {
            child = CommunityEntryGate(
              repository: community,
              showWelcome: true,
              child: _DestinationProbe(
                kind,
                () => destinationMounts[kind] =
                    (destinationMounts[kind] ?? 0) + 1,
              ),
            );
          } else {
            child = BilFeatureEntrySplashGate(
              kind: BilFeatureEntryKind.values.singleWhere(
                (value) => value.name == kind,
              ),
              child: _DestinationProbe(
                kind,
                () => destinationMounts[kind] =
                    (destinationMounts[kind] ?? 0) + 1,
              ),
            );
          }
          return _MountProbe(
            onMount: () {
              mounted[kind] = (mounted[kind] ?? 0) + 1;
              holdObservers[kind]?.stop();
              holdObservers[kind] = NativeHoldObserver(
                welcome: _welcome(kind),
                readVisibleFrame: () => _welcomeFrameDetails(kind),
              )..start();
              if (warmupTraces.isNotEmpty) {
                warmupTraces.last.attach(kind, holdObservers[kind]!);
              }
            },
            child: child,
          );
        }

        final router = GoRouter(
          initialLocation: '/native-origin',
          routes: [
            GoRoute(
              path: '/native-origin',
              builder: (context, _) => Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Isolated native QA'),
                        for (final kind in _kinds)
                          TextButton(
                            key: ValueKey('native-open-$kind'),
                            onPressed: () => context.push(_location(kind)),
                            child: Text(kind),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final kind in _kinds)
              GoRoute(
                path: _location(kind),
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: entry(kind, state, context),
                ),
              ),
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const Scaffold(body: Text('QA fallback')),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                coachContextSnapshotProvider.overrideWith(
                  (ref) async => CoachContextSnapshot.empty(),
                ),
                coachHealthBriefProvider.overrideWith(
                  (ref) async => CoachContextSnapshot.empty(),
                ),
                intelligenceCenterModelGatewayProvider.overrideWithValue(
                  gateway,
                ),
                intelligenceHealthContextProvider.overrideWith(
                  (ref) async => const IntelligenceHealthContext(
                    primaryMessage: '',
                    explanation: [],
                    confidence: 1,
                    evidence: [],
                    missingData: [],
                  ),
                ),
                verifiedSubscriptionStateProvider.overrideWith(
                  (ref) async => SubscriptionState(
                    plan: CommercePlan.free,
                    entitlements: const {},
                    authority: EntitlementAuthority.localDefault,
                    isPurchasable: false,
                    canRestorePurchases: false,
                  ),
                ),
                aiCoachCreditAccessProvider.overrideWith((ref) async => false),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                routerConfig: router,
                theme: BilFlagshipTheme.light(
                  isArabic: scene.language == 'ar',
                ).copyWith(platform: TargetPlatform.android),
                locale: Locale(scene.language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scene.scale),
                    disableAnimations: scene.reduced,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await _nativeSettle(tester);
          final originContext = tester.element(find.text('Isolated native QA'));
          // Preparation is completed BEFORE entering each measured welcome.
          // Production gates themselves still never wait on assets or network.
          await precacheImage(
            ResizeImage.resizeIfNeeded(
              512,
              null,
              const AssetImage(bilApprovedAiCoachAsset),
            ),
            originContext,
          );
          await precacheImage(
            ResizeImage.resizeIfNeeded(
              900,
              null,
              const AssetImage(CommunityWelcome.imageAsset),
            ),
            originContext,
          );
          for (final asset in bilFeatureEntryArtworkAssets.values) {
            await precacheImage(
              ResizeImage.resizeIfNeeded(900, null, AssetImage(asset)),
              originContext,
            );
          }
          if (Platform.isAndroid) {
            await binding.convertFlutterSurfaceToImage();
          }
          await tester.pump();
          for (final kind in _kinds) {
            // Prime this real route's native text/raster work in an independent
            // QA visit. No production hold is frozen or extended for warm-up.
            await tester.ensureVisible(
              find.byKey(ValueKey('native-open-$kind')),
            );
            final warmup = _NativeEntryWarmupTrace(kind)..start();
            warmupTraces.add(warmup);
            try {
              await tester.tap(find.byKey(ValueKey('native-open-$kind')));
              await warmup.complete(tester);
            } finally {
              warmup.stop();
            }
            router.pop();
            await _nativeSettle(tester);
            mounted.remove(kind);
            destinationMounts.remove(kind);
            await tester.ensureVisible(
              find.byKey(ValueKey('native-open-$kind')),
            );
            await tester.tap(find.byKey(ValueKey('native-open-$kind')));
            await tester.pump();
            final observer = holdObservers[kind]!;
            expect(
              observer.timeline.firstFrameVisible,
              isTrue,
              reason:
                  'The measured welcome must be present in its actual first frame.',
            );
            expect(
              observer.firstVisibleFrame?['indicator_animating'],
              !scene.reduced,
            );
            expect(observer.firstVisibleFrame?['indicator_radius'], 12);
            expect(mounted[kind], 1);
            if (kind == 'community') {
              while (destinationMounts[kind] == null &&
                  observer.watch.elapsedMilliseconds < 1900) {
                await tester.pump(const Duration(milliseconds: 20));
              }
              expect(_welcome(kind), findsOneWidget);
            }
            if (!['diet', 'coach'].contains(kind)) {
              expect(
                destinationMounts[kind],
                1,
                reason: 'destination prewarms once during the hold',
              );
            }
            if (kind == 'diet') {
              expect(find.byType(NutritionPathwaysPage), findsOneWidget);
            }
            if (kind == 'coach') {
              expect(find.byType(IntelligenceCenterPage), findsOneWidget);
            }
            // Measure the real unmodified hold without screenshot IPC. Native
            // PNG encoding/host delivery can finish after the 2.2s Timer even
            // when the PNG correctly contains the early welcome frame.
            final observed = await observeNativeHoldEnd(tester, observer);
            expect(
              _welcome(kind),
              findsNothing,
              reason: 'no extra asset or data readiness hold',
            );
            expect(mounted[kind], 1);
            if (!['diet', 'coach'].contains(kind)) {
              expect(destinationMounts[kind], 1);
            }
            expect(tester.takeException(), isNull);
            await _capture(binding, '$kind-$name-released', output);
            await _returnToNativeOrigin(tester, router, kind);
            final timedMountCount = mounted[kind];
            // Independent visual visit. No frozen/extended production timer,
            // replacement image, or screenshot latency counted as hold time.
            await tester.ensureVisible(
              find.byKey(ValueKey('native-open-$kind')),
            );
            await tester.tap(find.byKey(ValueKey('native-open-$kind')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 80));
            final captureObserver = holdObservers[kind]!;
            final captureWatch = captureObserver.watch;
            expect(_welcome(kind), findsOneWidget);
            final captureAt = captureWatch.elapsedMilliseconds;
            expect(captureAt, lessThan(1900));
            await _capture(binding, '$kind-$name-welcome', output);
            final captureCompleteAt = captureWatch.elapsedMilliseconds;
            while (_welcome(kind).evaluate().isNotEmpty &&
                captureWatch.elapsedMilliseconds < 4500) {
              await tester.pump(const Duration(milliseconds: 20));
            }
            expect(_welcome(kind), findsNothing);
            captureObserver.stop();
            expect(tester.takeException(), isNull);
            expect(mounted[kind], 2);
            await _returnToNativeOrigin(tester, router, kind);
            expect(transport.sends, 0);
            expect(gateway.calls, 0);
            expect(community.writes, 0);
            timings.add({
              'kind': kind,
              'capture_started_ms': captureAt,
              'capture_completed_ms': captureCompleteAt,
              'capture_separate_visit': true,
              ...observed,
              'requested_observation_interval_ms': 20,
              'qa_warmup_separate_visit': true,
              'return_verified': true,
              'mounted_once': timedMountCount == 1,
              'capture_visit_mounted_once': mounted[kind] == 2,
              'surface_conversion_during_timing': false,
              'native_screenshot_during_timing': false,
              'measurement_scope':
                  'native debug QA renderer; PNG delivery observed in separate visit, not a production performance benchmark',
            });
          }
          // A real Community back control must also cancel its live welcome.
          // This extra visit is not included in the six timing samples.
          await tester.tap(find.byKey(const ValueKey('native-open-community')));
          await tester.pump();
          expect(_welcome('community'), findsOneWidget);
          final earlyBack = find.byKey(const Key('community-safe-return'));
          expect(earlyBack.hitTestable(), findsOneWidget);
          await tester.tap(earlyBack);
          await _nativeSettle(tester);
          await tester.pump(const Duration(milliseconds: 2300));
          expect(router.state.uri.path, '/native-origin');
          expect(_welcome('community'), findsNothing);
          expect(tester.takeException(), isNull);
          expect(_dartNetworkDeny.blockedClientCreations, 0);
          expect(transport.sends, 0);
          expect(gateway.calls, 0);
          expect(community.writes, 0);
          source['early_community_return_cancelled'] = true;
          source['cloud_sends'] = transport.sends;
          source['model_calls'] = gateway.calls;
          source['profile_writes'] = community.writes;
        } finally {
          source['cold_warmup_observations'] = [
            for (final trace in warmupTraces) trace.toJson(),
          ];
          source['last_visit_hold_observations'] = {
            for (final entry in holdObservers.entries)
              entry.key: entry.value.toJson(),
          };
          for (final observer in holdObservers.values) {
            observer.stop();
          }
          source['dart_network_client_creations_blocked'] =
              _dartNetworkDeny.blockedClientCreations;
          await File('${output.path}/$name-metadata.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(source),
            flush: true,
          );
          binding.reportData ??= <String, dynamic>{};
          final reports =
              (binding.reportData!['native_feature_splashes'] ??= <dynamic>[])
                  as List<dynamic>;
          reports.add(source);
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          await client.dispose();
          transport.close();
          await db.close();
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
  _registerNativeCoachReveal(binding);
  _registerNativeSmartPlanSessions(binding);
  _registerNativeConversationsAndStoreActivity(binding);
}

// These eight additional cases mount the real production page and renderer.
// Only the model boundary and account/context data are synthetic and isolated.
// They do not assess remote AI intelligence, spend credits, or grant an account.
