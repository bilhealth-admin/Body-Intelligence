import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _teamId = '43F9Y5Y96K';
const _bundleId = 'com.bilhealth.bodyintelligencelog';

String get _python => Platform.isWindows ? 'python' : 'python3';

List<int> _plist({bool healthKit = true}) => utf8.encode(
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
  <key>aps-environment</key>
  <string>production</string>
  <key>get-task-allow</key>
  <false/>
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

ProcessResult _verify(File evidence) => Process.runSync(_python, <String>[
  'tool/release/verify_signed_ios_entitlements.py',
  '--entitlements',
  evidence.path,
  '--team-id',
  _teamId,
  '--bundle-id',
  _bundleId,
]);

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
}
