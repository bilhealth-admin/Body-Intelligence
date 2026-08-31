import 'dart:convert';
import 'dart:io';

final class ReleasePluginSanitizationResult {
  const ReleasePluginSanitizationResult({
    required this.document,
    required this.removedPluginNames,
  });

  final Map<String, Object?> document;
  final Set<String> removedPluginNames;
}

ReleasePluginSanitizationResult sanitizeFlutterPluginDependencies(
  Map<String, Object?> source,
) {
  final document = Map<String, Object?>.from(
    jsonDecode(jsonEncode(source)) as Map<String, Object?>,
  );
  final pluginsValue = document['plugins'];
  final graphValue = document['dependencyGraph'];
  if (pluginsValue is! Map<String, Object?> || graphValue is! List<Object?>) {
    throw const FormatException(
      'Flutter plugin metadata must contain plugins and dependencyGraph.',
    );
  }

  final devOnlyNames = <String>{};
  final productionNames = <String>{};
  for (final platformEntry in pluginsValue.entries) {
    final entries = platformEntry.value;
    if (entries is! List<Object?>) {
      throw FormatException(
        'Flutter plugin list for ${platformEntry.key} is malformed.',
      );
    }
    for (final value in entries) {
      if (value is! Map<String, Object?>) {
        throw FormatException(
          'Flutter plugin entry for ${platformEntry.key} is malformed.',
        );
      }
      final name = value['name'];
      final devDependency = value['dev_dependency'];
      if (name is! String || name.isEmpty || devDependency is! bool) {
        throw FormatException(
          'Flutter plugin entry for ${platformEntry.key} lacks authority fields.',
        );
      }
      (devDependency ? devOnlyNames : productionNames).add(name);
    }
  }

  final conflictingNames = devOnlyNames.intersection(productionNames);
  if (conflictingNames.isNotEmpty) {
    throw FormatException(
      'Plugins cannot be both production and dev-only: '
      '${conflictingNames.toList()..sort()}',
    );
  }

  final sanitizedPlatforms = <String, Object?>{};
  for (final platformEntry in pluginsValue.entries) {
    final entries = platformEntry.value! as List<Object?>;
    sanitizedPlatforms[platformEntry.key] = entries
        .where(
          (value) => (value! as Map<String, Object?>)['dev_dependency'] != true,
        )
        .toList(growable: false);
  }
  document['plugins'] = sanitizedPlatforms;

  final sanitizedGraph = <Object?>[];
  for (final value in graphValue) {
    if (value is! Map<String, Object?>) {
      throw const FormatException(
        'Flutter dependencyGraph entry is malformed.',
      );
    }
    final name = value['name'];
    final dependencies = value['dependencies'];
    if (name is! String || name.isEmpty || dependencies is! List<Object?>) {
      throw const FormatException(
        'Flutter dependencyGraph entry lacks name or dependencies.',
      );
    }
    if (devOnlyNames.contains(name)) continue;
    final dependencyNames = dependencies.whereType<String>().toSet();
    if (dependencyNames.length != dependencies.length) {
      throw FormatException('Plugin $name has a malformed dependency list.');
    }
    final forbiddenDependencies = dependencyNames.intersection(devOnlyNames);
    if (forbiddenDependencies.isNotEmpty) {
      throw FormatException(
        'Production plugin $name depends on dev-only native plugin(s): '
        '${forbiddenDependencies.toList()..sort()}',
      );
    }
    sanitizedGraph.add(value);
  }
  document['dependencyGraph'] = sanitizedGraph;

  return ReleasePluginSanitizationResult(
    document: document,
    removedPluginNames: Set<String>.unmodifiable(devOnlyNames),
  );
}

Set<String> _nativePluginNamesForPlatform(
  Map<String, Object?> source, {
  required String platform,
  required bool devDependency,
}) {
  final plugins = source['plugins'];
  if (plugins is! Map<String, Object?>) {
    throw const FormatException('Flutter plugins metadata is malformed.');
  }
  final entries = plugins[platform];
  if (entries is! List<Object?>) {
    throw FormatException('Flutter plugin list for $platform is malformed.');
  }
  final names = <String>{};
  for (final value in entries) {
    if (value is! Map<String, Object?>) {
      throw FormatException('Flutter plugin entry for $platform is malformed.');
    }
    final name = value['name'];
    final isDev = value['dev_dependency'];
    final nativeBuild = value['native_build'];
    if (name is! String ||
        name.isEmpty ||
        isDev is! bool ||
        nativeBuild is! bool) {
      throw FormatException(
        'Flutter plugin entry for $platform lacks runtime authority fields.',
      );
    }
    if (nativeBuild && isDev == devDependency) names.add(name);
  }
  return names;
}

String _joinGeneratedLines(
  List<String> lines, {
  required String lineEnding,
  required bool trailingLineEnding,
}) => '${lines.join(lineEnding)}${trailingLineEnding ? lineEnding : ''}';

List<String> _generatedLines(String source) {
  final lines = source.split(RegExp(r'\r?\n'));
  if (source.endsWith('\n') && lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

int _braceDelta(String line) =>
    '{'.allMatches(line).length - '}'.allMatches(line).length;

List<String> _androidRegistrantPluginNames(String source) => RegExp(
  r'Error registering plugin ([^,"\r\n]+),',
).allMatches(source).map((match) => match.group(1)!).toList(growable: false);

void _validateAndroidRegistrantRuntime(String source) {
  if (source.trim().isEmpty ||
      !source.contains('package io.flutter.plugins;') ||
      !source.contains('public final class GeneratedPluginRegistrant') ||
      !source.contains('public static void registerWith') ||
      _braceDelta(source) != 0) {
    throw const FormatException(
      'Android GeneratedPluginRegistrant runtime contract is malformed.',
    );
  }
}

String sanitizeAndroidGeneratedPluginRegistrant(
  String source, {
  required Set<String> devOnlyPluginNames,
  required Set<String> productionPluginNames,
}) {
  _validateAndroidRegistrantRuntime(source);
  final beforeNames = _androidRegistrantPluginNames(source);
  if (beforeNames.toSet().length != beforeNames.length) {
    throw const FormatException(
      'Android GeneratedPluginRegistrant contains duplicate registrations.',
    );
  }
  final missingProduction = productionPluginNames.difference(
    beforeNames.toSet(),
  );
  if (missingProduction.isNotEmpty) {
    throw FormatException(
      'Android GeneratedPluginRegistrant is missing production plugins: '
      '${missingProduction.toList()..sort()}',
    );
  }

  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
  final trailingLineEnding = source.endsWith('\n');
  final lines = _generatedLines(source);
  final output = <String>[];
  for (var index = 0; index < lines.length;) {
    if (lines[index].trim() != 'try {') {
      output.add(lines[index]);
      index += 1;
      continue;
    }

    var depth = 0;
    var end = index;
    for (; end < lines.length; end += 1) {
      depth += _braceDelta(lines[end]);
      if (depth == 0) break;
    }
    if (end >= lines.length || depth != 0) {
      throw const FormatException(
        'Android GeneratedPluginRegistrant has an unterminated plugin block.',
      );
    }
    final block = lines.sublist(index, end + 1);
    final marker = RegExp(
      r'Error registering plugin ([^,"\r\n]+),',
    ).firstMatch(block.join('\n'));
    final pluginName = marker?.group(1);
    if (pluginName == null || !devOnlyPluginNames.contains(pluginName)) {
      output.addAll(block);
    }
    index = end + 1;
  }

  final sanitized = _joinGeneratedLines(
    output,
    lineEnding: lineEnding,
    trailingLineEnding: trailingLineEnding,
  );
  _validateAndroidRegistrantRuntime(sanitized);
  final afterNames = _androidRegistrantPluginNames(sanitized);
  final expectedNames = beforeNames
      .where((name) => !devOnlyPluginNames.contains(name))
      .toList(growable: false);
  if (jsonEncode(afterNames) != jsonEncode(expectedNames)) {
    throw const FormatException(
      'Android sanitizer changed a production plugin registration.',
    );
  }
  return sanitized;
}

final class _IosImportBlock {
  const _IosImportBlock({
    required this.start,
    required this.end,
    required this.module,
    required this.pluginClass,
  });

  final int start;
  final int end;
  final String module;
  final String pluginClass;
}

List<_IosImportBlock> _iosImportBlocks(List<String> lines) {
  final blocks = <_IosImportBlock>[];
  final declaration = RegExp(
    r'^#if __has_include\(<([A-Za-z0-9_]+)/([^>]+\.h)>\)$',
  );
  for (var index = 0; index < lines.length; index += 1) {
    final match = declaration.firstMatch(lines[index].trim());
    if (match == null) continue;
    var end = index + 1;
    while (end < lines.length && lines[end].trim() != '#endif') {
      end += 1;
    }
    if (end >= lines.length) {
      throw const FormatException(
        'iOS GeneratedPluginRegistrant has an unterminated import block.',
      );
    }
    final module = match.group(1)!;
    final header = match.group(2)!;
    final blockText = lines.sublist(index, end + 1).join('\n');
    if (!blockText.contains('@import $module;')) {
      throw FormatException(
        'iOS GeneratedPluginRegistrant import block for $module is malformed.',
      );
    }
    final headerName = header.split('/').last;
    blocks.add(
      _IosImportBlock(
        start: index,
        end: end,
        module: module,
        pluginClass: headerName.substring(0, headerName.length - 2),
      ),
    );
    index = end;
  }
  return blocks;
}

List<String> _iosRegistrationClasses(String source) => RegExp(
  r'^\s*\[([A-Za-z_][A-Za-z0-9_]*) registerWithRegistrar:',
  multiLine: true,
).allMatches(source).map((match) => match.group(1)!).toList(growable: false);

void _validateIosRegistrantRuntime(String source) {
  if (source.trim().isEmpty ||
      !source.contains('#import "GeneratedPluginRegistrant.h"') ||
      !source.contains('@implementation GeneratedPluginRegistrant') ||
      !source.contains('+ (void)registerWithRegistry:') ||
      !source.contains('@end')) {
    throw const FormatException(
      'iOS GeneratedPluginRegistrant runtime contract is malformed.',
    );
  }
}

void _validateIosRegistrantHeader(String source) {
  if (source.trim().isEmpty ||
      !source.contains('@interface GeneratedPluginRegistrant') ||
      !source.contains('+ (void)registerWithRegistry:') ||
      !source.contains('@end')) {
    throw const FormatException(
      'iOS GeneratedPluginRegistrant header runtime contract is malformed.',
    );
  }
}

String sanitizeIosGeneratedPluginRegistrant(
  String source, {
  required Set<String> devOnlyPluginNames,
  required Set<String> productionPluginNames,
}) {
  _validateIosRegistrantRuntime(source);
  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
  final trailingLineEnding = source.endsWith('\n');
  final lines = _generatedLines(source);
  final blocks = _iosImportBlocks(lines);
  final beforeModules = blocks.map((block) => block.module).toList();
  if (beforeModules.toSet().length != beforeModules.length) {
    throw const FormatException(
      'iOS GeneratedPluginRegistrant contains duplicate import blocks.',
    );
  }
  final missingProduction = productionPluginNames.difference(
    beforeModules.toSet(),
  );
  if (missingProduction.isNotEmpty) {
    throw FormatException(
      'iOS GeneratedPluginRegistrant is missing production plugins: '
      '${missingProduction.toList()..sort()}',
    );
  }
  final importedClasses = blocks.map((block) => block.pluginClass).toSet();
  final beforeRegistrations = _iosRegistrationClasses(source);
  final unknownRegistrations = beforeRegistrations.toSet().difference(
    importedClasses,
  );
  if (unknownRegistrations.isNotEmpty) {
    throw FormatException(
      'iOS GeneratedPluginRegistrant has registrations without imports: '
      '${unknownRegistrations.toList()..sort()}',
    );
  }

  final devClasses = blocks
      .where((block) => devOnlyPluginNames.contains(block.module))
      .map((block) => block.pluginClass)
      .toSet();
  final blockByStart = <int, _IosImportBlock>{
    for (final block in blocks) block.start: block,
  };
  final registration = RegExp(
    r'^\s*\[([A-Za-z_][A-Za-z0-9_]*) registerWithRegistrar:',
  );
  final output = <String>[];
  for (var index = 0; index < lines.length;) {
    final block = blockByStart[index];
    if (block != null) {
      if (!devOnlyPluginNames.contains(block.module)) {
        output.addAll(lines.sublist(block.start, block.end + 1));
      }
      index = block.end + 1;
      continue;
    }
    final registrationMatch = registration.firstMatch(lines[index]);
    if (registrationMatch == null ||
        !devClasses.contains(registrationMatch.group(1))) {
      output.add(lines[index]);
    }
    index += 1;
  }

  final sanitized = _joinGeneratedLines(
    output,
    lineEnding: lineEnding,
    trailingLineEnding: trailingLineEnding,
  );
  _validateIosRegistrantRuntime(sanitized);
  final afterBlocks = _iosImportBlocks(_generatedLines(sanitized));
  final afterModules = afterBlocks.map((block) => block.module).toList();
  final expectedModules = beforeModules
      .where((module) => !devOnlyPluginNames.contains(module))
      .toList(growable: false);
  final afterRegistrations = _iosRegistrationClasses(sanitized);
  final expectedRegistrations = beforeRegistrations
      .where((pluginClass) => !devClasses.contains(pluginClass))
      .toList(growable: false);
  if (jsonEncode(afterModules) != jsonEncode(expectedModules) ||
      jsonEncode(afterRegistrations) != jsonEncode(expectedRegistrations)) {
    throw const FormatException(
      'iOS sanitizer changed a production plugin registration.',
    );
  }
  return sanitized;
}

ReleasePluginSanitizationResult sanitizeFlutterReleaseProject({
  required Directory projectRoot,
  required String platform,
}) {
  if (platform != 'android' && platform != 'ios') {
    throw ArgumentError.value(platform, 'platform', 'Expected android or ios.');
  }

  final dependenciesFile = File(
    '${projectRoot.path}${Platform.pathSeparator}.flutter-plugins-dependencies',
  );
  if (!dependenciesFile.existsSync()) {
    throw StateError(
      '.flutter-plugins-dependencies is missing. Run flutter pub get first.',
    );
  }
  final decoded = jsonDecode(dependenciesFile.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Flutter plugin metadata root is malformed.');
  }
  final platformDevNames = _nativePluginNamesForPlatform(
    decoded,
    platform: platform,
    devDependency: true,
  );
  final platformProductionNames = _nativePluginNamesForPlatform(
    decoded,
    platform: platform,
    devDependency: false,
  );
  final result = sanitizeFlutterPluginDependencies(decoded);

  File projectFile(String relativePath) => File(
    '${projectRoot.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );

  late final File registrant;
  late final String sanitizedRegistrant;
  if (platform == 'android') {
    registrant = projectFile(
      'android/app/src/main/java/io/flutter/plugins/'
      'GeneratedPluginRegistrant.java',
    );
    if (!registrant.existsSync()) {
      throw StateError(
        'Android GeneratedPluginRegistrant is missing. '
        'Run flutter pub get before sanitizing.',
      );
    }
    sanitizedRegistrant = sanitizeAndroidGeneratedPluginRegistrant(
      registrant.readAsStringSync(),
      devOnlyPluginNames: platformDevNames,
      productionPluginNames: platformProductionNames,
    );
  } else {
    final header = projectFile('ios/Runner/GeneratedPluginRegistrant.h');
    registrant = projectFile('ios/Runner/GeneratedPluginRegistrant.m');
    if (!header.existsSync() || !registrant.existsSync()) {
      throw StateError(
        'iOS GeneratedPluginRegistrant files are missing. '
        'Run flutter pub get before sanitizing.',
      );
    }
    _validateIosRegistrantHeader(header.readAsStringSync());
    sanitizedRegistrant = sanitizeIosGeneratedPluginRegistrant(
      registrant.readAsStringSync(),
      devOnlyPluginNames: platformDevNames,
      productionPluginNames: platformProductionNames,
    );
  }

  // Preserve a loadable production registrant before persisting metadata.
  // If metadata persistence then fails, the runtime entry point still exists.
  registrant.writeAsStringSync(sanitizedRegistrant, flush: true);
  if (!registrant.existsSync() || registrant.lengthSync() == 0) {
    throw StateError('$platform GeneratedPluginRegistrant was not preserved.');
  }
  dependenciesFile.writeAsStringSync(
    '${jsonEncode(result.document)}\n',
    flush: true,
  );
  return result;
}

void main(List<String> arguments) {
  final platformArguments = arguments
      .where((argument) => argument.startsWith('--platform='))
      .toList(growable: false);
  if (platformArguments.length != 1 || arguments.length != 1) {
    final scriptName = Platform.script.pathSegments.isEmpty
        ? 'sanitize_flutter_release_plugins.dart'
        : Platform.script.pathSegments.last;
    stderr.writeln('Usage: dart run $scriptName --platform=android|ios');
    exitCode = 64;
    return;
  }
  final platform = platformArguments.single.substring('--platform='.length);
  try {
    final result = sanitizeFlutterReleaseProject(
      projectRoot: Directory.current,
      platform: platform,
    );
    final removed = result.removedPluginNames.toList()..sort();
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'status': 'sanitized',
        'platform': platform,
        'removed_dev_native_plugins': removed,
      }),
    );
  } on Object catch (error) {
    stderr.writeln('FLUTTER_RELEASE_PLUGIN_SANITIZER_FAILED: $error');
    exitCode = 1;
  }
}
