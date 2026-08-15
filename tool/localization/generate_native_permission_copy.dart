import 'dart:convert';
import 'dart:io';

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

const _delimiter = 'ZXQPNATIVEPERMISSION9X7ZXQP';
const _brand = 'ZXQPBILBRAND9X7ZXQP';

Future<void> main() async {
  final source = File('ios/Runner/en.lproj/InfoPlist.strings');
  final rows = _parse(source.readAsStringSync());
  if (rows.length != 8) {
    throw StateError('Expected exactly 8 English native permission strings.');
  }
  for (final target in _targets.entries) {
    final protected = rows.values
        .map((value) => value.replaceAll('BIL', _brand))
        .join('\n$_delimiter\n');
    List<String>? values;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final translated = await _translate(protected, target.value);
      final candidate = translated
          .split(_delimiter)
          .map((value) => value.trim().replaceAll(_brand, 'BIL'))
          .toList(growable: false);
      if (candidate.length == rows.length &&
          !candidate.any((value) => value.isEmpty)) {
        values = candidate;
        break;
      }
    }
    if (values == null) {
      values = <String>[];
      for (final sourceValue in rows.values) {
        values.add(
          (await _translate(
            sourceValue.replaceAll('BIL', _brand),
            target.value,
          )).trim().replaceAll(_brand, 'BIL'),
        );
      }
    }
    final output = StringBuffer();
    for (var index = 0; index < rows.length; index++) {
      final key = rows.keys.elementAt(index);
      final value = _polish(values[index], target.key);
      if (rows[key]!.contains('BIL') && !value.contains('BIL')) {
        throw StateError('BIL brand was lost for ${target.key}:$key');
      }
      output.writeln('"${_escape(key)}" = "${_escape(value)}";');
    }
    final file = File('ios/Runner/${target.key}.lproj/InfoPlist.strings');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(output.toString());
    stdout.writeln('WROTE ${target.key} (${rows.length})');
  }
}

String _polish(String value, String locale) => switch (locale) {
  'zh-Hans' => value.replaceAll('健康时间表', '健康时间线'),
  'zh-Hant' => value.replaceAll('健康時間表', '健康時間線'),
  _ => value,
};

Map<String, String> _parse(String source) {
  final result = <String, String>{};
  final pattern = RegExp(
    r'^"([^"]+)"\s*=\s*"((?:\\.|[^"])*)";$',
    multiLine: true,
  );
  for (final match in pattern.allMatches(source)) {
    final key = match.group(1)!;
    if (result.containsKey(key)) throw StateError('Duplicate key: $key');
    result[key] = match
        .group(2)!
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');
  }
  return result;
}

Future<String> _translate(String text, String target) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 4; attempt++) {
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
      return (decoded.first as List<dynamic>)
          .map((row) => (row as List<dynamic>).first.toString())
          .join();
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
    } finally {
      client.close(force: true);
    }
  }
  throw StateError('Translation failed for $target: $lastError');
}

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n');
