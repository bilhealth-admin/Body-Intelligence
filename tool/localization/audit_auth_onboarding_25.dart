import 'dart:convert';
import 'dart:io';

const _extendedTags = <String>{
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

Future<void> main() async {
  final onboardingSources = await _onboardingSources();
  final sources = <String>{
    ...await _mapKeys(
      'lib/features/auth/auth_five_locale_copy.dart',
      'const _authAuthoredCopy',
    ),
    ...onboardingSources,
    ...await _mapKeys(
      'lib/features/intelligence_center/intelligence_service_locale_copy.dart',
      'const _serviceAuthored',
    ),
    ...await _mapKeys(
      'lib/features/intelligence_center/intelligence_ui_locale_copy.dart',
      'const _authored',
    ),
    ...await _mapKeys(
      'lib/features/nutrition/presentation/nutrition_copy.dart',
      'const _copy',
      indentation: 4,
    ),
  };
  final sharedValues = await _generatedRuntimeValues(
    'lib/app/localization/runtime_copy_extended.dart',
  );
  final onboardingValues = await _generatedRuntimeValues(
    'lib/features/onboarding/onboarding_runtime_copy.dart',
  );
  final missing = <String>[];
  for (final source in sources) {
    final values = onboardingSources.contains(source)
        ? onboardingValues[source]
        : sharedValues[source];
    for (final tag in _extendedTags) {
      final value = values?[tag]?.trim();
      if (value == null || value.isEmpty) missing.add('$tag:$source');
    }
  }
  stdout.writeln('AUTH_ONBOARDING_KEYS=${sources.length}');
  stdout.writeln('CHECKS=${sources.length * _extendedTags.length}');
  stdout.writeln('MISSING=${missing.length}');
  for (final item in missing.take(100)) {
    stdout.writeln(item);
  }
  if (missing.isNotEmpty) exitCode = 1;
}

/// Uses the same live source boundary as
/// `generate_onboarding_runtime_copy.dart`, instead of the two authored maps
/// removed by the generated onboarding runtime-copy migration.
Future<Set<String>> _onboardingSources() async {
  final page = await File(
    'lib/features/onboarding/onboarding_page.dart',
  ).readAsString();
  final scaffold = await File(
    'lib/features/onboarding/widgets/modern_onboarding_scaffold.dart',
  ).readAsString();
  final values = <String>{};
  values.addAll(
    RegExp(
      r"\bt\(\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    ).allMatches(page).map((match) => _unescape(match.group(1)!)),
  );
  values.addAll(
    RegExp(
      r"_copy\(context,\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    ).allMatches(scaffold).map((match) => _unescape(match.group(1)!)),
  );
  if (values.isEmpty) {
    throw StateError('No onboarding runtime-copy sources found.');
  }
  return values;
}

Future<Set<String>> _mapKeys(
  String path,
  String marker, {
  int indentation = 2,
}) async {
  final source = await File(path).readAsString();
  final start = source.indexOf(marker);
  if (start < 0) throw StateError('Missing marker $marker in $path');
  final block = source.substring(start);
  final spaces = ' ' * indentation;
  return RegExp(
    '^$spaces'
    r"'((?:\\.|[^'])*)':",
    multiLine: true,
  ).allMatches(block).map((match) => _unescape(match.group(1)!)).toSet();
}

String _unescape(String value) => value
    .replaceAll(r"\'", "'")
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\\', r'\');

/// Parses the deterministic generated catalog format without importing the
/// Flutter application. This keeps the audit runnable as `dart tool/...` and
/// prevents unrelated native build hooks from participating in a text audit.
Future<Map<String, Map<String, String>>> _generatedRuntimeValues(
  String path,
) async {
  final source = await File(path).readAsString();
  final entryPattern = RegExp(r'^    ("(?:\\.|[^"])*"):\s*\{', multiLine: true);
  final entries = entryPattern.allMatches(source).toList(growable: false);
  final values = <String, Map<String, String>>{};
  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    final key = _decodeGeneratedDartString(entry.group(1)!);
    final end = index + 1 < entries.length
        ? entries[index + 1].start
        : source.indexOf('\n  };', entry.end);
    if (end < 0) throw StateError('Unclosed generated catalog in $path');
    final block = source.substring(entry.end, end);
    final translations = <String, String>{};
    for (final tag in _extendedTags) {
      final tagLiteral = RegExp.escape(jsonEncode(tag));
      final translation = RegExp(
        '^      $tagLiteral:\\s*("(?:\\\\.|[^"])*")',
        multiLine: true,
      ).firstMatch(block);
      if (translation != null) {
        translations[tag] = _decodeGeneratedDartString(translation.group(1)!);
      }
    }
    values[key] = translations;
  }
  if (values.isEmpty) throw StateError('No generated entries found in $path');
  return values;
}

String _decodeGeneratedDartString(String literal) =>
    jsonDecode(literal.replaceAll(r'\$', r'$')) as String;
