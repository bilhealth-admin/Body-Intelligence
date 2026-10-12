import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import '../../nutrition/services/meal_voice_session.dart';
import '../../nutrition/presentation/bil_meal_voice_session_panel.dart';
import '../../nutrition/presentation/bil_meal_voice_capture_dialog.dart';
import '../domain/community_text_limits.dart';
import '../presentation/community_body_counter.dart';
import '../presentation/community_copy.dart';

typedef CommunityVoicePermissionGate =
    Future<bool> Function(BuildContext context);

final class CommunityComposerVoiceInputService {
  CommunityComposerVoiceInputService(this._speech, {this.permissionGate});

  factory CommunityComposerVoiceInputService.platform() =>
      CommunityComposerVoiceInputService(SpeechToText());

  final SpeechToText _speech;
  @visibleForTesting
  final CommunityVoicePermissionGate? permissionGate;

  Future<String?> capture(BuildContext context) async {
    if (!VoiceCaptureLease.acquire(this)) return null;
    MealVoiceSession? session;
    try {
      final gate = permissionGate;
      final allowed = gate == null
          ? await _ensurePermission(context)
          : await gate(context);
      if (!allowed || !context.mounted) return null;
      final model = MealVoiceSession(
        speech: _speech,
        appLocale: BilLocalePolicy.canonicalTag(
          Localizations.localeOf(context),
        ),
        deviceLocale: WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag(),
      );
      session = model;
      String? acceptedText;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => BilMealVoiceSessionPanel(
          session: model,
          builder: (context) {
            final tooLong = CommunityTextLimits.exceedsBodyLimit(
              model.editor.text,
            );
            return BilMealVoiceCaptureDialog(
              title: _copy(context, 'Voice input', 'الإدخال الصوتي'),
              instructions: _copy(
                context,
                'Review the text before adding it to your draft.',
                'راجع النص قبل إضافته إلى مسودة المنشور.',
              ),
              transcript: model.editor.text,
              editor: model.editor,
              editing: true,
              phase: model.phase,
              reviewLabel: _copy(context, 'Review transcript', 'راجع النص'),
              textFieldKey: const Key('community-voice-transcript'),
              useKey: const Key('community-use-voice-transcript'),
              useIcon: Icons.done_rounded,
              maxLength: CommunityTextLimits.bodyCodePointLimit,
              buildCounter: communityBodyCounter(model.editor),
              error: tooLong
                  ? communityBodyLimitText(context)
                  : model.failure == null
                  ? null
                  : _copy(
                      context,
                      'Voice input is unavailable right now. You can edit the text or retry.',
                      'الإدخال الصوتي غير متاح حاليًا. يمكنك تعديل النص أو إعادة المحاولة.',
                    ),
              cancelLabel: _copy(context, 'Cancel', 'إلغاء'),
              useLabel: _copy(context, 'Use text', 'استخدام النص'),
              onEdit: model.beginManualEdit,
              onTextChanged: (_) => model.textChanged(),
              onRetry: model.starting ? null : () => unawaited(model.start()),
              onStop: () => unawaited(model.stop()),
              onCancel: () {
                unawaited(model.close());
                Navigator.pop(dialogContext);
              },
              onUse: !model.canAccept || tooLong
                  ? null
                  : () {
                      acceptedText = model.editor.text.trim();
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
      return acceptedText;
    } on Object {
      if (context.mounted) _showUnavailable(context);
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

  Future<bool> _ensurePermission(BuildContext context) async {
    const policy = BilRuntimePermissionPolicy();
    final microphoneState = await policy.status(
      BilRuntimeCapability.microphone,
    );
    BilRuntimePermissionState? speechState;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        microphoneState == BilRuntimePermissionState.granted) {
      speechState = await policy.status(BilRuntimeCapability.speechRecognition);
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
                _copy(dialogContext, 'Open settings', 'فتح الإعدادات'),
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
          await policy.request(capability) == BilRuntimePermissionState.granted;
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
      communityText(context, english, arabic);
}
