import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_links is the only native deep-link owner on Android and iOS', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosPlist = File('ios/Runner/Info.plist').readAsStringSync();

    final mainActivityStart = androidManifest.indexOf(
      'android:name=".MainActivity"',
    );
    final mainActivityEnd = androidManifest.indexOf(
      '</activity>',
      mainActivityStart,
    );
    expect(mainActivityStart, greaterThan(-1));
    expect(mainActivityEnd, greaterThan(mainActivityStart));
    final mainActivity = androidManifest.substring(
      mainActivityStart,
      mainActivityEnd,
    );
    expect(
      mainActivity,
      matches(
        RegExp(
          r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+'
          r'android:value="false"\s*/>',
        ),
      ),
    );
    expect(
      RegExp(
        r'android:name="flutter_deeplinking_enabled"',
      ).allMatches(androidManifest),
      hasLength(1),
    );

    expect(
      iosPlist,
      matches(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')),
    );
    expect(
      RegExp(r'<key>FlutterDeepLinkingEnabled</key>').allMatches(iosPlist),
      hasLength(1),
    );
  });

  test('iOS return links attach the event stream without an await gap', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final iosPlugin = File(
      'tool/vendor_app_links/ios/app_links/Sources/app_links/'
      'AppLinksIosPlugin.swift',
    ).readAsStringSync();
    final bindStart = mainSource.indexOf('void _bind()');
    final bindEnd = mainSource.indexOf(
      'Future<void> _handleIncomingUri',
      bindStart,
    );

    expect(bindStart, greaterThan(-1));
    expect(bindEnd, greaterThan(bindStart));
    final bindBody = mainSource.substring(bindStart, bindEnd);

    expect(bindBody, contains('appLinks.uriLinkStream.listen('));
    expect(bindBody, contains('getInitialLink()'));
    final synchronousBindBody = bindBody
        .split('Future<void> _consumeInitialLink')
        .first;
    expect(synchronousBindBody, isNot(contains('await ')));
    expect(bindBody, contains("'incoming_link_stream_failed'"));

    final onListenStart = iosPlugin.indexOf('public func onListen(');
    final onListenEnd = iosPlugin.indexOf(
      'public func onCancel(',
      onListenStart,
    );
    expect(onListenStart, greaterThan(-1));
    expect(onListenEnd, greaterThan(onListenStart));
    final onListenBody = iosPlugin.substring(onListenStart, onListenEnd);
    expect(onListenBody, contains('self.eventSink = events'));
    expect(onListenBody, contains('events(initialLink!)'));
  });

  test('OAuth HTTPS callback is registered as a narrow verified app link', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final releaseEntitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final debugEntitlements = File(
      'ios/Runner/RunnerDebug.entitlements',
    ).readAsStringSync();
    final ownerInputs = File(
      'docs/release/BIL_EPIC14_OWNER_INPUTS.json',
    ).readAsStringSync();

    expect(androidManifest, contains('android:autoVerify="true"'));
    expect(androidManifest, contains('android:scheme="https"'));
    expect(androidManifest, contains('android:host="www.bilhealth.com"'));
    expect(androidManifest, contains('android:path="/auth/callback"'));
    expect(androidManifest, contains('android:path="/auth/reset-password"'));
    for (final entitlements in <String>[
      releaseEntitlements,
      debugEntitlements,
    ]) {
      expect(entitlements, contains('com.apple.developer.associated-domains'));
      expect(entitlements, contains('applinks:www.bilhealth.com'));
    }

    // Registration in source is not proof that the domain association files
    // are live. Keep the independently verified publication state explicit in
    // release evidence so this contract cannot silently regress to source-only
    // configuration.
    expect(
      ownerInputs,
      contains(
        '"android_assetlinks_live": '
        '"VERIFIED_DIRECT_AND_GOOGLE_API_2026_09_05"',
      ),
    );
    expect(
      ownerInputs,
      contains(
        '"apple_app_site_association_live": '
        '"VERIFIED_DIRECT_AND_APPLE_CDN_2026_09_05"',
      ),
    );
  });
}
