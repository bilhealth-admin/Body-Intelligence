import 'dart:async';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Standalone QA entrypoint. Does not call lib/main.dart or initialize cloud,
// Firebase, purchases, ads, production Auth, First Use, or startup animations.
// Native fonts are deliberately untouched: no FontLoader/Evidence theme.
const _owner = '11111111-1111-4111-8111-111111111111';
const _head = String.fromEnvironment('BIL_QA_SOURCE_HEAD');
const _fingerprint = String.fromEnvironment('BIL_QA_SOURCE_FINGERPRINT');
const _androidQaEnabled = bool.fromEnvironment('BIL_QA_ANDROID_EMULATOR');
const _iosQaEnabled = bool.fromEnvironment('BIL_QA_IOS_SIMULATOR');
const _sceneFilter = String.fromEnvironment('BIL_QA_NATIVE_SCENE');
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

Future<void> _nativeSettle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 20),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
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
String _location(String kind) => switch (kind) {
  'diet' => '/nutrition-plans',
  'coach' => '/intelligence-center',
  'community' => '/community',
  _ => '/native/$kind',
};

Future<Directory> _output() async {
  final root = Platform.isAndroid
      ? await getExternalStorageDirectory()
      : await getApplicationDocumentsDirectory();
  if (root == null) {
    throw StateError('Native QA app documents directory unavailable');
  }
  final directory = Directory('${root.path}/feature-splashes-native');
  await directory.create(recursive: true);
  return directory;
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
  Directory output,
) async {
  final bytes = await binding.takeScreenshot(name);
  expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final priorHttpOverrides = HttpOverrides.current;
  HttpOverrides.global = _dartNetworkDeny;
  setUp(() => _dartNetworkDeny.blockedClientCreations = 0);
  tearDownAll(() => HttpOverrides.global = priorHttpOverrides);
  for (final scene in _scenes) {
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
        final watches = <String, Stopwatch>{};
        final mounted = <String, int>{};
        final destinationMounts = <String, int>{};
        Widget entry(String kind, GoRouterState state, BuildContext context) {
          final Widget child;
          if (kind == 'diet') {
            final production = AppRouter.router.configuration.routes
                .whereType<GoRoute>()
                .singleWhere((route) => route.path == '/nutrition-plans');
            child = production.builder!(context, state);
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
              watches[kind] = Stopwatch()..start();
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
            await tester.ensureVisible(
              find.byKey(ValueKey('native-open-$kind')),
            );
            await tester.tap(find.byKey(ValueKey('native-open-$kind')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 80));
            final watch = watches[kind]!;
            expect(_welcome(kind), findsOneWidget);
            final indicator = tester.widget<CupertinoActivityIndicator>(
              find.byType(CupertinoActivityIndicator),
            );
            expect(indicator.animating, !scene.reduced);
            expect(indicator.radius, 12);
            expect(mounted[kind], 1);
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
            final captureAt = watch.elapsedMilliseconds;
            expect(
              captureAt,
              lessThan(1900),
              reason: 'do not label a released screen as a welcome capture',
            );
            await _capture(binding, '$kind-$name-welcome', output);
            expect(
              _welcome(kind),
              findsOneWidget,
              reason:
                  'welcome capture must finish before the timer releases it',
            );
            var lastVisible = watch.elapsedMilliseconds;
            while (_welcome(kind).evaluate().isNotEmpty &&
                watch.elapsedMilliseconds < 4500) {
              lastVisible = watch.elapsedMilliseconds;
              await tester.pump(const Duration(milliseconds: 20));
            }
            final absentAt = watch.elapsedMilliseconds;
            expect(
              _welcome(kind),
              findsNothing,
              reason: 'no extra asset or data readiness hold',
            );
            expect(lastVisible, greaterThanOrEqualTo(2100));
            expect(absentAt, greaterThanOrEqualTo(2180));
            expect(
              absentAt,
              lessThan(3200),
              reason:
                  'documented debug-emulator observation budget, not a production SLA',
            );
            expect(mounted[kind], 1);
            if (!['diet', 'coach'].contains(kind)) {
              expect(destinationMounts[kind], 1);
            }
            expect(tester.takeException(), isNull);
            await _capture(binding, '$kind-$name-released', output);
            final Finder back;
            if (kind == 'diet') {
              back = find.byKey(const Key('nutrition-pathways-back'));
            } else if (kind == 'coach') {
              final page = tester.element(find.byType(IntelligenceCenterPage));
              back = find.byTooltip(
                MaterialLocalizations.of(page).backButtonTooltip,
              );
            } else {
              back = find.byKey(const Key('qa-native-return'));
            }
            expect(back.hitTestable(), findsOneWidget);
            await tester.tap(back);
            await _nativeSettle(tester);
            expect(router.state.uri.path, '/native-origin');
            expect(find.text('Isolated native QA'), findsOneWidget);
            expect(transport.sends, 0);
            expect(gateway.calls, 0);
            expect(community.writes, 0);
            timings.add({
              'kind': kind,
              'capture_started_ms': captureAt,
              'last_visible_ms': lastVisible,
              'first_absent_ms': absentAt,
              'observation_interval_ms': 20,
              'return_verified': true,
              'mounted_once': mounted[kind] == 1,
              'surface_conversion_during_timing': false,
              'native_screenshot_during_timing': true,
              'measurement_scope':
                  'native debug QA renderer with screenshot conversion; not performance benchmark',
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
}

// These eight additional cases mount the real production page and renderer.
// Only the model boundary and account/context data are synthetic and isolated.
// They do not assess remote AI intelligence, spend credits, or grant an account.
class _NativeHeldGateway implements LocalModelGateway {
  final replies = <Completer<LocalModelResult>>[];
  final questions = <String>[];
  final locales = <String>[];
  int calls = 0;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) {
    calls++;
    questions.add(question);
    locales.add(locale);
    final pending = Completer<LocalModelResult>();
    replies.add(pending);
    return pending.future;
  }

  void finish(String text) => replies.single.complete(
    LocalModelResult.answer(
      LocalModelAnswer(text: text, action: null, processedOnDevice: true),
    ),
  );
  void cancelPending() {
    for (final pending in replies) {
      if (!pending.isCompleted) {
        pending.complete(
          const LocalModelResult.answer(
            LocalModelAnswer(
              text: 'Synthetic native fixture cancelled.',
              action: null,
            ),
          ),
        );
      }
    }
  }
}

Finder _replyRow(String text) => find.byWidgetPredicate(
  (widget) => widget is CoachMessageText && widget.text == text,
);

Map<String, Object?> _replyGeometry(
  WidgetTester tester,
  String reply,
  Stopwatch watch, {
  Finder? anchor,
}) {
  final sample = <String, Object?>{'observed_at_ms': watch.elapsedMilliseconds};
  final viewport = find.byType(ChatHistoryViewport);
  if (viewport.evaluate().length != 1) {
    return sample..['viewport_present'] = false;
  }
  final rect = tester.getRect(viewport);
  final controller = tester.widget<ChatHistoryViewport>(viewport).controller;
  sample.addAll({
    'viewport_present': true,
    'scroll_pixels': controller.offset,
    'viewport_top': rect.top,
    'viewport_bottom': rect.bottom,
  });
  if (anchor != null && anchor.evaluate().length == 1) {
    sample['history_anchor_top'] = tester.getTopLeft(anchor).dy;
  }
  final row = _replyRow(reply);
  sample['reply_row_present'] = row.evaluate().length == 1;
  if (row.evaluate().length != 1) return sample;
  sample['message_height'] = tester.getSize(row).height;
  final selectable = find.descendant(
    of: row,
    matching: find.byType(SelectableText),
  );
  final editable = find.descendant(
    of: row,
    matching: find.byType(EditableText),
  );
  if (selectable.evaluate().length != 1 || editable.evaluate().length != 1) {
    return sample;
  }
  final text = tester.widget<SelectableText>(selectable).data ?? '';
  sample['visible_graphemes'] = text.characters.length;
  final render = tester.state<EditableTextState>(editable).renderEditable;
  final length = text.characters
      .take(8)
      .join()
      .length; // selection offsets are UTF16.
  var area = 0.0;
  if (length > 0) {
    for (final box in render.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
    )) {
      final global = box.toRect().shift(render.localToGlobal(Offset.zero));
      final overlap = global.intersect(rect);
      if (overlap.width > 0 && overlap.height > 0) {
        area += overlap.width * overlap.height;
      }
    }
  }
  sample['first_glyphs_visible_area'] = area;
  return sample;
}

class _NativeReplyFrameTrace {
  _NativeReplyFrameTrace(this.tester, this.reply, {this.anchor});
  final WidgetTester tester;
  final String reply;
  final Finder? anchor;
  final Stopwatch watch = Stopwatch();
  final samples = <Map<String, Object?>>[];
  final nativeTimings = <Map<String, Object?>>[];
  bool active = false;
  void _timings(List<ui.FrameTiming> values) {
    if (!active || nativeTimings.length >= 500) return;
    for (final value in values) {
      nativeTimings.add({
        'build_us': value.buildDuration.inMicroseconds,
        'raster_us': value.rasterDuration.inMicroseconds,
        'total_us': value.totalSpan.inMicroseconds,
        'raster_finish_us': value.timestampInMicroseconds(
          ui.FramePhase.rasterFinish,
        ),
      });
    }
  }

  void start() {
    active = true;
    watch.start();
    WidgetsBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void _sample(Duration _) {
    if (!active) return;
    if (samples.length < 500) {
      samples.add(_replyGeometry(tester, reply, watch, anchor: anchor));
    }
    // Observe actual native frames. This callback does not schedule extra frames.
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void stop() {
    active = false;
    watch.stop();
    WidgetsBinding.instance.removeTimingsCallback(_timings);
  }
}

Future<GoRouter> _mountNativeCoach(
  WidgetTester tester,
  AppDatabase db,
  _NativeHeldGateway gateway, {
  required String language,
  required bool reduced,
  required bool history,
}) async {
  if (history) {
    await PreferencesRepository(db).set(
      'intelligenceConversationV1',
      jsonEncode(
        List.generate(
          35,
          (i) => IntelligenceMessage(
            id: 'native-history-$i',
            role: i.isEven
                ? IntelligenceMessageRole.user
                : IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: language == 'ar'
                ? 'سجل محلي تركيبي $i: رسالة مقروءة لا تنتمي لأي حساب حقيقي.'
                : 'Synthetic local history $i: a readable message unrelated to any real account.',
            createdAt: DateTime(2026, 10, 13, 8, i),
          ).toJson(),
        ),
      ),
    );
  }
  final router = GoRouter(
    initialLocation: '/native-origin',
    routes: [
      GoRoute(
        path: '/native-origin',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('native-open-coach-reveal'),
              onPressed: () => context.push('/intelligence-center'),
              child: const Text('Isolated native Coach QA'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/intelligence-center',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const IntelligenceCenterPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('QA fallback')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        coachContextSnapshotProvider.overrideWith(
          (ref) async => CoachContextSnapshot.empty(),
        ),
        coachHealthBriefProvider.overrideWith(
          (ref) async => CoachContextSnapshot.empty(),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
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
            plan: CommercePlan.premiumAiCoach,
            entitlements: const {},
            authority: EntitlementAuthority.verifiedServer,
            currentPeriodEndsAt: DateTime(2030),
            isPurchasable: false,
            canRestorePurchases: false,
          ),
        ),
        storefrontTargetPlanProvider.overrideWith(
          (ref) async => CommercePlan.premiumAiCoach,
        ),
        verifiedEntitlementOwnerProvider.overrideWith(
          (ref) => Stream.value(_owner),
        ),
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(_owner),
        aiCoachCreditAccessProvider.overrideWith((ref) async => true),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(
          () async => <String, Object?>{
            'credits': <String, Object?>{'total_remaining': 1000},
          },
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: BilFlagshipTheme.light(
          isArabic: language == 'ar',
        ).copyWith(platform: TargetPlatform.android),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await _nativeSettle(tester);
  await tester.tap(find.byKey(const ValueKey('native-open-coach-reveal')));
  await tester.pump();
  final entryWatch = Stopwatch()..start();
  while (find
          .byKey(const Key('ai-coach-entry-welcome'))
          .evaluate()
          .isNotEmpty &&
      entryWatch.elapsedMilliseconds < 4500) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  // Static reduced-motion spinners do not schedule frames: settling alone
  // would return before the independent 2.2s hold Timer completes.
  expect(find.byKey(const Key('ai-coach-entry-welcome')), findsNothing);
  await _nativeSettle(tester);
  expect(
    find.byKey(const Key('ai-coach-question-field')).hitTestable(),
    findsOneWidget,
  );
  if (Platform.isAndroid) {
    await IntegrationTestWidgetsFlutterBinding.ensureInitialized()
        .convertFlutterSurfaceToImage();
  }
  await tester.pump();
  return router;
}

Future<void> _sendNativeCoach(
  WidgetTester tester,
  _NativeHeldGateway gateway,
  String language,
) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    language == 'ar' ? 'مرحبا' : 'Hello',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  final wait = Stopwatch()..start();
  while (gateway.calls == 0 && wait.elapsedMilliseconds < 5000) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    gateway.calls,
    1,
    reason: 'One real page send reaches only the held synthetic boundary.',
  );
  expect(gateway.questions.single, language == 'ar' ? 'مرحبا' : 'hello');
  expect(gateway.locales.single, language);
}

Future<void> _captureReply(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
  Directory output,
  _NativeReplyFrameTrace trace,
  Map<String, Object?> metadata,
) async {
  final before = _replyGeometry(
    tester,
    trace.reply,
    trace.watch,
    anchor: trace.anchor,
  );
  await _capture(binding, name, output);
  final after = _replyGeometry(
    tester,
    trace.reply,
    trace.watch,
    anchor: trace.anchor,
  );
  (metadata['capture_windows'] as List).add({
    'name': name,
    'before': before,
    'after': after,
  });
}

void _registerNativeCoachReveal(IntegrationTestWidgetsFlutterBinding binding) {
  for (final language in ['ar', 'en']) {
    for (final reduced in [false, true]) {
      final scene = '$language-light-${reduced ? 'reduced' : 'normal'}';
      if (_sceneFilter.isNotEmpty && scene != _sceneFilter) continue;
      for (final history in [false, true]) {
        final mode = history ? 'history' : 'reveal';
        testWidgets(
          'native Coach $mode $scene 2x real fonts and frames',
          (tester) async {
            expect(Platform.isAndroid || Platform.isIOS, isTrue);
            expect(_isExpectedNativeQaTarget(), isTrue);
            expect(AppEnvironment.profile, EnvironmentProfile.testing);
            expect(
              AppEnvironment.useSupabase ||
                  AppEnvironment.paymentsEnabled ||
                  AppEnvironment.pushEnabled ||
                  AppEnvironment.adsEnabled,
              isFalse,
            );
            expect(_head.isNotEmpty && _fingerprint.isNotEmpty, isTrue);
            final output = await _output();
            final db = AppDatabase.forTesting(
              NativeDatabase.memory(),
              localOwnerId: _owner,
            );
            final gateway = _NativeHeldGateway();
            final reply = List.generate(
              26,
              (i) => language == 'ar'
                  ? 'فقرة تركيبية $i: هذه قراءة محلية واضحة لا تحفظ طعامًا ولا تغيّر حسابًا.'
                  : 'Synthetic paragraph $i: this readable reply performs no food write or account change.',
            ).join('\n');
            final metadata = <String, Object?>{
              'classification':
                  'native ${Platform.operatingSystem} QA production Coach page / held synthetic model, not AI-quality E2E',
              'platform': Platform.operatingSystem,
              'source_head': _head,
              'source_fingerprint': _fingerprint,
              'scene': scene,
              'mode': mode,
              'text_scale': 2.0,
              'reduced_motion_fixture': reduced,
              'native_reduce_motion':
                  binding.platformDispatcher.accessibilityFeatures.reduceMotion,
              'fonts':
                  'actual platform theme and bundled BIL fonts; no Evidence override',
              'physical_size':
                  '${tester.view.physicalSize.width}x${tester.view.physicalSize.height}',
              'device_pixel_ratio': tester.view.devicePixelRatio,
              'capture_windows': <Object?>[],
              'completed': false,
            };
            GoRouter? router;
            _NativeReplyFrameTrace? trace;
            try {
              router = await _mountNativeCoach(
                tester,
                db,
                gateway,
                language: language,
                reduced: reduced,
                history: history,
              );
              await _sendNativeCoach(tester, gateway, language);
              Finder? anchor;
              double? anchorBefore, offsetBefore;
              if (history) {
                final viewport = find.byType(ChatHistoryViewport);
                // User-owned drag dismisses the actual keyboard and enters older history.
                await tester.drag(viewport, const Offset(0, 220));
                final controller = tester
                    .widget<ChatHistoryViewport>(viewport)
                    .controller;
                for (
                  var i = 0;
                  i < 80 && controller.position.isScrollingNotifier.value;
                  i++
                ) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                expect(controller.position.isScrollingNotifier.value, isFalse);
                expect(
                  controller.offset - controller.position.minScrollExtent,
                  greaterThan(72),
                  reason:
                      'History condition must actually leave the newest-end follow zone.',
                );
                final bounds = tester.getRect(viewport);
                final candidate = find
                    .byType(CoachMessageText)
                    .evaluate()
                    .firstWhere((element) {
                      final widget = element.widget as CoachMessageText;
                      if (!widget.text.startsWith(
                        language == 'ar'
                            ? 'سجل محلي تركيبي'
                            : 'Synthetic local history',
                      )) {
                        return false;
                      }
                      final rect = tester.getRect(find.byKey(widget.key!));
                      return rect.top >= bounds.top &&
                          rect.bottom <= bounds.bottom;
                    });
                anchor = find.byKey(candidate.widget.key!);
                anchorBefore = tester.getTopLeft(anchor).dy;
                offsetBefore = controller.offset;
                metadata.addAll({
                  'history_anchor_top_before': anchorBefore,
                  'scroll_pixels_before': offsetBefore,
                });
              }
              trace = _NativeReplyFrameTrace(tester, reply, anchor: anchor)
                ..start();
              if (history) {
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-reading',
                  output,
                  trace,
                  metadata,
                );
              }
              final replyReleasedAt = trace.watch.elapsedMilliseconds;
              metadata['held_reply_released_at_ms'] = replyReleasedAt;
              gateway.finish(reply);
              if (history) {
                for (var i = 0; i < 25; i++) {
                  await tester.pump(const Duration(milliseconds: 16));
                  expect(
                    tester.getTopLeft(anchor!).dy,
                    closeTo(anchorBefore!, .5),
                  );
                  final controller = tester
                      .widget<ChatHistoryViewport>(
                        find.byType(ChatHistoryViewport),
                      )
                      .controller;
                  expect(controller.offset, closeTo(offsetBefore!, .5));
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-mid',
                  output,
                  trace,
                  metadata,
                );
              } else {
                while (!trace.samples.any(
                      (sample) =>
                          (sample['visible_graphemes'] as int? ?? 0) > 0,
                    ) &&
                    trace.watch.elapsedMilliseconds < 1500) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                final nonempty = trace.samples
                    .where(
                      (sample) =>
                          (sample['visible_graphemes'] as int? ?? 0) > 0,
                    )
                    .toList();
                expect(
                  nonempty,
                  isNotEmpty,
                  reason:
                      'Real page must paint a nonempty reply within the recorded native observation budget.',
                );
                final first = nonempty.first;
                metadata['first_nonempty_native_frame'] = first;
                expect(
                  first['first_glyphs_visible_area'] as num,
                  greaterThan(0),
                  reason:
                      'First nonempty painted glyphs must be inside the actual native viewport.',
                );
                expect(
                  first['visible_graphemes'] as int,
                  greaterThanOrEqualTo(8),
                );
                if (reduced) {
                  expect(first['visible_graphemes'], reply.characters.length);
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-first',
                  output,
                  trace,
                  metadata,
                );
                while (trace.watch.elapsedMilliseconds < 1100) {
                  await tester.pump(const Duration(milliseconds: 16));
                }
                final mid = _replyGeometry(tester, reply, trace.watch);
                if (!reduced) {
                  expect(
                    mid['visible_graphemes'] as int,
                    lessThan(reply.characters.length),
                    reason:
                        'If native screenshot overhead missed mid-reveal, record a capture limitation rather than fake it.',
                  );
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-mid',
                  output,
                  trace,
                  metadata,
                );
              }
              while (trace.watch.elapsedMilliseconds - replyReleasedAt < 2800) {
                await tester.pump(const Duration(milliseconds: 16));
              }
              if (history) {
                expect(
                  tester.getTopLeft(anchor!).dy,
                  closeTo(anchorBefore!, .5),
                );
                final controller = tester
                    .widget<ChatHistoryViewport>(
                      find.byType(ChatHistoryViewport),
                    )
                    .controller;
                expect(controller.offset, closeTo(offsetBefore!, .5));
                await _captureReply(
                  binding,
                  tester,
                  'coach-history-$scene-end',
                  output,
                  trace,
                  metadata,
                );
              } else {
                final row = _replyRow(reply);
                expect(
                  tester
                      .widget<SelectableText>(
                        find.descendant(
                          of: row,
                          matching: find.byType(SelectableText),
                        ),
                      )
                      .data,
                  reply,
                );
                final painted = trace.samples
                    .where(
                      (sample) =>
                          (sample['visible_graphemes'] as int? ?? 0) > 0,
                    )
                    .toList();
                final height = (painted.first['message_height'] as num)
                    .toDouble();
                for (final sample in painted) {
                  expect(
                    (sample['message_height'] as num).toDouble(),
                    closeTo(height, .5),
                    reason:
                        'Full reply typography stays reserved while its prefix reveals.',
                  );
                }
                await _captureReply(
                  binding,
                  tester,
                  'coach-reveal-$scene-end',
                  output,
                  trace,
                  metadata,
                );
              }
              expect(gateway.calls, 1);
              expect(tester.takeException(), isNull);
              expect(_dartNetworkDeny.blockedClientCreations, 0);
              metadata['completed'] = true;
            } finally {
              trace?.stop();
              gateway.cancelPending();
              metadata['geometry_native_frames'] =
                  trace?.samples ?? <Object?>[];
              metadata['native_frame_timings'] =
                  trace?.nativeTimings ?? <Object?>[];
              metadata['synthetic_gateway_calls'] = gateway.calls;
              metadata['synthetic_gateway_questions'] = gateway.questions;
              metadata['synthetic_gateway_locales'] = gateway.locales;
              metadata['dart_network_client_creations_blocked'] =
                  _dartNetworkDeny.blockedClientCreations;
              metadata['real_model_calls'] = 0;
              metadata['real_credits_spent'] = 0;
              await File(
                '${output.path}/coach-$mode-$scene-metadata.json',
              ).writeAsString(
                const JsonEncoder.withIndent('  ').convert(metadata),
                flush: true,
              );
              binding.reportData ??= <String, dynamic>{};
              final reports =
                  (binding.reportData!['native_coach_$mode'] ??= <dynamic>[])
                      as List<dynamic>;
              reports.add(metadata);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              router?.dispose();
              await db.close();
            }
          },
          timeout: const Timeout(Duration(seconds: 90)),
        );
      }
    }
  }
}
