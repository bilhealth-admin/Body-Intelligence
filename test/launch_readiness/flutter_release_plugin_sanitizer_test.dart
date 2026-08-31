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

  test(
    'Android sanitizer preserves runtime registrant and production plugins',
    () {
      final root = Directory.systemTemp.createTempSync('bil-plugin-sanitizer-');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/.flutter-plugins-dependencies')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode(
            _document(
              android: <Map<String, Object?>>[
                _plugin('production_plugin', dev: false),
                _plugin('dart_only_plugin', dev: false, native: false),
                _plugin('integration_test', dev: true),
              ],
              ios: <Map<String, Object?>>[
                _plugin('production_plugin', dev: false),
                _plugin('integration_test', dev: true),
              ],
              graph: <Map<String, Object?>>[
                _graph('production_plugin'),
                _graph('dart_only_plugin'),
                _graph('integration_test'),
              ],
            ),
          ),
        );
      final androidRegistrant =
          File(
              '${root.path}/android/app/src/main/java/io/flutter/plugins/'
              'GeneratedPluginRegistrant.java',
            )
            ..createSync(recursive: true)
            ..writeAsStringSync(_androidRegistrant);
      final iosHeader =
          File('${root.path}/ios/Runner/GeneratedPluginRegistrant.h')
            ..createSync(recursive: true)
            ..writeAsStringSync(_iosRegistrantHeader);
      final iosRegistrant =
          File('${root.path}/ios/Runner/GeneratedPluginRegistrant.m')
            ..createSync(recursive: true)
            ..writeAsStringSync(_iosRegistrant);

      sanitizeFlutterReleaseProject(projectRoot: root, platform: 'android');

      expect(androidRegistrant.existsSync(), isTrue);
      expect(androidRegistrant.lengthSync(), greaterThan(0));
      expect(
        androidRegistrant.readAsStringSync(),
        allOf(
          contains('public final class GeneratedPluginRegistrant'),
          contains('plugin production_plugin,'),
          isNot(contains('plugin integration_test,')),
        ),
      );
      expect(iosHeader.existsSync(), isTrue);
      expect(iosRegistrant.existsSync(), isTrue);
      expect(iosRegistrant.readAsStringSync(), contains('integration_test'));
      final persisted = File(
        '${root.path}/.flutter-plugins-dependencies',
      ).readAsStringSync();
      expect(persisted, isNot(contains('integration_test')));
      expect(persisted, contains('dart_only_plugin'));

      final firstProductionRegistrant = androidRegistrant.readAsStringSync();
      sanitizeFlutterReleaseProject(projectRoot: root, platform: 'android');
      expect(androidRegistrant.readAsStringSync(), firstProductionRegistrant);
    },
  );

  test(
    'iOS sanitizer preserves header, implementation, and production plugin',
    () {
      final root = Directory.systemTemp.createTempSync('bil-plugin-sanitizer-');
      addTearDown(() => root.deleteSync(recursive: true));
      final metadata = File('${root.path}/.flutter-plugins-dependencies')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode(
            _document(
              android: const <Map<String, Object?>>[],
              ios: <Map<String, Object?>>[
                _plugin('production_plugin', dev: false),
                _plugin('integration_test', dev: true),
              ],
              graph: <Map<String, Object?>>[
                _graph('production_plugin'),
                _graph('integration_test'),
              ],
            ),
          ),
        );
      final header = File('${root.path}/ios/Runner/GeneratedPluginRegistrant.h')
        ..createSync(recursive: true)
        ..writeAsStringSync(_iosRegistrantHeader);
      final implementation =
          File('${root.path}/ios/Runner/GeneratedPluginRegistrant.m')
            ..createSync(recursive: true)
            ..writeAsStringSync(_iosRegistrant);

      sanitizeFlutterReleaseProject(projectRoot: root, platform: 'ios');

      expect(header.existsSync(), isTrue);
      expect(header.readAsStringSync(), _iosRegistrantHeader);
      expect(implementation.existsSync(), isTrue);
      expect(implementation.lengthSync(), greaterThan(0));
      expect(
        implementation.readAsStringSync(),
        allOf(
          contains('@implementation GeneratedPluginRegistrant'),
          contains('@import production_plugin;'),
          contains('[ProductionPlugin registerWithRegistrar:'),
          isNot(contains('integration_test')),
          isNot(contains('IntegrationTestPlugin')),
        ),
      );
      expect(metadata.readAsStringSync(), isNot(contains('integration_test')));
    },
  );

  test(
    'missing runtime registrant fails before plugin metadata is changed',
    () {
      final root = Directory.systemTemp.createTempSync('bil-plugin-sanitizer-');
      addTearDown(() => root.deleteSync(recursive: true));
      final metadata = File('${root.path}/.flutter-plugins-dependencies')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode(
            _document(
              android: <Map<String, Object?>>[
                _plugin('integration_test', dev: true),
              ],
              ios: const <Map<String, Object?>>[],
              graph: <Map<String, Object?>>[_graph('integration_test')],
            ),
          ),
        );

      expect(
        () => sanitizeFlutterReleaseProject(
          projectRoot: root,
          platform: 'android',
        ),
        throwsStateError,
      );
      expect(metadata.readAsStringSync(), contains('integration_test'));
    },
  );

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

Map<String, Object?> _plugin(
  String name, {
  required bool dev,
  bool native = true,
}) => <String, Object?>{
  'name': name,
  'path': '/generated/$name',
  'native_build': native,
  'dependencies': const <String>[],
  'dev_dependency': dev,
};

Map<String, Object?> _graph(
  String name, {
  List<String> dependencies = const <String>[],
}) => <String, Object?>{'name': name, 'dependencies': dependencies};

const _androidRegistrant = r'''package io.flutter.plugins;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import io.flutter.Log;
import io.flutter.embedding.engine.FlutterEngine;

@Keep
public final class GeneratedPluginRegistrant {
  private static final String TAG = "GeneratedPluginRegistrant";
  public static void registerWith(@NonNull FlutterEngine flutterEngine) {
    try {
      flutterEngine.getPlugins().add(new example.ProductionPlugin());
    } catch (Exception e) {
      Log.e(TAG, "Error registering plugin production_plugin, example.ProductionPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new dev.flutter.plugins.integration_test.IntegrationTestPlugin());
    } catch (Exception e) {
      Log.e(TAG, "Error registering plugin integration_test, dev.flutter.plugins.integration_test.IntegrationTestPlugin", e);
    }
  }
}
''';

const _iosRegistrantHeader = r'''#ifndef GeneratedPluginRegistrant_h
#define GeneratedPluginRegistrant_h
#import <Flutter/Flutter.h>
@interface GeneratedPluginRegistrant : NSObject
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry;
@end
#endif
''';

const _iosRegistrant = r'''#import "GeneratedPluginRegistrant.h"

#if __has_include(<production_plugin/ProductionPlugin.h>)
#import <production_plugin/ProductionPlugin.h>
#else
@import production_plugin;
#endif

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

@implementation GeneratedPluginRegistrant
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [ProductionPlugin registerWithRegistrar:[registry registrarForPlugin:@"ProductionPlugin"]];
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
}
@end
''';
