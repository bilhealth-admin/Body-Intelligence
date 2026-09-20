import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_meal_voice.dart';
import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_input_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal voice copy covers exactly all 25 production locale tags', () {
    expect(MealVoiceRuntimeCopy.productionLocaleTags, hasLength(25));
    expect(
      MealVoiceRuntimeCopy.productionLocaleTags,
      BilLocaleRolloutManifest.releaseTargets25,
    );
    expect(MealVoiceRuntimeCopy.balanced, isTrue);

    for (final tag in MealVoiceRuntimeCopy.productionLocaleTags) {
      for (final key in MealVoiceCopyKey.values) {
        expect(
          MealVoiceRuntimeCopy.resolve(key, tag).trim(),
          isNotEmpty,
          reason: '$tag is missing ${key.name}',
        );
      }
    }
  });

  test('production locales cannot silently fall back to English copy', () {
    const keysThatMustBeLocalized = <MealVoiceCopyKey>{
      MealVoiceCopyKey.title,
      MealVoiceCopyKey.instructions,
      MealVoiceCopyKey.reviewLabel,
      MealVoiceCopyKey.useForSearch,
      MealVoiceCopyKey.unavailable,
      MealVoiceCopyKey.permissionDenied,
      MealVoiceCopyKey.microphonePermissionTitle,
      MealVoiceCopyKey.microphonePermissionRationale,
      MealVoiceCopyKey.speechPermissionTitle,
      MealVoiceCopyKey.speechPermissionRationale,
      MealVoiceCopyKey.microphoneSettingsRecovery,
      MealVoiceCopyKey.speechSettingsRecovery,
      MealVoiceCopyKey.openSettings,
      MealVoiceCopyKey.continueLabel,
      MealVoiceCopyKey.timeout,
      MealVoiceCopyKey.noMatch,
      MealVoiceCopyKey.localeUnavailable,
      MealVoiceCopyKey.recognizerUnavailable,
      MealVoiceCopyKey.unknown,
    };

    for (final tag in MealVoiceRuntimeCopy.productionLocaleTags.where(
      (tag) => tag != 'en',
    )) {
      for (final key in keysThatMustBeLocalized) {
        expect(
          MealVoiceRuntimeCopy.resolve(key, tag),
          isNot(MealVoiceRuntimeCopy.resolve(key, 'en')),
          reason: '$tag unexpectedly uses English for ${key.name}',
        );
      }
    }
  });

  test('Portuguese regions and Chinese scripts remain exact and distinct', () {
    expect(MealVoiceRuntimeCopy.resolvedLocaleTag('pt_BR'), 'pt-BR');
    expect(MealVoiceRuntimeCopy.resolvedLocaleTag('pt-PT'), 'pt-PT');
    expect(MealVoiceRuntimeCopy.resolvedLocaleTag('zh_Hans'), 'zh-Hans');
    expect(MealVoiceRuntimeCopy.resolvedLocaleTag('zh-Hant'), 'zh-Hant');

    expect(
      MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.instructions, 'pt-BR'),
      isNot(
        MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.instructions, 'pt-PT'),
      ),
    );
    expect(
      MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.reviewLabel, 'zh-Hans'),
      isNot(
        MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.reviewLabel, 'zh-Hant'),
      ),
    );
  });

  test('permission recovery, settings, and continue copy is localized', () {
    for (final tag in MealVoiceRuntimeCopy.productionLocaleTags.where(
      (tag) => tag != 'en',
    )) {
      final microphoneRecovery = mealVoiceSettingsRecoveryCopy(
        languageCode: tag,
        capability: BilRuntimeCapability.microphone,
      );
      final speechRecovery = mealVoiceSettingsRecoveryCopy(
        languageCode: tag,
        capability: BilRuntimeCapability.speechRecognition,
      );
      final speechRationale = mealVoicePermissionRationaleCopy(
        languageCode: tag,
        capability: BilRuntimeCapability.speechRecognition,
      );

      expect(
        microphoneRecovery,
        MealVoiceRuntimeCopy.resolve(
          MealVoiceCopyKey.microphoneSettingsRecovery,
          tag,
        ),
      );
      expect(
        speechRecovery,
        MealVoiceRuntimeCopy.resolve(
          MealVoiceCopyKey.speechSettingsRecovery,
          tag,
        ),
      );
      expect(
        speechRationale,
        MealVoiceRuntimeCopy.resolve(
          MealVoiceCopyKey.speechPermissionRationale,
          tag,
        ),
      );
      expect(
        MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.openSettings, tag),
        isNot(
          MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.openSettings, 'en'),
        ),
      );
      expect(
        MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.continueLabel, tag),
        isNot(
          MealVoiceRuntimeCopy.resolve(MealVoiceCopyKey.continueLabel, 'en'),
        ),
      );
    }
  });
}
