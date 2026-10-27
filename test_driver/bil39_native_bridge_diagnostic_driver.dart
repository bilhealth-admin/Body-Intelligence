import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

import '../tools/qa/flutter/native_capture_manifest.dart';
import 'native_capture_transport.dart';

// Host-only collector. No generated video, baseline updates, app/cloud writes.
Future<void> main() async {
  final output = Directory(
    Platform.environment['BIL_FEATURE_NATIVE_OUTPUT'] ??
        'build/stage1-closure/feature-splashes-pearl-20261013/native-evidence',
  );
  await output.create(recursive: true);
  final captures = <Map<String, Object?>>[];
  final transport = NativeCaptureTransport(
    deviceId: Platform.environment['BIL_NATIVE_CAPTURE_DEVICE_ID'] ?? '',
  );
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!isNativeCaptureName(name) ||
          captures.any((capture) => capture['name'] == name)) {
        throw StateError('Unexpected native screenshot label');
      }
      // Compatibility with old SDK report entries, validated as strictly as
      // manifest captures. New native captures use the bounded transport below.
      final png = inspectNativeCapturePng(bytes);
      final capture = NativeCaptureManifest.fromPng(
        name: name,
        platform: Platform.isMacOS ? 'ios' : 'android',
        nativePath: '/legacy-sdk-entry/$name.png',
        bytes: bytes,
      );
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      capture.verify(await File('${output.path}/$name.png').readAsBytes());
      captures.add({
        'name': name,
        'sha256': capture.sha256Hex,
        'width_pixels': png.width,
        'height_pixels': png.height,
        'byte_count': bytes.length,
        'classification':
            'native Flutter screenshot captured by integration_test',
      });
      return true;
    },
    responseDataCallback: (data) async {
      final coachOnly = data?['native_scope'] == 'coach-only';
      final conversationOnly = data?['native_scope'] == 'conversations-only';
      final selected = data?['native_scenes'];
      final scenes =
          data?['native_feature_splashes'] ??
          (coachOnly || conversationOnly ? [] : null);
      final reveal =
          data?['native_coach_reveal'] ?? (conversationOnly ? [] : null);
      final history =
          data?['native_coach_history'] ?? (conversationOnly ? [] : null);
      final conversations = data?['community_conversations_native'] ?? const [];
      final storeActivity = data?['store_activity_native'] ?? const [];
      Object? collectionFailure;
      final collectionFailures = <Map<String, Object?>>[];
      Future<void> checkpoint() async {
        await File('${output.path}/native-metadata.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'diagnostic_only_not_release_acceptance': true,
            'native_bridge_diagnostics': data?['native_bridge_diagnostics'],
            'scope': data?['native_scope'],
            'selected_scenes': selected,
            'scenes': scenes,
            'coach_reveal': reveal,
            'coach_history': history,
            'community_conversations': conversations,
            'store_activity': storeActivity,
            'native_capture_manifest': data?[nativeCaptureManifestKey],
            'collection_error': collectionFailure?.toString(),
            'collection_failures': collectionFailures,
            'collection_concurrency_limit': nativeCaptureCollectionConcurrency,
            'captures': captures,
          }),
          flush: true,
        );
      }

      try {
        final manifest = data?[nativeCaptureManifestKey];
        if (manifest != null) {
          final entries = readNativeCaptureManifest(manifest);
          await transport.collectAll(
            entries,
            output,
            captures: captures,
            onProgress: (failures) async {
              collectionFailures.addAll(failures);
              if (failures.isNotEmpty) collectionFailure = failures.first;
              await checkpoint();
            },
          );
        }
      } catch (error) {
        collectionFailure = error;
        rethrow;
      } finally {
        // Save valid partial originals/manifest before propagating any error.
        await checkpoint();
      }
      const expectedNames = {
        'bil39-community-ar-dark-1x',
        'bil39-community-en-light-2x',
        'bil39-community-en-dark-2x',
      };
      if (data?['bridge_diagnostic_only_not_release_acceptance'] != true ||
          reveal is! List ||
          reveal.length != 1 ||
          history is! List ||
          history.isNotEmpty ||
          conversations is! List ||
          conversations.length != 3 ||
          reveal.single['scene'] != 'ar-light-normal' ||
          reveal.single['mode'] != 'reveal' ||
          captures.length != 9 ||
          conversations
              .map((row) => row['name'])
              .toSet()
              .difference(expectedNames)
              .isNotEmpty ||
          reveal.single['completed'] != true ||
          conversations.any(
            (row) =>
                row['completed'] != true ||
                row['one_send'] != true ||
                row['network_requests'] != 0,
          )) {
        throw StateError(
          'Four actual bridge discovery cases did not complete; not release acceptance.',
        );
      }
    },
  );
}
