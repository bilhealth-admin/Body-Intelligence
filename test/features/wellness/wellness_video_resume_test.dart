import 'dart:convert';

import 'package:body_intelligence_log/features/wellness/services/wellness_video_resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const other =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save and reopen resumes only the matching content digest', () async {
    await WellnessVideoResume.save(digest, const Duration(seconds: 13));
    expect(await WellnessVideoResume.load(digest), const Duration(seconds: 13));
    expect(await WellnessVideoResume.load(other), Duration.zero);
  });

  test(
    'completed or explicitly reset playback clears the saved position',
    () async {
      await WellnessVideoResume.save(digest, const Duration(seconds: 13));
      await WellnessVideoResume.save(digest, Duration.zero);
      expect(await WellnessVideoResume.load(digest), Duration.zero);
    },
  );

  test('concurrent exits retain both latest positions', () async {
    await Future.wait([
      WellnessVideoResume.save(digest, const Duration(seconds: 4)),
      WellnessVideoResume.save(other, const Duration(seconds: 7)),
      WellnessVideoResume.save(digest, const Duration(seconds: 8)),
    ]);
    expect(await WellnessVideoResume.load(digest), const Duration(seconds: 8));
    expect(await WellnessVideoResume.load(other), const Duration(seconds: 7));
  });

  test(
    'history evicts the least recently saved entry after 100 items',
    () async {
      for (var index = 1; index <= 100; index++) {
        await WellnessVideoResume.save(
          index.toRadixString(16).padLeft(64, '0'),
          const Duration(seconds: 1),
        );
      }
      final first = 1.toRadixString(16).padLeft(64, '0');
      final second = 2.toRadixString(16).padLeft(64, '0');
      await WellnessVideoResume.save(first, const Duration(seconds: 2));
      await WellnessVideoResume.save(digest, const Duration(seconds: 3));
      expect(await WellnessVideoResume.load(first), const Duration(seconds: 2));
      expect(await WellnessVideoResume.load(second), Duration.zero);
      final preferences = await SharedPreferences.getInstance();
      final history = jsonDecode(
        preferences.getString(WellnessVideoResume.storageKey)!,
      );
      expect((history as Map).length, 100);
    },
  );

  test('corrupt history cannot strand playback', () async {
    SharedPreferences.setMockInitialValues({
      WellnessVideoResume.storageKey: '{bad-json',
    });
    expect(await WellnessVideoResume.load(digest), Duration.zero);
    await WellnessVideoResume.save(digest, const Duration(seconds: 1));
    expect(await WellnessVideoResume.load(digest), const Duration(seconds: 1));
  });

  test('untrusted history values are ignored', () async {
    for (final value in [null, -1, 1.5, '12000', 86400001, true]) {
      SharedPreferences.setMockInitialValues({
        WellnessVideoResume.storageKey: jsonEncode({digest: value}),
      });
      expect(await WellnessVideoResume.load(digest), Duration.zero);
    }
  });

  test('URLs or secrets cannot become resume keys', () async {
    const invalid = 'https://example.test/video?token=secret';
    await WellnessVideoResume.save(invalid, const Duration(seconds: 1));
    expect(await WellnessVideoResume.load(invalid), Duration.zero);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(WellnessVideoResume.storageKey), isNull);
  });

  test('negative or implausibly long positions are not persisted', () async {
    for (final position in [
      const Duration(seconds: -1),
      const Duration(hours: 25),
    ]) {
      await WellnessVideoResume.save(digest, position);
      expect(await WellnessVideoResume.load(digest), Duration.zero);
    }
  });
}
