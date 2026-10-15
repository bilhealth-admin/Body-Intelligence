import 'dart:convert';
import 'dart:io';

part 'deferred_simple_barcode_provenance.dart';

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

bool _isBareKey(String line, String key) => RegExp(
  '^${RegExp.escape(key)}'
  r':\s*(?:#.*)?$',
).hasMatch(line.trim());

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
      'simple_barcode_scanner pubspec must contain exactly one direct $key mapping key.',
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

void _verifySupportedPlatforms(
  List<String> lines, {
  bool androidRemoved = false,
}) {
  final declaredPlatforms = _directKey(lines, 'platforms');
  for (final platform in <String>[
    if (!androidRemoved) 'android',
    'web',
    'windows',
  ]) {
    _directKey(lines, platform, parent: declaredPlatforms);
  }
  if (_directKeys(lines, 'ios', parent: declaredPlatforms).isNotEmpty) {
    throw const FormatException(
      'Deferred simple_barcode_scanner pubspec still declares top-level iOS support.',
    );
  }

  final flutter = _directKey(lines, 'flutter');
  if (androidRemoved) {
    if (_directKeys(lines, 'plugin', parent: flutter).isNotEmpty) {
      throw const FormatException(
        'Dart-only Windows barcode must not declare an empty native plugin.',
      );
    }
    return;
  }
  final plugin = _directKey(lines, 'plugin', parent: flutter);
  final pluginPlatforms = _directKey(lines, 'platforms', parent: plugin);
  final androidKeys = _directKeys(lines, 'android', parent: pluginPlatforms);
  if (androidRemoved ? androidKeys.isNotEmpty : androidKeys.length != 1) {
    throw const FormatException(
      'Unexpected Android barcode plugin declaration.',
    );
  }
  if (!androidRemoved &&
      !_mappingText(
        lines,
        androidKeys.single,
      ).contains('FlutterBarcodeScannerPlugin')) {
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
    throw FormatException('$description root must be a JSON object.');
  }
  return decoded;
}

File _packageConfig(Directory projectRoot) => File(
  '${projectRoot.absolute.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}package_config.json',
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
    throw StateError('$description must not be a symbolic link.');
  }
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw StateError('$description must be a directory.');
  }
}

void _assertCopyTreeHasNoLinks(Directory source) {
  for (final entity in source.listSync(followLinks: false)) {
    if (entity is Link) {
      throw StateError(
        'Symlinks are forbidden in the package override source: ${entity.path}',
      );
    }
    if (entity is Directory) {
      _assertCopyTreeHasNoLinks(entity);
    } else if (entity is! File) {
      throw StateError(
        'Special files are forbidden in the package override source: ${entity.path}',
      );
    }
  }
}

void _copyDirectory(Directory source, Directory destination) {
  if (destination.existsSync()) {
    throw StateError(
      'Refusing to overwrite an existing package override directory: ${destination.path}',
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
    throw StateError('Project root does not exist: ${projectRoot.path}');
  }
  _assertDirectoryIsNotLink(projectRoot, 'Project root');
  final resolvedRoot = _canonical(projectRoot);
  final dartTool = Directory(
    '${projectRoot.absolute.path}${Platform.pathSeparator}.dart_tool',
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

// Mobile BIL uses mobile_scanner; this legacy package remains for Windows.
String removeAndroidPlatformFromDeferredBarcodePubspec(String source) {
  _verifyPackageIdentity(source);
  final lines = _lines(source);
  _verifySupportedPlatforms(lines);
  _removeMapping(
    lines,
    _directKey(lines, 'android', parent: _directKey(lines, 'platforms')),
  );
  final flutter = _directKey(lines, 'flutter');
  final plugin = _directKey(lines, 'plugin', parent: flutter);
  _removeMapping(lines, plugin);
  _verifySupportedPlatforms(lines, androidRemoved: true);
  return '${lines.join(source.contains('\r\n') ? '\r\n' : '\n')}\n';
}

DeferredIosSimpleBarcodeScannerResult
prepareDeferredIosSimpleBarcodeScannerPackage(
  Directory projectRoot, {
  bool removeAndroid = false,
}) {
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
      'simple_barcode_scanner package root does not exist: ${source.path}',
    );
  }
  _assertDirectoryIsNotLink(source, 'simple_barcode_scanner package root');

  final destination = _validatedOverrideDirectory(
    projectRoot,
    createParent: true,
  );
  final marker = File(destination.path + Platform.pathSeparator + _markerName);
  final alreadyBound = _sameDirectory(source, destination);
  if (destination.existsSync()) {
    final markerPayload = _verifyOwnedBarcodeOverride(
      destination,
      expectedSource: alreadyBound ? null : source,
    );
    var pubspec = File(
      '${destination.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();
    _verifyPackageIdentity(pubspec);
    final androidRemoved = markerPayload['android_removed'] == true;
    // Upgrade only our owned early mobile overlay: an empty plugin mapping is
    // invalid for Flutter discovery. The Dart/Windows library remains intact.
    if (androidRemoved) {
      final lines = _lines(pubspec);
      final flutter = _directKey(lines, 'flutter');
      final plugins = _directKeys(lines, 'plugin', parent: flutter);
      if (plugins.length == 1) {
        final platforms = _directKey(
          lines,
          'platforms',
          parent: plugins.single,
        );
        if (_directKeys(lines, 'android', parent: platforms).isNotEmpty ||
            _directKeys(lines, 'ios', parent: platforms).isNotEmpty) {
          throw const FormatException(
            'Owned mobile override unexpectedly contains native declarations.',
          );
        }
        _removeMapping(lines, plugins.single);
        pubspec = '${lines.join('\n')}\n';
        _verifySupportedPlatforms(_lines(pubspec), androidRemoved: true);
        File(
          '${destination.path}${Platform.pathSeparator}pubspec.yaml',
        ).writeAsStringSync(pubspec, flush: true);
      }
    }
    if (removeAndroid && !androidRemoved) {
      File(
        '${destination.path}${Platform.pathSeparator}pubspec.yaml',
      ).writeAsStringSync(
        removeAndroidPlatformFromDeferredBarcodePubspec(pubspec),
        flush: true,
      );
      markerPayload['android_removed'] = true;
      marker.writeAsStringSync('${jsonEncode(markerPayload)}\n', flush: true);
    } else {
      _verifySupportedPlatforms(
        _lines(pubspec),
        androidRemoved: androidRemoved,
      );
    }
    if (!alreadyBound) {
      _bindDeferredBarcodeConfiguration(
        packageConfigFile,
        packageConfig,
        entry,
        destination,
      );
    }
    return DeferredIosSimpleBarcodeScannerResult(
      overrideDirectory: destination,
      alreadyPrepared: true,
    );
  }

  final sourcePubspec = File(
    '${source.path}${Platform.pathSeparator}pubspec.yaml',
  );
  if (!sourcePubspec.existsSync()) {
    throw StateError(
      'simple_barcode_scanner pubspec is missing: ${sourcePubspec.path}',
    );
  }
  var sanitizedPubspec = removeIosPlatformFromSimpleBarcodeScannerPubspec(
    sourcePubspec.readAsStringSync(),
  );

  if (removeAndroid) {
    sanitizedPubspec = removeAndroidPlatformFromDeferredBarcodePubspec(
      sanitizedPubspec,
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
    '${destination.path}${Platform.pathSeparator}pubspec.yaml',
  ).writeAsStringSync(sanitizedPubspec, flush: true);
  marker.writeAsStringSync(
    '${jsonEncode(<String, Object?>{'status': 'ios-native-platform-removed', 'plugin': deferredIosSimpleBarcodeScannerPlugin, 'version': _expectedVersion, 'source_root_uri': Directory(source.resolveSymbolicLinksSync()).uri.toString(), 'android_removed': removeAndroid})}\n',
    flush: true,
  );

  _bindDeferredBarcodeConfiguration(
    packageConfigFile,
    packageConfig,
    entry,
    destination,
  );

  return DeferredIosSimpleBarcodeScannerResult(
    overrideDirectory: destination,
    alreadyPrepared: false,
  );
}

void verifyDeferredIosSimpleBarcodeScannerDiscovery(
  Directory projectRoot, {
  String platform = 'ios',
}) {
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
    '${root.path}${Platform.pathSeparator}pubspec.yaml',
  ).readAsStringSync();
  _verifyPackageIdentity(pubspec);
  final androidRemoved =
      _readJsonMap(
        File('${root.path}${Platform.pathSeparator}$_markerName'),
        'override marker',
      )['android_removed'] ==
      true;
  _verifySupportedPlatforms(_lines(pubspec), androidRemoved: androidRemoved);

  final dependencies = _readJsonMap(
    File(
      '${projectRoot.absolute.path}${Platform.pathSeparator}.flutter-plugins-dependencies',
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
  if (platform == 'ios' ? containsPlugin(ios) : containsPlugin(android)) {
    throw StateError(
      'Deferred metadata must remove the selected mobile barcode plugin.',
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

  if (platform != 'ios') {
    return;
  }
  final registrant = File(
    '${projectRoot.absolute.path}${Platform.pathSeparator}ios${Platform.pathSeparator}Runner${Platform.pathSeparator}GeneratedPluginRegistrant.m',
  ).readAsStringSync();
  if (registrant.contains('simple_barcode_scanner') ||
      registrant.contains('SwiftFlutterBarcodeScannerPlugin')) {
    throw StateError(
      'iOS GeneratedPluginRegistrant still registers simple_barcode_scanner.',
    );
  }
}
