import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';

const _targets = <String, String>{
  'de': 'de',
  'it': 'it',
  'pt-BR': 'pt-BR',
  'pt-PT': 'pt-PT',
  'ur': 'ur',
  'fa': 'fa',
  'hi': 'hi',
  'id': 'id',
  'ms': 'ms',
  'ja': 'ja',
  'ko': 'ko',
  'zh-Hans': 'zh-CN',
  'zh-Hant': 'zh-TW',
  'ru': 'ru',
  'bn': 'bn',
  'vi': 'vi',
  'th': 'th',
  'pl': 'pl',
  'nl': 'nl',
  'uk': 'uk',
};

const _delimiter = 'ZXQPSEGMENT9X7ZXQP';
const _bilToken = 'ZXQPBILBRAND9X7ZXQP';
const _coachToken = 'ZXQPAICOACHBRAND9X7ZXQP';

// Reviewed exceptions where the generic translator preserved an English UI
// label even though the locale has a clearer native equivalent.
const _reviewedOverrides = <(String, String), String>{
  ('vi', 'Low carb'): 'Ít carbohydrate',
  ('uk', 'Custom'): 'Користувацький',
  (
    'de',
    _invalidLink,
  ): 'Dieser Link kann nicht sicher geöffnet werden. Kehren Sie zum Dashboard zurück und versuchen Sie es erneut.',
  (
    'it',
    _invalidLink,
  ): 'Questo link non può essere aperto in sicurezza. Torna alla dashboard e riprova.',
  (
    'pt-BR',
    _invalidLink,
  ): 'Não é possível abrir este link com segurança. Volte ao painel e tente novamente.',
  (
    'pt-PT',
    _invalidLink,
  ): 'Não é possível abrir esta ligação em segurança. Volte ao painel e tente novamente.',
  (
    'ur',
    _invalidLink,
  ): 'اس لنک کو محفوظ طریقے سے نہیں کھولا جا سکتا۔ ڈیش بورڈ پر واپس جائیں اور دوبارہ کوشش کریں۔',
  (
    'fa',
    _invalidLink,
  ): 'این پیوند را نمی‌توان با اطمینان باز کرد. به داشبورد برگردید و دوباره تلاش کنید.',
  (
    'hi',
    _invalidLink,
  ): 'इस लिंक को सुरक्षित रूप से नहीं खोला जा सकता। डैशबोर्ड पर लौटें और फिर कोशिश करें।',
  (
    'id',
    _invalidLink,
  ): 'Tautan ini tidak dapat dibuka dengan aman. Kembali ke dasbor dan coba lagi.',
  (
    'ms',
    _invalidLink,
  ): 'Pautan ini tidak dapat dibuka dengan selamat. Kembali ke papan pemuka dan cuba lagi.',
  ('ja', _invalidLink): 'このリンクは安全に開けません。ダッシュボードに戻って、もう一度お試しください。',
  ('ko', _invalidLink): '이 링크를 안전하게 열 수 없습니다. 대시보드로 돌아가 다시 시도하세요.',
  ('zh-Hans', _invalidLink): '无法安全打开此链接。请返回仪表板后重试。',
  ('zh-Hant', _invalidLink): '無法安全開啟此連結。請返回儀表板後再試一次。',
  (
    'ru',
    _invalidLink,
  ): 'Эту ссылку невозможно безопасно открыть. Вернитесь на панель и повторите попытку.',
  ('bn', _invalidLink):
      'এই লিংকটি নিরাপদভাবে খোলা যাচ্ছে না। ড্যাশবোর্ডে ফিরে আবার চেষ্টা করুন।',
  (
    'vi',
    _invalidLink,
  ): 'Không thể mở liên kết này một cách an toàn. Hãy quay lại bảng điều khiển và thử lại.',
  (
    'th',
    _invalidLink,
  ): 'ไม่สามารถเปิดลิงก์นี้ได้อย่างปลอดภัย โปรดกลับไปที่แดชบอร์ดแล้วลองอีกครั้ง',
  (
    'pl',
    _invalidLink,
  ): 'Nie można bezpiecznie otworzyć tego linku. Wróć do panelu i spróbuj ponownie.',
  (
    'nl',
    _invalidLink,
  ): 'Deze link kan niet veilig worden geopend. Ga terug naar het dashboard en probeer het opnieuw.',
  (
    'uk',
    _invalidLink,
  ): 'Це посилання неможливо безпечно відкрити. Поверніться на панель і спробуйте ще раз.',
};

const _invalidLink =
    'This link cannot be opened safely. Return to the dashboard and try again.';

Future<void> main(List<String> args) async {
  final mergeMissing = args.contains('--merge-missing');
  final only = args.where((value) => value != '--merge-missing').toSet();
  final targets = Map<String, String>.fromEntries(
    _targets.entries.where((entry) => only.isEmpty || only.contains(entry.key)),
  );
  if (targets.isEmpty) {
    stderr.writeln('No recognized locale tags: ${args.join(', ')}');
    exitCode = 64;
    return;
  }
  final sources = <String>{
    ...RuntimeCopy.values.keys,
    ...await _additionalSources(),
  }.toList(growable: false);
  if (mergeMissing) {
    await _mergeMissingSources(sources);
    return;
  }
  final translatedByTag = <String, List<String>>{};
  final entries = targets.entries.toList(growable: false);
  for (var start = 0; start < entries.length; start += 4) {
    final group = entries.skip(start).take(4);
    final results = await Future.wait(
      group.map((entry) async {
        stdout.writeln('Translating ${entry.key} (${sources.length} entries)');
        return MapEntry(
          entry.key,
          await _translateCatalog(sources, entry.value),
        );
      }),
    );
    translatedByTag.addEntries(results);
  }
  if (only.isNotEmpty) {
    stderr.writeln(
      'Partial generation is intentionally not written. Run with no tags.',
    );
    return;
  }
  final output = StringBuffer()
    ..writeln('// GENERATED FILE. Regenerate with:')
    ..writeln(
      '// dart run tool/localization/generate_extended_runtime_copy.dart',
    )
    ..writeln('// Source keys are the canonical English RuntimeCopy keys.')
    ..writeln('abstract final class ExtendedRuntimeCopy {')
    ..writeln('  static const supported = <String>{');
  for (final tag in targets.keys) {
    output.writeln('    ${_dartString(tag)},');
  }
  output
    ..writeln('  };')
    ..writeln('  static const values = <String, Map<String, String>>{');
  for (var index = 0; index < sources.length; index += 1) {
    output.writeln('    ${_dartString(sources[index])}: {');
    for (final tag in targets.keys) {
      final translated =
          _reviewedOverrides[(tag, sources[index])] ??
          translatedByTag[tag]![index];
      output.writeln('      ${_dartString(tag)}: ${_dartString(translated)},');
    }
    output.writeln('    },');
  }
  output
    ..writeln('  };')
    ..writeln('}');
  await File(
    'lib/app/localization/runtime_copy_extended.dart',
  ).writeAsString(output.toString());
}

Future<List<String>> _translateCatalog(
  List<String> sources,
  String target,
) async {
  final result = <String>[];
  for (var start = 0; start < sources.length; start += 24) {
    final chunk = sources.skip(start).take(24).toList(growable: false);
    final protected = chunk.map(_protectBrands).join('\n$_delimiter\n');
    List<String>? parts;
    for (var segmentAttempt = 1; segmentAttempt <= 3; segmentAttempt += 1) {
      final translated = await _requestWithRetry(protected, target);
      final candidate = translated
          .split(_delimiter)
          .map((value) => value.trim())
          .toList();
      if (candidate.length == chunk.length &&
          !candidate.any((value) => value.isEmpty)) {
        parts = candidate;
        break;
      }
      stderr.writeln(
        'Retrying segment $target/$start after mismatch '
        '${candidate.length}/${chunk.length} (attempt $segmentAttempt/3)',
      );
    }
    if (parts == null) {
      throw StateError('Segment mismatch for $target at $start after retries');
    }
    for (var index = 0; index < parts.length; index += 1) {
      result.add(_restoreProtectedBrands(chunk[index], parts[index]));
    }
    stdout.writeln('  $target ${result.length}/${sources.length}');
  }
  return result;
}

Future<String> _requestWithRetry(String text, String target) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 4; attempt += 1) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        Uri.parse('https://translate.google.com/translate_a/t?client=gtx'),
      );
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        Uri(
          queryParameters: {
            'client': 'gtx',
            'sl': 'en',
            'tl': target,
            'dt': 't',
            'q': text,
          },
        ).query,
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body) as List<dynamic>;
      if (decoded.every((value) => value is String)) {
        return decoded.cast<String>().join();
      }
      final segments = decoded.first as List<dynamic>;
      return segments
          .map((row) => (row as List<dynamic>).first.toString())
          .join();
    } catch (error) {
      lastError = error;
      if (attempt < 4) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    } finally {
      client.close(force: true);
    }
  }
  throw StateError('Translation failed for $target: $lastError');
}

String _protectBrands(String value) {
  var variableIndex = 0;
  return value
      .replaceAllMapped(
        RegExp(r'\{[^}]+\}'),
        (_) => 'ZXQPVAR${variableIndex++}X7ZXQP',
      )
      .replaceAll('AI Coach', _coachToken)
      .replaceAll('BIL', _bilToken);
}

String _restoreBrands(String value) =>
    value.replaceAll(_coachToken, 'AI Coach').replaceAll(_bilToken, 'BIL');

String _restoreProtectedBrands(String source, String translated) {
  var restored = _restoreBrands(translated).replaceAllMapped(
    RegExp(r'ZXQP[^\s]*9X7ZXQP'),
    (match) => match.group(0)!.contains('BIL') ? 'BIL' : 'AI Coach',
  );
  if (source.contains('AI Coach') && !restored.contains('AI Coach')) {
    restored = '$restored AI Coach';
  }
  if (source.contains('BIL') && !restored.contains('BIL')) {
    restored = '$restored BIL';
  }
  final variables = RegExp(
    r'\{[^}]+\}',
  ).allMatches(source).map((match) => match.group(0)!).toList();
  for (var index = 0; index < variables.length; index += 1) {
    restored = restored.replaceAll('ZXQPVAR${index}X7ZXQP', variables[index]);
  }
  return restored;
}

String _dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

Future<Set<String>> _additionalSources() async {
  final app = await File(
    'lib/app/localization/app_localizations.dart',
  ).readAsString();
  final marker = 'static const Map<String, String> _en = {';
  final start = app.indexOf(marker);
  final end = app.indexOf('\n  };', start);
  if (start < 0 || end < 0) throw StateError('English base catalog not found');
  final feature = await File(
    'lib/app/localization/feature_strings.dart',
  ).readAsString();
  final values = <String>{};
  final valuePattern = RegExp(r":\s*'((?:\\.|[^'])*)'");
  for (final match in valuePattern.allMatches(app.substring(start, end))) {
    values.add(_unescapeDartSingle(match.group(1)!));
  }
  final arabicMarker = 'static const Map<String, String> _arabicText = {';
  final arabicStart = app.indexOf(arabicMarker);
  final arabicEnd = app.indexOf('\n  };', arabicStart);
  if (arabicStart < 0 || arabicEnd < 0) {
    throw StateError('Arabic text catalog not found');
  }
  final keyPattern = RegExp(r"^\s*'((?:\\.|[^'])*)':", multiLine: true);
  for (final match in keyPattern.allMatches(
    app.substring(arabicStart, arabicEnd),
  )) {
    values.add(_unescapeDartSingle(match.group(1)!));
  }
  final englishPattern = RegExp(r"'en':\s*'((?:\\.|[^'])*)'");
  for (final match in englishPattern.allMatches(feature)) {
    values.add(_unescapeDartSingle(match.group(1)!));
  }
  values.addAll(
    await _authoredMapKeys(
      'lib/features/auth/auth_five_locale_copy.dart',
      'const _authAuthoredCopy',
    ),
  );
  values.add('Set calories and percentages totaling 100% to calculate grams.');
  values.addAll(
    await _authoredMapKeys(
      'lib/features/onboarding/onboarding_locale_copy.dart',
      'const onboardingAuthoredCopy',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/onboarding/shared/calibration_components.dart',
      'const _bodyCanvasCopy',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/intelligence_center/intelligence_locale_copy.dart',
      'const _serviceAuthored',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/dashboard/dashboard_five_locale_copy.dart',
      'const _dashboardAuthoredCopy',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/profile/profile_summary_locale_copy.dart',
      'const profileSummaryAuthoredCopy',
    ),
  );
  values.addAll(await _progressEnglishValues());
  values.addAll(await _fastingEnglishValues());
  values.addAll(await _notificationSettingsEnglishValues());
  values.addAll(const {
    'Food names in connected health',
    'With your permission, BIL can export a meal name, calories, and macros to connected health. You can revoke access at any time.',
    'Sync food names and nutrition',
    'Food-name and nutrition sync is enabled',
    'Turn on to request connected-health nutrition access.',
    'Nutrition export is unavailable on this platform.',
    'This platform does not support BIL nutrition export. Your local meal records are unchanged.',
    'Distance',
    'Diastolic blood pressure',
    'Body fat',
    'Lean mass',
    'Heart-rate variability',
    'Respiratory rate',
    'Dietary energy',
    'Protein',
    'Carbohydrates',
    'Total fat',
    'Fiber',
    'Sugar',
    'Sodium',
    'Potassium',
  });
  values.addAll(
    await _englishMapKeys(
      'lib/features/connected_health/connected_health_copy.dart',
      "  'fr': {",
    ),
  );
  values.addAll(await _wellnessLearnEnglishValues());
  values.addAll(const {
    'Steps',
    'Choose a source',
    'Phone motion and health source',
    'Uses a source only after you authorize it on this device.',
    'Connected watch',
    'A connected watch source is available.',
    'No connected watch source is available.',
    'Add a device',
    'Open connected-health sources and permissions.',
    'Do not track steps',
    'Step goal',
    'Daily step goal',
    'Not set',
    'Cancel',
    'Save',
    'Retry',
    'Step settings could not be loaded.',
    'Could not save step settings. Try again.',
    'Enter a whole-number goal from 1000 to 100000.',
    'Loading step settings',
    'Checking connected sources…',
    'Connected sources could not be checked.',
    'Retry connected sources',
    'Nutrient goals',
    'Goal or nutrition evidence is unavailable',
    'Edit goal',
    'Nutrition goals',
    'Exercise settings',
    'Illustration only',
    'Review meals alongside sleep',
    'Open Daily Log to review meal timing alongside saved sleep. This does not establish causation.',
    'Diary sharing is not available yet. Your diary remains private.',
    'Customize the four supported meal names. Empty slots are hidden from the diary.',
  });
  values.addAll(await _communityConnectionsEnglishValues());
  values.addAll(await _communityMessagesEnglishValues());
  values.addAll(await _legalDocumentEnglishValues());
  values.addAll(await _trustSupportEnglishValues());
  values.addAll(await _helpCenterEnglishValues());
  values.addAll(await _accountDeletionEnglishValues());
  values.addAll(await _advertisingPrivacyEnglishValues());
  values.addAll(
    await _authoredMapKeys(
      'lib/features/settings/reference_preferences_pages.dart',
      'const _nutritionGoalCopy',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/settings/reference_goals_page.dart',
      'const _copy',
      indentation: 2,
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/exercise_calorie_controls/presentation/exercise_calorie_settings_page.dart',
      "  'en': _Copy(",
      endMarker: '\n  ),',
    ),
  );
  values.addAll(const {
    'Active',
    'Locked Pro feature',
    'Retry subscription check',
    'This is an independent Premium feature.',
    'Choose the nutrients you want to track as dashboard cards. This is an independent Premium feature.',
    'View Premium plans',
    'Add nutrient goal cards, Premium active',
    'Add nutrient goal cards, locked Premium feature',
    'Loading saved setting',
    'Choose what appears on Today. Your data stays saved and every card can be restored at any time.',
    'Choose the information that matters most to you',
    'Calorie focused',
    'Calories consumed, activity, and remaining energy.',
    'Macronutrients focused',
    'Carbs, protein, fat, and remaining calories.',
    'Heart and activity view',
    'Nutrition, activity, and connected health together.',
    'Low carb',
    'Macros, calories, quick logging, and evidence.',
    'Custom',
    'Choose each card below.',
    'Custom cards',
    'AI Coach',
    'Calories',
    'Macros',
    'Activity',
    'Quick log',
    'Discover',
    'Personal intelligence',
    'Daily intelligence',
    'Progress',
    'Connected health',
    'Body Twin',
    'Loading saved view',
    'Saved view could not be loaded.',
    'Saved setting could not be loaded. Tap to retry.',
    'Loading saved cards',
    'Cards could not be loaded. Tap to retry.',
    'Restore default view',
    'Done editing',
    'A private conversation with your health intelligence',
    'Goal, food, exercise, and remaining energy',
    'Protein and fat progress',
    'Steps and exercise status',
    'Food, water, and weight shortcuts',
    'Sleep, recipes, workouts, and community',
    'One Best Action, evidence, and Body Twin',
    'Explanations, confidence, and evidence',
    'Measured trends from your saved records',
    'Health sources and synchronization status',
    'Your explainable body model and its evidence',
    'Add nutrient goal cards',
    'Save cards',
    'Today preferences could not be saved. Please try again.',
    'Calorie goals by meal',
    'Set a separate calorie goal for each meal.',
    'No meal goal',
    'breakfast',
    'lunch',
    'dinner',
    'snack',
    'Clear',
    'Save',
    'Retry',
    'Enter 100 to 10000 kcal.',
    'Could not save changes.',
    'Macros by meal',
    'Show carbs, protein and fat by meal',
    'Grams',
    'Percent',
    'Exercise calorie settings could not be saved.',
  });
  values.addAll(
    await _englishMapKeys(
      'lib/features/analytics/nutrition_analytics_page.dart',
      "  'en': {",
      afterMarker: 'const _copy = <String, Map<String, String>>{',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/app/router/bil_quick_add_locale_copy.dart',
      'const bilQuickAddAuthoredCopy',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/intelligence_center/intelligence_locale_copy.dart',
      'const _authored',
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/nutrition/presentation/nutrition_copy.dart',
      'const _copy',
      indentation: 4,
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
      'const _dailyInputCopy',
    ),
  );
  values.addAll(await _bodyContextPageSources());
  values.addAll(
    await _allEnglishMapValues(
      'lib/features/nutrition/presentation/meals_recipes_foods_page.dart',
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/daily_log/daily_log_meal_entry.dart',
      "  'en': {",
    ),
  );
  values.addAll(
    await _englishListValues(
      'lib/features/daily_log/daily_log_meal_entry.dart',
      "  'en': [",
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/nutrition/presentation/meal_image_guide_page.dart',
      "  'en': {",
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/nutrition/presentation/meal_vision_ui_copy.dart',
      "    'en': MealVisionUiCopy({",
      endMarker: '\n    }),',
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/nutrition/presentation/meal_image_review_dialog.dart',
      "    'en': _VisionReviewCopy({",
      endMarker: '\n    }),',
    ),
  );
  values.addAll(const {'Previous day', 'Today', 'Next day', 'Save log'});
  values.addAll(await _releaseSurfaceEnglishValues());
  return values;
}

Future<Set<String>> _releaseSurfaceEnglishValues() async {
  final values = <String>{};
  final weeklySource = await File(
    'lib/features/analytics/weekly_report_page.dart',
  ).readAsString();
  values.addAll(
    RegExp(r"'en':\s*'((?:\\.|[^'])*)'", multiLine: true)
        .allMatches(weeklySource)
        .map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/settings/reference_settings_copy.dart',
      'static const _copy',
      indentation: 6,
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/dashboard/widgets/dashboard_top_bar.dart',
      "  'en': {",
    ),
  );
  for (final path in const [
    'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    'lib/features/dashboard/widgets/dashboard_reference_phone_components.dart',
  ]) {
    final dashboardPhoneSource = await File(path).readAsString();
    values.addAll(
      RegExp(
            r"_referenceText\(\s*context\s*,\s*'((?:\\.|[^'])*)'\s*,",
            multiLine: true,
          )
          .allMatches(dashboardPhoneSource)
          .map((match) => _unescapeDartSingle(match.group(1)!)),
    );
    values.addAll(
      RegExp(r"\btr\(\s*'((?:\\.|[^'])*)'\s*,", multiLine: true)
          .allMatches(dashboardPhoneSource)
          .map((match) => _unescapeDartSingle(match.group(1)!)),
    );
  }
  values.addAll(
    await _authoredMapKeys(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      'const _referencePhoneCopy',
      indentation: 2,
    ),
  );
  values.addAll(
    await _authoredMapKeys(
      'lib/features/daily_log/daily_log_page.dart',
      'const _dailyLogCopy',
      indentation: 2,
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
      "  'en': {",
    ),
  );
  for (final path in <String>[
    'lib/features/analytics/weekly_report_page.dart',
  ]) {
    final source = await File(path).readAsString();
    values.addAll(
      RegExp(
        r"(?:localized|wellnessCopy)\(\s*'((?:\\.|[^'])*)'\s*,",
        multiLine: true,
      ).allMatches(source).map((match) => _unescapeDartSingle(match.group(1)!)),
    );
  }
  final recipeSource = await File(
    'lib/features/wellness/presentation/recipe_library_page.dart',
  ).readAsString();
  values.addAll(
    RegExp(
          r"wellnessCopy\(\s*context\s*,\s*'((?:\\.|[^'])*)'\s*,",
          multiLine: true,
        )
        .allMatches(recipeSource)
        .map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  values.addAll(const {
    'Choose report week',
    'Previous week',
    'Next week',
    'BIL INSIGHT',
    'Set a goal',
    '{visible} of {total} recipes',
    '{count} min',
    'Original · {language}',
    'Save recipe',
    'Remove saved recipe',
    'Free',
    'Premium',
    'Premium AI Coach',
    'BIL AI Boost',
    'Monthly',
    'Annual',
    'Free trial',
    'Restore purchases',
    'Manage subscription',
    'Loading price from the store…',
    'Price unavailable on this device',
    'The purchase was not completed. No access was granted.',
    'Choose whether BIL may show contextual ads.',
    'Complete profile',
    'Complete your profile to calculate personalized targets.',
    'No body trend data recorded yet.',
    'No nutrition data recorded yet.',
    'No trend data recorded yet.',
  });
  values.addAll(
    await _englishMapValues(
      'lib/features/commerce/presentation/glass_store_offer.dart',
      "  'en': {",
    ),
  );
  values.addAll(
    await _englishMapValues(
      'lib/features/commerce/presentation/bil_store_copy.dart',
      "    'en': {",
    ),
  );
  values.addAll(const {
    'Display options',
    'Exercise sort order',
    'A to Z',
    'Z to A',
    'Create exercise',
    'Exercise name',
    'Category',
    'Could not save exercise. Review and retry.',
    'Delete exercise?',
    'This removes the custom exercise from My Exercises.',
    'Could not delete exercise.',
    'Could not save display options.',
    'Community profile',
    'Display name',
    'Bio',
    'Let people find me',
    'Members can find you and send a friend request.',
    'Save profile',
    'Community profile saved.',
    'Enter at least two characters.',
    'Could not load your community profile safely.',
    'Could not save your profile now. Try again.',
    'Your measurements and health logs stay private.',
    'Could not request account deletion. Try again.',
    'Community updates',
    'Community updates are unavailable',
    'BIL could not check your updates safely. Try again.',
    'Sign in required',
    'Sign in to check private community updates.',
    'No community updates',
    'Friend requests and unread messages will appear here.',
    'Find people',
    'Friend requests',
    'Unread messages',
    'Refresh',
    'Sign in',
  });
  return values;
}

Future<void> _mergeMissingSources(List<String> sources) async {
  final file = File('lib/app/localization/runtime_copy_extended.dart');
  final current = await file.readAsString();
  final existing = RegExp(r'^    ("(?:\\.|[^"])*"): \{$', multiLine: true)
      .allMatches(current)
      .map(
        (match) =>
            jsonDecode(match.group(1)!.replaceAll(r'\$', r'$')) as String,
      )
      .toSet();
  final missing = sources
      .where((source) => !existing.contains(source))
      .toList();
  if (missing.isEmpty) {
    stdout.writeln('Extended runtime copy already contains every source.');
    return;
  }
  stdout.writeln('Translating ${missing.length} missing release-surface keys.');
  final translated = <String, List<String>>{};
  for (final entry in _targets.entries) {
    translated[entry.key] = await _translateCatalog(missing, entry.value);
  }
  final addition = StringBuffer();
  for (var index = 0; index < missing.length; index += 1) {
    addition.writeln('    ${_dartString(missing[index])}: {');
    for (final tag in _targets.keys) {
      addition.writeln(
        '      ${_dartString(tag)}: ${_dartString(translated[tag]![index])},',
      );
    }
    addition.writeln('    },');
  }
  const marker = '  };\n}';
  final insertion = current.lastIndexOf(marker);
  if (insertion < 0) throw StateError('Extended catalog terminator not found');
  await file.writeAsString(
    current.replaceRange(insertion, insertion, addition.toString()),
  );
  stdout.writeln('Merged ${missing.length} keys into ${file.path}.');
}

Future<Set<String>> _bodyContextPageSources() async {
  final source = await File(
    'lib/features/daily_log/daily_body_context_page.dart',
  ).readAsString();
  final marker = "'en': {";
  final start = source.indexOf(marker);
  final end = source.indexOf("\n  },", start);
  if (start < 0 || end < 0) return const <String>{};
  return RegExp(r":\s*'((?:\\.|[^'])*)'")
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _englishMapValues(
  String path,
  String marker, {
  String endMarker = '\n  },',
}) async {
  final source = await File(path).readAsString();
  final start = source.indexOf(marker);
  final end = source.indexOf(endMarker, start);
  if (start < 0 || end < 0) return const <String>{};
  return RegExp(r":\s*'((?:\\.|[^'])*)'", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _englishMapKeys(
  String path,
  String marker, {
  String? afterMarker,
}) async {
  final source = await File(path).readAsString();
  final offset = afterMarker == null ? 0 : source.indexOf(afterMarker);
  final start = source.indexOf(marker, offset < 0 ? 0 : offset);
  final end = source.indexOf('\n  },', start);
  if (start < 0 || end < 0) return const <String>{};
  return RegExp(r"^\s*'((?:\\.|[^'])*)':", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _allEnglishMapValues(String path) async {
  final source = await File(path).readAsString();
  final values = <String>{};
  var offset = 0;
  while (true) {
    final start = source.indexOf("'en': {", offset);
    if (start < 0) break;
    final end = source.indexOf('\n  },', start);
    if (end < 0) break;
    values.addAll(
      RegExp(r":\s*'((?:\\.|[^'])*)'", multiLine: true)
          .allMatches(source.substring(start, end))
          .map((match) => _unescapeDartSingle(match.group(1)!)),
    );
    offset = end + 4;
  }
  return values;
}

Future<Set<String>> _englishListValues(String path, String marker) async {
  final source = await File(path).readAsString();
  final start = source.indexOf(marker);
  final end = source.indexOf('\n  ],', start);
  if (start < 0 || end < 0) return const <String>{};
  return RegExp(r"'((?:\\.|[^'])*)'", multiLine: true)
      .allMatches(source.substring(start + marker.length, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _authoredMapKeys(
  String path,
  String marker, {
  int indentation = 2,
}) async {
  final source = await File(path).readAsString();
  final start = source.indexOf(marker);
  if (start < 0) throw StateError('Missing marker $marker in $path');
  final spaces = ' ' * indentation;
  return RegExp(
        '^$spaces'
        r"'((?:\\.|[^'])*)':",
        multiLine: true,
      )
      .allMatches(source.substring(start))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _progressEnglishValues() async {
  final source = await File(
    'lib/features/history/progress_page.dart',
  ).readAsString();
  const marker = "  'en': {";
  final start = source.indexOf(marker);
  final end = source.indexOf('\n  },', start);
  if (start < 0 || end < 0) {
    throw StateError('Progress English copy block not found');
  }
  return RegExp(r":\s*'((?:\\.|[^'])*)'")
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _fastingEnglishValues() async {
  final source = await File(
    'lib/features/wellness/presentation/fasting_timer_page.dart',
  ).readAsString();
  return RegExp(r"tr\(\s*'((?:\\.|[^'])*)'\s*,", multiLine: true)
      .allMatches(source)
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _notificationSettingsEnglishValues() async {
  final values = <String>{};
  values.addAll(
    await _englishMapValues(
      'lib/features/notifications/presentation/notification_settings_copy.dart',
      "  'en': NotificationSettingsCopy(",
      endMarker: '\n  ),',
    ),
  );
  final source = await File(
    'lib/features/notifications/presentation/notification_settings_page.dart',
  ).readAsString();
  values.addAll(
    RegExp(
      r"_ui\(\s*'((?:\\.|[^'])*)'\s*,",
      multiLine: true,
    ).allMatches(source).map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  return values;
}

Future<Set<String>> _wellnessLearnEnglishValues() async {
  final source = await File(
    'lib/features/wellness/presentation/wellness_learn_page.dart',
  ).readAsString();
  final values = <String>{};
  values.addAll(
    RegExp(
      r"wellnessCopy\(\s*context,\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    ).allMatches(source).map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  values.addAll(
    RegExp(
      r"_learnText\(\s*context,\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    ).allMatches(source).map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  return values;
}

Future<Set<String>> _communityConnectionsEnglishValues() async {
  final source = await File(
    'lib/features/community/presentation/community_connections_page.dart',
  ).readAsString();
  final marker = 'factory _ConnectionsCopy.extended';
  final start = source.indexOf(marker);
  final end = source.indexOf('\n  }', start);
  if (start < 0 || end < 0) {
    throw StateError('Community connections extended copy block not found');
  }
  return RegExp(r"t\(\s*'((?:\\.|[^'])*)'", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _communityMessagesEnglishValues() async {
  final source = await File(
    'lib/features/community/presentation/community_messages_page.dart',
  ).readAsString();
  final marker = "    'en': {";
  final start = source.indexOf(marker);
  final end = source.indexOf('\n    },', start);
  if (start < 0 || end < 0) {
    throw StateError('Community messages English catalog not found');
  }
  return RegExp(r":\s*'((?:\\.|[^'])*)'", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _legalDocumentEnglishValues() async {
  final source = await File(
    'lib/features/settings/legal_document_page.dart',
  ).readAsString();
  final values = <String>{};
  for (final marker in const [
    'const _privacySections =',
    'const _termsSections =',
    'const _healthDisclaimerSections =',
  ]) {
    final start = source.indexOf(marker);
    final end = source.indexOf('\n];', start);
    if (start < 0 || end < 0) {
      throw StateError('Legal English block not found: $marker');
    }
    values.addAll(
      RegExp(r"'((?:\\.|[^'])*)'", multiLine: true)
          .allMatches(source.substring(start, end))
          .map((match) => _unescapeDartSingle(match.group(1)!)),
    );
  }
  const englishMarker = "  'en': _LegalPageCopy(";
  final start = source.indexOf(englishMarker);
  final end = source.indexOf("\n  'ar':", start);
  if (start < 0 || end < 0) {
    throw StateError('Legal English metadata not found');
  }
  values.addAll(
    RegExp(r"'((?:\\.|[^'])*)'", multiLine: true)
        .allMatches(source.substring(start, end))
        .map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  return values;
}

Future<Set<String>> _trustSupportEnglishValues() async {
  final source = await File(
    'lib/features/settings/trust_support_page.dart',
  ).readAsString();
  final marker = 'const _trustSecondary';
  final start = source.indexOf(marker);
  final end = source.indexOf('\n};', start);
  if (start < 0 || end < 0) {
    throw StateError('Trust support catalog not found');
  }
  return RegExp(r"^  '((?:\\.|[^'])*)':", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _helpCenterEnglishValues() async {
  final source = await File(
    'lib/features/settings/help_center_page.dart',
  ).readAsString();
  final values = <String>{};
  values.addAll(
    RegExp(
      r"'en':\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    ).allMatches(source).map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  values.addAll(
    RegExp(
      r"\bt\(\s*'((?:\\.|[^'])*)'\s*,",
      multiLine: true,
    ).allMatches(source).map((match) => _unescapeDartSingle(match.group(1)!)),
  );
  if (values.isEmpty) throw StateError('Help center catalog not found');
  return values;
}

Future<Set<String>> _accountDeletionEnglishValues() async {
  final source = await File(
    'lib/features/settings/account_deletion_page.dart',
  ).readAsString();
  final start = source.indexOf("    'en': {");
  final end = source.indexOf("\n    },\n    'ar': {", start);
  if (start < 0 || end < 0) {
    throw StateError('Account deletion English catalog not found');
  }
  return RegExp(r":\s*'((?:\\.|[^'])*)'", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((match) => _unescapeDartSingle(match.group(1)!))
      .toSet();
}

Future<Set<String>> _advertisingPrivacyEnglishValues() async {
  final source = await File(
    'lib/features/ads/advertising_privacy_page.dart',
  ).readAsString();
  final values = <String>{};

  void addEnglishBlock(
    String containerMarker,
    String englishMarker,
    String arabicMarker,
  ) {
    final container = source.indexOf(containerMarker);
    final start = source.indexOf(englishMarker, container);
    final end = source.indexOf(arabicMarker, start + englishMarker.length);
    if (container < 0 || start < 0 || end < 0) {
      throw StateError('Advertising copy block not found: $containerMarker');
    }
    final matches = RegExp(r"'((?:\\.|[^'])*)'", multiLine: true)
        .allMatches(source.substring(start, end))
        .map((match) => _unescapeDartSingle(match.group(1)!))
        .where((value) => value != 'en');
    values.addAll(matches);
  }

  addEnglishBlock('const _eligibilityCopy', "  'en': (", "\n  'ar':");
  addEnglishBlock('const _adultConfirmationTitle', "  'en':", "\n  'ar':");
  addEnglishBlock('const _adultConfirmationBody', "  'en':", "\n  'ar':");
  addEnglishBlock(
    'const _eligibilityDetailCopy',
    "      'en': (",
    "\n      'ar':",
  );
  addEnglishBlock(
    'const _copy =',
    "  'en': _AdPrivacyCopy(",
    "\n  'ar': _AdPrivacyCopy(",
  );
  return values;
}

String _unescapeDartSingle(String value) => value
    .replaceAll(r"\'", "'")
    .replaceAll(r'\n', '\n')
    .replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    )
    .replaceAll(r'\\', r'\');
