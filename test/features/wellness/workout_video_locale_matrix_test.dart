import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_copy.dart';
import 'package:body_intelligence_log/features/wellness/presentation/workout_video_group_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metadata preview state copy is reviewed in all 25 locales', () {
    expect(
      WorkoutRoutinesStateCopy.supportedTags,
      BilLocalePolicy.productionTags,
    );

    final english = WorkoutRoutinesStateCopy.forTag('en');
    expect(english.exploreStyles, 'Explore workout styles');
    expect(
      english.previewExplanation,
      'Original BIL previews. Log an activity now, or install a reviewed pack for guided routines. No video is available from a preview.',
    );
    expect(english.manageReviewedPacks, 'Manage reviewed packs');
    expect(
      english.offlineExplanation,
      'Offline: only previously installed reviewed packs can provide guided routines.',
    );
    expect(english.metadataPreviewLabel, 'Metadata preview; no playable video');

    for (final tag in BilLocalePolicy.productionTags) {
      final copy = WorkoutRoutinesStateCopy.forTag(tag);
      final values = <String>[
        copy.exploreStyles,
        copy.previewExplanation,
        copy.manageReviewedPacks,
        copy.offlineExplanation,
        copy.metadataPreviewLabel,
      ];
      expect(values.every((value) => value.trim().isNotEmpty), isTrue);
      if (tag != 'en') {
        expect(copy.exploreStyles, isNot(english.exploreStyles), reason: tag);
        expect(
          copy.previewExplanation,
          isNot(english.previewExplanation),
          reason: tag,
        );
        expect(
          copy.manageReviewedPacks,
          isNot(english.manageReviewedPacks),
          reason: tag,
        );
        expect(
          copy.offlineExplanation,
          isNot(english.offlineExplanation),
          reason: tag,
        );
        expect(
          copy.metadataPreviewLabel,
          isNot(english.metadataPreviewLabel),
          reason: tag,
        );
      }
    }
  });

  testWidgets('workout video navigation and section copy covers 25 locales', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      late _CapturedWorkoutVideoCopy captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Builder(
            builder: (context) {
              captured = _CapturedWorkoutVideoCopy(
                tag: BilLocalePolicy.canonicalTag(locale),
                direction: Directionality.of(context),
                title: wellnessWorkoutVideosAndRoutinesTitle(context),
                month: workoutVideoMonthTitle(context, 1),
                phase: workoutVideoPhaseTitle(context, 1),
                count: workoutVerifiedMovementCount(context, 7),
                groupTitles: [
                  for (final id in workoutVideoGroupIds)
                    workoutVideoGroupTitle(context, id),
                ],
                sessionTitles: [
                  for (final type in workoutVideoSessionTypes)
                    workoutVideoSessionName(context, '$type-a'),
                ],
                actions: [
                  for (final action in const [
                    'Play video',
                    'Pause video',
                    'Download',
                    'Remove download',
                  ])
                    wellnessWorkoutVideoAction(context, action),
                ],
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(captured.title.trim(), isNotEmpty, reason: captured.tag);
      expect(captured.month, contains('1'), reason: captured.tag);
      expect(captured.phase, contains('1'), reason: captured.tag);
      expect(captured.count, contains('7'), reason: captured.tag);
      expect(captured.groupTitles, hasLength(workoutVideoGroupIds.length));
      expect(
        captured.groupTitles.every((value) => value.trim().isNotEmpty),
        isTrue,
      );
      expect(
        captured.groupTitles.toSet().intersection(workoutVideoGroupIds.toSet()),
        isEmpty,
        reason: captured.tag,
      );
      expect(captured.sessionTitles, hasLength(3));
      expect(
        captured.sessionTitles.every(
          (value) => value.endsWith(' A') && !value.contains('-'),
        ),
        isTrue,
        reason: captured.tag,
      );
      expect(
        captured.actions.every((value) => value.trim().isNotEmpty),
        isTrue,
      );

      final expectedDirection = BilLocalePolicy.isRtlTag(captured.tag)
          ? TextDirection.rtl
          : TextDirection.ltr;
      expect(captured.direction, expectedDirection, reason: captured.tag);
      if (captured.tag != 'en') {
        expect(
          captured.title,
          isNot('Workout Videos & Routines'),
          reason: captured.tag,
        );
      }
    }
  });
}

final class _CapturedWorkoutVideoCopy {
  const _CapturedWorkoutVideoCopy({
    required this.tag,
    required this.direction,
    required this.title,
    required this.month,
    required this.phase,
    required this.count,
    required this.groupTitles,
    required this.sessionTitles,
    required this.actions,
  });

  final String tag;
  final TextDirection direction;
  final String title, month, phase, count;
  final List<String> groupTitles, sessionTitles, actions;
}
