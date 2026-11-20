import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/nutrition/domain/catalog_pack.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/catalog_packs_page.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/nutrition_copy.dart';
import 'package:body_intelligence_log/features/nutrition/services/catalog_pack_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _downloadIntro =
    'Download verified libraries when needed and search them offline.';
const _downloadIntroAr = 'نزّل مكتبات موثقة عند الحاجة، وابحث فيها دون إنترنت.';
const _implementationCopy =
    'The core library is bundled. Optional packs enter BIL only after size and cryptographic hash verification.';
const _implementationCopyAr =
    'المكتبة الأساسية مضمّنة. الحزم الإضافية لا تدخل التطبيق إلا بعد التحقق من الحجم والبصمة الرقمية.';
const _buildCopy =
    'Pack downloads are not configured in this build yet. No placeholder links or unverified downloads are used.';
const _buildCopyAr =
    'تنزيل الحزم غير مفعّل في هذه النسخة بعد. لا توجد روابط وهمية أو تنزيلات غير موثقة.';
const _emptyCopy = 'No packs are currently published.';
const _emptyCopyAr = 'لا توجد حزم منشورة حاليًا.';
const _errorCopy =
    'The pack list could not be refreshed. Your local library still works.';
const _errorCopyAr = 'تعذّر تحديث قائمة الحزم. المكتبة المحلية ما زالت تعمل.';

class _CopyPacks extends CatalogPackManager {
  _CopyPacks({required this.configured, this.fail = false});
  final bool configured;
  final bool fail;

  @override
  bool get downloadsConfigured => configured;
  @override
  Future<List<InstalledCatalogPack>> installed() async => const [];
  @override
  Future<List<CatalogPack>> fetchAvailable() async {
    if (fail) throw StateError('Synthetic optional catalog outage');
    return const [];
  }
}

Future<void> _mount(
  WidgetTester tester, {
  required Locale locale,
  required bool configured,
  bool fail = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('${locale.toLanguageTag()}-$configured-$fail'),
      overrides: [
        catalogPackManagerProvider.overrideWithValue(
          _CopyPacks(configured: configured, fail: fail),
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
        home: const CatalogPacksPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectCore(WidgetTester tester, String tag) {
  final offlineStatus = nutritionTextForLanguage(
    tag,
    'Installed and offline-ready',
    'مثبّت وجاهز دون إنترنت',
  );
  if (tag != 'en') {
    expect(offlineStatus, isNot('Installed and offline-ready'), reason: tag);
  }
  expect(
    find.byKey(const Key('catalog-core-installed')).hitTestable(),
    findsOneWidget,
  );
  expect(
    find.text(
      nutritionTextForLanguage(tag, 'BIL Food Core', 'أساس BIL الغذائي'),
    ),
    findsOneWidget,
  );
  expect(find.text(offlineStatus), findsOneWidget);
  expect(
    find.text(
      nutritionTextForLanguage(tag, _implementationCopy, _implementationCopyAr),
    ),
    findsNothing,
  );
  expect(
    find.text(nutritionTextForLanguage(tag, _buildCopy, _buildCopyAr)),
    findsNothing,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'unconfigured food libraries show offline core without build or hash copy in every shipped locale',
    (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        await _mount(tester, locale: locale, configured: false);
        _expectCore(tester, tag);
        expect(
          find.text(
            nutritionTextForLanguage(tag, _downloadIntro, _downloadIntroAr),
          ),
          findsNothing,
        );
        expect(
          find.text(nutritionTextForLanguage(tag, _emptyCopy, _emptyCopyAr)),
          findsNothing,
        );
        expect(
          find.text(nutritionTextForLanguage(tag, _errorCopy, _errorCopyAr)),
          findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'configured food libraries retain truthful empty and refresh-error states',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        for (final fail in [false, true]) {
          await _mount(tester, locale: locale, configured: true, fail: fail);
          _expectCore(tester, tag);
          expect(
            find.text(
              nutritionTextForLanguage(tag, _downloadIntro, _downloadIntroAr),
            ),
            findsOneWidget,
          );
          expect(
            find.text(nutritionTextForLanguage(tag, _emptyCopy, _emptyCopyAr)),
            fail ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(nutritionTextForLanguage(tag, _errorCopy, _errorCopyAr)),
            fail ? findsOneWidget : findsNothing,
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
