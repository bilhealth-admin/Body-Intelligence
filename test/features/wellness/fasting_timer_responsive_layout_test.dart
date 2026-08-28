import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} fasting title and timer do not overlap at narrow 160%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues(const {});
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesRepositoryProvider.overrideWithValue(
                PreferencesRepository(database),
              ),
              fastingNotificationServiceProvider.overrideWithValue(
                _TestFastingNotificationService(),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child ?? const SizedBox.shrink(),
              ),
              home: const FastingTimerPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(tester.takeException(), isNull);
        final pageTitle = tester.getRect(
          find.byKey(const Key('fasting-page-title')),
        );
        final introduction = tester.getRect(
          find.byKey(const Key('fasting-reference-introduction')),
        );
        expect(pageTitle.bottom, lessThanOrEqualTo(introduction.top));

        final statusPanel = find.byKey(const Key('fasting-status-panel'));
        await tester.scrollUntilVisible(
          statusPanel,
          260,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        final statusIcon = tester.getRect(
          find.byKey(const Key('fasting-status-icon')),
        );
        final statusTitle = tester.getRect(
          find.byKey(const Key('fasting-status-title')),
        );
        expect(statusIcon.overlaps(statusTitle), isFalse);
        expect(tester.takeException(), isNull);

        final timerRing = find.byKey(const Key('fasting-timer-ring'));
        await tester.scrollUntilVisible(
          timerRing,
          260,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        final ringRect = tester.getRect(timerRing);
        expect(ringRect.left, greaterThanOrEqualTo(0));
        expect(ringRect.right, lessThanOrEqualTo(320));
        expect(ringRect.width, lessThanOrEqualTo(220));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}

final class _TestFastingNotificationService extends BilNotificationService {
  _TestFastingNotificationService()
    : super(FlutterLocalNotificationsPlugin());

  @override
  Future<BilNotificationPermissionState> permissionState() async =>
      BilNotificationPermissionState.granted;

  @override
  Future<Set<int>> pendingNotificationIds() async => const {};
}
