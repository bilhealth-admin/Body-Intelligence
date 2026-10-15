import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/runtime_copy_check_in.dart';
import '../../../app/localization/runtime_copy_voice_status.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../../core/units/measurement_units.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import '../../nutrition/services/meal_voice_session.dart';
import '../../nutrition/presentation/bil_meal_voice_session_panel.dart';
import '../../nutrition/presentation/bil_meal_voice_capture_dialog.dart';
import 'spoken_weight_parser.dart';

export 'spoken_weight_parser.dart';

typedef WeightVoicePermissionGate = Future<bool> Function(BuildContext context);

@visibleForTesting
({BilRuntimeCapability capability, BilRuntimePermissionState state})
weightVoiceEffectivePermission({
  required TargetPlatform platform,
  required BilRuntimePermissionState microphoneState,
  BilRuntimePermissionState? speechRecognitionState,
}) {
  final usesSpeechRecognition =
      platform == TargetPlatform.iOS &&
      microphoneState == BilRuntimePermissionState.granted;
  return (
    capability: usesSpeechRecognition
        ? BilRuntimeCapability.speechRecognition
        : BilRuntimeCapability.microphone,
    state: usesSpeechRecognition
        ? speechRecognitionState ?? BilRuntimePermissionState.denied
        : microphoneState,
  );
}

@visibleForTesting
String weightVoiceSettingsRecoverySource(BilRuntimeCapability capability) =>
    capability == BilRuntimeCapability.speechRecognition
    ? 'Speech recognition access is off. Enable it in system settings to add weight by voice; manual entry remains available.'
    : 'Microphone access is off. Enable it in system settings to add weight by voice; manual entry remains available.';

/// Captures a multilingual transcript and returns a reviewed value only.
/// Saving remains the responsibility of the surrounding weight dialog.
final class WeightVoiceInputService {
  WeightVoiceInputService(this._speech, {this.permissionGate});

  final SpeechToText _speech;
  @visibleForTesting
  final WeightVoicePermissionGate? permissionGate;

  Future<SpokenWeightCandidate?> capture({
    required BuildContext context,
    required MeasurementSystem fallbackSystem,
  }) async {
    if (!VoiceCaptureLease.acquire(this)) return null;
    MealVoiceSession? session;
    try {
      if (!await _speech.systemSpeechDisclosure.authorize(
        context,
        use: BilSpeechUse.weight,
      )) {
        return null;
      }
      if (!context.mounted) return null;
      final gate = permissionGate;
      final permissionGranted = gate == null
          ? await _ensurePermission(context)
          : await gate(context);
      if (!permissionGranted || !context.mounted) return null;
      var reviewUnit = fallbackSystem == MeasurementSystem.metric
          ? SpokenWeightUnit.kilograms
          : SpokenWeightUnit.pounds;
      final interfaceLocale = Localizations.localeOf(context).toLanguageTag();
      var recognizedLocale = interfaceLocale;
      final model = MealVoiceSession(
        speech: _speech,
        appLocale: interfaceLocale,
        deviceLocale: WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag(),
        optionsForLocales: (locales) {
          final allowed = _releaseSpeechLocales(
            locales
                .map((locale) => locale.localeId)
                .where((locale) => locale.trim().isNotEmpty)
                .toList(growable: false),
          );
          return SpeechListenOptions(
            localeId: _preferredSpeechLocale(allowed, interfaceLocale),
            listenFor: const Duration(seconds: 20),
            pauseFor: const Duration(seconds: 3),
            listenMode: ListenMode.confirmation,
            partialResults: true,
            cancelOnError: true,
            autoDetectLanguage: true,
            allowedLocaleIds: allowed,
          );
        },
        reviewTextForResult: (result) {
          recognizedLocale = result.localeId?.trim().isNotEmpty == true
              ? result.localeId!.trim()
              : interfaceLocale;
          final parsed = SpokenWeightParser.parse(
            result.recognizedWords,
            fallbackSystem: fallbackSystem,
            localeTag: recognizedLocale,
          );
          if (parsed != null) reviewUnit = parsed.unit;
          // Only a real parsed number enters the editor; an unrecognized phrase
          // never invents a value. Manual edits use the displayed review unit.
          return parsed == null ? '' : _formatReviewedNumber(parsed.value);
        },
      );
      session = model;
      SpokenWeightCandidate? accepted;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => BilMealVoiceSessionPanel(
          session: model,
          builder: (context) {
            final reviewSystem = reviewUnit == SpokenWeightUnit.kilograms
                ? MeasurementSystem.metric
                : MeasurementSystem.imperial;
            final candidate = SpokenWeightParser.parse(
              model.editor.text,
              fallbackSystem: reviewSystem,
              localeTag: recognizedLocale,
            );
            return BilMealVoiceCaptureDialog(
              title: context.strings.text('Add weight'),
              instructions: VoiceStatusRuntimeCopy.resolve(
                VoiceStatusCopyKey.weightReview,
                interfaceLocale,
              ),
              transcript: model.editor.text,
              editor: model.editor,
              editing: true,
              phase: model.phase,
              reviewLabel: context.strings.text('Weight'),
              textFieldKey: const Key('spoken-weight-review-field'),
              useKey: const Key('use-spoken-weight'),
              useIcon: Icons.done_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              unitLabel: reviewUnit == SpokenWeightUnit.kilograms ? 'kg' : 'lb',
              error: model.failure != null
                  ? context.strings.text('Voice input unavailable')
                  : model.phase == MealVoicePhase.review && candidate == null
                  ? _invalidWeightText(context)
                  : null,
              cancelLabel: context.strings.text('Cancel'),
              useLabel:
                  CheckInRuntimeCopy.resolve(
                    'Apply',
                    Localizations.localeOf(context).toLanguageTag(),
                  ) ??
                  context.strings.text('Apply'),
              onEdit: model.beginManualEdit,
              onTextChanged: (_) => model.textChanged(),
              onRetry: model.starting ? null : () => unawaited(model.start()),
              onStop: () => unawaited(model.stop()),
              onCancel: () {
                unawaited(model.close());
                Navigator.pop(dialogContext);
              },
              onUse: !model.canAccept || candidate == null
                  ? null
                  : () {
                      accepted = candidate;
                      unawaited(model.close());
                      Navigator.pop(dialogContext);
                    },
            );
          },
        ),
      );
      final popped = Navigator.of(context, rootNavigator: true).push(route);
      await Future.any<void>([popped, route.completed.then<void>((_) {})]);
      await model.close();
      await route.completed;
      return accepted;
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.strings.text('Voice input unavailable')),
          ),
        );
      }
      return null;
    } finally {
      try {
        await session?.close();
        await _speech.dispose();
      } finally {
        session?.dispose();
        VoiceCaptureLease.release(this);
      }
    }
  }

  static String _formatReviewedNumber(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _invalidWeightText(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return CheckInRuntimeCopy.resolve('Enter a valid weight.', locale) ??
        'Enter a valid weight.';
  }

  static String? _preferredSpeechLocale(
    List<String> available,
    String interfaceLocale,
  ) {
    final normalizedInterface = interfaceLocale
        .replaceAll('_', '-')
        .toLowerCase();
    for (final locale in available) {
      if (locale.replaceAll('_', '-').toLowerCase() == normalizedInterface) {
        return locale;
      }
    }
    final language = normalizedInterface.split('-').first;
    for (final locale in available) {
      final candidate = locale.replaceAll('_', '-').toLowerCase();
      if (candidate.split('-').first == language) return locale;
    }
    // Some platform recognizers return an empty locale inventory even though
    // recognition is available. The app locale is still the safest seed.
    return available.isEmpty ? interfaceLocale : null;
  }

  static List<String> _releaseSpeechLocales(List<String> available) {
    final candidates =
        available
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final selected = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final requested = _normalizeLocaleTag(locale.toLanguageTag());
      final language = locale.languageCode.toLowerCase();
      String? match;
      for (final candidate in candidates) {
        if (_normalizeLocaleTag(candidate) == requested) {
          match = candidate;
          break;
        }
      }
      if (match == null) {
        final languageMatches = candidates.where((candidate) {
          return _normalizeLocaleTag(candidate).split('-').first == language;
        });
        final script = locale.scriptCode?.toLowerCase();
        final country =
            locale.countryCode?.toLowerCase() ??
            _preferredSpeechCountries[language];
        for (final candidate in languageMatches) {
          final normalized = _normalizeLocaleTag(candidate);
          final isRequestedVariant = switch (script) {
            'hans' =>
              normalized.contains('-hans') ||
                  normalized.endsWith('-cn') ||
                  normalized.endsWith('-sg'),
            'hant' =>
              normalized.contains('-hant') ||
                  normalized.endsWith('-tw') ||
                  normalized.endsWith('-hk') ||
                  normalized.endsWith('-mo'),
            _ => country != null && normalized.endsWith('-$country'),
          };
          if (isRequestedVariant) {
            match = candidate;
            break;
          }
          match ??= candidate;
        }
      }
      if (match != null && !selected.contains(match)) selected.add(match);
    }
    return selected;
  }

  static String _normalizeLocaleTag(String value) =>
      value.replaceAll('_', '-').toLowerCase();

  static const _preferredSpeechCountries = <String, String>{
    'ar': 'eg',
    'en': 'us',
    'fr': 'fr',
    'es': 'es',
    'tr': 'tr',
    'de': 'de',
    'it': 'it',
    'ur': 'pk',
    'fa': 'ir',
    'hi': 'in',
    'id': 'id',
    'ms': 'my',
    'ja': 'jp',
    'ko': 'kr',
    'ru': 'ru',
    'bn': 'bd',
    'vi': 'vn',
    'th': 'th',
    'pl': 'pl',
    'nl': 'nl',
    'uk': 'ua',
  };

  Future<bool> _ensurePermission(BuildContext context) async {
    const policy = BilRuntimePermissionPolicy();
    final microphoneState = await policy.status(
      BilRuntimeCapability.microphone,
    );
    BilRuntimePermissionState? speechRecognitionState;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        microphoneState == BilRuntimePermissionState.granted) {
      speechRecognitionState = await policy.status(
        BilRuntimeCapability.speechRecognition,
      );
    }
    final decision = weightVoiceEffectivePermission(
      platform: defaultTargetPlatform,
      microphoneState: microphoneState,
      speechRecognitionState: speechRecognitionState,
    );
    final capability = decision.capability;
    final current = decision.state;
    if (current == BilRuntimePermissionState.granted) return true;
    if (!context.mounted) return false;
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await policy.openSettings();
        return false;
      }
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: Text(context.strings.text('Voice input unavailable')),
          content: Text(
            context.strings.text(weightVoiceSettingsRecoverySource(capability)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.strings.text('Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.strings.text('Open system settings')),
            ),
          ],
        ),
      );
      if (open == true) await policy.openSettings();
      return false;
    }

    // The voice button is already the user's contextual action on iOS. Ask
    // Apple's native permission sheet immediately; an in-app rationale in
    // front of it is treated as a pre-permission prompt during review.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted =
          await policy.request(capability) == BilRuntimePermissionState.granted;
      if (!granted || capability != BilRuntimeCapability.microphone) {
        return granted;
      }
      // iOS requests speech recognition separately after microphone access.
      if (!context.mounted) return false;
      return await _ensurePermission(context);
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(
          context.strings.text(
            capability == BilRuntimeCapability.speechRecognition
                ? 'Allow speech recognition for this action?'
                : 'Allow voice input for this action?',
          ),
        ),
        content: Text(
          context.strings.text(
            capability == BilRuntimeCapability.speechRecognition
                ? 'BIL uses speech recognition only after you choose voice weight entry. Review the recognized value before saving.'
                : 'BIL starts listening only after you choose voice weight entry. Review the recognized value before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Continue')),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    final granted =
        await policy.request(capability) == BilRuntimePermissionState.granted;
    if (!granted || capability != BilRuntimeCapability.microphone) {
      return granted;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    if (!context.mounted) return false;
    return await _ensurePermission(context);
  }
}
