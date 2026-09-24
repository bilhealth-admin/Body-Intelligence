import 'dart:convert';
import 'dart:io';

const targets = <String, String>{
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

const sources = <String>[
  'Send selected personal data to Google Gemini?',
  'If you agree, BIL sends your question and only the context you selected—such as weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns—to Google Gemini, a third-party AI service operated by Google, to generate your requested answer. Raw microphone audio is not sent to BIL or Google Gemini. You can decline and keep using BIL’s local features, and withdraw consent later in AI Coach settings.',
  'AI Coach is optional. With consent, selected personal context is sent to Google Gemini, a third-party AI service operated by Google, only to answer your request. You may decline and keep local features.',
  'BIL sends your questions and only the categories you select—weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns—to Google Gemini, a third-party AI service operated by Google, to generate requested answers. Raw microphone audio is not sent. You can decline and keep using local features, or withdraw later in AI Coach settings.',
  'Allow & Continue',
  "Don't Allow",
  'Google Gemini AI consent',
  'When enabled, your question and selected weight/body, nutrition, activity, sleep, habit, and recent conversation context can be sent to Google Gemini, a third-party AI service operated by Google, only to answer your request. Turn this off at any time; local BIL features remain available.',
  'Send this meal photo to Google Gemini?',
  'If you agree, BIL sends the photo you select, your app language, and necessary technical request metadata to Google Gemini, a third-party AI service operated by Google. It is used to suggest foods and portions for your review. Nothing is logged until you confirm the results.\n\nYou can decline and continue with manual food entry. You can withdraw consent later in Privacy settings.',
  'Could not save photo-analysis consent. The photo was not sent.',
  'Google Gemini meal-photo consent',
  'Only when enabled, a selected photo, app language, and technical request metadata may be sent to Google’s third-party AI service to suggest food. Turn it off to stop new uploads.',
];

const protected = <String, String>{
  'Google Gemini': 'ZXQPGOOGLEGEMINI9X7ZXQP',
  'AI Coach': 'ZXQPAICOACH9X7ZXQP',
  'BIL': 'ZXQPBIL9X7ZXQP',
};

Future<void> main() async {
  final translated = <String, List<String>>{};
  final entries = targets.entries.toList(growable: false);
  for (var start = 0; start < entries.length; start += 4) {
    final results = await Future.wait(
      entries
          .skip(start)
          .take(4)
          .map(
            (entry) async => MapEntry(entry.key, await _translate(entry.value)),
          ),
    );
    translated.addEntries(results);
  }
  // Google occasionally returns an empty first segment for zh-TW. Keep the
  // reviewed title deterministic rather than accepting an empty UI label.
  translated['zh-Hant']![0] = '將選定的個人資料傳送至 Google Gemini？';
  final out = StringBuffer()
    ..writeln('// GENERATED FILE. Regenerate with:')
    ..writeln(
      '// dart run tool/localization/generate_apple_ai_privacy_copy.dart',
    )
    ..writeln('// Machine-translated; do not describe as native-reviewed.')
    ..writeln('abstract final class AppleAiPrivacyRuntimeCopy {')
    ..writeln('  static const supported = <String>{');
  for (final tag in <String>['en', ...targets.keys]) {
    out.writeln("    '${_escape(tag)}',");
  }
  out.writeln('  };');
  out.writeln('  static const values = <String, Map<String, String>>{');
  for (var i = 0; i < sources.length; i++) {
    out.writeln("    '${_escape(sources[i])}': {");
    out.writeln("      'en': '${_escape(sources[i])}',");
    for (final tag in targets.keys) {
      out.writeln("      '$tag': '${_escape(translated[tag]![i])}',");
    }
    out.writeln('    },');
  }
  out
    ..writeln('  };')
    ..writeln('  static String? resolve(String source, String localeTag) {')
    ..writeln("    final normalized = localeTag.replaceAll('_', '-');")
    ..writeln('    final exact = values[source]?[normalized];')
    ..writeln('    if (exact != null) return exact;')
    ..writeln("    final language = normalized.split('-').first.toLowerCase();")
    ..writeln(
      '    for (final entry in values[source]?.entries ?? const <MapEntry<String, String>>[]) {',
    )
    ..writeln(
      "      if (entry.key.split('-').first.toLowerCase() == language) {",
    )
    ..writeln('        return entry.value;')
    ..writeln('      }')
    ..writeln('    }')
    ..writeln('    return null;')
    ..writeln('  }')
    ..writeln('}');
  await File(
    'lib/app/localization/runtime_copy_apple_ai_privacy.dart',
  ).writeAsString(out.toString());
}

Future<List<String>> _translate(String target) async {
  final chunks = <String>[];
  for (final source in sources) {
    final batch = _protect(source);
    final client = HttpClient();
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
            'q': batch,
          },
        ).query,
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        throw StateError('translate HTTP ${response.statusCode}');
      }
      final decoded =
          jsonDecode(await utf8.decoder.bind(response).join()) as List<dynamic>;
      final text = decoded.every((value) => value is String)
          ? decoded.cast<String>().join()
          : (decoded.first as List<dynamic>)
                .map((part) => (part as List<dynamic>).first.toString())
                .join();
      chunks.add(_restore(text));
    } finally {
      client.close(force: true);
    }
  }
  return chunks;
}

String _protect(String value) {
  var result = value;
  for (final entry in protected.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

String _restore(String value) {
  var result = value.trim();
  for (final entry in protected.entries) {
    result = result.replaceAll(entry.value, entry.key);
  }
  return result;
}

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll('\r', '')
    .replaceAll('\n', r'\n');
