import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../domain/workout_release_catalog_item.dart';

class WorkoutReleaseCatalogRepository {
  const WorkoutReleaseCatalogRepository();

  static const assetPath =
      'artifacts/workout_media/workout_release_manifest_v2.json';
  static Future<List<WorkoutReleaseCatalogItem>>? _cached;

  Future<List<WorkoutReleaseCatalogItem>> load() {
    final current = _cached;
    if (current != null) return current;
    final future = rootBundle.loadString(assetPath).then(parseManifest);
    _cached = future;
    future.catchError((Object _) {
      if (identical(_cached, future)) _cached = null;
      return <WorkoutReleaseCatalogItem>[];
    });
    return future;
  }

  static List<WorkoutReleaseCatalogItem> parseManifest(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Workout manifest must be an object.');
    }
    _keys(decoded, const {
      'schema',
      'recordCount',
      'summary',
      'recordsSha256',
      'records',
    });
    if (decoded['schema'] != 'bil.workout-media.release-manifest.v2' ||
        decoded['recordCount'] != 200) {
      throw const FormatException('Unsupported workout release manifest.');
    }
    final summary = decoded['summary'];
    if (summary is! Map<String, dynamic>) {
      throw const FormatException('Workout summary must be an object.');
    }
    _keys(summary, const {
      'durationValidAwaitingHumanReview',
      'durationNonconformant',
      'missingProcessed',
      'playable',
    });
    if (summary['durationValidAwaitingHumanReview'] != 138 ||
        summary['durationNonconformant'] != 54 ||
        summary['missingProcessed'] != 8 ||
        summary['playable'] != 0) {
      throw const FormatException('Workout summary is invalid.');
    }
    final rawRows = decoded['records'];
    if (rawRows is! List || rawRows.length != 200) {
      throw const FormatException('Workout manifest must contain 200 rows.');
    }
    final expectedDigest = decoded['recordsSha256'];
    if (expectedDigest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedDigest) ||
        sha256.convert(utf8.encode(_canonical(rawRows))).toString() !=
            expectedDigest) {
      throw const FormatException('Workout records digest is invalid.');
    }

    final ids = <String>{};
    final slots = <String>{};
    final result = <WorkoutReleaseCatalogItem>[];
    var valid = 0, nonconformant = 0, missing = 0;
    for (final raw in rawRows) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Workout row must be an object.');
      }
      _keys(raw, const {
        'slotId',
        'variationId',
        'candidateAvailable',
        'playable',
        'reviewStatus',
        'objectPath',
        'sha256',
        'byteLength',
        'mimeType',
        'durationMilliseconds',
        'frameCount',
        'fpsNumerator',
        'fpsDenominator',
        'width',
        'height',
        'codecName',
      });
      final slot = _text(raw['slotId'], 'slotId');
      final id = _text(raw['variationId'], 'variationId');
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id) ||
          !slots.add(slot) ||
          !ids.add(id) ||
          raw['playable'] != false) {
        throw const FormatException(
          'Workout row identity/play gate is invalid.',
        );
      }
      final status = raw['reviewStatus'];
      if (status == 'missing_processed') {
        if (raw['candidateAvailable'] != false) {
          throw const FormatException('Missing workout cannot be available.');
        }
        for (final key in const {
          'objectPath',
          'sha256',
          'byteLength',
          'mimeType',
          'durationMilliseconds',
          'frameCount',
          'fpsNumerator',
          'fpsDenominator',
          'width',
          'height',
          'codecName',
        }) {
          if (raw[key] != null) {
            throw const FormatException('Missing workout has media claims.');
          }
        }
        missing++;
        result.add(
          WorkoutReleaseCatalogItem(
            slot: slot,
            variationId: id,
            expectedSha256: null,
            expectedBytes: null,
            durationMilliseconds: null,
            frameCount: null,
            availability: WorkoutReleaseAvailability.unavailable,
          ),
        );
        continue;
      }
      if (raw['candidateAvailable'] != true ||
          raw['objectPath'] != 'workouts/v1/movements/$id.mp4' ||
          raw['mimeType'] != 'video/mp4') {
        throw const FormatException('Workout media locator is invalid.');
      }
      final digest = _text(raw['sha256'], 'sha256');
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw const FormatException('Workout SHA-256 is invalid.');
      }
      final bytes = _positiveInt(raw['byteLength'], 'byteLength');
      final duration = _positiveInt(
        raw['durationMilliseconds'],
        'durationMilliseconds',
      );
      final frames = _positiveInt(raw['frameCount'], 'frameCount');
      final fpsNumerator = _positiveInt(raw['fpsNumerator'], 'fpsNumerator');
      final fpsDenominator = _positiveInt(
        raw['fpsDenominator'],
        'fpsDenominator',
      );
      final width = _positiveInt(raw['width'], 'width');
      final height = _positiveInt(raw['height'], 'height');
      final codecName = _text(raw['codecName'], 'codecName');
      final conforms =
          duration == 10000 &&
          frames == 300 &&
          fpsNumerator == 30 &&
          fpsDenominator == 1 &&
          width == 720 &&
          height == 1280 &&
          codecName == 'h264';
      final expectedStatus = conforms
          ? 'duration_valid_awaiting_human_review'
          : 'duration_nonconformant';
      if (status != expectedStatus) {
        throw const FormatException('Workout evidence/status mismatch.');
      }
      if (conforms) {
        valid++;
      } else {
        nonconformant++;
      }
      result.add(
        WorkoutReleaseCatalogItem(
          slot: slot,
          variationId: id,
          expectedSha256: digest,
          expectedBytes: bytes,
          durationMilliseconds: duration,
          frameCount: frames,
          availability: conforms
              ? WorkoutReleaseAvailability.durationValidAwaitingHumanReview
              : WorkoutReleaseAvailability.durationNonconformant,
        ),
      );
    }
    if (valid != 138 || nonconformant != 54 || missing != 8) {
      throw const FormatException('Workout release distribution is invalid.');
    }
    return List.unmodifiable(result);
  }

  static void _keys(Map<String, dynamic> value, Set<String> expected) {
    if (value.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('Workout manifest fields are invalid.');
    }
  }

  static String _text(Object? value, String field) {
    if (value is! String || value.isEmpty || value != value.trim()) {
      throw FormatException('$field is invalid.');
    }
    return value;
  }

  static int _positiveInt(Object? value, String field) {
    if (value is! int || value <= 0) {
      throw FormatException('$field is invalid.');
    }
    return value;
  }

  static String _canonical(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is int) return value.toString();
    if (value is String) return jsonEncode(value);
    if (value is List) return '[${value.map(_canonical).join(',')}]';
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
    }
    throw const FormatException('Unsupported workout manifest value.');
  }
}
