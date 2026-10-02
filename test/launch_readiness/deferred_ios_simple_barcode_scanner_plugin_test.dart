import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/defer_ios_simple_barcode_scanner.dart';
import '../../tool/release/sanitize_flutter_release_plugins.dart';

void main() {
  test('removes only iOS support from simple_barcode_scanner 0.6.0', () {
    final sanitized =
        removeIosPlatformFromSimpleBarcodeScannerPubspec(_barcodePubspec);

    expect(sanitized, contains('name: simple_barcode_scanner'));
    expect(sanitized, contains('version: 0.6.0'));
    expect(sanitized, contains('windows:'));
    expect(sanitized, contains('web:'));
    expect(sanitized, contains('FlutterBarcodeScannerPlugin'));
    expect(sanitized, isNot(contains('SwiftFlutterBarcodeScannerPlugin')));
  });

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

  test('deferred override controls Flutter discovery and preserves Android', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    final prepared =
        prepareDeferredIosSimpleBarcodeScannerPackage(fixture.root);
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
      prepared.overrideDirectory.path +
          Platform.pathSeparator +
          'pubspec.yaml',
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
        jsonDecode(fixture.metadata.readAsStringSync())
            as Map<String, Object?>;
    final plugins = metadata['plugins']! as Map<String, Object?>;
    expect(
      _pluginNames(plugins['ios']! as List<Object?>),
      <String>['production_plugin'],
    );
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

final class _Fixture {
  _Fixture({
    required this.root,
    required this.sourcePubspec,
    required this.packageConfig,
    required this.metadata,
    required this.registrant,
  });

  factory _Fixture.create() {
    final root = Directory.systemTemp.createTempSync('bil-ios-barcode-defer-');
    final source = Directory(
      root.path +
          Platform.pathSeparator +
          'cache' +
          Platform.pathSeparator +
          'simple_barcode_scanner-0.6.0',
    )..createSync(recursive: true);
    final sourcePubspec = File(
      source.path + Platform.pathSeparator + 'pubspec.yaml',
    )..writeAsStringSync(_barcodePubspec);
    File(
      source.path +
          Platform.pathSeparator +
          'lib' +
          Platform.pathSeparator +
          'simple_barcode_scanner.dart',
    )
      ..createSync(recursive: true)
      ..writeAsStringSync('library simple_barcode_scanner;\n');

    final packageConfig = File(
      root.path +
          Platform.pathSeparator +
          '.dart_tool' +
          Platform.pathSeparator +
          'package_config.json',
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
          ],
        }),
      );

    Map<String, Object?> plugin(String name) => <String, Object?>{
      'name': name,
      'path': root.path + '/generated/' + name,
      'native_build': true,
      'dependencies': const <String>[],
      'dev_dependency': false,
    };
    final metadata = File(
      root.path +
          Platform.pathSeparator +
          '.flutter-plugins-dependencies',
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
      root.path +
          Platform.pathSeparator +
          'ios' +
          Platform.pathSeparator +
          'Runner' +
          Platform.pathSeparator +
          'GeneratedPluginRegistrant.h',
    )
      ..createSync(recursive: true)
      ..writeAsStringSync(_registrantHeader);
    final registrant = File(
      root.path +
          Platform.pathSeparator +
          'ios' +
          Platform.pathSeparator +
          'Runner' +
          Platform.pathSeparator +
          'GeneratedPluginRegistrant.m',
    )..writeAsStringSync(_registrant);

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

  void dispose() => root.deleteSync(recursive: true);
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
