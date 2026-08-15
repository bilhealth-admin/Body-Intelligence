import 'dart:convert';

import 'package:body_intelligence_log/features/wellness/domain/workout_release_catalog_item.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String manifest({bool corruptStatus = false}) {
    final rows = <Map<String, Object?>>[];
    for (var index = 0; index < 200; index++) {
      final missing = index >= 192;
      final valid = index < 138;
      rows.add({
        'slotId': 'category-${index ~/ 20}|movement-$index',
        'variationId': 'movement-$index-technique',
        'candidateAvailable': !missing,
        'playable': false,
        'reviewStatus': missing
            ? (corruptStatus ? 'duration_nonconformant' : 'missing_processed')
            : valid
            ? 'duration_valid_awaiting_human_review'
            : 'duration_nonconformant',
        'objectPath': missing
            ? null
            : 'workouts/v1/movements/movement-$index-technique.mp4',
        'sha256': missing ? null : index.toRadixString(16).padLeft(64, '0'),
        'byteLength': missing ? null : 1000 + index,
        'mimeType': missing ? null : 'video/mp4',
        'durationMilliseconds': missing ? null : (valid ? 10000 : 7000),
        'frameCount': missing ? null : (valid ? 300 : 210),
        'fpsNumerator': missing ? null : 30,
        'fpsDenominator': missing ? null : 1,
        'width': missing ? null : 720,
        'height': missing ? null : 1280,
        'codecName': missing ? null : 'h264',
      });
    }
    final digest = sha256.convert(utf8.encode(_canonical(rows))).toString();
    return jsonEncode({
      'schema': 'bil.workout-media.release-manifest.v2',
      'recordCount': 200,
      'summary': {
        'durationValidAwaitingHumanReview': 138,
        'durationNonconformant': 54,
        'missingProcessed': 8,
        'playable': 0,
      },
      'recordsSha256': digest,
      'records': rows,
    });
  }

  test('derives exact 138/54/8 split and keeps all media non-playable', () {
    final items = WorkoutReleaseCatalogRepository.parseManifest(manifest());
    expect(items, hasLength(200));
    expect(
      items.where(
        (item) =>
            item.availability ==
            WorkoutReleaseAvailability.durationValidAwaitingHumanReview,
      ),
      hasLength(138),
    );
    expect(
      items.where(
        (item) =>
            item.availability ==
            WorkoutReleaseAvailability.durationNonconformant,
      ),
      hasLength(54),
    );
    expect(
      items.where(
        (item) => item.availability == WorkoutReleaseAvailability.unavailable,
      ),
      hasLength(8),
    );
    expect(items.every((item) => !item.canPlay), isTrue);
  });

  test('rejects status that contradicts the media evidence', () {
    expect(
      () => WorkoutReleaseCatalogRepository.parseManifest(
        manifest(corruptStatus: true),
      ),
      throwsFormatException,
    );
  });
}

String _canonical(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is int) return value.toString();
  if (value is String) return jsonEncode(value);
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  throw ArgumentError.value(value);
}
