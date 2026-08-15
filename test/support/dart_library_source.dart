import 'dart:io';

/// Reads a Dart library together with every local `part` file it declares.
///
/// Source-contract tests use this helper so architecture-only file splits do
/// not make them mistake a moved implementation for a removed contract.
String readDartLibrarySource(String libraryPath) {
  final visited = <String>{};

  String readFile(File file) {
    final absolute = file.absolute;
    if (!visited.add(absolute.path)) {
      return '';
    }

    final source = absolute.readAsStringSync();
    final parts = RegExp(
      r'''^\s*part\s+['"]([^'"]+)['"]\s*;''',
      multiLine: true,
    ).allMatches(source);

    return <String>[
      source,
      for (final match in parts)
        readFile(File.fromUri(absolute.uri.resolve(match.group(1)!))),
    ].join('\n');
  }

  return readFile(File(libraryPath));
}
