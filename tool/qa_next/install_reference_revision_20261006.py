"""Bounded R2 repair against the actual tracked 4803 application revision."""
from pathlib import Path
import subprocess, os

ROOT = Path('.')
BASE = '4803ac1545fcf8a2e72e2a5806f5f4b57eb5aeac'
if os.environ.get('GITHUB_REF') != 'refs/heads/qa/coach-community-next-20261005':
    raise RuntimeError('Isolated QA branch only')
subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], check=True)
changed = []

def edit(name, old, new, count=1):
    p = ROOT / name
    source = p.read_text()
    if source.count(old) != count:
        raise RuntimeError('Source drift ' + name + ': ' + repr(old[:70]))
    p.write_text(source.replace(old, new))
    changed.append(name)

p = 'lib/app/localization/runtime_copy_next_workspace.dart'
edit(p, '  static const sources = <String>[', '  static const _primarySources = <String>[')
edit(p, '  static const rows = <String, List<String>>{', '''  static const supplementalSources = ['Overview', 'Post photos', 'Home'];
  static const sources = <String>[..._primarySources, ...supplementalSources];
  static const _supplemental = <String, List<String>>{
    'ar': ['نظرة عامة', 'صور المنشور', 'الرئيسية'],
    'fr': ['Vue d’ensemble', 'Photos de la publication', 'Accueil'],
    'es': ['Resumen', 'Fotos de la publicación', 'Inicio'],
    'tr': ['Genel bakış', 'Gönderi fotoğrafları', 'Ana sayfa'],
    'de': ['Übersicht', 'Beitragsfotos', 'Startseite'],
    'it': ['Panoramica', 'Foto del post', 'Pagina iniziale'],
    'pt-BR': ['Visão geral', 'Fotos da publicação', 'Início'],
    'pt-PT': ['Visão geral', 'Fotografias da publicação', 'Início'],
    'ur': ['جائزہ', 'پوسٹ کی تصاویر', 'مرکزی صفحہ'],
    'fa': ['نمای کلی', 'عکس‌های پست', 'خانه'],
    'hi': ['अवलोकन', 'पोस्ट की तस्वीरें', 'मुख्य पृष्ठ'],
    'id': ['Ringkasan', 'Foto postingan', 'Beranda'],
    'ms': ['Gambaran keseluruhan', 'Foto siaran', 'Laman utama'],
    'ja': ['概要', '投稿の写真', 'ホーム'],
    'ko': ['개요', '게시물 사진', '홈'],
    'zh-Hans': ['概览', '帖子照片', '首页'],
    'zh-Hant': ['總覽', '貼文照片', '首頁'],
    'ru': ['Обзор', 'Фотографии публикации', 'Главная'],
    'bn': ['সারসংক্ষেপ', 'পোস্টের ছবি', 'প্রধান পাতা'],
    'vi': ['Tổng quan', 'Ảnh bài viết', 'Trang chủ'],
    'th': ['ภาพรวม', 'รูปภาพของโพสต์', 'หน้าหลัก'],
    'pl': ['Przegląd', 'Zdjęcia wpisu', 'Strona główna'],
    'nl': ['Overzicht', 'Berichtfoto’s', 'Startpagina'],
    'uk': ['Огляд', 'Фотографії допису', 'Головна'],
  };
  static const rows = <String, List<String>>{''')
edit(p, '''    final row = rows[tag];
    if (row == null) return null;
    if (row.length != sources.length) {''', '''    final primary = rows[tag];
    final supplemental = _supplemental[tag];
    if (primary == null || supplemental == null) return null;
    final row = <String>[...primary, ...supplemental];
    if (row.length != sources.length) {''')
p = 'lib/shared/widgets/bil_reference_bottom_bar.dart'
edit(p, "import '../../app/localization/app_localizations.dart';", "import '../../app/localization/app_localizations.dart';\nimport '../../app/localization/bil_locale_policy.dart';\nimport '../../app/localization/runtime_copy.dart';")
edit(p, '    final labels = [', '''    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final labels = [''')
edit(p, '        AppLocalizations.of(context).text(source),', '''        copy?.text(source) ??
            RuntimeCopy.resolve(source, BilLocalePolicy.canonicalTag(locale)) ??
            source,''')
edit(p, '''                                      ? BoxDecoration(
                                          boxShadow:''', '''                                      ? BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow:''')
p = 'lib/features/intelligence_center/presentation/intelligence_reference_workspace_flow.dart'
edit(p, '''        scaffoldBackgroundColor: const Color(0xFF07111B),
        colorScheme:''', '''        scaffoldBackgroundColor: const Color(0xFF07111B),
        iconTheme: const IconThemeData(color: Color(0xFFB4C5DA)),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFB4C5DA),
            disabledForegroundColor: const Color(0xFF738397),
          ),
        ),
        colorScheme:''')
p = 'lib/features/intelligence_center/presentation/coach_message_text.dart'
edit(p, '          style: widget.style,', '''          style: (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
            // A user's writing language can differ from the interface locale.
            // Use the bundled Arabic face before an OS/test fallback glyph.
            fontFamilyFallback: <String>[
              'BILArabic',
              ...?widget.style?.fontFamilyFallback,
            ],
          ),''')
p = 'test/qa_next/coach_reference_workspace_capture_test.dart'
edit(p, '''        theme: visualEvidenceTheme(
          BilFlagshipTheme.light(isArabic: language == 'ar'),
        ),''', '''        theme: visualEvidenceTheme(
          BilFlagshipTheme.light(isArabic: language == 'ar'),
          fontFamily: language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
        ),''')
p = 'test/qa_next/reference_regression_r2_cases.dart'
(ROOT / p).write_text('''import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_next_workspace.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void registerReferenceRegressionCases() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('shared navigation survives missing BIL delegate $locale', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(bottomNavigationBar: BilReferenceBottomBar(selected: 3, onSelected: taps.add)),
      ));
      expect(tester.takeException(), isNull);
      final home = NextWorkspaceRuntimeCopy.resolve('Home', locale.toLanguageTag());
      expect(find.text(home!), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(Key('bil-reference-nav-$i')));
      }
      expect(taps, [0, 1, 2, 3, 4]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Arabic and mixed script text has bundled fallback in English UI', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CoachMessageText(
      text: 'Breakfast سجل فطوري', createdAt: DateTime(2026, 10, 5),
      textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'Roboto'),
    ))));
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, 'Breakfast سجل فطوري');
    expect(text.style!.fontFamilyFallback, contains('BILArabic'));
    expect(text.style!.fontFamily, 'Roboto');
    expect(tester.takeException(), isNull);
  });
}
''')
changed.append(p)
edit('test/qa_next/next_workspace_locale_test.dart', "import 'package:flutter_test/flutter_test.dart';", "import 'package:flutter_test/flutter_test.dart';\nimport 'reference_regression_r2_cases.dart';")
edit('test/qa_next/next_workspace_locale_test.dart', 'void main() {', 'void main() {\n  registerReferenceRegressionCases();')
subprocess.run(['dart', 'format', *dict.fromkeys(changed)], check=True)
print('R2 application fixes materialized:', len(set(changed)))
