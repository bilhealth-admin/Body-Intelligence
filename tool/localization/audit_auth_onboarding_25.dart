import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';

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
  final sources = <String>{
    ...await _mapKeys(
      'lib/features/auth/auth_five_locale_copy.dart',
      'const _authAuthoredCopy',
    ),
    ...await _mapKeys(
      'lib/features/onboarding/onboarding_locale_copy.dart',
      'const onboardingAuthoredCopy',
    ),
    ...await _mapKeys(
      'lib/features/onboarding/shared/calibration_components.dart',
      'const _bodyCanvasCopy',
    ),
    ...await _mapKeys(
      'lib/features/intelligence_center/intelligence_locale_copy.dart',
      'const _serviceAuthored',
    ),
    ...await _mapKeys(
      'lib/features/intelligence_center/intelligence_locale_copy.dart',
      'const _authored',
    ),
    ...await _mapKeys(
      'lib/features/nutrition/presentation/nutrition_copy.dart',
      'const _copy',
      indentation: 4,
    ),
  };
  final missing = <String>[];
  for (final source in sources) {
    for (final tag in _extendedTags) {
      final value = RuntimeCopy.resolve(source, tag)?.trim();
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
