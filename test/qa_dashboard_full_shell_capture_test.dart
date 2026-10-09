// Read-only QA capture of production Dashboard + production 5-tab shell.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_closure/visual_evidence_font.dart';

const _tts = MethodChannel('bil/tts');
final _free = SubscriptionState(
  plan: CommercePlan.free,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  lifecycle: SubscriptionLifecycle.inactive,
  isPurchasable: true,
  canRestorePurchases: true,
);

class _UnavailableHealth implements ConnectedHealthGateway {
  const _UnavailableHealth();
  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();
  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();
  @override
  Future<ConnectedHealthSnapshot> synchronize() => load();
}

Future<void> _writeCapture(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['BIL_DASHBOARD_CAPTURE_DIR'];
  if (dir == null) throw StateError('Capture directory not configured');
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final snapshot = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await snapshot.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Image bytes unavailable for $name');
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(data.buffer.asUint8List());
      stdout.writeln('BIL_DASHBOARD_CAPTURE:$dir/$name.png');
    } finally {
      snapshot.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadVisualEvidenceFont();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tts, (call) async {
          if (call.method == 'stop') return null;
          throw MissingPluginException('Unexpected voice action in capture');
        });
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tts, null);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });
  for (final localeCode in ['en', 'ar']) {
    testWidgets('Real Dashboard plus full 5-tab shell $localeCode', (tester) async {
      final arabic = localeCode == 'ar';
      SharedPreferences.setMockInitialValues({
        'bil_app_settings': '{"localeCode":"$localeCode",'
            '"themeMode":"light","highContrast":false,"reduceMotion":true}',
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await UserProfileRepository(db).save(
        gender: 'male',
        age: 35,
        height: 181,
        currentWeight: 93.4,
        targetWeight: 85,
        activityLevel: 'light',
        exercises: true,
      );
      await PreferencesRepository(db).set('timezoneName', 'Egypt Daylight Time');
      final moment = DateTime(2026, 10, 9, 19, 30);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (_, state, child) =>
                ResponsiveAppShell(currentUri: state.uri, child: child),
            routes: [
              GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
              for (final path in [
                '/intelligence-center',
                '/daily-log',
                '/community',
                '/settings',
                '/connected-health',
              ])
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(
                    appBar: AppBar(),
                    body: Text('Test-only destination: $path'),
                  ),
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dashboardClockProvider.overrideWithValue(() => moment),
            liveHealthNowProvider.overrideWithValue(() => moment),
            connectedHealthGatewayProvider.overrideWithValue(
              const _UnavailableHealth(),
            ),
            verifiedEntitlementClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 10, 9, 19, 30),
            ),
            verifiedSubscriptionStateProvider.overrideWithValue(AsyncData(_free)),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            locale: Locale(localeCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: visualEvidenceTheme(
              BilFlagshipTheme.light(isArabic: arabic),
              fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
            ),
            builder: (context, child) => RepaintBoundary(
              key: captureKey,
              child: visualEvidenceTextSurface(
                child,
                fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await settleVisualAssetImages(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('bil-reference-navigation')), findsOneWidget);
      expect(find.byKey(const Key('shell-community-destination')), findsOneWidget);
      expect(find.byKey(const Key('shell-quick-add')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-wordmark')), findsOneWidget);
      await _writeCapture(tester, captureKey, 'dashboard_' + localeCode + '_top');
      for (var page = 1; page <= 3; page++) {
        await tester.drag(
          find.byKey(const Key('dashboard-scroll-view')),
          const Offset(0, -570),
        );
        await tester.pumpAndSettle();
        await _writeCapture(
          tester, captureKey, 'dashboard_' + localeCode + '_scroll_' + page.toString(),
        );
      }
    });
  }
}
