import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_body_context_copy.dart';
import 'package:body_intelligence_log/features/daily_log/domain/daily_body_context_codec.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_today_sections.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _excellentSleep = <String, String>{
  'en': 'Excellent sleep',
  'ar': 'نوم ممتاز',
  'fr': 'Excellent sommeil',
  'es': 'Sueño excelente',
  'tr': 'Mükemmel uyku',
  'de': 'Ausgezeichneter Schlaf',
  'it': 'Sonno eccellente',
  'pt-BR': 'Excelente sono',
  'pt-PT': 'Excelente sono',
  'ur': 'بہترین نیند',
  'fa': 'خواب عالی',
  'hi': 'बेहतरीन नींद',
  'id': 'Tidur nyenyak',
  'ms': 'Tidur yang sangat baik',
  'ja': '素晴らしい睡眠',
  'ko': '우수한 수면',
  'zh-Hans': '睡眠质量极佳',
  'zh-Hant': '睡眠品質極佳',
  'ru': 'Отличный сон',
  'bn': 'চমৎকার ঘুম',
  'vi': 'giấc ngủ tuyệt vời',
  'th': 'การนอนหลับที่ดีเยี่ยม',
  'pl': 'Doskonały sen',
  'nl': 'Uitstekende nachtrust',
  'uk': 'Чудовий сон',
};

void main() {
  test('authored sleep labels cover the exact supported locale set', () {
    expect(
      _excellentSleep.keys.toSet(),
      AppLocalizations.supportedLocales
          .map(BilLocalePolicy.canonicalTag)
          .toSet(),
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('persisted Today Body context is localized and icon-free $tag', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DailyLogRepository(database);
      final date = DateTime(2026, 10, 4);
      final persisted = DailyBodyContextCodec.encode(
        selected: const {'greatSleep'},
      );
      await repository.saveBodyContext(date: date, notes: persisted);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: DailyLogNotesShortcut()),
            ),
          ),
          GoRoute(
            path: '/daily-log/body-context',
            builder: (_, _) =>
                const Scaffold(body: Text('body-context-editor')),
          ),
        ],
      );
      var disposed = false;
      Future<void> cleanup() async {
        if (disposed) return;
        disposed = true;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        router.dispose();
        await database.close();
      }

      addTearDown(cleanup);
      try {
        final authoredLabels = <String, String>{};
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              selectedLogDateProvider.overrideWith((_) => date),
            ],
            child: MaterialApp.router(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              routerConfig: router,
              builder: (context, child) {
                for (final key in dailyBodyContextEnglishCopy.keys) {
                  authoredLabels[key] = dailyBodyContextCopy(context, key);
                }
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const Key('daily-log-body-context-link'));
        final tileFinder = find.descendant(
          of: card,
          matching: find.byType(ListTile),
        );
        final tile = tester.widget<ListTile>(tileFinder);
        expect(find.text(_excellentSleep[tag]!), findsOneWidget);
        expect(tile.leading, isNull);
        expect(
          find.descendant(
            of: card,
            matching: find.byType(BilSemanticIconBadge),
          ),
          findsNothing,
        );
        expect(tile.trailing, isA<Icon>());
        expect(tile.onTap, isNotNull);
        expect(tester.getSize(tileFinder).height, greaterThanOrEqualTo(48));
        for (final entry in dailyBodyContextEnglishCopy.entries) {
          expect(
            authoredLabels[entry.key],
            isNotEmpty,
            reason: '$tag ${entry.key}',
          );
          // The reviewed French word is legitimately spelled identically in
          // English; an equality assertion cannot identify fallback there.
          if (tag != 'en' && !(tag == 'fr' && entry.key == 'constipation')) {
            expect(
              authoredLabels[entry.key],
              isNot(entry.value),
              reason: '$tag ${entry.key} must not fall back to English',
            );
          }
        }
        expect(tester.takeException(), isNull);
        // Do not translate arbitrary private text just because it happens to
        // equal an authored option's English label.
        final privateText = DailyBodyContextCodec.encode(
          selected: const {'greatSleep', 'other'},
          note: 'Excellent sleep',
          other: 'Travel',
        );
        await repository.saveBodyContext(date: date, notes: privateText);
        await tester.pumpAndSettle();
        final summary = tester.widget<ListTile>(tileFinder).title! as Text;
        expect(
          summary.data,
          'Excellent sleep\n${_excellentSleep[tag]} · ${authoredLabels['other']}\nTravel',
        );
        expect((await repository.getForDay(date))?.notes, privateText);
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();
        expect(find.text('body-context-editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        // Riverpod disposes the genuine Drift watch stream. Drain that owned
        // zero-duration cancellation before Flutter verifies timer invariants.
        await cleanup();
      }
    });
  }
}
