import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/static_workout_artwork.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('six static workout covers are centralized and locally available', () {
    expect(StaticWorkoutArtwork.all, hasLength(6));
    for (final asset in StaticWorkoutArtwork.all) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
      expect(asset, startsWith('assets/images/workouts/workout_'));
      expect(asset, endsWith('_cover_v1.png'));
    }
  });

  test('replacement manifest covers only static artwork slots', () {
    final manifest =
        jsonDecode(
              File(
                'docs/audits/account_gateway_workout_artwork_replacement_manifest_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(manifest['rasterMutationPerformed'], isFalse);
    final excluded = manifest['excludedScope'] as Map<String, dynamic>;
    expect(excluded['workoutVideoPosterCount'], 302);

    final gateway = manifest['accountGateway'] as Map<String, dynamic>;
    expect(gateway['keepUnchanged'] as List, hasLength(1));
    final gatewayReplacements = (gateway['replaceWithVersionedAssets'] as List)
        .cast<Map<String, dynamic>>();
    expect(gatewayReplacements, hasLength(2));
    for (final replacement in gatewayReplacements) {
      final asset = replacement['asset'] as String;
      final decoded = image.decodeImage(File(asset).readAsBytesSync());
      expect(decoded, isNotNull, reason: asset);
      expect(decoded!.width, 1200, reason: asset);
      expect(decoded.height, 1200, reason: asset);
    }

    final workout = manifest['staticWorkoutArtwork'] as Map<String, dynamic>;
    final coverContract =
        workout['sharedCoverContract'] as Map<String, dynamic>;
    final files = (coverContract['files'] as List)
        .cast<Map<String, dynamic>>()
        .map((entry) => entry['asset'] as String)
        .toSet();
    expect(files, StaticWorkoutArtwork.all);
  });
}
