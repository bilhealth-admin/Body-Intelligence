import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _teamId = '43F9Y5Y96K';
const _bundleId = 'com.bilhealth.bodyintelligencelog';

String get _python => Platform.isWindows ? 'python' : 'python3';

List<int> _plist({
  bool healthKit = true,
  bool associatedDomains = true,
  String? appAttestEnvironment = 'production',
}) => utf8.encode(
  '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>$_teamId.$_bundleId</string>
  <key>com.apple.developer.healthkit</key>
  <${healthKit ? 'true' : 'false'}/>
  <key>com.apple.developer.applesignin</key>
  <array><string>Default</string></array>
  ${associatedDomains ? '''
  <key>com.apple.developer.associated-domains</key>
  <array><string>applinks:www.bilhealth.com</string></array>
  ''' : ''}
  <key>aps-environment</key>
  <string>production</string>
  ${appAttestEnvironment == null ? '' : '''
  <key>com.apple.developer.devicecheck.appattest-environment</key>
  <string>$appAttestEnvironment</string>
  '''}
  <key>get-task-allow</key>
  <false/>
</dict>
</plist>
'''
      .trimLeft(),
);

List<int> _embeddedProfile({
  bool healthKit = true,
  bool associatedDomains = true,
  String? appAttestEnvironment = 'production',
  String teamId = _teamId,
}) => utf8.encode(
  '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>TeamIdentifier</key>
  <array><string>$teamId</string></array>
  <key>ExpirationDate</key>
  <date>2099-01-01T00:00:00Z</date>
  <key>Entitlements</key>
  <dict>
    <key>application-identifier</key>
    <string>$teamId.$_bundleId</string>
    <key>com.apple.developer.healthkit</key>
    <${healthKit ? 'true' : 'false'}/>
    <key>com.apple.developer.applesignin</key>
    <array><string>Default</string></array>
    ${associatedDomains ? '''
    <key>com.apple.developer.associated-domains</key>
    <string>*</string>
    ''' : ''}
    <key>aps-environment</key>
    <string>production</string>
    ${appAttestEnvironment == null ? '' : '''
    <key>com.apple.developer.devicecheck.appattest-environment</key>
    <array>
      <string>development</string>
      <string>$appAttestEnvironment</string>
    </array>
    '''}
    <key>get-task-allow</key>
    <false/>
  </dict>
</dict>
</plist>
'''
      .trimLeft(),
);

Uint8List _codeSigningBlob(List<int> plist, {int? declaredLength}) {
  final totalLength = 8 + plist.length;
  final header = ByteData(8)
    ..setUint32(0, 0xFADE7171, Endian.big)
    ..setUint32(4, declaredLength ?? totalLength, Endian.big);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(plist))
      .takeBytes();
}

ProcessResult _verify(File evidence, {File? embeddedProfile}) {
  final profile =
      embeddedProfile ??
      (File('${evidence.parent.path}/embedded-profile.plist')
        ..writeAsBytesSync(_embeddedProfile()));
  return Process.runSync(_python, <String>[
    'tool/release/verify_signed_ios_entitlements.py',
    '--entitlements',
    evidence.path,
    '--embedded-profile',
    profile.path,
    '--team-id',
    _teamId,
    '--bundle-id',
    _bundleId,
  ]);
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('bil-ios-ent-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('accepts the raw Code Signing entitlement blob emitted by codesign', () {
    final evidence = File('${temp.path}/entitlements.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist()));

    final result = _verify(evidence);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('SIGNED_IPA_ENTITLEMENTS_GATE=PASS'));
    expect(result.stdout, contains('SIGNED_IPA_EMBEDDED_PROFILE_GATE=PASS'));
  });

  test('accepts a directly decoded XML entitlement plist', () {
    final evidence = File('${temp.path}/entitlements.plist')
      ..writeAsBytesSync(_plist());

    final result = _verify(evidence);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('rejects an inconsistent Code Signing blob length', () {
    final evidence = File('${temp.path}/truncated.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist(), declaredLength: 9));

    final result = _verify(evidence);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('blob length is inconsistent'));
  });

  test('rejects a signed payload without the HealthKit entitlement', () {
    final evidence = File('${temp.path}/wrong-entitlements.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist(healthKit: false)));

    final result = _verify(evidence);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('does not authorize HealthKit'));
  });

  test('rejects a signed payload without the production universal link', () {
    final evidence = File('${temp.path}/missing-associated-domain.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist(associatedDomains: false)));

    final result = _verify(evidence);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('applinks:www.bilhealth.com'));
  });

  test('rejects an embedded profile from a different Apple team', () {
    final evidence = File('${temp.path}/entitlements.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist()));
    final profile = File('${temp.path}/wrong-team-profile.plist')
      ..writeAsBytesSync(_embeddedProfile(teamId: 'ABCDEFGHIJ'));

    final result = _verify(evidence, embeddedProfile: profile);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('expected Apple team'));
  });

  test('rejects capabilities not authorized by the embedded profile', () {
    final evidence = File('${temp.path}/entitlements.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist()));
    final profile = File('${temp.path}/wrong-capability-profile.plist')
      ..writeAsBytesSync(_embeddedProfile(healthKit: false));

    final result = _verify(evidence, embeddedProfile: profile);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('does not authorize HealthKit'));
  });

  test('rejects a profile without production App Attest authorization', () {
    final evidence = File('${temp.path}/entitlements.blob')
      ..writeAsBytesSync(_codeSigningBlob(_plist()));
    final profile = File('${temp.path}/missing-app-attest-profile.plist')
      ..writeAsBytesSync(_embeddedProfile(appAttestEnvironment: null));

    final result = _verify(evidence, embeddedProfile: profile);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('production App Attest'));
  });
}
