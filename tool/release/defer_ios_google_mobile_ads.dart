import 'dart:convert';
import 'dart:io';

const String deferredIosGoogleMobileAdsPlugin = 'google_mobile_ads';
const String _overrideDirectoryName = 'bil_release_plugin_overrides';
const String _markerName = '.bil-deferred-ios-google-mobile-ads.json';

final class DeferredIosGoogleMobileAdsResult {
  const DeferredIosGoogleMobileAdsResult({
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
      'google_mobile_ads pubspec must not use tabs for YAML indentation.',
    );
  }
  return line.length - line.trimLeft().length;
}

bool _isBareKey(String line, String key) =>
    RegExp('^${RegExp.escape(key)}:\\s*(?:#.*)?\$').hasMatch(line.trim());

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
      'google_mobile_ads pubspec must contain exactly one direct $key mapping key.',
    );
  }
  return matches.single;
}

List<_YamlKey> _platformKeys(List<String> lines, String platform) {
  final flutter = _directKey(lines, 'flutter');
  final plugin = _directKey(lines, 'plugin', parent: flutter);
  final platforms = _directKey(lines, 'platforms', parent: plugin);
  return _directKeys(lines, platform, parent: platforms);
}

_YamlKey _platformKey(List<String> lines, String platform) {
  final matches = _platformKeys(lines, platform);
  if (matches.length != 1) {
    throw FormatException(
      'google_mobile_ads pubspec must contain exactly one direct $platform '
      'mapping key.',
    );
  }
  return matches.single;
}

bool _hasPlatform(List<String> lines, String platform) {
  final matches = _platformKeys(lines, platform);
  if (matches.length > 1) {
    throw FormatException(
      'google_mobile_ads pubspec must contain at most one direct $platform '
      'mapping key.',
    );
  }
  return matches.isNotEmpty;
}

String removeIosPlatformFromGoogleMobileAdsPubspec(String source) {
  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
  final trailingLineEnding = source.endsWith('\n');
  final lines = _lines(source);
  final name = RegExp(
    r'^name:[ \t]*google_mobile_ads[ \t]*(?:#.*)?$',
    multiLine: true,
  ).allMatches(source);
  if (name.length != 1) {
    throw const FormatException(
      'Package override source must be exactly the google_mobile_ads package.',
    );
  }

  _platformKey(lines, 'android');
  final ios = _platformKey(lines, 'ios');
  var end = lines.length;
  for (var index = ios.line + 1; index < lines.length; index += 1) {
    if (_isContent(lines[index]) && _indent(lines[index]) <= ios.indent) {
      end = index;
      break;
    }
  }
  if (end == ios.line + 1) {
    throw const FormatException(
      'google_mobile_ads iOS platform declaration has no configuration body.',
    );
  }
  lines.removeRange(ios.line, end);
  _platformKey(lines, 'android');
  if (!_hasPlatform(lines, 'ios')) {
    return '${lines.join(lineEnding)}${trailingLineEnding ? lineEnding : ''}';
  }
  throw const FormatException(
    'Failed to remove google_mobile_ads iOS platform declaration.',
  );
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
        'Special files are forbidden in the package override source: '
        '${entity.path}',
      );
    }
  }
}

void _copyDirectory(Directory source, Directory destination) {
  if (destination.existsSync()) {
    throw StateError(
      'Refusing to overwrite an existing package override directory: '
      '${destination.path}',
    );
  }
  _assertCopyTreeHasNoLinks(source);
  destination.createSync();
  for (final entity in source.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final targetPath = '${destination.path}${Platform.pathSeparator}$name';
    if (entity is File) {
      entity.copySync(targetPath);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(targetPath));
    } else {
      throw StateError('Package source changed while it was being copied.');
    }
  }
}

Map<String, Object?> _readJsonMap(File file, String description) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$description root must be a JSON object.');
  }
  return decoded;
}

Map<String, Object?> _packageEntry(Map<String, Object?> packageConfig) {
  final packages = packageConfig['packages'];
  if (packages is! List<Object?>) {
    throw const FormatException('package_config.json has no packages list.');
  }
  final matches = packages.whereType<Map<String, Object?>>().where(
    (entry) => entry['name'] == deferredIosGoogleMobileAdsPlugin,
  );
  if (matches.length != 1) {
    throw const FormatException(
      'package_config.json must contain exactly one google_mobile_ads entry.',
    );
  }
  return matches.single;
}

Directory _entryRoot(File packageConfigFile, Map<String, Object?> entry) {
  final rootUri = entry['rootUri'];
  if (rootUri is! String || rootUri.isEmpty) {
    throw const FormatException(
      'google_mobile_ads package rootUri is missing.',
    );
  }
  final resolved = packageConfigFile.uri.resolve(rootUri);
  if (resolved.scheme != 'file') {
    throw const FormatException(
      'google_mobile_ads package rootUri must be local.',
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
    child == parent || child.startsWith('$parent${Platform.pathSeparator}');

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
    '${dartTool.path}${Platform.pathSeparator}$_overrideDirectoryName',
  );
  _assertDirectoryIsNotLink(overrideParent, 'Package override parent');
  if (!overrideParent.existsSync()) {
    if (!createParent) {
      return Directory(
        '${overrideParent.path}${Platform.pathSeparator}'
        '$deferredIosGoogleMobileAdsPlugin',
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
    '${overrideParent.path}${Platform.pathSeparator}'
    '$deferredIosGoogleMobileAdsPlugin',
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

File _packageConfig(Directory projectRoot) => File(
  '${projectRoot.absolute.path}${Platform.pathSeparator}.dart_tool'
  '${Platform.pathSeparator}package_config.json',
);

void assertNoStaleDeferredIosGoogleMobileAdsOverride(Directory projectRoot) {
  final packageConfigFile = _packageConfig(projectRoot);
  if (!packageConfigFile.existsSync()) return;
  final packageConfig = _readJsonMap(packageConfigFile, 'package_config.json');
  final root = _entryRoot(packageConfigFile, _packageEntry(packageConfig));
  final expected = _validatedOverrideDirectory(projectRoot);
  if (_sameDirectory(root, expected)) {
    throw StateError(
      'Stale deferred iOS google_mobile_ads override detected. '
      'Run flutter pub get before an ads-enabled iOS release.',
    );
  }
}

DeferredIosGoogleMobileAdsResult prepareDeferredIosGoogleMobileAdsPackage(
  Directory projectRoot,
) {
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
      'google_mobile_ads package root does not exist: ${source.path}',
    );
  }
  _assertDirectoryIsNotLink(source, 'google_mobile_ads package root');

  final destination = _validatedOverrideDirectory(
    projectRoot,
    createParent: true,
  );
  final marker = File(
    '${destination.path}${Platform.pathSeparator}$_markerName',
  );
  if (_sameDirectory(source, destination)) {
    if (!marker.existsSync()) {
      throw StateError(
        'Existing google_mobile_ads override is missing its provenance marker.',
      );
    }
    final markerPayload = _readJsonMap(marker, 'deferred override marker');
    if (markerPayload['status'] != 'ios-native-platform-removed' ||
        markerPayload['plugin'] != deferredIosGoogleMobileAdsPlugin ||
        markerPayload['source_root_uri'] is! String ||
        (markerPayload['source_root_uri']! as String).trim().isEmpty) {
      throw StateError(
        'Existing google_mobile_ads override has invalid provenance.',
      );
    }
    final pubspec = File(
      '${destination.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();
    _platformKey(_lines(pubspec), 'android');
    if (!_hasPlatform(_lines(pubspec), 'ios')) {
      return DeferredIosGoogleMobileAdsResult(
        overrideDirectory: destination,
        alreadyPrepared: true,
      );
    }
    throw StateError(
      'Existing deferred google_mobile_ads override still declares iOS.',
    );
  }

  final sourcePubspec = File(
    '${source.path}${Platform.pathSeparator}pubspec.yaml',
  );
  if (!sourcePubspec.existsSync()) {
    throw StateError(
      'google_mobile_ads pubspec is missing: ${sourcePubspec.path}',
    );
  }
  final sanitizedPubspec = removeIosPlatformFromGoogleMobileAdsPubspec(
    sourcePubspec.readAsStringSync(),
  );

  if (destination.existsSync()) {
    throw StateError(
      'Refusing to overwrite a pre-existing deferred package directory. '
      'Use a clean build workspace or run flutter pub get to restore state.',
    );
  }
  final resolvedSource = _canonical(source);
  final resolvedOverrideParent = _canonical(destination.parent);
  final resolvedDestination = _normalized(
    Directory(
      '$resolvedOverrideParent${Platform.pathSeparator}'
      '$deferredIosGoogleMobileAdsPlugin',
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
    '${jsonEncode(<String, Object?>{'status': 'ios-native-platform-removed', 'plugin': deferredIosGoogleMobileAdsPlugin, 'source_root_uri': source.uri.toString()})}\n',
    flush: true,
  );

  entry['rootUri'] =
      '$_overrideDirectoryName/$deferredIosGoogleMobileAdsPlugin/';
  packageConfigFile.writeAsStringSync(
    '${jsonEncode(packageConfig)}\n',
    flush: true,
  );
  final written = _readJsonMap(packageConfigFile, 'package_config.json');
  final writtenRoot = _entryRoot(packageConfigFile, _packageEntry(written));
  if (!_sameDirectory(writtenRoot, destination)) {
    throw StateError(
      'package_config.json did not resolve google_mobile_ads to the override.',
    );
  }
  return DeferredIosGoogleMobileAdsResult(
    overrideDirectory: destination,
    alreadyPrepared: false,
  );
}

void verifyDeferredIosGoogleMobileAdsDiscovery(Directory projectRoot) {
  final packageConfigFile = _packageConfig(projectRoot);
  final packageConfig = _readJsonMap(packageConfigFile, 'package_config.json');
  final root = _entryRoot(packageConfigFile, _packageEntry(packageConfig));
  final expected = _validatedOverrideDirectory(projectRoot);
  if (!root.existsSync() ||
      !expected.existsSync() ||
      !_sameDirectory(root, expected)) {
    throw StateError(
      'Flutter package discovery is not bound to the deferred iOS override.',
    );
  }
  final pubspec = File(
    '${root.path}${Platform.pathSeparator}pubspec.yaml',
  ).readAsStringSync();
  _platformKey(_lines(pubspec), 'android');
  if (_hasPlatform(_lines(pubspec), 'ios')) {
    throw StateError('Deferred google_mobile_ads pubspec still declares iOS.');
  }

  final dependencies = _readJsonMap(
    File(
      '${projectRoot.absolute.path}${Platform.pathSeparator}'
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
      .any((entry) => entry['name'] == deferredIosGoogleMobileAdsPlugin);
  if (containsPlugin(ios) || !containsPlugin(android)) {
    throw StateError(
      'Deferred metadata must remove google_mobile_ads only from iOS.',
    );
  }
  final graph = dependencies['dependencyGraph'];
  if (graph is! List<Object?> ||
      !graph.whereType<Map<String, Object?>>().any(
        (entry) => entry['name'] == deferredIosGoogleMobileAdsPlugin,
      )) {
    throw StateError(
      'Deferred metadata must preserve the Dart dependency graph entry.',
    );
  }
  final registrant = File(
    '${projectRoot.absolute.path}${Platform.pathSeparator}ios'
    '${Platform.pathSeparator}Runner${Platform.pathSeparator}'
    'GeneratedPluginRegistrant.m',
  ).readAsStringSync();
  if (registrant.contains('google_mobile_ads') ||
      registrant.contains('FLTGoogleMobileAdsPlugin')) {
    throw StateError(
      'iOS GeneratedPluginRegistrant still registers google_mobile_ads.',
    );
  }
}
