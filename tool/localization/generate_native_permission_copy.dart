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
const _healthConnect = 'ZXQPHEALTHCONNECTBRAND9X7ZXQP';

Future<void> main(List<String> args) async {
  if (args.contains('--check-android-app-name')) {
    _checkAndroidAppNames();
    return;
  }
  if (args.contains('--android-only')) {
    await _generateAndroidResources();
    return;
  }
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
  await _generateAndroidResources();
}

Future<void> _generateAndroidResources() async {
  const rows = <String, String>{
    'app_name': 'Body Intelligence Log',
    'health_permissions_rationale_title': 'Health data privacy',
    'health_permissions_rationale_body':
        'BIL requests only the Health Connect data types needed for features you choose to use. Your health data is processed locally by default. You can grant, deny, or revoke individual permissions at any time from Health Connect settings. BIL does not sell health data or use it for advertising.',
  };
  for (final target in _targets.entries) {
    final protected = rows.values
        .map(
          (value) => value
              .replaceAll('Health Connect', _healthConnect)
              .replaceAll('BIL', _brand),
        )
        .join('\n$_delimiter\n');
    final translated = await _translate(protected, target.value);
    var values = translated
        .split(_delimiter)
        .map((value) => _restoreAndroidBrands(value.trim()))
        .toList(growable: false);
    if (values.length != rows.length || values.any((value) => value.isEmpty)) {
      values = <String>[];
      for (final source in rows.values) {
        final translatedSource = await _translate(
          source
              .replaceAll('Health Connect', _healthConnect)
              .replaceAll('BIL', _brand),
          target.value,
        );
        values.add(_restoreAndroidBrands(translatedSource.trim()));
      }
    }
    if (values.any((value) => value.contains('ZXQP'))) {
      throw StateError('Android brand token survived for ${target.key}');
    }
    final output = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<resources>');
    for (var index = 0; index < rows.length; index++) {
      final key = rows.keys.elementAt(index);
      final value = key == 'app_name'
          ? _withoutAndroidAppNameBrandPrefix(values[index])
          : values[index];
      output.writeln('    <string name="$key">${_escapeXml(value)}</string>');
    }
    output.writeln('</resources>');
    final directory = Directory(
      'android/app/src/main/res/${_androidQualifier(target.key)}',
    )..createSync(recursive: true);
    File('${directory.path}/strings.xml').writeAsStringSync(output.toString());
    stdout.writeln('WROTE Android ${target.key} (${rows.length})');
  }
}

void _checkAndroidAppNames() {
  final files = Directory('android/app/src/main/res')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('strings.xml'))
      .toList(growable: false);
  final appNamePattern = RegExp(r'<string name="app_name">([^<]+)</string>');
  final forbiddenPrefix = RegExp(r'^\s*BIL\s*(?:-|–|—)\s*');
  var checked = 0;
  for (final file in files) {
    final match = appNamePattern.firstMatch(file.readAsStringSync());
    if (match == null) continue;
    checked++;
    final value = match.group(1)!.trim();
    if (value.isEmpty || forbiddenPrefix.hasMatch(value)) {
      throw StateError('Invalid Android app_name in ${file.path}: $value');
    }
  }
  if (checked != 25) {
    throw StateError('Expected 25 Android app_name resources; found $checked.');
  }
  stdout.writeln('ANDROID_APP_NAME_PREFIX_CHECK=PASS;COUNT=$checked');
}

String _withoutAndroidAppNameBrandPrefix(String value) {
  final result = value
      .replaceFirst(RegExp(r'^\s*BIL\s*(?:-|–|—)\s*'), '')
      .trim();
  if (result.isEmpty) {
    throw StateError('Translated Android app_name became empty.');
  }
  return result;
}

String _androidQualifier(String locale) => switch (locale) {
  'pt-BR' => 'values-pt-rBR',
  'pt-PT' => 'values-pt-rPT',
  'zh-Hans' => 'values-b+zh+Hans',
  'zh-Hant' => 'values-b+zh+Hant',
  _ => 'values-$locale',
};

String _restoreAndroidBrands(String value) => value
    .replaceAll(_healthConnect, 'Health Connect')
    .replaceAllMapped(
      RegExp(r'ZXQP[^\s<>]*HEALTHCONNECTBRAND9X7ZXQP'),
      (_) => 'Health Connect',
    )
    .replaceAll(_brand, 'BIL')
    .replaceAllMapped(RegExp(r'ZXQP[^\s<>]*BILBRAND9X7ZXQP'), (_) => 'BIL');

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", r"\'");

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
