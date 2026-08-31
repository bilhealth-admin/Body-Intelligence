import 'dart:convert';
import 'dart:io';

const _targets = <String, String>{
  'ar': 'ar',
  'fr': 'fr',
  'es': 'es',
  'tr': 'tr',
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

// This opaque separator is intentionally shared with the established runtime
// copy generator because Google Translate preserves it across all 25 locales.
const _delimiter = 'ZXQPSEGMENT9X7ZXQP';
const _protected = <String, String>{
  'Apple Health': 'ZXQPAPPLEHEALTH9X7ZXQP',
  'Health Connect': 'ZXQPHEALTHCONNECT9X7ZXQP',
  'AI Coach': 'ZXQPAICOACH9X7ZXQP',
  'Body Twin': 'ZXQPBODYTWIN9X7ZXQP',
  'Mifflin–St Jeor': 'ZXQPMIFFLIN9X7ZXQP',
  'BIL': 'ZXQPBIL9X7ZXQP',
};

Future<void> main() async {
  final sources = await _sources();
  stdout.writeln(
    'Translating ${sources.length} onboarding strings into '
    '${_targets.length} non-English locale tags.',
  );
  final translated = <String, List<String>>{};
  final entries = _targets.entries.toList(growable: false);
  for (var start = 0; start < entries.length; start += 4) {
    final batch = entries.skip(start).take(4);
    final results = await Future.wait(
      batch.map(
        (entry) async =>
            MapEntry(entry.key, await _translateCatalog(sources, entry.value)),
      ),
    );
    translated.addEntries(results);
  }

  final output = StringBuffer()
    ..writeln('// GENERATED FILE. Regenerate with:')
    ..writeln(
      '// dart run tool/localization/generate_onboarding_runtime_copy.dart',
    )
    ..writeln(
      '// Non-English values are machine-translated and require human review; '
      'do not describe them as native-reviewed.',
    )
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln("import '../../app/localization/bil_locale_policy.dart';")
    ..writeln("import '../../app/localization/runtime_copy.dart';")
    ..writeln()
    ..writeln('abstract final class OnboardingRuntimeCopy {')
    ..writeln("  static const supportedTags = <String>{'en',");
  for (final tag in _targets.keys) {
    output.writeln('    ${_dartString(tag)},');
  }
  output
    ..writeln('  };')
    ..writeln('  static const values = <String, Map<String, String>>{');
  for (var index = 0; index < sources.length; index += 1) {
    output
      ..writeln('    ${_dartString(sources[index])}: {')
      ..writeln("      'en': ${_dartString(sources[index])},");
    for (final tag in _targets.keys) {
      output.writeln(
        '      ${_dartString(tag)}: '
        '${_dartString(translated[tag]![index])},',
      );
    }
    output.writeln('    },');
  }
  output
    ..writeln('  };')
    ..writeln()
    ..writeln('  static Set<String> get englishKeys => values.keys.toSet();')
    ..writeln()
    ..writeln('  static bool coversTag(String tag) =>')
    ..writeln('      supportedTags.contains(tag) &&')
    ..writeln('      values.values.every((translations) =>')
    ..writeln('          (translations[tag] ?? "").trim().isNotEmpty);')
    ..writeln()
    ..writeln('  static String resolve(String english, Locale locale) {')
    ..writeln('    final tag = BilLocalePolicy.canonicalTag(locale);')
    ..writeln("    if (tag == 'en') return english;")
    ..writeln('    final shared = RuntimeCopy.resolve(english, tag);')
    ..writeln(
      '    if (shared != null && shared.trim().isNotEmpty) return shared;',
    )
    ..writeln('    return values[english]?[tag] ?? english;')
    ..writeln('  }')
    ..writeln('}');

  final file = File('lib/features/onboarding/onboarding_runtime_copy.dart');
  await file.writeAsString(output.toString());
  stdout.writeln('Wrote ${file.path}.');
}

Future<List<String>> _sources() async {
  final page = await File(
    'lib/features/onboarding/onboarding_page.dart',
  ).readAsString();
  final scaffold = await File(
    'lib/features/onboarding/widgets/modern_onboarding_scaffold.dart',
  ).readAsString();
  final values = <String>{};
  for (final match in RegExp(
    r"\bt\(\s*'((?:\\.|[^'])*)'",
    multiLine: true,
  ).allMatches(page)) {
    values.add(_unescape(match.group(1)!));
  }
  for (final match in RegExp(
    r"_copy\(context,\s*'((?:\\.|[^'])*)'",
    multiLine: true,
  ).allMatches(scaffold)) {
    values.add(_unescape(match.group(1)!));
  }
  final ordered = values.toList(growable: false)..sort();
  if (ordered.isEmpty) throw StateError('No onboarding strings found.');
  return ordered;
}

String _unescape(String value) => value
    .replaceAll(r"\'", "'")
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\\', r'\');

Future<List<String>> _translateCatalog(
  List<String> sources,
  String target,
) async {
  final result = <String>[];
  for (final chunk in _chunks(sources)) {
    final protected = chunk.map(_protect).join('\n$_delimiter\n');
    List<String>? parts;
    for (var attempt = 1; attempt <= 3; attempt += 1) {
      final response = await _requestWithRetry(protected, target);
      final candidate = response
          .split(_delimiter)
          .map((value) => value.trim())
          .toList(growable: false);
      if (candidate.length == chunk.length &&
          !candidate.any((value) => value.isEmpty)) {
        parts = candidate;
        break;
      }
      stderr.writeln(
        'Retrying $target segment after ${candidate.length}/'
        '${chunk.length} split mismatch ($attempt/3).',
      );
    }
    if (parts == null) {
      throw StateError('Could not segment translations for $target.');
    }
    result.addAll(parts.map(_restore));
    stdout.writeln('  $target ${result.length}/${sources.length}');
  }
  return result;
}

Iterable<List<String>> _chunks(List<String> sources) sync* {
  var current = <String>[];
  var length = 0;
  for (final source in sources) {
    final addition = source.length + _delimiter.length + 2;
    if (current.isNotEmpty &&
        (current.length >= 18 || length + addition > 3500)) {
      yield current;
      current = <String>[];
      length = 0;
    }
    current.add(source);
    length += addition;
  }
  if (current.isNotEmpty) yield current;
}

Future<String> _requestWithRetry(String text, String target) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 5; attempt += 1) {
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
        const Duration(seconds: 35),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
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
    } on Object catch (error) {
      lastError = error;
      if (attempt < 5) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    } finally {
      client.close(force: true);
    }
  }
  throw StateError('Translation failed for $target: $lastError');
}

String _protect(String source) {
  var value = source;
  for (final entry in _protected.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value;
}

String _restore(String translated) {
  var value = translated;
  for (final entry in _protected.entries) {
    value = value.replaceAll(entry.value, entry.key);
  }
  return value;
}

String _dartString(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
