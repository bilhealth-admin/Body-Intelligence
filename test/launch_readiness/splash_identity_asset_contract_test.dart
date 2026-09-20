import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _canonicalPath = 'assets/branding/bil_splash_identity.png';
const _nativePaths = <String>[
  'ios/Runner/Assets.xcassets/BILLaunchWordmark.imageset/'
      'BILLaunchWordmark.png',
  'android/app/src/main/res/drawable-nodpi/bil_splash_identity.png',
];
const _approvedSha256 =
    'ec56f3c02556f0f5a9736f65f3eef2be1b961d497715da788529dde6bc237429';

void main() {
  test('approved splash identity is exact and byte-identical natively', () {
    final canonical = File(_canonicalPath).readAsBytesSync();
    expect(_pngSize(canonical), (1080, 1080));
    expect(sha256.convert(canonical).toString(), _approvedSha256);

    for (final path in _nativePaths) {
      final native = File(path).readAsBytesSync();
      expect(_pngSize(native), (1080, 1080), reason: path);
      expect(native, orderedEquals(canonical), reason: path);
    }
  });

  test('iOS launch metadata preserves the complete approved identity', () {
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    final catalog = File(
      'ios/Runner/Assets.xcassets/BILLaunchWordmark.imageset/Contents.json',
    ).readAsStringSync();

    expect(storyboard, contains('contentMode="scaleAspectFit"'));
    expect(
      storyboard,
      contains('<image name="BILLaunchWordmark" width="1080" height="1080"/>'),
    );
    expect(catalog, contains('BILLaunchWordmark.png'));
  });

  test('retired 864 generator fails before any asset write', () {
    final generator = File('tool/branding/generate_splash_wordmark.ps1');
    final source = generator.readAsStringSync();

    for (final mutation in <String>[
      'Copy-Item',
      '.Save(',
      'System.Drawing.Bitmap',
      'File]::Delete',
    ]) {
      expect(source, isNot(contains(mutation)), reason: mutation);
    }
    expect(source, contains('RETIRED, FAIL CLOSED'));

    if (!Platform.isWindows) return;
    final before = <String, String>{
      for (final path in [_canonicalPath, ..._nativePaths])
        path: sha256.convert(File(path).readAsBytesSync()).toString(),
    };
    final result = Process.runSync('powershell.exe', const [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'tool/branding/generate_splash_wordmark.ps1',
    ]);
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('RETIRED'));
    for (final entry in before.entries) {
      expect(
        sha256.convert(File(entry.key).readAsBytesSync()).toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });
}

(int, int) _pngSize(List<int> bytes) {
  expect(bytes.length, greaterThanOrEqualTo(24));
  expect(bytes.take(8), orderedEquals(const [137, 80, 78, 71, 13, 10, 26, 10]));
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (data.getUint32(16), data.getUint32(20));
}
