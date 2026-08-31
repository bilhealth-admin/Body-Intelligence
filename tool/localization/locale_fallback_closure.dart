import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy_release_closure.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_release_polish.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_release_actions.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_food_actions.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_daily_log_actions.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_fitness_watch.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_connected_health.dart';

const extendedLocaleTags = <String>{
  'de',
  'it',
  'pt-BR',
  'pt-PT',
  'ur',
  'fa',
  'hi',
  'id',
  'ms',
  'ja',
  'ko',
  'zh-Hans',
  'zh-Hant',
  'ru',
  'bn',
  'vi',
  'th',
  'pl',
  'nl',
  'uk',
};

const _androidQualifiers = <String, String>{
  'de': 'values-de',
  'it': 'values-it',
  'pt-BR': 'values-pt-rBR',
  'pt-PT': 'values-pt-rPT',
  'ur': 'values-ur',
  'fa': 'values-fa',
  'hi': 'values-hi',
  'id': 'values-id',
  'ms': 'values-ms',
  'ja': 'values-ja',
  'ko': 'values-ko',
  'zh-Hans': 'values-b+zh+Hans',
  'zh-Hant': 'values-b+zh+Hant',
  'ru': 'values-ru',
  'bn': 'values-bn',
  'vi': 'values-vi',
  'th': 'values-th',
  'pl': 'values-pl',
  'nl': 'values-nl',
  'uk': 'values-uk',
};

final class LocaleFallbackClosureResult {
  const LocaleFallbackClosureResult({
    required this.requiredSourceCount,
    required this.catalogSourceCount,
    required this.missingSources,
    required this.directFallbackFiles,
    required this.androidFailures,
  });

  final int requiredSourceCount;
  final int catalogSourceCount;
  final List<String> missingSources;
  final List<String> directFallbackFiles;
  final List<String> androidFailures;

  bool get passed =>
      missingSources.isEmpty &&
      directFallbackFiles.isEmpty &&
      androidFailures.isEmpty;

  Map<String, Object> toJson() => {
    'required_sources': requiredSourceCount,
    'catalog_sources': catalogSourceCount,
    'missing_sources': missingSources,
    'direct_english_fallback_files': directFallbackFiles,
    'android_failures': androidFailures,
    'passed': passed,
  };
}

Future<LocaleFallbackClosureResult> auditLocaleFallbackClosure() async {
  final catalogSource = (await Future.wait([
    File('lib/app/localization/runtime_copy_extended.dart').readAsString(),
    File('lib/app/localization/runtime_copy_profile.dart').readAsString(),
    File('lib/app/localization/runtime_copy_profile_photo.dart').readAsString(),
    File('lib/app/localization/runtime_copy_legal_status.dart').readAsString(),
    File('lib/app/localization/runtime_copy_check_in.dart').readAsString(),
    File('lib/app/localization/runtime_copy_ai_access.dart').readAsString(),
    File(
      'lib/app/localization/runtime_copy_accessibility_wellness.dart',
    ).readAsString(),
    File('lib/features/auth/auth_five_locale_copy.dart').readAsString(),
  ])).join('\n');
  final catalogKeys = <String>{
    ...RegExp(r'^    ("(?:\\.|[^"])*"): \{$', multiLine: true)
        .allMatches(catalogSource)
        .map(
          (match) =>
              jsonDecode(match.group(1)!.replaceAll(r'\$', r'$')) as String,
        ),
    ...RegExp(r"^    '((?:\\.|[^'])*)': \{$", multiLine: true)
        .allMatches(catalogSource)
        .map((match) => _unescapeDartSingle(match.group(1)!)),
    ...ReleaseClosureRuntimeCopy.sources,
    ...ReleasePolishRuntimeCopy.sources,
    ...ReleaseActionRuntimeCopy.sources,
    ...FoodActionRuntimeCopy.sources,
    ...DailyLogActionRuntimeCopy.sources,
    ...FitnessWatchRuntimeCopy.sources,
    ...ConnectedHealthRuntimeCopy.sources,
  };
  final required = await _requiredRuntimeSources();
  final missing =
      required.where((value) => !catalogKeys.contains(value)).toList()..sort();

  final directFallbackFiles = <String>[];
  for (final path in const [
    'lib/features/analytics/analytics_locale_copy.dart',
    'lib/features/commerce/presentation/commerce_paywall.dart',
    'lib/features/wellness/presentation/professional_content_library_page.dart',
    'lib/features/wellness/presentation/wellness_learn_page.dart',
    'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
  ]) {
    final source = await File(path).readAsString();
    if (RegExp(r'_\s*=>\s*(?:english|en)\s*,').hasMatch(source)) {
      directFallbackFiles.add(path);
    }
  }
  final barcode = await File(
    'lib/features/nutrition/presentation/barcode_runtime_copy.dart',
  ).readAsString();
  if (!barcode.contains('RuntimeCopy.resolve(source, localeTag)')) {
    directFallbackFiles.add(
      'lib/features/nutrition/presentation/barcode_runtime_copy.dart',
    );
  }
  final dashboardIntelligence = await File(
    'lib/features/dashboard/presentation/dashboard_intelligence_localizer.dart',
  ).readAsString();
  if (!dashboardIntelligence.contains(
    'RuntimeCopy.resolve(english, localeTag)',
  )) {
    directFallbackFiles.add(
      'lib/features/dashboard/presentation/dashboard_intelligence_localizer.dart',
    );
  }
  final dailyInput = await File(
    'lib/features/daily_log/presentation/daily_log_input_sections.dart',
  ).readAsString();
  if (!dailyInput.contains("RuntimeCopy.resolve('{count} selected', tag)")) {
    directFallbackFiles.add(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
    );
  }

  final androidFailures = await _auditAndroidResources();
  return LocaleFallbackClosureResult(
    requiredSourceCount: required.length,
    catalogSourceCount: catalogKeys.length,
    missingSources: missing,
    directFallbackFiles: directFallbackFiles,
    androidFailures: androidFailures,
  );
}

Future<Set<String>> _requiredRuntimeSources() async {
  final values = <String>{
    'Recorded today: {value}',
    'Duration: {value}',
    'of {value} hours',
    '{count} recorded nights · {average} h average',
    '{minutes} min • {count} ingredients',
    '{minutes} minutes • guidance quantities',
    '{count} selected',
  };

  void addMatches(String source, RegExp pattern, {int group = 1}) {
    values.addAll(
      pattern
          .allMatches(source)
          .map((match) => _unescapeDartSingle(match.group(group)!)),
    );
  }

  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final file in files) {
    final source = await file.readAsString();
    addMatches(
      source,
      RegExp(
        r"(?:strings\.text|RuntimeCopy\.resolve)\(\s*'((?:\\.|[^'])*)'",
        multiLine: true,
      ),
    );
    addMatches(
      source,
      RegExp(
        r"(?:analyticsText|wellnessCopy|connectedHealthText|communityText|nutritionText|intelligenceText|profileLocaleText|onboardingText|_bodyCanvasText|_trustText|_referenceText|_learnText)\(\s*(?:context|sheetContext)\s*,\s*'((?:\\.|[^'])*)'",
        multiLine: true,
      ),
    );
    addMatches(
      source,
      RegExp(
        r"(?:authFiveLocaleText|dashboardFiveLocaleText|_inputText)\(\s*'((?:\\.|[^'])*)'",
        multiLine: true,
      ),
    );
  }

  // Safety-report confirmation is emitted through the page-local `tr`
  // helper rather than a widget copy helper. Keep it in the release closure
  // explicitly so adding the reporting flow cannot silently expose English.
  values.add('Thanks — this answer was reported for safety review.');

  Future<String> read(String path) => File(path).readAsString();
  for (final entry in const [
    ('lib/features/analytics/analytics_locale_copy.dart', 'const _copy'),
    (
      'lib/features/wellness/presentation/wellness_copy_catalog_a.dart',
      'const _wellnessSecondaryA',
    ),
    (
      'lib/features/wellness/presentation/wellness_copy_catalog_b.dart',
      'const _wellnessSecondaryB',
    ),
  ]) {
    final source = await read(entry.$1);
    final start = source.indexOf(entry.$2);
    addMatches(
      source.substring(start),
      RegExp(r"^  '((?:\\.|[^'])*)':", multiLine: true),
    );
  }
  addMatches(
    await read('lib/features/commerce/presentation/commerce_paywall.dart'),
    RegExp(
      r"_commerceLabel\(.*?\ben:\s*'((?:\\.|[^'])*)'",
      multiLine: true,
      dotAll: true,
    ),
  );
  addMatches(
    await read(
      'lib/features/wellness/presentation/professional_content_library_page.dart',
    ),
    RegExp(
      r"_localized\(\s*context,\s*'(?:\\.|[^'])*',\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    ),
  );
  addMatches(
    await read('lib/features/wellness/presentation/wellness_learn_page.dart'),
    RegExp(r"_learnText\(\s*context,\s*'((?:\\.|[^'])*)'", multiLine: true),
  );
  addMatches(
    await read(
      'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
    ),
    RegExp(r"\bt\(\s*'((?:\\.|[^'])*)'\s*,", multiLine: true),
  );
  final barcode = await read(
    'lib/features/nutrition/presentation/barcode_runtime_copy.dart',
  );
  final barcodeStart = barcode.indexOf("    'en': BarcodeRuntimeCopy(");
  final barcodeEnd = barcode.indexOf('\n    ),', barcodeStart);
  addMatches(
    barcode.substring(barcodeStart, barcodeEnd),
    RegExp(r":\s*'((?:\\.|[^'])*)'", multiLine: true),
  );
  values.addAll(await _dashboardIntelligenceEnglishValues());
  final premiumGate = await read(
    'lib/features/commerce/presentation/premium_route_glass_gate.dart',
  );
  addMatches(
    premiumGate,
    RegExp(r"\bt\(\s*'((?:\\.|[^'])*)'", multiLine: true),
  );
  return values;
}

Future<Set<String>> _dashboardIntelligenceEnglishValues() async {
  final values = <String>{
    'Gender is not recorded',
    'Gender value is unsupported',
    'Age is not recorded',
    'Age value is invalid',
    'Height is not recorded',
    'Height value is invalid',
    'Current weight is not recorded',
    'Current weight is invalid',
    'Neck circumference is not recorded',
    'Neck circumference is invalid',
    'Waist circumference is not recorded',
    'Waist circumference is invalid',
    'Body fat estimate is invalid',
    'Protein below target',
    'Hydration opportunity',
    'Possible plateau',
    'Possible short-term water retention',
    'Build your baseline',
    'Add about {count} g protein',
    'Drink {count} ml gradually',
  };
  for (final path in const [
    'lib/engine/one_best_action_engine.dart',
    'lib/engine/what_changed_engine.dart',
  ]) {
    final source = await File(path).readAsString();
    values.addAll(
      RegExp(r"(?:title|reason|summary):\s*'((?:\\.|[^'])*)'", multiLine: true)
          .allMatches(source)
          .map((match) => _unescapeDartSingle(match.group(1)!))
          .where((value) => !value.contains(r'$')),
    );
  }
  return values;
}

Future<List<String>> _auditAndroidResources() async {
  final failures = <String>[];
  final localeConfig = await File(
    'android/app/src/main/res/xml/locales_config.xml',
  ).readAsString();
  final english = await File(
    'android/app/src/main/res/values/strings.xml',
  ).readAsString();
  for (final tag in extendedLocaleTags) {
    if (!localeConfig.contains('android:name="$tag"')) {
      failures.add('$tag:locale_config');
    }
    final path =
        'android/app/src/main/res/${_androidQualifiers[tag]}/strings.xml';
    final file = File(path);
    if (!file.existsSync()) {
      failures.add('$tag:missing_resource');
      continue;
    }
    final source = await file.readAsString();
    for (final key in const [
      'app_name',
      'health_permissions_rationale_title',
      'health_permissions_rationale_body',
      'health_permissions_privacy_policy_action',
    ]) {
      final localizedValue = _androidStringValue(source, key);
      if (localizedValue == null || localizedValue.trim().isEmpty) {
        failures.add('$tag:$key');
        continue;
      }
      final englishValue = _androidStringValue(english, key);
      if (englishValue != null &&
          localizedValue.trim() == englishValue.trim()) {
        failures.add('$tag:$key:english_fallback');
      }
    }
    if (source == english) failures.add('$tag:english_resource');
    if (source.contains('ZXQP') || source.contains('\uFFFD')) {
      failures.add('$tag:invalid_unicode_or_token');
    }
  }
  return failures;
}

String? _androidStringValue(String xml, String key) => RegExp(
  '<string\\s+name="$key"[^>]*>([\\s\\S]*?)</string>',
).firstMatch(xml)?.group(1);

String _unescapeDartSingle(String value) => value
    .replaceAll(r"\'", "'")
    .replaceAll(r'\n', '\n')
    .replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    )
    .replaceAll(r'\\', r'\');
