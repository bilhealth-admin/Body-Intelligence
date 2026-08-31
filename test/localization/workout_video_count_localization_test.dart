import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_accessibility_wellness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout video count has reviewed copy for every production locale', () {
    for (final tag in BilLocalePolicy.productionTags) {
      final singular =
          AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(1, tag);
      final plural = AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(
        2,
        tag,
      );

      expect(singular.trim(), isNotEmpty, reason: tag);
      expect(plural.trim(), isNotEmpty, reason: tag);
      if (tag != 'en') {
        expect(
          singular,
          isNot('1 verified workout video'),
          reason: '$tag must not fall back to English',
        );
        expect(
          plural,
          isNot('2 verified workout videos'),
          reason: '$tag must not fall back to English',
        );
      }
    }
  });

  test('core locales render correct singular and plural forms', () {
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(1, 'en'),
      '1 verified workout video',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(2, 'en'),
      '2 verified workout videos',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(1, 'fr'),
      '1 vidéo d’entraînement vérifiée',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(2, 'es'),
      '2 vídeos de entrenamiento verificados',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(2, 'tr'),
      '2 doğrulanmış antrenman videosu',
    );
  });

  test('complex plural locales select few and many forms', () {
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(2, 'pl'),
      '2 zweryfikowane filmy treningowe',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(5, 'pl'),
      '5 zweryfikowanych filmów treningowych',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(2, 'uk'),
      '2 перевірені тренувальні відео',
    );
    expect(
      AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(5, 'ru'),
      '5 проверенных тренировочных видео',
    );
  });

  test('Premium brand label is reviewed without changing visible copy', () {
    for (final tag in BilLocalePolicy.productionTags) {
      expect(RuntimeCopy.resolve('Premium', tag), 'Premium', reason: tag);
    }
  });
}
