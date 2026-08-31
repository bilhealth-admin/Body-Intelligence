import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/sanitize_flutter_release_plugins.dart';

void main() {
  test('removes every dev-only native plugin and keeps production plugins', () {
    final result = sanitizeFlutterPluginDependencies(
      _document(
        android: <Map<String, Object?>>[
          _plugin('production_plugin', dev: false),
          _plugin('integration_test', dev: true),
        ],
        ios: <Map<String, Object?>>[
          _plugin('production_plugin', dev: false),
          _plugin('integration_test', dev: true),
        ],
        graph: <Map<String, Object?>>[
          _graph('production_plugin'),
          _graph('integration_test'),
        ],
      ),
    );

    expect(result.removedPluginNames, <String>{'integration_test'});
    final plugins = result.document['plugins']! as Map<String, Object?>;
    for (final platform in <String>['android', 'ios']) {
      final entries = plugins[platform]! as List<Object?>;
      expect(entries, hasLength(1));
      expect(
        (entries.single! as Map<String, Object?>)['name'],
        'production_plugin',
      );
    }
    final graph = result.document['dependencyGraph']! as List<Object?>;
    expect(graph, hasLength(1));
    expect(
      (graph.single! as Map<String, Object?>)['name'],
      'production_plugin',
    );
  });

  test('sanitizer is idempotent', () {
    final first = sanitizeFlutterPluginDependencies(
      _document(
        android: <Map<String, Object?>>[
          _plugin('production_plugin', dev: false),
          _plugin('integration_test', dev: true),
        ],
        ios: const <Map<String, Object?>>[],
        graph: <Map<String, Object?>>[
          _graph('production_plugin'),
          _graph('integration_test'),
        ],
      ),
    );
    final second = sanitizeFlutterPluginDependencies(first.document);

    expect(second.removedPluginNames, isEmpty);
    expect(jsonEncode(second.document), jsonEncode(first.document));
  });

  test('fails closed when production transitively requires a dev plugin', () {
    expect(
      () => sanitizeFlutterPluginDependencies(
        _document(
          android: <Map<String, Object?>>[
            _plugin('production_plugin', dev: false),
            _plugin('integration_test', dev: true),
          ],
          ios: const <Map<String, Object?>>[],
          graph: <Map<String, Object?>>[
            _graph(
              'production_plugin',
              dependencies: <String>['integration_test'],
            ),
            _graph('integration_test'),
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test('project sanitizer deletes only the selected generated registrant', () {
    final root = Directory.systemTemp.createTempSync('bil-plugin-sanitizer-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/.flutter-plugins-dependencies')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode(
          _document(
            android: <Map<String, Object?>>[
              _plugin('integration_test', dev: true),
            ],
            ios: <Map<String, Object?>>[_plugin('integration_test', dev: true)],
            graph: <Map<String, Object?>>[_graph('integration_test')],
          ),
        ),
      );
    final androidRegistrant = File(
      '${root.path}/android/app/src/main/java/io/flutter/plugins/'
      'GeneratedPluginRegistrant.java',
    )..createSync(recursive: true);
    final iosRegistrant = File(
      '${root.path}/ios/Runner/GeneratedPluginRegistrant.m',
    )..createSync(recursive: true);

    sanitizeFlutterReleaseProject(projectRoot: root, platform: 'android');

    expect(androidRegistrant.existsSync(), isFalse);
    expect(iosRegistrant.existsSync(), isTrue);
    final persisted = File(
      '${root.path}/.flutter-plugins-dependencies',
    ).readAsStringSync();
    expect(persisted, isNot(contains('integration_test')));
  });

  test('signed workflows sanitize after tests and before release build', () {
    final android = File(
      '.github/workflows/bil_android_release_candidate.yml',
    ).readAsStringSync();
    final ios = File(
      '.github/workflows/bil_ios_signed_release.yml',
    ).readAsStringSync();
    _expectWorkflowOrder(
      android,
      platform: 'android',
      build: 'flutter build appbundle',
    );
    _expectWorkflowOrder(ios, platform: 'ios', build: 'flutter build ipa');
  });
}

void _expectWorkflowOrder(
  String workflow, {
  required String platform,
  required String build,
}) {
  final tests = workflow.lastIndexOf('flutter test');
  final sanitizer = workflow.indexOf(
    'dart run tool/release/sanitize_flutter_release_plugins.dart '
    '--platform=$platform',
  );
  final releaseBuild = workflow.indexOf(build);
  expect(tests, greaterThanOrEqualTo(0));
  expect(sanitizer, greaterThan(tests));
  expect(sanitizer, lessThan(releaseBuild));
}

Map<String, Object?> _document({
  required List<Map<String, Object?>> android,
  required List<Map<String, Object?>> ios,
  required List<Map<String, Object?>> graph,
}) => <String, Object?>{
  'info': <String, Object?>{'version': 'test'},
  'plugins': <String, Object?>{'android': android, 'ios': ios},
  'dependencyGraph': graph,
};

Map<String, Object?> _plugin(String name, {required bool dev}) =>
    <String, Object?>{
      'name': name,
      'path': '/generated/$name',
      'native_build': true,
      'dependencies': const <String>[],
      'dev_dependency': dev,
    };

Map<String, Object?> _graph(
  String name, {
  List<String> dependencies = const <String>[],
}) => <String, Object?>{'name': name, 'dependencies': dependencies};
