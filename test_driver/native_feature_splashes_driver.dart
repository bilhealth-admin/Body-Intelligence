import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

// Host-only collector. No generated video, baseline updates, app/cloud writes.
Future<void> main() async {
  final output = Directory(
    Platform.environment['BIL_FEATURE_NATIVE_OUTPUT'] ??
        'build/stage1-closure/feature-splashes-pearl-20261013/native-evidence',
  );
  await output.create(recursive: true);
  final captures = <Map<String, Object?>>[];
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(
            r'^(recipes|videos|sleep|diet|coach|community)-(ar|en)-light-(normal|reduced)-(welcome|released)$',
          ).hasMatch(name) &&
          !RegExp(
            r'^coach-(reveal|history)-(ar|en)-light-(normal|reduced)-(first|reading|mid|end)$',
          ).hasMatch(name)) {
        throw StateError('Unexpected native screenshot label');
      }
      const header = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < 24 ||
          List.generate(8, (i) => bytes[i] == header[i]).contains(false)) {
        throw StateError('Native screenshot must be valid PNG data');
      }
      final png = ByteData.sublistView(Uint8List.fromList(bytes));
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      captures.add({
        'name': name,
        'sha256': sha256.convert(bytes).toString(),
        'width_pixels': png.getUint32(16),
        'height_pixels': png.getUint32(20),
        'byte_count': bytes.length,
        'classification':
            'native Flutter screenshot captured by integration_test',
      });
      return true;
    },
    responseDataCallback: (data) async {
      final scenes = data?['native_feature_splashes'];
      final reveal = data?['native_coach_reveal'];
      final history = data?['native_coach_history'];
      await File('${output.path}/native-metadata.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'scenes': scenes,
          'coach_reveal': reveal,
          'coach_history': history,
          'captures': captures,
        }),
        flush: true,
      );
      // Preserve partial evidence on failure rather than manufacturing a full pass.
      if (scenes is! List ||
          scenes.isEmpty ||
          scenes.any(
            (scene) =>
                scene is! Map ||
                scene['timings'] is! List ||
                (scene['timings'] as List).length != 6,
          )) {
        throw StateError(
          'Native six-entry evidence is incomplete; inspect retained metadata',
        );
      }
      if (reveal is! List ||
          reveal.length != scenes.length ||
          history is! List ||
          history.length != scenes.length ||
          [...reveal, ...history].any(
            (scene) =>
                scene is! Map ||
                scene['completed'] != true ||
                scene['capture_windows'] is! List ||
                (scene['capture_windows'] as List).length != 3,
          )) {
        throw StateError(
          'Native Coach reveal/history evidence is incomplete; inspect retained frame metadata',
        );
      }
      final names = captures.map((item) => item['name']).toSet();
      if (names.length !=
          scenes.length * 12 + reveal.length * 3 + history.length * 3) {
        throw StateError(
          'Required welcome/released and Coach first/mid/end/history PNGs are incomplete',
        );
      }
      for (final scene in scenes) {
        final label = (scene as Map)['scene'];
        for (final kind in [
          'recipes',
          'videos',
          'sleep',
          'diet',
          'coach',
          'community',
        ]) {
          for (final phase in ['welcome', 'released']) {
            if (!names.contains('$kind-$label-$phase')) {
              throw StateError('Missing entry PNG');
            }
          }
        }
        for (final phase in ['first', 'mid', 'end']) {
          if (!names.contains('coach-reveal-$label-$phase')) {
            throw StateError('Missing reveal PNG');
          }
        }
        for (final phase in ['reading', 'mid', 'end']) {
          if (!names.contains('coach-history-$label-$phase')) {
            throw StateError('Missing history PNG');
          }
        }
      }
      stdout.writeln(
        'Native evidence saved: ${scenes.length} entry scenes / '
        '${reveal.length} reply scenes / ${history.length} history scenes / ${captures.length} PNGs',
      );
    },
  );
}
