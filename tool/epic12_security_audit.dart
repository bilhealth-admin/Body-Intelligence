import 'dart:convert';
import 'dart:io';

const excluded = <String>[
  '.git/',
  'build/',
  '.dart_tool/',
  'artifacts/',
  '.bil-package-backups/',
  '.bil-package-evidence/',
];
const textExtensions = <String>{
  '.dart',
  '.ts',
  '.sql',
  '.xml',
  '.plist',
  '.gradle',
  '.properties',
  '.yaml',
  '.yml',
  '.json',
  '.md',
  '.html',
};

void main() {
  final findings = <String>[];
  for (final entity in _walkReadableFiles(Directory.current)) {
    final path = entity.path.replaceAll('\\', '/');
    if (excluded.any(path.contains)) continue;
    if (!textExtensions.any(path.endsWith)) continue;
    final text = utf8.decode(entity.readAsBytesSync(), allowMalformed: true);
    final relative = path.substring(
      Directory.current.path.replaceAll('\\', '/').length + 1,
    );
    if (relative == 'tool/epic12_security_audit.dart') continue;
    if (RegExp(
      r'''(service_role|api[_-]?key|client_secret|password)\s*[:=]\s*(?:"[A-Za-z0-9_-]{20,}"|'[A-Za-z0-9_-]{20,}')''',
      caseSensitive: false,
    ).hasMatch(text)) {
      findings.add('$relative: probable embedded secret');
    }
    if (RegExp(
      r'badCertificateCallback\s*=|CERT_NONE|verify\s*=\s*false',
    ).hasMatch(text)) {
      findings.add('$relative: TLS verification disabled');
    }
    if (RegExp(
      r'(print|debugPrint)\s*\([^\n]*(token|password|health|authorization)',
      caseSensitive: false,
    ).hasMatch(text)) {
      findings.add('$relative: sensitive diagnostic logging');
    }
    if (relative.contains('settings_store') &&
        RegExp(
          r'token|password|session',
          caseSensitive: false,
        ).hasMatch(text)) {
      findings.add('$relative: sensitive value in preferences boundary');
    }
  }
  if (findings.isNotEmpty) {
    stderr.writeln(findings.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('EPIC12_SECRET_TLS_LOG_AUDIT=PASS');
}

Iterable<File> _walkReadableFiles(Directory directory) sync* {
  List<FileSystemEntity> children;
  try {
    children = directory.listSync(followLinks: false);
  } on FileSystemException {
    return;
  }
  for (final entity in children) {
    final path = entity.path.replaceAll('\\', '/');
    if (excluded.any(path.contains)) continue;
    if (entity is File) {
      yield entity;
    } else if (entity is Directory) {
      yield* _walkReadableFiles(entity);
    }
  }
}
