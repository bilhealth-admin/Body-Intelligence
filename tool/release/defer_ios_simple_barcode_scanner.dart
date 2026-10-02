import 'dart:convert';
import 'dart:io';

const String deferredIosSimpleBarcodeScannerPlugin = 'simple_barcode_scanner';
const String _expectedVersion = '0.6.0';
const String _overrideDirectoryName = 'bil_release_plugin_overrides';
const String _markerName = '.bil-deferred-ios-simple-barcode-scanner.json';

final class DeferredIosSimpleBarcodeScannerResult {
  const DeferredIosSimpleBarcodeScannerResult({
    required this.overrideDirectory,
    required this.alreadyPrepared,
  });

  final Directory overrideDirectory;
  final bool alreadyPrepared;
}

final class _YamlKey {
  const _YamlKey(this.line, this.indent);

  final int line;
  final int indent;
}

List<String> _lines(String source) {
  final lines = source.split(RegExp(r'\r?\n'));
  if (source.endsWith('\n') && lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

bool _isContent(String line) {
  final trimmed = line.trim();
  return trimmed.isNotEmpty && !trimmed.startsWith('#');
}

int _indent(String line) {
  if (line.contains('\t')) {
    throw const FormatException(
      'simple_barcode_scanner pubspec must not use tabs for YAML indentation.',
    );
  }
  return line.length - line.trimLeft().length;
}

bool _isBareKey(String line, String key) =>
    RegExp('^' + RegExp.escape(key) + r':\s*(?:#.*)?$').hasMatch(line.trim());

List<_YamlKey> _directKeys(List<String> lines, String key, {_YamlKey? parent}) {
  final start = parent == null ? 0 : parent.line + 1;
  var end = lines.length;
  if (parent != null) {
    for (var index = start; index < lines.length; index += 1) {
      if (_isContent(lines[index]) && _indent(lines[index]) <= parent.indent) {
        end = index;
        break;
      }
    }
  }

  int? directIndent;
  for (var index = start; index < end; index += 1) {
    if (!_isContent(lines[index])) continue;
    final indent = _indent(lines[index]);
    if (parent == null || indent > parent.indent) {
      directIndent = directIndent == null || indent < directIndent
          ? indent
          : directIndent;
    }
  }
  if (directIndent == null) return const <_YamlKey>[];

  final matches = <_YamlKey>[];
  for (var index = start; index < end; index += 1) {
    if (!_isContent(lines[index]) || _indent(lines[index]) != directIndent) {
      continue;
    }
    if (_isBareKey(lines[index], key)) {
      matches.add(_YamlKey(index, directIndent));
    }
  }
  return matches;
}

_YamlKey _directKey(List<String> lines, String key, {_YamlKey? parent}) {
  final matches = _directKeys(lines, key, parent: parent);
  if (matches.length != 1) {
    throw FormatException(
      'simple_barcode_scanner pubspec must contain exactly one direct ' +
          key +
          ' mapping key.',
    );
  }
  return matches.single;
}

int _mappingEnd(List<String> lines, _YamlKey key) {
  for (var index = key.line + 1; index < lines.length; index += 1) {
    if (_isContent(lines[index]) && _indent(lines[index]) <= key.indent) {
      return index;
    }
  }
  return lines.length;
}

String _mappingText(List<String> lines, _YamlKey key) =>
    lines.sublist(key.line, _mappingEnd(lines, key)).join('\n');

void _removeMapping(List<String> lines, _YamlKey key) {
  lines.removeRange(key.line, _mappingEnd(lines, key));
}

void _verifyPackageIdentity(String source) {
  final nameMatches = RegExp(
    r'^name:[ \t]*simple_barcode_scanner[ \t]*(?:#.*)?$',
    multiLine: true,
  ).allMatches(source);
  final versionMatches = RegExp(
    r'^version:[ \t]*0\.6\.0[ \t]*(?:#.*)?$',
    multiLine: true,
  ).allMatches(source);
  if (nameMatches.length != 1 || versionMatches.length != 1) {
    throw const FormatException(
      'Package override source must be simple_barcode_scanner 0.6.0.',
    );
  }
}

void _verifySupportedPlatforms(List<String> lines) {
  final declaredPlatforms = _directKey(lines, 'platforms');
  for (final platform in const <String>['android', 'web', 'windows']) {
    _directKey(lines, platform, parent: declaredPlatforms);
  }
  if (_directKeys(lines, 'ios', parent: declaredPlatforms).isNotEmpty) {
    throw const FormatException(
      'Deferred simple_barcode_scanner pubspec still declares top-level iOS support.',
    );
  }

  final flutter = _directKey(lines, 'flutter');
  final plugin = _directKey(lines, 'plugin', parent: flutter);
  final pluginPlatforms = _directKey(lines, 'platforms', parent: plugin);
  final android = _directKey(lines, 'android', parent: pluginPlatforms);
  if (!_mappingText(lines, android).contains('FlutterBarcodeScannerPlugin')) {
    throw const FormatException(
      'Deferred simple_barcode_scanner pubspec lost its Android plugin.',
    );
  }
  if (_directKeys(lines, 'ios', parent: pluginPlatforms).isNotEmpty) {
    throw const FormatException(
      'Deferred simple_barcode_scanner pubspec still declares an iOS plugin.',
    );
  }
}

String removeIosPlatformFromSimpleBarcodeScannerPubspec(String source) {
  _verifyPackageIdentity(source);
  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
  final trailingLineEnding = source.endsWith('\n');
  final lines = _lines(source);

  final topPlatforms = _directKey(lines, 'platforms');
  final topIos = _directKey(lines, 'ios', parent: topPlatforms);
  _removeMapping(lines, topIos);

  final flutter = _directKey(lines, 'flutter');
  final plugin = _directKey(lines, 'plugin', parent: flutter);
  final pluginPlatforms = _directKey(lines, 'platforms', parent: plugin);
  final pluginIos = _directKey(lines, 'ios', parent: pluginPlatforms);
  if (!_mappingText(
    lines,
    pluginIos,
  ).contains('SwiftFlutterBarcodeScannerPlugin')) {
    throw const FormatException(
      'Unexpected simple_barcode_scanner iOS plugin declaration.',
    );
  }
  _removeMapping(lines, pluginIos);

  _verifySupportedPlatforms(lines);
  final sanitized =
      lines.join(lineEnding) + (trailingLineEnding ? lineEnding : '');
  if (sanitized.contains('SwiftFlutterBarcodeScannerPlugin')) {
    throw const FormatException(
      'Failed to remove the simple_barcode_scanner iOS plugin class.',
    );
  }
  return sanitized;
}

Map<String, Object?> _readJsonMap(File file, String description) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException(description + ' root must be a JSON object.');
  }
  return decoded;
}

File _packageConfig(Directory projectRoot) => File(
  projectRoot.absolute.path +
      Platform.pathSeparator +
      '.dart_tool' +
      Platform.pathSeparator +
      'package_config.json',
);

Map<String, Object?> _packageEntry(Map<String, Object?> packageConfig) {
  final packages = packageConfig['packages'];
  if (packages is! List<Object?>) {
    throw const FormatException('package_config.json has no packages list.');
  }
  final matches = packages.whereType<Map<String, Object?>>().where(
    (entry) => entry['name'] == deferredIosSimpleBarcodeScannerPlugin,
  );
  if (matches.length != 1) {
    throw const FormatException(
      'package_config.json must contain exactly one simple_barcode_scanner entry.',
    );
  }
  return matches.single;
}

Directory _entryRoot(File packageConfigFile, Map<String, Object?> entry) {
  final rootUri = entry['rootUri'];
  if (rootUri is! String || rootUri.isEmpty) {
    throw const FormatException(
      'simple_barcode_scanner package rootUri is missing.',
    );
  }
  final resolved = packageConfigFile.uri.resolve(rootUri);
  if (resolved.scheme != 'file') {
    throw const FormatException(
      'simple_barcode_scanner package rootUri must be local.',
    );
  }
  return Directory.fromUri(resolved);
}

String _normalized(Directory directory) {
  final path = directory.absolute.path.replaceAll('/', Platform.pathSeparator);
  return Platform.isWindows ? path.toLowerCase() : path;
}

String _canonical(Directory directory) =>
    _normalized(Directory(directory.resolveSymbolicLinksSync()));

bool _sameDirectory(Directory first, Directory second) {
  if (first.existsSync() && second.existsSync()) {
    return _canonical(first) == _canonical(second);
  }
  return _normalized(first) == _normalized(second);
}

bool _isWithin(String child, String parent) =>
    child == parent || child.startsWith(parent + Platform.pathSeparator);

void _assertDirectoryIsNotLink(Directory directory, String description) {
  final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
  if (type == FileSystemEntityType.link) {
    throw StateError(description + ' must not be a symbolic link.');
  }
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw StateError(description + ' must be a directory.');
  }
}

void _assertCopyTreeHasNoLinks(Directory source) {
  for (final entity in source.listSync(followLinks: false)) {
    if (entity is Link) {
      throw StateError(
        'Symlinks are forbidden in the package override source: ' + entity.path,
      );
    }
    if (entity is Directory) {
      _assertCopyTreeHasNoLinks(entity);
    } else if (entity is! File) {
      throw StateError(
        'Special files are forbidden in the package override source: ' +
            entity.path,
      );
    }
  }
}

void _copyDirectory(Directory source, Directory destination) {
  if (destination.existsSync()) {
    throw StateError(
      'Refusing to overwrite an existing package override directory: ' +
          destination.path,
    );
  }
  _assertCopyTreeHasNoLinks(source);
  destination.createSync();
  for (final entity in source.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final targetPath = destination.path + Platform.pathSeparator + name;
    if (entity is File) {
      entity.copySync(targetPath);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(targetPath));
    } else {
      throw StateError('Package source changed while it was being copied.');
    }
  }
}

Directory _validatedOverrideDirectory(
  Directory projectRoot, {
  bool createParent = false,
}) {
  if (!projectRoot.existsSync()) {
    throw StateError('Project root does not exist: ' + projectRoot.path);
  }
  _assertDirectoryIsNotLink(projectRoot, 'Project root');
  final resolvedRoot = _canonical(projectRoot);
  final dartTool = Directory(
    projectRoot.absolute.path + Platform.pathSeparator + '.dart_tool',
  );
  if (!dartTool.existsSync()) {
    throw StateError('.dart_tool is missing. Run flutter pub get first.');
  }
  _assertDirectoryIsNotLink(dartTool, '.dart_tool');
  final resolvedDartTool = _canonical(dartTool);
  if (resolvedDartTool == resolvedRoot ||
      !_isWithin(resolvedDartTool, resolvedRoot)) {
    throw StateError('.dart_tool must resolve beneath the project root.');
  }

  final overrideParent = Directory(
    dartTool.path + Platform.pathSeparator + _overrideDirectoryName,
  );
  _assertDirectoryIsNotLink(overrideParent, 'Package override parent');
  if (!overrideParent.existsSync()) {
    if (!createParent) {
      return Directory(
        overrideParent.path +
            Platform.pathSeparator +
            deferredIosSimpleBarcodeScannerPlugin,
      );
    }
    overrideParent.createSync();
  }
  _assertDirectoryIsNotLink(overrideParent, 'Package override parent');
  final resolvedOverrideParent = _canonical(overrideParent);
  if (resolvedOverrideParent == resolvedDartTool ||
      !_isWithin(resolvedOverrideParent, resolvedDartTool) ||
      !_isWithin(resolvedOverrideParent, resolvedRoot)) {
    throw StateError(
      'Package override parent must resolve beneath .dart_tool and the project.',
    );
  }

  final destination = Directory(
    overrideParent.path +
        Platform.pathSeparator +
        deferredIosSimpleBarcodeScannerPlugin,
  );
  _assertDirectoryIsNotLink(destination, 'Package override destination');
  if (destination.existsSync()) {
    final resolvedDestination = _canonical(destination);
    if (resolvedDestination == resolvedOverrideParent ||
        !_isWithin(resolvedDestination, resolvedOverrideParent)) {
      throw StateError(
        'Package override destination must resolve beneath its parent.',
      );
    }
  }
  return destination;
}

DeferredIosSimpleBarcodeScannerResult
prepareDeferredIosSimpleBarcodeScannerPackage(Directory projectRoot) {
  final packageConfigFile = _packageConfig(projectRoot);
  if (!packageConfigFile.existsSync()) {
    throw StateError(
      '.dart_tool/package_config.json is missing. Run flutter pub get first.',
    );
  }
  final packageConfig = _readJsonMap(packageConfigFile, 'package_config.json');
  final entry = _packageEntry(packageConfig);
  final source = _entryRoot(packageConfigFile, entry);
  if (!source.existsSync()) {
    throw StateError(
      'simple_barcode_scanner package root does not exist: ' + source.path,
    );
  }
  _assertDirectoryIsNotLink(source, 'simple_barcode_scanner package root');

  final destination = _validatedOverrideDirectory(
    projectRoot,
    createParent: true,
  );
  final marker = File(destination.path + Platform.pathSeparator + _markerName);
  if (_sameDirectory(source, destination)) {
    if (!marker.existsSync()) {
      throw StateError(
        'Existing simple_barcode_scanner override is missing its provenance marker.',
      );
    }
    final markerPayload = _readJsonMap(marker, 'deferred override marker');
    if (markerPayload['status'] != 'ios-native-platform-removed' ||
        markerPayload['plugin'] != deferredIosSimpleBarcodeScannerPlugin ||
        markerPayload['version'] != _expectedVersion) {
      throw StateError(
        'Existing simple_barcode_scanner override has invalid provenance.',
      );
    }
    final pubspec = File(
      destination.path + Platform.pathSeparator + 'pubspec.yaml',
    ).readAsStringSync();
    _verifyPackageIdentity(pubspec);
    _verifySupportedPlatforms(_lines(pubspec));
    return DeferredIosSimpleBarcodeScannerResult(
      overrideDirectory: destination,
      alreadyPrepared: true,
    );
  }

  final sourcePubspec = File(
    source.path + Platform.pathSeparator + 'pubspec.yaml',
  );
  if (!sourcePubspec.existsSync()) {
    throw StateError(
      'simple_barcode_scanner pubspec is missing: ' + sourcePubspec.path,
    );
  }
  final sanitizedPubspec = removeIosPlatformFromSimpleBarcodeScannerPubspec(
    sourcePubspec.readAsStringSync(),
  );

  if (destination.existsSync()) {
    throw StateError(
      'Refusing to overwrite a pre-existing simple_barcode_scanner override.',
    );
  }
  final resolvedSource = _canonical(source);
  final resolvedOverrideParent = _canonical(destination.parent);
  final resolvedDestination = _normalized(
    Directory(
      resolvedOverrideParent +
          Platform.pathSeparator +
          deferredIosSimpleBarcodeScannerPlugin,
    ),
  );
  if (_isWithin(resolvedSource, resolvedDestination) ||
      _isWithin(resolvedDestination, resolvedSource)) {
    throw StateError(
      'Source and deferred package destination must not contain each other.',
    );
  }

  _copyDirectory(source, destination);
  File(
    destination.path + Platform.pathSeparator + 'pubspec.yaml',
  ).writeAsStringSync(sanitizedPubspec, flush: true);
  marker.writeAsStringSync(
    jsonEncode(<String, Object?>{
          'status': 'ios-native-platform-removed',
          'plugin': deferredIosSimpleBarcodeScannerPlugin,
          'version': _expectedVersion,
          'source_root_uri': source.uri.toString(),
        }) +
        '\n',
    flush: true,
  );

  entry['rootUri'] =
      _overrideDirectoryName +
      '/' +
      deferredIosSimpleBarcodeScannerPlugin +
      '/';
  packageConfigFile.writeAsStringSync(
    jsonEncode(packageConfig) + '\n',
    flush: true,
  );
  final written = _readJsonMap(packageConfigFile, 'package_config.json');
  final writtenRoot = _entryRoot(packageConfigFile, _packageEntry(written));
  if (!_sameDirectory(writtenRoot, destination)) {
    throw StateError(
      'package_config.json did not resolve simple_barcode_scanner to the override.',
    );
  }

  return DeferredIosSimpleBarcodeScannerResult(
    overrideDirectory: destination,
    alreadyPrepared: false,
  );
}

void verifyDeferredIosSimpleBarcodeScannerDiscovery(Directory projectRoot) {
  final packageConfigFile = _packageConfig(projectRoot);
  final packageConfig = _readJsonMap(packageConfigFile, 'package_config.json');
  final root = _entryRoot(packageConfigFile, _packageEntry(packageConfig));
  final expected = _validatedOverrideDirectory(projectRoot);
  if (!root.existsSync() ||
      !expected.existsSync() ||
      !_sameDirectory(root, expected)) {
    throw StateError(
      'Flutter package discovery is not bound to the deferred simple_barcode_scanner override.',
    );
  }

  final pubspec = File(
    root.path + Platform.pathSeparator + 'pubspec.yaml',
  ).readAsStringSync();
  _verifyPackageIdentity(pubspec);
  _verifySupportedPlatforms(_lines(pubspec));

  final dependencies = _readJsonMap(
    File(
      projectRoot.absolute.path +
          Platform.pathSeparator +
          '.flutter-plugins-dependencies',
    ),
    '.flutter-plugins-dependencies',
  );
  final plugins = dependencies['plugins'];
  if (plugins is! Map<String, Object?>) {
    throw const FormatException('Flutter plugin metadata is malformed.');
  }
  final ios = plugins['ios'];
  final android = plugins['android'];
  if (ios is! List<Object?> || android is! List<Object?>) {
    throw const FormatException(
      'Flutter iOS/Android plugin metadata is malformed.',
    );
  }

  bool containsPlugin(List<Object?> entries) => entries
      .whereType<Map<String, Object?>>()
      .any((entry) => entry['name'] == deferredIosSimpleBarcodeScannerPlugin);
  if (containsPlugin(ios) || !containsPlugin(android)) {
    throw StateError(
      'Deferred metadata must remove simple_barcode_scanner only from iOS.',
    );
  }

  final graph = dependencies['dependencyGraph'];
  if (graph is! List<Object?> ||
      !graph.whereType<Map<String, Object?>>().any(
        (entry) => entry['name'] == deferredIosSimpleBarcodeScannerPlugin,
      )) {
    throw StateError(
      'Deferred metadata must preserve the Dart dependency graph entry.',
    );
  }

  final registrant = File(
    projectRoot.absolute.path +
        Platform.pathSeparator +
        'ios' +
        Platform.pathSeparator +
        'Runner' +
        Platform.pathSeparator +
        'GeneratedPluginRegistrant.m',
  ).readAsStringSync();
  if (registrant.contains('simple_barcode_scanner') ||
      registrant.contains('SwiftFlutterBarcodeScannerPlugin')) {
    throw StateError(
      'iOS GeneratedPluginRegistrant still registers simple_barcode_scanner.',
    );
  }
}
