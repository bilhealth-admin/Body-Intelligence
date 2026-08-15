import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_profile_page.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/settings/trust_support_page.dart';
import 'package:body_intelligence_log/features/notifications/presentation/notification_settings_page.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/professional_content_library_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_library_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_evidence_font.dart';

final class _VisualHealthGateway implements ConnectedHealthGateway {
  const _VisualHealthGateway(this.snapshot);

  final ConnectedHealthSnapshot snapshot;

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}

final class _EmptyWellnessManager extends WellnessContentPackManager {
  @override
  Future<List<WellnessContentItem>> loadTrustedInstalledItems(
    WellnessContentType type, {
    String? locale,
  }) async => const [];
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  Future<void> capture(
    WidgetTester tester, {
    required Widget page,
    required String name,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    Widget Function(Widget child)? wrapper,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final arabic = locale.languageCode == 'ar';
    final theme = brightness == Brightness.dark
        ? BilFlagshipTheme.dark(isArabic: arabic)
        : BilFlagshipTheme.light(isArabic: arabic);
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(
        theme,
        fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      builder: (context, child) => visualEvidenceTextSurface(
        child,
        fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      home: page,
    );
    final databaseScope = ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: app,
    );
    await tester.pumpWidget(wrapper?.call(databaseScope) ?? databaseScope);
    await tester.pumpAndSettle();
    await settleVisualAssetImages(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/visual_closure_$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  testWidgets('store plans production page phone capture', (tester) async {
    await capture(
      tester,
      page: const BilStorePlansPage(connectToDeviceStore: false),
      name: 'store_plans_phone',
    );
  });

  testWidgets('community signed-out production state phone capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityHubPage(),
      name: 'community_signed_out_phone',
    );
  });

  testWidgets('community profile production unavailable state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityProfilePage(),
      name: 'community_profile_phone',
    );
  });

  testWidgets('community connections production unavailable state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityConnectionsPage(),
      name: 'community_connections_phone',
    );
  });

  testWidgets('community messages production unavailable state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityChatPage(
        userId: 'visual-reference-user',
        displayName: 'BIL member',
      ),
      name: 'community_messages_phone',
    );
  });

  testWidgets('trust and support production page RTL dark capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const TrustSupportPage(),
      name: 'trust_support_rtl_dark_phone',
      locale: const Locale('ar'),
      brightness: Brightness.dark,
    );
  });

  testWidgets('connected health permission state production capture', (
    tester,
  ) async {
    const snapshot = ConnectedHealthSnapshot(
      status: ConnectedHealthStatus.permissionDenied,
      platformSource: 'Health Connect',
      availableSources: ['Health Connect'],
      signals: [],
      importedCount: 0,
      lastSyncAt: null,
      failureCode: 'permission_denied',
    );
    await capture(
      tester,
      page: const ConnectedHealthPage(),
      name: 'connected_health_permission_phone',
      wrapper: (child) => ProviderScope(
        overrides: [
          connectedHealthGatewayProvider.overrideWithValue(
            const _VisualHealthGateway(snapshot),
          ),
        ],
        child: child,
      ),
    );
  });

  testWidgets('verified recipe library production capture', (tester) async {
    await capture(
      tester,
      page: ProfessionalContentLibraryPage(
        type: WellnessContentType.recipes,
        manager: _EmptyWellnessManager(),
      ),
      name: 'recipe_library_phone',
    );
  });

  testWidgets('professional workout library production capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: ProfessionalContentLibraryPage(
        type: WellnessContentType.workouts,
        manager: _EmptyWellnessManager(),
      ),
      name: 'workout_library_phone',
    );
  });

  testWidgets('workout logging production page capture', (tester) async {
    await capture(
      tester,
      page: const WorkoutLibraryPage(),
      name: 'workout_log_phone',
    );
  });

  testWidgets('sleep production page capture', (tester) async {
    await capture(tester, page: const SleepTrackerPage(), name: 'sleep_phone');
  });

  testWidgets('fasting production page capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const FastingTimerPage(),
      name: 'fasting_phone',
    );
  });

  testWidgets('wellness directory production page capture', (tester) async {
    await capture(
      tester,
      page: const WellnessLibraryPage(),
      name: 'wellness_library_phone',
    );
  });

  testWidgets('notification settings production page capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const NotificationSettingsPage(),
      name: 'notification_settings_phone',
    );
  });
}
