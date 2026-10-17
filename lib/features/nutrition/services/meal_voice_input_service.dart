import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_meal_voice.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../../shared/widgets/bil_permission_recovery_dialog.dart';
import '../../../shared/widgets/bil_pearl_alert_dialog.dart';
import 'bil_speech_to_text.dart';
import 'meal_voice_candidate.dart';
import 'meal_voice_session.dart';
import '../presentation/bil_meal_voice_capture_dialog.dart';
import '../presentation/bil_meal_voice_session_panel.dart';

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
    if (!VoiceCaptureLease.acquire(this)) return null;
    try {
      if (!await _speech.systemSpeechDisclosure.authorize(
        context,
        use: BilSpeechUse.food,
      )) {
        return null;
      }
      if (!context.mounted) return null;
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
      try {
        await _speech.dispose();
      } finally {
        VoiceCaptureLease.release(this);
      }
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
      final open = await showBilPearlPermissionDecision(
        context,
        title: copy.unavailable,
        description: copy.settingsRecovery(capability),
        cancelLabel: copy.cancel,
        confirmLabel: copy.openSettings,
      );
      if (open && context.mounted) await policy.openSettings();
      return false;
    }

    // On iOS, request the native permission sheet immediately after the user
    // taps voice input. Apple review rejects dismissible pre-permission
    // prompts that sit in front of the system permission request. The voice
    // button is already the contextual user action, and the native sheet
    // provides the platform's authoritative explanation and controls.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted =
          await policy.request(capability) == BilRuntimePermissionState.granted;
      if (!granted || capability != BilRuntimeCapability.microphone) {
        return granted;
      }
      // iOS asks for speech recognition separately after microphone access.
      if (!context.mounted) return false;
      return await _ensureMicrophonePermission(context);
    }

    final continueRequest = await showBilPearlPermissionDecision(
      context,
      title: copy.permissionTitle(capability),
      description: copy.permissionRationale(capability),
      cancelLabel: copy.cancel,
      confirmLabel: copy.continueLabel,
    );
    if (!continueRequest || !context.mounted) return false;
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
    final session = MealVoiceSession(
      speech: _speech,
      appLocale: localeId,
      deviceLocale: WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
    );
    String? reviewedText;
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => BilMealVoiceSessionPanel(
          session: session,
          builder: (context) {
            final copy = _VoiceCopy.forLocaleTag(
              BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
            );
            return BilMealVoiceCaptureDialog(
              title: copy.title,
              instructions: copy.instructions,
              transcript: session.editor.text,
              editor: session.editor,
              editing: true,
              phase: session.phase,
              cancelLabel: copy.cancel,
              useLabel: copy.useForSearch,
              error: session.failure == null
                  ? null
                  : copy.failure(session.failure!),
              onEdit: session.beginManualEdit,
              onTextChanged: (_) => session.textChanged(),
              onRetry: session.starting
                  ? null
                  : () => unawaited(session.start()),
              onStop: () => unawaited(session.stop()),
              onCancel: () {
                unawaited(session.close());
                Navigator.pop(dialogContext);
              },
              onUse: !session.canAccept
                  ? null
                  : () {
                      reviewedText = session.editor.text.trim();
                      unawaited(session.close());
                      Navigator.pop(dialogContext);
                    },
            );
          },
        ),
      );
      final popped = Navigator.of(context, rootNavigator: true).push(route);
      // Navigator disposal also ends this lease, even if no pop result arrives.
      await Future.any<void>([popped, route.completed.then<void>((_) {})]);
      await session.close();
      await route.completed;
      if (reviewedText == null) return null;
      return MealVoiceCandidateParser.parse(
        transcript: reviewedText!,
        localeId: session.selectedLocale ?? localeId,
      );
    } finally {
      await session.close();
      session.dispose();
    }
  }

  Future<void> _showFailure(BuildContext context, MealVoiceFailure failure) {
    final copy = _VoiceCopy.forLocaleTag(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
    );
    return showDialog<void>(
      context: context,
      builder: (context) => BilPearlAlertDialog(
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
