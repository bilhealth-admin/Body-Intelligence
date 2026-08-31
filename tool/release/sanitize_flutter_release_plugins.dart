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

ReleasePluginSanitizationResult sanitizeFlutterReleaseProject({
  required Directory projectRoot,
  required String platform,
}) {
  const registrants = <String, List<String>>{
    'android': <String>[
      'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
    ],
    'ios': <String>[
      'ios/Runner/GeneratedPluginRegistrant.h',
      'ios/Runner/GeneratedPluginRegistrant.m',
    ],
  };
  final generatedPaths = registrants[platform];
  if (generatedPaths == null) {
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
  final result = sanitizeFlutterPluginDependencies(decoded);
  dependenciesFile.writeAsStringSync(
    '${jsonEncode(result.document)}\n',
    flush: true,
  );

  for (final relativePath in generatedPaths) {
    final file = File(
      '${projectRoot.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (file.existsSync()) file.deleteSync();
  }
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
