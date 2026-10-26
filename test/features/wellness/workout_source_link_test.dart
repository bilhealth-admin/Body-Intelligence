import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/workout_source_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every approved movement maps to public provenance without changing its playback/catalog URL',
    () {
      final document =
          jsonDecode(
                File(
                  'artifacts/workout_media/cloudflare_runtime_v2/workout_source_pages_v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final entries = document['entries'] as Map<String, dynamic>;
      expect(entries.length, 302);
      for (final key in entries.keys) {
        final original = Uri.parse(
          'https://workouts.bilhealth.com/v2/objects/$key',
        );
        final before = original.toString();
        final source = workoutOriginalSourcePage(original);
        expect(
          source.toString(),
          'https://workouts.bilhealth.com/v2/source/$key',
        );
        expect(source!.hasQuery, isFalse);
        expect(source.userInfo, isEmpty);
        expect(workoutOriginalSourcePage(source), source);
        expect(original.toString(), before);
      }
    },
  );
  for (final url in [
    'http://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/chair-squat.mp4',
    'https://user:secret@workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/chair-squat.mp4',
    'https://workouts.bilhealth.com:8443/v2/objects/workouts/v1/home/movements/chair-squat.mp4',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/chair-squat.mp4?token=secret',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/chair-squat.mp4#private',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/../private.mp4',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/%2e%2e%2fprivate.mp4',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/%252e%252e%252fprivate.mp4',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/chair_squat.mp4',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/other/movements/chair-squat.mp4',
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/chair-squat.webm',
    'https://workouts.bilhealth.com/v2/objects/private.json',
    'https://localhost/private',
    'https://127.0.0.1/private',
    'https://[::1]/private',
    'https://bilhealth.com/reference?ACCESS_TOKEN=secret',
    'https://bilhealth.com/reference?%FF=invalid',
    'javascript:alert(1)',
  ]) {
    test(
      'unsafe or noncanonical source is not sent to an external browser: $url',
      () {
        expect(workoutOriginalSourcePage(Uri.parse(url)), isNull);
      },
    );
  }
  test(
    'existing ordinary HTTPS publisher references keep their destination',
    () {
      final original = Uri.parse(
        'https://www.bilhealth.com/reference?section=training#source',
      );
      expect(workoutOriginalSourcePage(original), original);
    },
  );
}
