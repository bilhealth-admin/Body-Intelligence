import 'dart:io';

const _allowedDirectText = <String>{
  'BIL',
  'English',
  'Français',
  'Español',
  'Türkçe',
  'العربية',
  '1.0.0+1',
  '12:12',
  '14:10',
  '16:8',
};

void main() {
  final violations = <String>[];
  final dartFiles = Directory('lib')
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  final directText = RegExp(
    r'''\bText\(\s*(?:const\s+)?(['"])([^'"\$]{2,})\1''',
  );

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final match = directText.firstMatch(lines[index]);
      if (match == null) continue;
      final value = match.group(2)!.trim();
      if (!_allowedDirectText.contains(value)) {
        violations.add('${file.path}:${index + 1}:$value');
      }
    }
  }

  final requiredNativeLocales = <String>{'ar', 'en', 'fr', 'es', 'tr'};
  for (final locale in requiredNativeLocales) {
    final ios = File('ios/Runner/$locale.lproj/InfoPlist.strings');
    if (!ios.existsSync()) violations.add('missing:${ios.path}');
    final androidDirectory = locale == 'en'
        ? Directory('android/app/src/main/res/values')
        : Directory('android/app/src/main/res/values-$locale');
    final android = File('${androidDirectory.path}/strings.xml');
    if (!android.existsSync()) violations.add('missing:${android.path}');
  }

  if (violations.isNotEmpty) {
    stderr.writeln('EPIC11_LOCALIZATION_AUDIT=FAIL');
    for (final violation in violations) {
      stderr.writeln(violation);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('EPIC11_LOCALIZATION_AUDIT=PASS');
  stdout.writeln('DIRECT_TEXT_ALLOWLIST=${_allowedDirectText.length}');
  stdout.writeln('NATIVE_LOCALES=${requiredNativeLocales.length}');
}
