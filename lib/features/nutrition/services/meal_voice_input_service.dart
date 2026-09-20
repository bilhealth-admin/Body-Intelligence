import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_meal_voice.dart';
import '../../../app/services/runtime_permission_policy.dart';
import 'bil_speech_to_text.dart';
import 'meal_voice_candidate.dart';

typedef MealVoicePermissionGate = Future<bool> Function(BuildContext context);

@visibleForTesting
({BilRuntimeCapability capability, BilRuntimePermissionState state})
mealVoiceEffectivePermission({
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
String mealVoiceSettingsRecoveryCopy({
  required String languageCode,
  required BilRuntimeCapability capability,
}) => _VoiceCopy.forLocaleTag(languageCode).settingsRecovery(capability);

@visibleForTesting
String mealVoicePermissionRationaleCopy({
  required String languageCode,
  required BilRuntimeCapability capability,
}) => _VoiceCopy.forLocaleTag(languageCode).permissionRationale(capability);

/// Captures a bounded food phrase with the device recognizer and returns only
/// an explicitly reviewed, editable candidate. It never writes a meal.
class MealVoiceInputService {
  MealVoiceInputService(this._speech, {this.permissionGate});

  final SpeechToText _speech;
  @visibleForTesting
  final MealVoicePermissionGate? permissionGate;

  Future<MealVoiceCandidate?> capture({
    required BuildContext context,
    required String localeId,
    required bool arabic,
  }) async {
    try {
      final gate = permissionGate;
      final permissionGranted = gate == null
          ? await _ensureMicrophonePermission(context)
          : await gate(context);
      if (!permissionGranted || !context.mounted) return null;
      try {
        return await _capture(context: context, localeId: localeId);
      } on Object catch (error) {
        try {
          await _speech.cancel();
        } on Object {
          // The platform recognizer may already be unavailable or disposed.
        }
        if (context.mounted) {
          await _showFailure(
            context,
            classifyMealVoiceFailure(error.toString()),
          );
        }
        return null;
      }
    } finally {
      // Each Quick Add voice invocation owns its recognizer subscription.
      // Releasing it here prevents stale EventChannel listeners from receiving
      // results during a later attempt or after the route has closed.
      await _speech.dispose();
    }
  }

  Future<bool> _ensureMicrophonePermission(BuildContext context) async {
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
    final decision = mealVoiceEffectivePermission(
      platform: defaultTargetPlatform,
      microphoneState: microphoneState,
      speechRecognitionState: speechRecognitionState,
    );
    final capability = decision.capability;
    final current = decision.state;
    if (current == BilRuntimePermissionState.granted) return true;
    if (!context.mounted) return false;
    final copy = _VoiceCopy.forLocaleTag(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
    );
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: Text(copy.unavailable),
          content: Text(copy.settingsRecovery(capability)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(copy.openSettings),
            ),
          ],
        ),
      );
      if (open == true) await policy.openSettings();
      return false;
    }
    final continueRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(copy.permissionTitle(capability)),
        content: Text(copy.permissionRationale(capability)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.continueLabel),
          ),
        ],
      ),
    );
    if (continueRequest != true) return false;
    final granted =
        await policy.request(capability) == BilRuntimePermissionState.granted;
    if (!granted || capability != BilRuntimeCapability.microphone) {
      return granted;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    if (!context.mounted) return false;
    return await _ensureMicrophonePermission(context);
  }

  Future<MealVoiceCandidate?> _capture({
    required BuildContext context,
    required String localeId,
  }) async {
    var transcript = '';
    var userEdited = false;
    MealVoiceFailure? failure;
    StateSetter? refreshDialog;
    var dialogActive = true;
    Timer? timeout;
    final editor = TextEditingController();
    final available = await _speech.initialize(
      onError: (error) {
        failure = classifyMealVoiceFailure(error.errorMsg);
        if (dialogActive) refreshDialog?.call(() {});
      },
    );
    if (!available || !context.mounted) {
      editor.dispose();
      if (context.mounted) {
        await _showFailure(context, MealVoiceFailure.recognizerUnavailable);
      }
      return null;
    }

    final locales = await _speech.locales();
    final selectedLocale = MealVoiceLocaleResolver.resolve(
      appLanguage: localeId,
      deviceLocale: WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
      availableLocales: locales.map((locale) => locale.localeId),
    );
    if (selectedLocale == null) {
      editor.dispose();
      if (context.mounted) {
        await _showFailure(context, MealVoiceFailure.localeUnavailable);
      }
      return null;
    }
    if (!context.mounted) {
      editor.dispose();
      return null;
    }

    await _speech.listen(
      onResult: (result) {
        transcript = result.recognizedWords.trim();
        if (!userEdited) {
          editor.value = TextEditingValue(
            text: transcript,
            selection: TextSelection.collapsed(offset: transcript.length),
          );
        }
        if (result.isFinal && transcript.isEmpty) {
          failure = MealVoiceFailure.noMatch;
        }
        if (dialogActive) refreshDialog?.call(() {});
      },
      listenOptions: SpeechListenOptions(
        localeId: selectedLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
    timeout = Timer(const Duration(seconds: 31), () async {
      if (!_speech.isListening) return;
      failure = transcript.isEmpty
          ? MealVoiceFailure.timeout
          : MealVoiceFailure.noMatch;
      await _speech.cancel();
      if (dialogActive) refreshDialog?.call(() {});
    });

    if (!context.mounted) {
      timeout.cancel();
      editor.dispose();
      return null;
    }
    var accepted = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          refreshDialog = setDialogState;
          final copy = _VoiceCopy.forLocaleTag(
            BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
          );
          return AlertDialog(
            icon: Icon(
              failure == null
                  ? Icons.graphic_eq_rounded
                  : Icons.mic_off_outlined,
            ),
            title: Text(copy.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(copy.instructions),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('editable-voice-food-candidate'),
                  controller: editor,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) {
                    userEdited = true;
                    setDialogState(() {});
                  },
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: copy.reviewLabel,
                    errorText: failure == null ? null : copy.failure(failure!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  dialogActive = false;
                  refreshDialog = null;
                  await _speech.cancel();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: Text(copy.cancel),
              ),
              FilledButton.icon(
                key: const Key('accept-reviewed-voice-candidate'),
                onPressed: failure != null || editor.text.trim().isEmpty
                    ? null
                    : () async {
                        accepted = true;
                        dialogActive = false;
                        refreshDialog = null;
                        await _speech.stop();
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(copy.useForSearch),
              ),
            ],
          );
        },
      ),
    );
    dialogActive = false;
    refreshDialog = null;
    timeout.cancel();
    if (_speech.isListening) await _speech.stop();
    if (!accepted) {
      editor.dispose();
      return null;
    }
    try {
      final candidate = MealVoiceCandidateParser.parse(
        transcript: editor.text,
        localeId: selectedLocale,
      );
      editor.dispose();
      return candidate;
    } on FormatException {
      editor.dispose();
      if (context.mounted) {
        await _showFailure(context, MealVoiceFailure.noMatch);
      }
      return null;
    }
  }

  Future<void> _showFailure(BuildContext context, MealVoiceFailure failure) {
    final copy = _VoiceCopy.forLocaleTag(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
    );
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.unavailable),
        content: Text(copy.failure(failure)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(copy.ok),
          ),
        ],
      ),
    );
  }
}

final class _VoiceCopy {
  const _VoiceCopy(this.localeTag);

  final String localeTag;

  static _VoiceCopy forLocaleTag(String localeTag) =>
      _VoiceCopy(MealVoiceRuntimeCopy.resolvedLocaleTag(localeTag));

  String _value(MealVoiceCopyKey key) =>
      MealVoiceRuntimeCopy.resolve(key, localeTag);

  String get title => _value(MealVoiceCopyKey.title);
  String get instructions => _value(MealVoiceCopyKey.instructions);
  String get reviewLabel => _value(MealVoiceCopyKey.reviewLabel);
  String get cancel => _value(MealVoiceCopyKey.cancel);
  String get useForSearch => _value(MealVoiceCopyKey.useForSearch);
  String get unavailable => _value(MealVoiceCopyKey.unavailable);
  String get ok => _value(MealVoiceCopyKey.ok);

  String permissionTitle(BilRuntimeCapability capability) {
    return _value(
      capability == BilRuntimeCapability.speechRecognition
          ? MealVoiceCopyKey.speechPermissionTitle
          : MealVoiceCopyKey.microphonePermissionTitle,
    );
  }

  String permissionRationale(BilRuntimeCapability capability) {
    return _value(
      capability == BilRuntimeCapability.speechRecognition
          ? MealVoiceCopyKey.speechPermissionRationale
          : MealVoiceCopyKey.microphonePermissionRationale,
    );
  }

  String settingsRecovery(BilRuntimeCapability capability) {
    return _value(
      capability == BilRuntimeCapability.speechRecognition
          ? MealVoiceCopyKey.speechSettingsRecovery
          : MealVoiceCopyKey.microphoneSettingsRecovery,
    );
  }

  String get openSettings => _value(MealVoiceCopyKey.openSettings);
  String get continueLabel => _value(MealVoiceCopyKey.continueLabel);

  String failure(MealVoiceFailure failure) => _value(switch (failure) {
    MealVoiceFailure.permissionDenied => MealVoiceCopyKey.permissionDenied,
    MealVoiceFailure.timeout => MealVoiceCopyKey.timeout,
    MealVoiceFailure.noMatch => MealVoiceCopyKey.noMatch,
    MealVoiceFailure.localeUnavailable => MealVoiceCopyKey.localeUnavailable,
    MealVoiceFailure.recognizerUnavailable =>
      MealVoiceCopyKey.recognizerUnavailable,
    MealVoiceFailure.unknown => MealVoiceCopyKey.unknown,
  });
}
