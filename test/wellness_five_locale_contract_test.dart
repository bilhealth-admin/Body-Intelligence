import 'dart:io';

import 'package:body_intelligence_log/features/wellness/presentation/wellness_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wellness presentation copy catalogs cover all production locales', () {
    expect(WellnessCopyCatalog.supportedLanguageCodes, {
      'ar',
      'en',
      'fr',
      'es',
      'tr',
    });
    expect(WellnessCopyCatalog.catalogsBalanced, isTrue);
  });

  test('wellness presentation has no remaining Arabic-English text branch', () {
    final directory = Directory('lib/features/wellness/presentation');
    final binaryBranch = RegExp(r'\b(?:arabic|_arabic|ar)\s*\?');
    for (final file in directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.dart'),
    )) {
      final source = file.readAsStringSync();
      expect(
        binaryBranch.hasMatch(source),
        isFalse,
        reason: 'Bilingual-only branch remains in ${file.path}',
      );
    }
  });

  test('remaining wellness pages use the five-locale copy surface', () {
    for (final path in const [
      'lib/features/wellness/presentation/wellness_library_page.dart',
      'lib/features/wellness/presentation/wellness_content_packs_page.dart',
      'lib/features/wellness/presentation/wellness_learn_page.dart',
      'lib/features/wellness/presentation/recipe_library_page.dart',
      'lib/features/wellness/presentation/wellness_tools_pages.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('wellnessCopy'));
    }
  });
}
