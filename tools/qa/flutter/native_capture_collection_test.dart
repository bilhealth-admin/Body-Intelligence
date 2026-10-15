import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:flutter_test/flutter_test.dart';

import '../../../test_driver/native_capture_transport.dart';
import 'native_capture_manifest.dart';

const _root =
    '/storage/emulated/0/Android/data/com.bilhealth.bodyintelligencelog/files/'
    'feature-splashes-native';
const _names = [
  'recipes-ar-light-normal-welcome',
  'recipes-ar-light-normal-released',
  'videos-ar-light-normal-welcome',
  'videos-ar-light-normal-released',
  'sleep-ar-light-normal-welcome',
  'sleep-ar-light-normal-released',
  'diet-ar-light-normal-welcome',
  'diet-ar-light-normal-released',
  'coach-ar-light-normal-welcome',
  'coach-ar-light-normal-released',
  'community-ar-light-normal-welcome',
  'community-ar-light-normal-released',
];

void main() {
  late Uint8List png;
  NativeCaptureManifest capture(int index, {String? path}) =>
      NativeCaptureManifest.fromPng(
        name: _names[index],
        platform: 'android',
        nativePath: path ?? '$_root/${_names[index]}.png',
        bytes: png,
      );
  Future<Directory> outputDirectory() async {
    final parent = Directory(
      'build/qa/policy-gate-20261015/capture-collection-unit',
    ).absolute;
    await parent.create(recursive: true);
    final output = await parent.createTemp('owned-');
    addTearDown(() async {
      if (!output.absolute.path.startsWith(
        '${parent.path}${Platform.pathSeparator}',
      )) {
        throw StateError('Unit cleanup escaped its owned output directory');
      }
      await output.delete(recursive: true);
    });
    return output;
  }

  setUp(() {
    // Independently generated unit PNG, never a product screenshot/baseline.
    png = image.encodePng(image.Image(width: 3, height: 2));
  });

  test(
    'four readers preserve manifest order despite reverse completion',
    () async {
      final output = await outputDirectory();
      final gates = [for (var i = 0; i < 8; i++) Completer<void>()];
      final firstBatch = Completer<void>(), secondBatch = Completer<void>();
      final partialReadersDone = Completer<void>();
      final started = <int>[];
      var active = 0, maximum = 0, firstReadersEnded = 0;
      final captures = <Map<String, Object?>>[
        {'name': _names[11]},
      ];
      final checkpoints = <List<String>>[];
      final transport = NativeCaptureTransport(
        deviceId: 'emulator-5580',
        reader: (value, _, _) async {
          final index = _names.indexOf(value.name);
          started.add(index);
          active++;
          if (active > maximum) maximum = active;
          if (started.length == 4) firstBatch.complete();
          if (started.length == 8) secondBatch.complete();
          try {
            await gates[index].future;
            return png;
          } finally {
            active--;
            if (index > 0 && index < 4 && ++firstReadersEnded == 3) {
              partialReadersDone.complete();
            }
          }
        },
      );
      final task = transport.collectAll(
        [for (var i = 0; i < 8; i++) capture(i)],
        output,
        captures: captures,
        onProgress: (failures) async {
          expect(failures, isEmpty);
          checkpoints.add(
            captures.map((value) => value['name']! as String).toList(),
          );
        },
      );
      final completion = expectLater(task, completes);
      await firstBatch.future.timeout(const Duration(seconds: 5));
      for (final index in [3, 2, 1]) {
        gates[index].complete();
      }
      await partialReadersDone.future.timeout(const Duration(seconds: 5));
      expect(started, [0, 1, 2, 3]);
      gates[0].complete();
      await secondBatch.future.timeout(const Duration(seconds: 5));
      expect(captures.map((value) => value['name']), [
        _names[11],
        ..._names.take(4),
      ]);
      for (final index in [7, 6, 5, 4]) {
        gates[index].complete();
      }
      await completion;
      expect(maximum, 4);
      expect(active, 0);
      expect(started.toSet().length, 8);
      expect(captures.map((value) => value['name']), [
        _names[11],
        ..._names.take(8),
      ]);
      expect(checkpoints.map((value) => value.length), [5, 9]);
      for (var i = 0; i < 8; i++) {
        expect(
          await File('${output.path}/${_names[i]}.png').readAsBytes(),
          png,
        );
      }
    },
  );

  test(
    'failed batch retains prefix and valid peers before error escapes',
    () async {
      final output = await outputDirectory();
      final captures = <Map<String, Object?>>[];
      final checkpoints = <(int, List<String>)>[];
      final reads = <int>[];
      final transport = NativeCaptureTransport(
        deviceId: 'emulator-5580',
        reader: (value, _, _) async {
          final index = _names.indexOf(value.name);
          reads.add(index);
          if (index == 4 || index == 7) {
            throw const FileSystemException('unit missing');
          }
          return png;
        },
      );
      await expectLater(
        transport.collectAll(
          [for (var i = 0; i < 12; i++) capture(i)],
          output,
          captures: captures,
          onProgress: (failures) async => checkpoints.add((
            captures.length,
            failures.map((value) => value['name']! as String).toList(),
          )),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(reads, List.generate(8, (i) => i));
      expect(captures.map((value) => value['name']), [
        ..._names.take(4),
        _names[5],
        _names[6],
      ]);
      expect(checkpoints.map((value) => value.$1), [4, 6]);
      expect(checkpoints.map((value) => value.$2), [
        <String>[],
        [_names[4], _names[7]],
      ]);
      expect(await output.list().length, 6);
    },
  );

  test(
    'hung reader times out without losing peers or starting later batch',
    () async {
      final output = await outputDirectory();
      var reads = 0;
      final captures = <Map<String, Object?>>[];
      final observedErrors = <String>[];
      final transport = NativeCaptureTransport(
        deviceId: 'emulator-5580',
        timeout: const Duration(milliseconds: 30),
        reader: (value, _, _) async {
          reads++;
          if (value.name == _names[0]) return Completer<List<int>>().future;
          return png;
        },
      );
      await expectLater(
        transport.collectAll(
          [for (var i = 0; i < 8; i++) capture(i)],
          output,
          captures: captures,
          onProgress: (failures) async {
            observedErrors.addAll(
              failures.map((value) => value['error_type']! as String),
            );
            expect(
              captures.map((value) => value['name']),
              _names.skip(1).take(3),
            );
          },
        ),
        throwsA(isA<TimeoutException>()),
      ).timeout(const Duration(seconds: 3));
      expect(reads, 4);
      expect(observedErrors, ['TimeoutException']);
      expect(await output.list().length, 3);
    },
  );

  for (final existingCollision in [false, true]) {
    test(
      'duplicate ${existingCollision ? 'SDK prefix' : 'manifest'} starts no reader',
      () async {
        final output = await outputDirectory();
        var reads = 0;
        final captures = <Map<String, Object?>>[
          if (existingCollision) {'name': _names[0]},
        ];
        final transport = NativeCaptureTransport(
          deviceId: 'emulator-5580',
          reader: (_, _, _) async {
            reads++;
            return png;
          },
        );
        await expectLater(
          transport.collectAll(
            [capture(0), if (!existingCollision) capture(0)],
            output,
            captures: captures,
          ),
          throwsStateError,
        );
        expect(reads, 0);
        expect(await output.list().isEmpty, isTrue);
        expect(captures.length, existingCollision ? 1 : 0);
      },
    );
  }

  test('a late foreign path rejects the entire queue before reading', () async {
    final output = await outputDirectory();
    var reads = 0;
    final transport = NativeCaptureTransport(
      deviceId: 'emulator-5580',
      reader: (_, _, _) async {
        reads++;
        return png;
      },
    );
    await expectLater(
      transport.collectAll(
        [capture(0), capture(1, path: '/private/secret.png')],
        output,
        captures: [],
      ),
      throwsStateError,
    );
    expect(reads, 0);
    expect(await output.list().isEmpty, isTrue);
  });

  test(
    'bad original PNG fails verification while valid batch peers remain',
    () async {
      final output = await outputDirectory();
      final captures = <Map<String, Object?>>[];
      final transport = NativeCaptureTransport(
        deviceId: 'emulator-5580',
        reader: (value, _, _) async =>
            value.name == _names[0] ? png.sublist(0, png.length - 1) : png,
      );
      await expectLater(
        transport.collectAll(
          [for (var i = 0; i < 4; i++) capture(i)],
          output,
          captures: captures,
        ),
        throwsFormatException,
      );
      expect(captures.map((value) => value['name']), _names.skip(1).take(3));
      expect(await File('${output.path}/${_names[0]}.png').exists(), isFalse);
    },
  );

  test('checkpoint failure remains fatal and stops later readers', () async {
    final output = await outputDirectory();
    var reads = 0;
    final captures = <Map<String, Object?>>[];
    final transport = NativeCaptureTransport(
      deviceId: 'emulator-5580',
      reader: (_, _, _) async {
        reads++;
        return png;
      },
    );
    await expectLater(
      transport.collectAll(
        [for (var i = 0; i < 8; i++) capture(i)],
        output,
        captures: captures,
        onProgress: (_) async =>
            throw const FileSystemException('unit checkpoint failure'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(reads, 4);
    expect(captures.map((value) => value['name']), _names.take(4));
  });
}
