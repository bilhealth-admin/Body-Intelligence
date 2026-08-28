import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/daily_water_page.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/history/progress_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MatrixHealthGateway implements ConnectedHealthGateway {
  const _MatrixHealthGateway();

  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> synchronize() => load();
}

typedef _CorePage = ({String name, Widget Function() build});

const _corePages = <_CorePage>[
  (name: 'Today', build: DashboardPage.new),
  (name: 'Diary', build: DailyLogPage.new),
  (name: 'Water', build: DailyWaterPage.new),
  (name: 'Progress', build: ProgressPage.new),
  (name: 'More', build: SettingsPage.new),
  (name: 'Plans', build: _buildPlans),
  (name: 'AI Coach', build: IntelligenceCenterPage.new),
];

const _coreRuntimeSources = <String>{
  'Loading Today dashboard',
  'Complete your profile to calculate personalized targets.',
  'Complete profile',
  'No body trend data recorded yet.',
  'No nutrition data recorded yet.',
  'No trend data recorded yet.',
  'Meals',
  'Water',
  'Calories',
  'Steps',
  'Copy from',
  'Manual barcode · Premium',
  'Complete diary',
  'Review today’s entries, then complete the diary to preserve an authoritative snapshot.',
  'Save log',
  'Checking subscription',
  'AI Coach',
  'AI Coach settings',
  'Advertising privacy',
  'Delete account',
  'BIL Premium',
  'Good evening',
  'I’m ready for your next useful decision.',
  'Coach controls',
  'Your BIL Coach',
  'I speak every language and turn your body data into the next clear decision.',
  'Talk now',
  'BIL Coach',
  'FOR TODAY',
};

Widget _buildPlans() => const BilStorePlansPage(connectToDeviceStore: false);

Widget _matrixApp({
  required AppDatabase database,
  required Locale locale,
  required Widget page,
}) {
  final rtl = BilLocalePolicy.isRtlTag(BilLocalePolicy.canonicalTag(locale));
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      connectedHealthGatewayProvider.overrideWithValue(
        const _MatrixHealthGateway(),
      ),
      coachContextSnapshotProvider.overrideWith(
        (ref) async => CoachContextSnapshot.empty(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BilFlagshipTheme.light(isArabic: rtl),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: page,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all 25 locales contain reviewed copy for the seven core pages', () {
    expect(AppLocalizations.supportedLocales, hasLength(25));
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final source in _coreRuntimeSources) {
        expect(
          RuntimeCopy.resolve(source, tag),
          isNotNull,
          reason: '$tag must localize "$source"',
        );
      }
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('$tag renders seven core pages at 160% text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final layoutFailures = <String>[];

      for (final page in _corePages) {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        await tester.pumpWidget(
          _matrixApp(database: database, locale: locale, page: page.build()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final exception = tester.takeException();
        if (exception != null) {
          final detail = exception is FlutterError
              ? exception.toStringDeep()
              : exception.toString();
          layoutFailures.add('${page.name}: $detail');
        }
        final direction = Directionality.of(
          tester.element(find.byType(page.build().runtimeType).first),
        );
        expect(
          direction,
          BilLocalePolicy.isRtlTag(tag) ? TextDirection.rtl : TextDirection.ltr,
          reason: '$tag / ${page.name} direction',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(Duration.zero);
        await tester.pump(Duration.zero);
        await database.close();
      }
      expect(
        layoutFailures,
        isEmpty,
        reason: '$tag core-page layout failures:\n${layoutFailures.join('\n')}',
      );
    });
  }
}
