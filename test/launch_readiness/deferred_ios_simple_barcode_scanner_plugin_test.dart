import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/defer_ios_simple_barcode_scanner.dart';
import '../../tool/release/sanitize_flutter_release_plugins.dart';

void main() {
  test('removes only iOS support from simple_barcode_scanner 0.6.0', () {
    final sanitized = removeIosPlatformFromSimpleBarcodeScannerPubspec(
      _barcodePubspec,
    );

    expect(sanitized, contains('name: simple_barcode_scanner'));
    expect(sanitized, contains('version: 0.6.0'));
    expect(sanitized, contains('windows:'));
    expect(sanitized, contains('web:'));
    expect(sanitized, contains('FlutterBarcodeScannerPlugin'));
    expect(sanitized, isNot(contains('SwiftFlutterBarcodeScannerPlugin')));
  });

  test(
    'Android defers only the Windows barcode plugin and preserves its assets',
    () {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final original = fixture.sourcePubspec.readAsStringSync();
      final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
        fixture.root,
        removeAndroid: true,
      );
      final copy = File(
        '${prepared.overrideDirectory.path}/pubspec.yaml',
      ).readAsStringSync();
      expect(copy, contains('  windows:'));
      expect(copy, contains('  web:'));
      expect(copy, isNot(contains('  plugin:')));
      expect(copy, contains('assets/barcode.html'));
      expect(copy, isNot(contains('FlutterBarcodeScannerPlugin')));
      expect(fixture.sourcePubspec.readAsStringSync(), original);
      final metadata =
          jsonDecode(fixture.metadata.readAsStringSync())
              as Map<String, Object?>;
      final result = sanitizeFlutterPluginDependencies(
        metadata,
        excludedPluginNamesByPlatform: const {
          'android': {'simple_barcode_scanner'},
        },
      );
      fixture.metadata.writeAsStringSync(jsonEncode(result.document));
      verifyDeferredIosSimpleBarcodeScannerDiscovery(
        fixture.root,
        platform: 'android',
      );
      final again = prepareDeferredIosSimpleBarcodeScannerPackage(
        fixture.root,
        removeAndroid: true,
      );
      expect(again.alreadyPrepared, isTrue);
      expect(
        File('${again.overrideDirectory.path}/pubspec.yaml').readAsStringSync(),
        copy,
      );
    },
  );

  test('pubspec surgery fails closed for another package or version', () {
    expect(
      () => removeIosPlatformFromSimpleBarcodeScannerPubspec(
        _barcodePubspec.replaceFirst(
          'name: simple_barcode_scanner',
          'name: lookalike_scanner',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => removeIosPlatformFromSimpleBarcodeScannerPubspec(
        _barcodePubspec.replaceFirst('version: 0.6.0', 'version: 0.6.1'),
      ),
      throwsFormatException,
    );
  });

  for (final platform in ['ios', 'android']) {
    test(
      'pub-get reset rebinds owned $platform overlay before metadata sanitizer',
      () {
        final fixture = _Fixture.create();
        addTearDown(fixture.dispose);
        final originalConfig = fixture.packageConfig.readAsBytesSync();
        final originalMetadata = fixture.metadata.readAsBytesSync();
        final originalRegistrant = fixture.registrant.readAsBytesSync();
        final originalAndroidRegistrant = fixture.androidRegistrant
            .readAsBytesSync();
        final first = prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
          removeAndroid: platform == 'android',
        );
        sanitizeFlutterReleaseProject(
          projectRoot: fixture.root,
          platform: platform,
          excludedNativePluginNames: const {
            deferredIosSimpleBarcodeScannerPlugin,
          },
        );
        // Emulate pub get restoring both upstream config and generated metadata.
        fixture.packageConfig.writeAsBytesSync(originalConfig);
        fixture.metadata.writeAsBytesSync(originalMetadata);
        fixture.registrant.writeAsBytesSync(originalRegistrant);
        fixture.androidRegistrant.writeAsBytesSync(originalAndroidRegistrant);
        final before = _snapshotTree(fixture.root)
          ..remove('.dart_tool/package_config.json');
        final rebound = prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
          removeAndroid: platform == 'android',
        );
        expect(rebound.alreadyPrepared, isTrue);
        expect(rebound.overrideDirectory.path, first.overrideDirectory.path);
        final expectedConfig =
            jsonDecode(utf8.decode(originalConfig)) as Map<String, dynamic>;
        (expectedConfig['packages'] as List)
                .cast<Map<String, dynamic>>()
                .singleWhere(
                  (value) =>
                      value['name'] == deferredIosSimpleBarcodeScannerPlugin,
                )['rootUri'] =
            'bil_release_plugin_overrides/simple_barcode_scanner/';
        expect(
          jsonDecode(fixture.packageConfig.readAsStringSync()),
          expectedConfig,
        );
        expect(
          _snapshotTree(fixture.root)..remove('.dart_tool/package_config.json'),
          before,
        );
        expect(fixture.metadata.readAsBytesSync(), originalMetadata);
        // Match the CLI: owned reuse means alreadyExcluded may be supplied even
        // when pub get has restored the original native plugin entry.
        sanitizeFlutterReleaseProject(
          projectRoot: fixture.root,
          platform: platform,
          excludedNativePluginNames: const {
            deferredIosSimpleBarcodeScannerPlugin,
          },
          alreadyExcludedNativePluginNames: const {
            deferredIosSimpleBarcodeScannerPlugin,
          },
        );
        verifyDeferredIosSimpleBarcodeScannerDiscovery(
          fixture.root,
          platform: platform,
        );
        final again = prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
          removeAndroid: platform == 'android',
        );
        expect(again.alreadyPrepared, isTrue);
      },
    );
  }

  for (final path in [
    'lib/simple_barcode_scanner.dart',
    'assets/barcode.html',
    'LICENSE',
    'android/src/Plugin.java',
    'ios/Classes/Plugin.swift',
    'pubspec.yaml',
  ]) {
    test('rebind rejects changed $path without touching any fixture file', () {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
        fixture.root,
        removeAndroid: true,
      );
      _restoreSourceBinding(fixture);
      final changed = File('${prepared.overrideDirectory.path}/$path');
      changed.writeAsBytesSync([...changed.readAsBytesSync(), 10, 35, 120]);
      final before = _snapshotTree(fixture.root);
      expect(
        () => prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
          removeAndroid: true,
        ),
        throwsStateError,
      );
      expect(_snapshotTree(fixture.root), before);
    });
  }
  for (final extraDirectory in [false, true]) {
    test(
      'rebind rejects an unknown ${extraDirectory ? 'directory' : 'file'} without overwriting it',
      () {
        final fixture = _Fixture.create();
        addTearDown(fixture.dispose);
        final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
        );
        _restoreSourceBinding(fixture);
        final path = '${prepared.overrideDirectory.path}/unrecognized-entry';
        if (extraDirectory) {
          Directory(path).createSync();
        } else {
          File(path).writeAsBytesSync([0, 255, 1]);
        }
        final before = _snapshotTree(fixture.root);
        expect(
          () => prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root),
          throwsStateError,
        );
        expect(_snapshotTree(fixture.root), before);
      },
    );
  }
  test(
    'rebind rejects a different canonical upstream even with identical bytes',
    () {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
        fixture.root,
      );
      _restoreSourceBinding(fixture);
      final original = fixture.sourcePubspec.parent;
      final other = Directory(
        '${fixture.root.path}/other-cache/simple_barcode_scanner-0.6.0',
      )..createSync(recursive: true);
      for (final entity in original.listSync(
        recursive: true,
        followLinks: false,
      )) {
        final target =
            '${other.path}/${entity.path.substring(original.path.length + 1)}';
        if (entity is Directory) {
          Directory(target).createSync(recursive: true);
        }
        if (entity is File) {
          File(target).createSync(recursive: true);
          entity.copySync(target);
        }
      }
      final marker = _marker(prepared.overrideDirectory);
      final payload =
          jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      payload['source_root_uri'] = Directory(
        other.resolveSymbolicLinksSync(),
      ).uri.toString();
      marker.writeAsStringSync(jsonEncode(payload));
      final before = _snapshotTree(fixture.root);
      expect(
        () => prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root),
        throwsStateError,
      );
      expect(_snapshotTree(fixture.root), before);
    },
  );
  for (final changed in <String, Object?>{
    'status': 'unknown',
    'plugin': 'lookalike',
    'version': '0.6.1',
    'source_root_uri': 'noncanonical',
    'android_removed': 'true',
    'unknown_marker_key': true,
  }.entries) {
    test('owned marker ${changed.key} fails closed before rebinding', () {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
        fixture.root,
      );
      _restoreSourceBinding(fixture);
      final marker = _marker(prepared.overrideDirectory);
      final payload =
          jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      payload[changed.key] = changed.key == 'source_root_uri'
          ? '${payload['source_root_uri']}./'
          : changed.value;
      marker.writeAsStringSync(jsonEncode(payload));
      final before = _snapshotTree(fixture.root);
      expect(
        () => prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root),
        throwsStateError,
      );
      expect(_snapshotTree(fixture.root), before);
    });
  }
  test('already-bound owned tree also rejects altered Dart bytes', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
      fixture.root,
    );
    File(
      '${prepared.overrideDirectory.path}/lib/simple_barcode_scanner.dart',
    ).writeAsStringSync('tampered');
    final before = _snapshotTree(fixture.root);
    expect(
      () => prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root),
      throwsStateError,
    );
    expect(_snapshotTree(fixture.root), before);
  });
  test('missing owned marker is preserved as a refusal without new writes', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
      fixture.root,
    );
    _restoreSourceBinding(fixture);
    _marker(prepared.overrideDirectory).deleteSync();
    final before = _snapshotTree(fixture.root);
    expect(
      () => prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root),
      throwsStateError,
    );
    expect(_snapshotTree(fixture.root), before);
  });
  for (final onUpstream in [false, true]) {
    test(
      'rebind rejects ${onUpstream ? 'upstream' : 'override'} symlink and keeps its target',
      () {
        final fixture = _Fixture.create();
        addTearDown(fixture.dispose);
        final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
        );
        _restoreSourceBinding(fixture);
        final parent = onUpstream
            ? fixture.sourcePubspec.parent
            : prepared.overrideDirectory;
        final link = Link('${parent.path}/linked-directory');
        addTearDown(() {
          final kind = FileSystemEntity.typeSync(link.path, followLinks: false);
          if (kind == FileSystemEntityType.link) {
            link.deleteSync();
          } else if (kind != FileSystemEntityType.notFound) {
            throw StateError('Owned test link was replaced.');
          }
        });
        link.createSync('${fixture.sourcePubspec.parent.path}/lib');
        final before = _snapshotTree(fixture.root);
        expect(
          () => prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root),
          throwsStateError,
        );
        expect(_snapshotTree(fixture.root), before);
      },
    );
  }
  for (final resetConfig in [false, true]) {
    test(
      'owned early empty-plugin upgrade survives ${resetConfig ? 'pub-get reset' : 'direct reuse'}',
      () {
        final fixture = _Fixture.create();
        addTearDown(fixture.dispose);
        final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
          fixture.root,
          removeAndroid: true,
        );
        final file = File('${prepared.overrideDirectory.path}/pubspec.yaml');
        final approved = file.readAsStringSync();
        file.writeAsStringSync('$approved  plugin:\n    platforms:\n');
        if (resetConfig) {
          _restoreSourceBinding(fixture);
        }
        final sourceBefore = _snapshotTree(fixture.sourcePubspec.parent);
        expect(
          prepareDeferredIosSimpleBarcodeScannerPackage(
            fixture.root,
            removeAndroid: true,
          ).alreadyPrepared,
          isTrue,
        );
        expect(file.readAsStringSync(), approved);
        expect(_snapshotTree(fixture.sourcePubspec.parent), sourceBefore);
      },
    );
  }

  test('deferred override controls Flutter discovery and preserves Android', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    final prepared = prepareDeferredIosSimpleBarcodeScannerPackage(
      fixture.root,
    );
    expect(prepared.alreadyPrepared, isFalse);

    sanitizeFlutterReleaseProject(
      projectRoot: fixture.root,
      platform: 'ios',
      excludedNativePluginNames: const <String>{
        deferredIosSimpleBarcodeScannerPlugin,
      },
    );
    verifyDeferredIosSimpleBarcodeScannerDiscovery(fixture.root);

    expect(fixture.sourcePubspec.readAsStringSync(), contains('      ios:'));
    final copiedPubspec = File(
      '${prepared.overrideDirectory.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();
    expect(copiedPubspec, contains('  windows:'));
    expect(copiedPubspec, contains('FlutterBarcodeScannerPlugin'));
    expect(copiedPubspec, isNot(contains('SwiftFlutterBarcodeScannerPlugin')));

    final packageConfig =
        jsonDecode(fixture.packageConfig.readAsStringSync())
            as Map<String, Object?>;
    final packages = packageConfig['packages']! as List<Object?>;
    final entry = packages.cast<Map<String, Object?>>().singleWhere(
      (item) => item['name'] == deferredIosSimpleBarcodeScannerPlugin,
    );
    final discovered = Directory.fromUri(
      fixture.packageConfig.uri.resolve(entry['rootUri']! as String),
    );
    expect(
      discovered.resolveSymbolicLinksSync(),
      prepared.overrideDirectory.resolveSymbolicLinksSync(),
    );

    final metadata =
        jsonDecode(fixture.metadata.readAsStringSync()) as Map<String, Object?>;
    final plugins = metadata['plugins']! as Map<String, Object?>;
    expect(_pluginNames(plugins['ios']! as List<Object?>), <String>[
      'production_plugin',
    ]);
    expect(
      _pluginNames(plugins['android']! as List<Object?>),
      contains(deferredIosSimpleBarcodeScannerPlugin),
    );
    expect(
      fixture.registrant.readAsStringSync(),
      allOf(
        contains('ProductionPlugin'),
        isNot(contains('simple_barcode_scanner')),
        isNot(contains('SwiftFlutterBarcodeScannerPlugin')),
      ),
    );
  });
}

List<String> _pluginNames(List<Object?> entries) => entries
    .cast<Map<String, Object?>>()
    .map((entry) => entry['name']! as String)
    .toList(growable: false);

Map<String, String> _snapshotTree(Directory root) => {
  for (final entity in root.listSync(recursive: true, followLinks: false))
    entity.path
        .substring(root.path.length + 1)
        .replaceAll('\\', '/'): entity is File
        ? 'file:${base64Encode(entity.readAsBytesSync())}'
        : entity is Link
        ? 'link:${entity.targetSync()}'
        : 'directory',
};

File _marker(Directory root) =>
    File('${root.path}/.bil-deferred-ios-simple-barcode-scanner.json');

void _restoreSourceBinding(_Fixture fixture) {
  final config =
      jsonDecode(fixture.packageConfig.readAsStringSync())
          as Map<String, dynamic>;
  (config['packages'] as List).cast<Map<String, dynamic>>().singleWhere(
    (value) => value['name'] == deferredIosSimpleBarcodeScannerPlugin,
  )['rootUri'] = fixture.sourcePubspec.parent.uri
      .toString();
  fixture.packageConfig.writeAsStringSync(jsonEncode(config));
}

final class _Fixture {
  _Fixture({
    required this.root,
    required this.sourcePubspec,
    required this.packageConfig,
    required this.metadata,
    required this.registrant,
  }) : _ownedRoot = root.resolveSymbolicLinksSync();

  factory _Fixture.create() {
    final root = Directory.systemTemp.createTempSync('bil-ios-barcode-defer-');
    final source = Directory(
      '${root.path}${Platform.pathSeparator}cache${Platform.pathSeparator}simple_barcode_scanner-0.6.0',
    )..createSync(recursive: true);
    final sourcePubspec = File(
      '${source.path}${Platform.pathSeparator}pubspec.yaml',
    )..writeAsStringSync(_barcodePubspec);
    File(
        '${source.path}${Platform.pathSeparator}lib${Platform.pathSeparator}simple_barcode_scanner.dart',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('library simple_barcode_scanner;\n');
    for (final path in [
      'assets/barcode.html',
      'LICENSE',
      'android/src/Plugin.java',
      'ios/Classes/Plugin.swift',
    ]) {
      File('${source.path}/$path')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0, 1, 255, ...utf8.encode('fixture $path\n')]);
    }

    final packageConfig =
        File(
            '${root.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}package_config.json',
          )
          ..createSync(recursive: true)
          ..writeAsStringSync(
            jsonEncode(<String, Object?>{
              'configVersion': 2,
              'packages': <Object?>[
                <String, Object?>{
                  'name': deferredIosSimpleBarcodeScannerPlugin,
                  'rootUri': source.uri.toString(),
                  'packageUri': 'lib/',
                  'languageVersion': '3.5',
                },
                <String, Object?>{
                  'name': 'unrelated_fixture_package',
                  'rootUri': source.uri.toString(),
                  'packageUri': 'lib/',
                  'languageVersion': '3.5',
                },
              ],
            }),
          );

    Map<String, Object?> plugin(String name) => <String, Object?>{
      'name': name,
      'path': '${root.path}/generated/$name',
      'native_build': true,
      'dependencies': const <String>[],
      'dev_dependency': false,
    };
    final metadata =
        File(
          '${root.path}${Platform.pathSeparator}.flutter-plugins-dependencies',
        )..writeAsStringSync(
          jsonEncode(<String, Object?>{
            'plugins': <String, Object?>{
              'android': <Object?>[
                plugin('production_plugin'),
                plugin(deferredIosSimpleBarcodeScannerPlugin),
              ],
              'ios': <Object?>[
                plugin('production_plugin'),
                plugin(deferredIosSimpleBarcodeScannerPlugin),
              ],
            },
            'dependencyGraph': <Object?>[
              <String, Object?>{
                'name': 'production_plugin',
                'dependencies': const <String>[],
              },
              <String, Object?>{
                'name': deferredIosSimpleBarcodeScannerPlugin,
                'dependencies': const <String>[],
              },
            ],
          }),
        );

    File(
        '${root.path}${Platform.pathSeparator}ios${Platform.pathSeparator}Runner${Platform.pathSeparator}GeneratedPluginRegistrant.h',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(_registrantHeader);
    final registrant = File(
      '${root.path}${Platform.pathSeparator}ios${Platform.pathSeparator}Runner${Platform.pathSeparator}GeneratedPluginRegistrant.m',
    )..writeAsStringSync(_registrant);
    File(
        '${root.path}/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(_androidRegistrant);

    return _Fixture(
      root: root,
      sourcePubspec: sourcePubspec,
      packageConfig: packageConfig,
      metadata: metadata,
      registrant: registrant,
    );
  }

  final Directory root;
  final File sourcePubspec;
  final File packageConfig;
  final File metadata;
  final File registrant;
  final String _ownedRoot;

  File get androidRegistrant => File(
    '${root.path}/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
  );

  void dispose() {
    if (root.resolveSymbolicLinksSync() != _ownedRoot) {
      throw StateError('Refusing cleanup outside the original owned fixture.');
    }
    root.deleteSync(recursive: true);
  }
}

const String _barcodePubspec = '''name: simple_barcode_scanner
description: test fixture
version: 0.6.0
platforms:
  android:
  ios:
  web:
  windows:

environment:
  sdk: ^3.5.3

dependencies:
  flutter:
    sdk: flutter

flutter:
  assets:
    - packages/simple_barcode_scanner/assets/barcode.html
  plugin:
    platforms:
      android:
        package: com.amolg.flutterbarcodescanner
        pluginClass: FlutterBarcodeScannerPlugin
      ios:
        pluginClass: SwiftFlutterBarcodeScannerPlugin
''';

const String _registrantHeader = '''#ifndef GeneratedPluginRegistrant_h
#define GeneratedPluginRegistrant_h
#import <Flutter/Flutter.h>
@interface GeneratedPluginRegistrant : NSObject
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry;
@end
#endif
''';

const String _registrant = '''#import "GeneratedPluginRegistrant.h"

#if __has_include(<production_plugin/ProductionPlugin.h>)
#import <production_plugin/ProductionPlugin.h>
#else
@import production_plugin;
#endif

#if __has_include(<simple_barcode_scanner/SwiftFlutterBarcodeScannerPlugin.h>)
#import <simple_barcode_scanner/SwiftFlutterBarcodeScannerPlugin.h>
#else
@import simple_barcode_scanner;
#endif

@implementation GeneratedPluginRegistrant
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [ProductionPlugin registerWithRegistrar:[registry registrarForPlugin:@"ProductionPlugin"]];
  [SwiftFlutterBarcodeScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"SwiftFlutterBarcodeScannerPlugin"]];
}
@end
''';

const _androidRegistrant = r'''package io.flutter.plugins;
import androidx.annotation.NonNull;
import io.flutter.Log;
import io.flutter.embedding.engine.FlutterEngine;
public final class GeneratedPluginRegistrant {
  private static final String TAG = "GeneratedPluginRegistrant";
  public static void registerWith(@NonNull FlutterEngine flutterEngine) {
    try {
      flutterEngine.getPlugins().add(new example.ProductionPlugin());
    } catch (Exception e) {
      Log.e(TAG, "Error registering plugin production_plugin, example.ProductionPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new com.amolg.flutterbarcodescanner.FlutterBarcodeScannerPlugin());
    } catch (Exception e) {
      Log.e(TAG, "Error registering plugin simple_barcode_scanner, com.amolg.flutterbarcodescanner.FlutterBarcodeScannerPlugin", e);
    }
  }
}
''';
