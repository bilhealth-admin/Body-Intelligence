import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import '../../nutrition/services/meal_voice_candidate.dart';

typedef CommunityVoicePermissionGate = Future<bool> Function(
  BuildContext context,
);

final class CommunityComposerVoiceInputService {
  CommunityComposerVoiceInputService(
    this._speech, {
    this.permissionGate,
  });

  factory CommunityComposerVoiceInputService.platform() =>
      CommunityComposerVoiceInputService(SpeechToText());

  final SpeechToText _speech;
  @visibleForTesting
  final CommunityVoicePermissionGate? permissionGate;

  Future<String?> capture(BuildContext context) async {
    final gate = permissionGate;
    final allowed = gate == null
        ? await _ensurePermission(context)
        : await gate(context);
    if (!allowed || !context.mounted) return null;

    var transcript = '';
    var finalResult = false;
    var failed = false;
    StateSetter? refresh;
    Timer? timeout;
    final editor = TextEditingController();
    try {
      final available = await _speech.initialize(
        onError: (_) {
          failed = true;
          refresh?.call(() {});
        },
      );
      if (!available || !context.mounted) {
        _showUnavailable(context);
        return null;
      }

      final locales = await _speech.locales();
      final localeId = MealVoiceLocaleResolver.resolve(
        appLanguage: BilLocalePolicy.canonicalTag(
          Localizations.localeOf(context),
        ),
        deviceLocale:
            WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        availableLocales: locales.map((value) => value.localeId),
      );
      if (localeId == null || !context.mounted) {
        _showUnavailable(context);
        return null;
      }

      await _speech.listen(
        onResult: (result) {
          transcript = result.recognizedWords.trim();
          finalResult = result.isFinal;
          editor.value = TextEditingValue(
            text: transcript,
            selection: TextSelection.collapsed(offset: transcript.length),
          );
          refresh?.call(() {});
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
        ),
      );

      timeout = Timer(const Duration(seconds: 46), () async {
        if (_speech.isListening) {
          await _speech.stop();
        }
        finalResult = true;
        refresh?.call(() {});
      });

      if (!context.mounted) return null;

      var accepted = false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            refresh = setDialogState;
            final hasText = editor.text.trim().isNotEmpty;
            return AlertDialog(
              icon: Icon(
                failed
                    ? Icons.mic_off_outlined
                    : finalResult
                    ? Icons.mic_none_rounded
                    : Icons.graphic_eq_rounded,
              ),
              title: Text(
                _copy(
                  context,
                  'Voice input',
                  'الإدخال الصوتي',
                ),
              ),
              content: TextField(
                key: const Key('community-voice-transcript'),
                controller: editor,
                minLines: 3,
                maxLines: 8,
                maxLength: 1200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _copy(
                    context,
                    finalResult ? 'Review transcript' : 'Listening…',
                    finalResult ? 'راجع النص' : 'جارٍ الاستماع…',
                  ),
                  errorText: failed
                      ? _copy(
                          context,
                          'Voice input is unavailable right now.',
                          'الإدخال الصوتي غير متاح حاليًا.',
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    unawaited(() async {
                      refresh = null;
                      await _speech.cancel();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    }());
                  },
                  child: Text(_copy(context, 'Cancel', 'إلغاء')),
                ),
                FilledButton.icon(
                  key: const Key('community-use-voice-transcript'),
                  onPressed: failed || !hasText
                      ? null
                      : () {
                          unawaited(() async {
                            accepted = true;
                            refresh = null;
                            if (_speech.isListening) await _speech.stop();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          }());
                        },
                  icon: const Icon(Icons.done_rounded),
                  label: Text(_copy(context, 'Use text', 'استخدام النص')),
                ),
              ],
            );
          },
        ),
      );

      return accepted ? editor.text.trim() : null;
    } on Object {
      if (context.mounted) _showUnavailable(context);
      return null;
    } finally {
      refresh = null;
      timeout?.cancel();
      if (_speech.isListening) {
        try {
          await _speech.cancel();
        } on Object {
          // Native recognizer may already have completed.
        }
      }
      await _speech.dispose();
      editor.dispose();
    }
  }

  Future<bool> _ensurePermission(BuildContext context) async {
    const policy = BilRuntimePermissionPolicy();
    final microphoneState = await policy.status(
      BilRuntimeCapability.microphone,
    );
    BilRuntimePermissionState? speechState;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        microphoneState == BilRuntimePermissionState.granted) {
      speechState = await policy.status(
        BilRuntimeCapability.speechRecognition,
      );
    }

    final capability =
        defaultTargetPlatform == TargetPlatform.iOS &&
            microphoneState == BilRuntimePermissionState.granted
        ? BilRuntimeCapability.speechRecognition
        : BilRuntimeCapability.microphone;
    final state = capability == BilRuntimeCapability.speechRecognition
        ? speechState ?? BilRuntimePermissionState.denied
        : microphoneState;

    if (state == BilRuntimePermissionState.granted) return true;
    if (!context.mounted) return false;

    if (state == BilRuntimePermissionState.permanentlyDenied ||
        state == BilRuntimePermissionState.restricted) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await policy.openSettings();
        return false;
      }
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: Text(
            _copy(
              dialogContext,
              'Voice input unavailable',
              'الإدخال الصوتي غير متاح',
            ),
          ),
          content: Text(
            _copy(
              dialogContext,
              'Enable microphone access in system settings to use voice input.',
              'فعّل الوصول إلى الميكروفون من إعدادات النظام لاستخدام الإدخال الصوتي.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_copy(dialogContext, 'Not now', 'ليس الآن')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                _copy(
                  dialogContext,
                  'Open settings',
                  'فتح الإعدادات',
                ),
              ),
            ),
          ],
        ),
      );
      if (open == true) await policy.openSettings();
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted =
          await policy.request(capability) ==
          BilRuntimePermissionState.granted;
      if (!granted || capability != BilRuntimeCapability.microphone) {
        return granted;
      }
      if (!context.mounted) return false;
      return _ensurePermission(context);
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(
          _copy(
            dialogContext,
            'Allow voice input for this post?',
            'السماح بالإدخال الصوتي لهذا المنشور؟',
          ),
        ),
        content: Text(
          _copy(
            dialogContext,
            'BIL starts listening only after you choose voice input. You review the transcript before it is added to the post.',
            'يبدأ BIL الاستماع فقط بعد اختيارك للإدخال الصوتي. تراجع النص قبل إضافته إلى المنشور.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_copy(dialogContext, 'Not now', 'ليس الآن')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_copy(dialogContext, 'Continue', 'متابعة')),
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
    return _ensurePermission(context);
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _copy(
            context,
            'Voice input is unavailable right now.',
            'الإدخال الصوتي غير متاح حاليًا.',
          ),
        ),
      ),
    );
  }

  String _copy(BuildContext context, String english, String arabic) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? arabic
      : english;
}
