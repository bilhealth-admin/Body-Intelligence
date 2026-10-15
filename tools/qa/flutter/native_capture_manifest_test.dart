import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:flutter_test/flutter_test.dart';

import '../../../test_driver/native_capture_transport.dart';
import 'native_capture_manifest.dart';

const _name = 'coach-reveal-ar-light-normal-first';
const _device = '12345678-1234-1234-1234-123456789abc';
const _container = 'abcdefab-1234-1234-1234-123456789abc';
const _android =
    '/storage/emulated/0/Android/data/com.bilhealth.bodyintelligencelog/files/'
    'feature-splashes-native/$_name.png';
const _ios =
    '/Users/qa/Library/Developer/CoreSimulator/Devices/$_device/data/'
    'Containers/Data/Application/$_container/Documents/'
    'feature-splashes-native/$_name.png';

void main() {
  late Uint8List original;
  NativeCaptureManifest manifest({String? path, String platform = 'android'}) =>
      NativeCaptureManifest.fromPng(
        name: _name,
        platform: platform,
        nativePath: path ?? _android,
        bytes: original,
      );

  setUp(() {
    // Independently encoded synthetic unit data, never a product screenshot or
    // baseline. The native transport never decodes, resizes or re-encodes PNGs.
    final source = image.Image(width: 3, height: 2);
    source.setPixelRgba(1, 1, 17, 59, 103, 255);
    original = image.encodePng(source);
  });

  test('manifest verifies the exact original size hash and dimensions', () {
    final capture = manifest();
    expect(capture.byteCount, original.length);
    expect(capture.sha256Hex, sha256.convert(original).toString());
    expect((capture.widthPixels, capture.heightPixels), (3, 2));
    expect(() => capture.verify(original), returnsNormally);
    expect(jsonEncode(capture.toJson()), isNot(contains('bytes')));
  });

  test('complete PNG required: header alone or missing IEND fails', () {
    expect(
      () => inspectNativeCapturePng(original.sublist(0, 24)),
      throwsFormatException,
    );
    expect(
      () => inspectNativeCapturePng(original.sublist(0, original.length - 12)),
      throwsFormatException,
    );
  });

  test('corrupted compressed image bytes fail PNG chunk CRC', () {
    final changed = Uint8List.fromList(original);
    final idat = ascii.decode(changed, allowInvalid: true).indexOf('IDAT');
    expect(idat, greaterThan(0));
    changed[idat + 4] ^= 1;
    expect(() => inspectNativeCapturePng(changed), throwsFormatException);
  });

  test('manifest size hash and dimensions cannot disagree with PNG', () {
    for (final alteration in <Map<String, Object?>>[
      {'byte_count': original.length + 1},
      {'sha256': '0' * 64},
      {'width_pixels': 4},
      {'height_pixels': 3},
    ]) {
      final capture = NativeCaptureManifest.parse({
        ...manifest().toJson(),
        ...alteration,
      });
      expect(() => capture.verify(original), throwsFormatException);
    }
  });

  test('only the matching persisted SDK entry loses its bytes', () {
    final unrelated = {'screenshotName': 'unrelated', 'bytes': original};
    final report = <String, dynamic>{
      'screenshots': [
        unrelated,
        {'screenshotName': _name, 'bytes': original},
      ],
      'unrelated_metadata': {'keep': true},
    };
    detachPersistedNativeCapture(report, manifest());
    expect(report['screenshots'], [same(unrelated)]);
    expect((report['screenshots'] as List).single['bytes'], same(original));
    expect(report['unrelated_metadata'], {'keep': true});
  });

  for (final mode in ['missing', 'duplicate', 'changed']) {
    test('SDK $mode capture fails without removing another entry', () {
      final valid = {'screenshotName': _name, 'bytes': original};
      final entries = <Map<String, Object?>>[
        if (mode != 'missing') valid,
        if (mode == 'duplicate') {...valid},
      ];
      if (mode == 'changed') {
        entries.single['bytes'] = original.sublist(0, original.length - 1);
      }
      final report = <String, dynamic>{'screenshots': entries};
      final before = jsonEncode(entries);
      expect(
        () => detachPersistedNativeCapture(report, manifest()),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
      expect(jsonEncode(entries), before);
    });
  }

  test('malformed or duplicated manifest data is rejected', () {
    expect(() => readNativeCaptureManifest(null), throwsFormatException);
    expect(
      () => readNativeCaptureManifest({
        'schema': 1,
        'captures': [manifest().toJson(), manifest().toJson()],
      }),
      throwsFormatException,
    );
    for (final invalid in <Map<String, Object?>>[
      {'schema': 2},
      {'byte_count': '12'},
      {'name': '$_name\n'},
      {'platform': 'macos'},
    ]) {
      expect(
        () => NativeCaptureManifest.parse({...manifest().toJson(), ...invalid}),
        throwsFormatException,
      );
    }
  });

  test('Android selected serial is passed as literal adb argv (5580)', () {
    expect(nativeCaptureAdbArguments(manifest(), deviceId: 'emulator-5580'), [
      '-s',
      'emulator-5580',
      'exec-out',
      'cat',
      _android,
    ]);
    expect(
      () => validateNativeCapturePath(
        manifest(path: _android.replaceFirst('/storage/emulated/0', '/sdcard')),
        deviceId: 'emulator-5580',
      ),
      returnsNormally,
    );
  });

  test('Android cannot read databases foreign files or shell paths', () {
    for (final path in [
      _android.replaceFirst('feature-splashes-native', 'databases'),
      _android.replaceFirst('com.bilhealth', 'com.other'),
      _android.replaceFirst('feature-splashes-native/', '../'),
      '$_android;id',
      '$_android\n',
    ]) {
      expect(
        () => validateNativeCapturePath(
          manifest(path: path),
          deviceId: 'emulator-5580',
        ),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
    }
    expect(
      () => validateNativeCapturePath(manifest(), deviceId: 'emulator-5580;id'),
      throwsStateError,
    );
  });

  test('iOS selected simulator owns its precise Documents capture path', () {
    final capture = manifest(path: _ios, platform: 'ios');
    expect(
      () => validateNativeCapturePath(capture, deviceId: _device),
      returnsNormally,
    );
    for (final path in [
      _ios.replaceFirst('/Documents/', '/Library/'),
      _ios.replaceFirst('feature-splashes-native', 'private-data'),
      _ios.replaceFirst('/Documents/', '/Documents/../Documents/'),
      '$_ios.png',
    ]) {
      expect(
        () => validateNativeCapturePath(
          manifest(path: path, platform: 'ios'),
          deviceId: _device,
        ),
        throwsStateError,
      );
    }
    expect(
      () => validateNativeCapturePath(capture, deviceId: _container),
      throwsStateError,
    );
  });

  Future<Directory> outputDirectory() async {
    final parent = Directory('build/qa/policy-gate-20261015/capture-unit');
    await parent.create(recursive: true);
    final output = await parent.createTemp('owned-');
    addTearDown(() => output.delete(recursive: true));
    return output;
  }

  test(
    'transport saves original PNG unchanged and records selected device',
    () async {
      final output = await outputDirectory();
      final transport = NativeCaptureTransport(
        deviceId: 'emulator-5580',
        reader: (capture, serial, timeout) async {
          expect(serial, 'emulator-5580');
          expect(capture.nativePath, _android);
          return original;
        },
      );
      final evidence = await transport.collect(manifest(), output);
      expect(await File('${output.path}/$_name.png').readAsBytes(), original);
      expect(evidence['selected_device'], 'emulator-5580');
      expect(evidence['sha256'], sha256.convert(original).toString());
    },
  );

  test('invalid path is rejected before the native reader runs', () async {
    final output = await outputDirectory();
    var reads = 0;
    final transport = NativeCaptureTransport(
      deviceId: 'emulator-5580',
      reader: (_, _, _) async {
        reads++;
        return original;
      },
    );
    await expectLater(
      transport.collect(manifest(path: '/private/secret.png'), output),
      throwsStateError,
    );
    expect(reads, 0);
    expect(await output.list().isEmpty, isTrue);
  });

  for (final mode in ['missing', 'corrupt', 'timeout']) {
    test('transport $mode image fails without manufacturing a PNG', () async {
      final output = await outputDirectory();
      final transport = NativeCaptureTransport(
        deviceId: 'emulator-5580',
        timeout: const Duration(milliseconds: 20),
        reader: (_, _, _) async {
          if (mode == 'missing') throw const FileSystemException('missing');
          if (mode == 'timeout') return Completer<List<int>>().future;
          return original.sublist(0, original.length - 1);
        },
      );
      await expectLater(
        transport.collect(manifest(), output),
        throwsA(
          anyOf(
            isA<FileSystemException>(),
            isA<FormatException>(),
            isA<TimeoutException>(),
          ),
        ),
      );
      expect(await output.list().isEmpty, isTrue);
    });
  }
}
