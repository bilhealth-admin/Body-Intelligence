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
      if (selected is! List || selected.isEmpty || selected.length > 4) {
        throw StateError('Explicit native scene selection is missing.');
      }
      // Preserve partial evidence on failure rather than manufacturing a full pass.
      if (scenes is! List ||
          scenes.length !=
              (coachOnly || conversationOnly ? 0 : selected.length) ||
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
          reveal.length != (conversationOnly ? 0 : selected.length) ||
          history is! List ||
          history.length != (conversationOnly ? 0 : selected.length) ||
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
      final expectedPlans =
          !coachOnly && !conversationOnly && selected.length == 4 ? 16 : 0;
      final expectedConversations = !coachOnly && selected.length == 4 ? 8 : 0;
      final expectedStoreActivity = !coachOnly && selected.length == 4 ? 4 : 0;
      if (data?['community_conversations_expected'] != expectedConversations ||
          data?['store_activity_expected'] != expectedStoreActivity ||
          conversations is! List ||
          conversations.length != expectedConversations ||
          storeActivity is! List ||
          storeActivity.length != expectedStoreActivity ||
          conversations.any(
            (row) =>
                row is! Map ||
                row['completed'] != true ||
                row['one_send'] != true ||
                row['network_requests'] != 0,
          ) ||
          storeActivity.any(
            (row) =>
                row is! Map ||
                row['completed'] != true ||
                row['one_indicator_above_cta'] != true ||
                row['purchase_requests'] != 0,
          )) {
        throw StateError('Native Community/checkout evidence is incomplete.');
      }
      final plans = data?['smart_plan_native'] ?? const [];
      if (data?['smart_plan_native_expected'] != expectedPlans ||
          plans is! List ||
          plans.length != expectedPlans ||
          plans.any(
            (plan) =>
                plan is! Map ||
                plan['completed'] != true ||
                plan['navigation_forward_and_back'] != 'PASS' ||
                plan['completion_recorded'] != false,
          )) {
        throw StateError('Native Smart Plan session evidence is incomplete');
      }
      if (names.length !=
          scenes.length * 12 +
              reveal.length * 3 +
              history.length * 3 +
              expectedPlans * 2 +
              expectedConversations * 2 +
              expectedStoreActivity) {
        throw StateError(
          'Required welcome/released and Coach first/mid/end/history PNGs are incomplete',
        );
      }
      if (expectedConversations != 0) {
        for (final language in ['ar', 'en']) {
          for (final brightness in ['dark', 'light']) {
            if (!names.contains(
              'bil39-store-$language-$brightness-2x-pending',
            )) {
              throw StateError('Missing native checkout waiting PNG');
            }
            for (final scale in [1, 2]) {
              for (final phase in ['reply', 'sent']) {
                if (!names.contains(
                  'bil39-community-$language-$brightness-${scale}x-$phase',
                )) {
                  throw StateError('Missing native conversation PNG');
                }
              }
            }
          }
        }
      }
      if (expectedPlans != 0) {
        for (final environment in ['home', 'gym']) {
          for (final language in ['ar', 'en']) {
            for (final brightness in ['dark', 'light']) {
              for (final scale in [1, 2]) {
                for (final phase in ['warmup', 'session']) {
                  if (!names.contains(
                    'bil39-plan-$environment-$language-$brightness-${scale}x-$phase',
                  )) {
                    throw StateError('Missing native Smart Plan PNG');
                  }
                }
              }
            }
          }
        }
      }
      for (final label in selected) {
        for (final kind
            in coachOnly || conversationOnly
                ? <String>[]
                : [
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
        for (final phase
            in conversationOnly ? <String>[] : ['first', 'mid', 'end']) {
          if (!names.contains('coach-reveal-$label-$phase')) {
            throw StateError('Missing reveal PNG');
          }
        }
        for (final phase
            in conversationOnly ? <String>[] : ['reading', 'mid', 'end']) {
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
