import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/defer_ios_google_mobile_ads.dart';
import '../../tool/release/sanitize_flutter_release_plugins.dart';

void main() {
  test('removes only the iOS platform from the google mobile ads pubspec', () {
    final sanitized = removeIosPlatformFromGoogleMobileAdsPubspec(
      _googleMobileAdsPubspec,
    );

    expect(sanitized, contains('name: google_mobile_ads'));
    expect(sanitized, contains('android:'));
    expect(sanitized, contains('pluginClass: GoogleMobileAdsPlugin'));
    expect(sanitized, isNot(contains('      ios:')));
    expect(sanitized, isNot(contains('FLTGoogleMobileAdsPlugin')));
    expect(sanitized, contains('dependencies:'));
  });

  test('pubspec surgery fails closed for a different package', () {
    expect(
      () => removeIosPlatformFromGoogleMobileAdsPubspec(
        _googleMobileAdsPubspec.replaceFirst(
          'name: google_mobile_ads',
          'name: lookalike_ads',
        ),
      ),
      throwsFormatException,
    );
  });

  test('pubspec surgery requires Android to remain available', () {
    expect(
      () => removeIosPlatformFromGoogleMobileAdsPubspec(
        _googleMobileAdsPubspec.replaceFirst(
          '      android:\n'
              '        package: io.flutter.plugins.googlemobileads\n'
              '        pluginClass: GoogleMobileAdsPlugin\n',
          '',
        ),
      ),
      throwsFormatException,
    );
  });

  test('duplicate iOS platform keys fail closed', () {
    final duplicateIos = _googleMobileAdsPubspec.replaceFirst(
      '      ios:\n'
          '        pluginClass: FLTGoogleMobileAdsPlugin\n',
      '      ios:\n'
          '        pluginClass: FLTGoogleMobileAdsPlugin\n'
          '      ios:\n'
          '        pluginClass: FLTGoogleMobileAdsPlugin\n',
    );

    expect(
      () => removeIosPlatformFromGoogleMobileAdsPubspec(duplicateIos),
      throwsFormatException,
    );
  });

  test(
    'deferred override drives Flutter package discovery and iOS registrant',
    () {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);

      final prepared = prepareDeferredIosGoogleMobileAdsPackage(fixture.root);
      expect(prepared.alreadyPrepared, isFalse);
      sanitizeFlutterReleaseProject(
        projectRoot: fixture.root,
        platform: 'ios',
        excludedNativePluginNames: const <String>{
          deferredIosGoogleMobileAdsPlugin,
        },
      );
      verifyDeferredIosGoogleMobileAdsDiscovery(fixture.root);

      expect(fixture.sourcePubspec.readAsStringSync(), contains('      ios:'));
      final copiedPubspec = File(
        '${prepared.overrideDirectory.path}${Platform.pathSeparator}pubspec.yaml',
      ).readAsStringSync();
      expect(copiedPubspec, contains('      android:'));
      expect(copiedPubspec, isNot(contains('      ios:')));
      expect(
        File(
          '${prepared.overrideDirectory.path}${Platform.pathSeparator}lib'
          '${Platform.pathSeparator}google_mobile_ads.dart',
        ).readAsStringSync(),
        contains('library google_mobile_ads;'),
      );

      final packageConfig =
          jsonDecode(fixture.packageConfig.readAsStringSync())
              as Map<String, Object?>;
      final packages = packageConfig['packages']! as List<Object?>;
      final adsEntry = packages.cast<Map<String, Object?>>().singleWhere(
        (entry) => entry['name'] == deferredIosGoogleMobileAdsPlugin,
      );
      final discovered = Directory.fromUri(
        fixture.packageConfig.uri.resolve(adsEntry['rootUri']! as String),
      );
      expect(
        discovered.resolveSymbolicLinksSync(),
        prepared.overrideDirectory.resolveSymbolicLinksSync(),
      );

      final metadata =
          jsonDecode(fixture.metadata.readAsStringSync())
              as Map<String, Object?>;
      final plugins = metadata['plugins']! as Map<String, Object?>;
      expect(_pluginNames(plugins['ios']! as List<Object?>), <String>[
        'production_plugin',
      ]);
      expect(
        _pluginNames(plugins['android']! as List<Object?>),
        contains(deferredIosGoogleMobileAdsPlugin),
      );
      expect(
        fixture.registrant.readAsStringSync(),
        allOf(
          contains('ProductionPlugin'),
          isNot(contains('FLTGoogleMobileAdsPlugin')),
          isNot(contains('google_mobile_ads')),
          isNot(contains('IntegrationTestPlugin')),
        ),
      );
    },
  );

  test('deferred preparation is idempotent and remains verifiable', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    final first = prepareDeferredIosGoogleMobileAdsPackage(fixture.root);
    sanitizeFlutterReleaseProject(
      projectRoot: fixture.root,
      platform: 'ios',
      excludedNativePluginNames: const <String>{
        deferredIosGoogleMobileAdsPlugin,
      },
    );
    final second = prepareDeferredIosGoogleMobileAdsPackage(fixture.root);
    expect(first.overrideDirectory.path, second.overrideDirectory.path);
    expect(second.alreadyPrepared, isTrue);
    sanitizeFlutterReleaseProject(
      projectRoot: fixture.root,
      platform: 'ios',
      excludedNativePluginNames: const <String>{
        deferredIosGoogleMobileAdsPlugin,
      },
      alreadyExcludedNativePluginNames: const <String>{
        deferredIosGoogleMobileAdsPlugin,
      },
    );
    verifyDeferredIosGoogleMobileAdsDiscovery(fixture.root);
  });

  test('already-prepared override rejects duplicate iOS keys', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    final prepared = prepareDeferredIosGoogleMobileAdsPackage(fixture.root);
    final shadowPubspec = File(
      '${prepared.overrideDirectory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    shadowPubspec.writeAsStringSync(
      shadowPubspec.readAsStringSync().replaceFirst(
        '    platforms:\n',
        '    platforms:\n'
            '      ios:\n'
            '        pluginClass: FLTGoogleMobileAdsPlugin\n'
            '      ios:\n'
            '        pluginClass: FLTGoogleMobileAdsPlugin\n',
      ),
    );

    expect(
      () => prepareDeferredIosGoogleMobileAdsPackage(fixture.root),
      throwsFormatException,
    );
  });

  test('pre-existing shadow is never deleted or overwritten', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    final destination = Directory(
      '${fixture.root.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}bil_release_plugin_overrides'
      '${Platform.pathSeparator}$deferredIosGoogleMobileAdsPlugin',
    )..createSync(recursive: true);
    final sentinel = File(
      '${destination.path}${Platform.pathSeparator}owner-sentinel.txt',
    )..writeAsStringSync('preserve-me');

    expect(
      () => prepareDeferredIosGoogleMobileAdsPackage(fixture.root),
      throwsStateError,
    );
    expect(sentinel.readAsStringSync(), 'preserve-me');
  });

  test(
    'symlinked override parent is rejected',
    () {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      final outside = Directory.systemTemp.createTempSync(
        'bil-ios-ads-outside-',
      );
      addTearDown(() => outside.deleteSync(recursive: true));
      Link(
        '${fixture.root.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}bil_release_plugin_overrides',
      ).createSync(outside.path);

      expect(
        () => prepareDeferredIosGoogleMobileAdsPackage(fixture.root),
        throwsStateError,
      );
    },
    skip: Platform.isWindows
        ? 'Creating symlinks is not reliably permitted on Windows CI.'
        : false,
  );

  test('ads-enabled iOS path rejects a stale deferred override', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    prepareDeferredIosGoogleMobileAdsPackage(fixture.root);

    expect(
      () => assertNoStaleDeferredIosGoogleMobileAdsOverride(fixture.root),
      throwsStateError,
    );
  });

  test('production plugin exclusion remains forbidden on Android', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    expect(
      () => sanitizeFlutterReleaseProject(
        projectRoot: fixture.root,
        platform: 'android',
        excludedNativePluginNames: const <String>{
          deferredIosGoogleMobileAdsPlugin,
        },
      ),
      throwsArgumentError,
    );
  });

  test('missing iOS ads metadata cannot claim deferred exclusion', () {
    final fixture = _Fixture.create(includeIosAdsMetadata: false);
    addTearDown(fixture.dispose);

    expect(
      () => sanitizeFlutterReleaseProject(
        projectRoot: fixture.root,
        platform: 'ios',
        excludedNativePluginNames: const <String>{
          deferredIosGoogleMobileAdsPlugin,
        },
      ),
      throwsFormatException,
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

  factory _Fixture.create({bool includeIosAdsMetadata = true}) {
    final root = Directory.systemTemp.createTempSync('bil-ios-ads-defer-');
    final source = Directory(
      '${root.path}${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}google_mobile_ads-9.1.0',
    )..createSync(recursive: true);
    final sourcePubspec = File(
      '${source.path}${Platform.pathSeparator}pubspec.yaml',
    )..writeAsStringSync(_googleMobileAdsPubspec);
    File(
        '${source.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}google_mobile_ads.dart',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('library google_mobile_ads;\n');
    File(
        '${source.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}google_mobile_ads${Platform.pathSeparator}'
        'Package.swift',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('// depends on GoogleMobileAds\n');
    File(
        '${source.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}build.gradle',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('// Android implementation remains available.\n');

    final packageConfig =
        File(
            '${root.path}${Platform.pathSeparator}.dart_tool'
            '${Platform.pathSeparator}package_config.json',
          )
          ..createSync(recursive: true)
          ..writeAsStringSync(
            jsonEncode(<String, Object?>{
              'configVersion': 2,
              'packages': <Object?>[
                <String, Object?>{
                  'name': deferredIosGoogleMobileAdsPlugin,
                  'rootUri': source.uri.toString(),
                  'packageUri': 'lib/',
                  'languageVersion': '3.10',
                },
              ],
            }),
          );

    Map<String, Object?> plugin(String name, {required bool dev}) =>
        <String, Object?>{
          'name': name,
          'path': '${root.path}/generated/$name',
          'native_build': true,
          'dependencies': const <String>[],
          'dev_dependency': dev,
        };
    final iosPlugins = <Map<String, Object?>>[
      plugin('production_plugin', dev: false),
      if (includeIosAdsMetadata)
        plugin(deferredIosGoogleMobileAdsPlugin, dev: false),
      plugin('integration_test', dev: true),
    ];
    final metadata =
        File(
          '${root.path}${Platform.pathSeparator}.flutter-plugins-dependencies',
        )..writeAsStringSync(
          jsonEncode(<String, Object?>{
            'plugins': <String, Object?>{
              'android': <Object?>[
                plugin('production_plugin', dev: false),
                plugin(deferredIosGoogleMobileAdsPlugin, dev: false),
                plugin('integration_test', dev: true),
              ],
              'ios': iosPlugins,
            },
            'dependencyGraph': <Object?>[
              <String, Object?>{
                'name': 'production_plugin',
                'dependencies': const <String>[],
              },
              <String, Object?>{
                'name': deferredIosGoogleMobileAdsPlugin,
                'dependencies': const <String>[],
              },
              <String, Object?>{
                'name': 'integration_test',
                'dependencies': const <String>[],
              },
            ],
          }),
        );

    File('${root.path}/ios/Runner/GeneratedPluginRegistrant.h')
      ..createSync(recursive: true)
      ..writeAsStringSync(_registrantHeader);
    final registrant = File(
      '${root.path}/ios/Runner/GeneratedPluginRegistrant.m',
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

const String _googleMobileAdsPubspec = '''name: google_mobile_ads
version: 9.1.0
flutter:
  plugin:
    platforms:
      android:
        package: io.flutter.plugins.googlemobileads
        pluginClass: GoogleMobileAdsPlugin
      ios:
        pluginClass: FLTGoogleMobileAdsPlugin

dependencies:
  flutter:
    sdk: flutter
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

#if __has_include(<google_mobile_ads/FLTGoogleMobileAdsPlugin.h>)
#import <google_mobile_ads/FLTGoogleMobileAdsPlugin.h>
#else
@import google_mobile_ads;
#endif

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

@implementation GeneratedPluginRegistrant
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [ProductionPlugin registerWithRegistrar:[registry registrarForPlugin:@"ProductionPlugin"]];
  [FLTGoogleMobileAdsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTGoogleMobileAdsPlugin"]];
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
}
@end
''';
