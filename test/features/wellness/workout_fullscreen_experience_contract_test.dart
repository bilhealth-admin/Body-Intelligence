import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy library delegates to the same verified playback surface', () {
    final source = File(
      'lib/features/wellness/presentation/professional_content_library_page.dart',
    ).readAsStringSync();
    expect(source, contains('BilVerifiedWorkoutVideo('));
    expect(source, isNot(contains('VideoPlayerController')));
    expect(source, contains('item.videoMedia == null'));
  });
  test('verified workout playback uses a dedicated full-screen route', () {
    final mediaSource = File(
      'lib/features/wellness/presentation/bil_workout_routine_media.dart',
    ).readAsStringSync();
    final fullscreenSource = _fullscreenSources();

    expect(mediaSource, contains('fullscreenDialog: true'));
    expect(
      mediaSource,
      contains('_createPlaybackController(asset, cache, online, generation)'),
    );
    expect(mediaSource, contains('rootNavigator: true'));
    expect(fullscreenSource, contains('fit: StackFit.expand'));
    expect(fullscreenSource, contains("'workout-video-fullscreen-back'"));
    expect(fullscreenSource, contains('Navigator.of(context).maybePop()'));
  });

  test(
    'full-screen video has surface playback without a small pause overlay',
    () {
      final source = _fullscreenSources();

      expect(source, contains("'workout-video-fullscreen-surface'"));
      expect(source, contains('excludeFromSemantics: true'));
      expect(source, contains('Semantics('));
      expect(source, contains('onTap: _togglePlayback'));
      expect(source, isNot(contains("'workout-video-fullscreen-playback'")));
    },
  );
}

String _fullscreenSources() =>
    ['bil_workout_fullscreen_video.dart', 'bil_workout_fullscreen_view.dart']
        .map(
          (name) => File(
            'lib/features/wellness/presentation/$name',
          ).readAsStringSync(),
        )
        .join('\n');
