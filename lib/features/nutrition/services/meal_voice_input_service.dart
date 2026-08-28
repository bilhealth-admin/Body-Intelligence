import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/services/runtime_permission_policy.dart';
import 'bil_speech_to_text.dart';
import 'meal_voice_candidate.dart';

/// Captures a bounded food phrase with the device recognizer and returns only
/// an explicitly reviewed, editable candidate. It never writes a meal.
class MealVoiceInputService {
  MealVoiceInputService(this._speech);

  final SpeechToText _speech;

  Future<MealVoiceCandidate?> capture({
    required BuildContext context,
    required String localeId,
    required bool arabic,
  }) async {
    if (!await _ensureMicrophonePermission(context) || !context.mounted) {
      return null;
    }
    try {
      return await _capture(context: context, localeId: localeId);
    } on Object catch (error) {
      try {
        await _speech.cancel();
      } on Object {
        // The platform recognizer may already be unavailable or disposed.
      }
      if (context.mounted) {
        await _showFailure(context, classifyMealVoiceFailure(error.toString()));
      }
      return null;
    }
  }

  Future<bool> _ensureMicrophonePermission(BuildContext context) async {
    const policy = BilRuntimePermissionPolicy();
    var capability = BilRuntimeCapability.microphone;
    var current = await policy.status(capability);
    if (current == BilRuntimePermissionState.granted &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      capability = BilRuntimeCapability.speechRecognition;
      current = await policy.status(capability);
    }
    if (current == BilRuntimePermissionState.granted) return true;
    if (!context.mounted) return false;
    final copy = _VoiceCopy.forLanguage(
      Localizations.localeOf(context).languageCode,
    );
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(copy.unavailable),
          content: Text(copy.settingsRecovery),
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
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.permissionTitle),
        content: Text(copy.permissionRationale),
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
          final copy = _VoiceCopy.forLanguage(
            Localizations.localeOf(context).languageCode,
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
    final copy = _VoiceCopy.forLanguage(
      Localizations.localeOf(context).languageCode,
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
  const _VoiceCopy(this.values);
  final Map<String, String> values;
  static _VoiceCopy forLanguage(String language) =>
      _VoiceCopy(_voiceCopies[language] ?? _voiceCopies['en']!);
  String get title => values['title']!;
  String get instructions => values['instructions']!;
  String get reviewLabel => values['review']!;
  String get cancel => values['cancel']!;
  String get useForSearch => values['use']!;
  String get unavailable => values['unavailable']!;
  String get ok => values['ok']!;
  String get permissionTitle =>
      values['permissionTitle'] ?? _voiceCopies['en']!['permissionTitle']!;
  String get permissionRationale =>
      values['permissionRationale'] ??
      _voiceCopies['en']!['permissionRationale']!;
  String get settingsRecovery =>
      values['settingsRecovery'] ?? _voiceCopies['en']!['settingsRecovery']!;
  String get openSettings =>
      values['openSettings'] ?? _voiceCopies['en']!['openSettings']!;
  String get continueLabel =>
      values['continueLabel'] ?? _voiceCopies['en']!['continueLabel']!;
  String failure(MealVoiceFailure failure) => values[failure.name]!;
}

const _voiceCopies = <String, Map<String, String>>{
  'en': {
    'title': 'Say the food name',
    'instructions':
        'Speak a food and optional amount. Edit the recognized words, then approve them for search. Nothing is logged automatically.',
    'review': 'Review recognized words',
    'cancel': 'Cancel',
    'use': 'Use for food search',
    'unavailable': 'Voice input unavailable',
    'ok': 'OK',
    'permissionDenied': 'Microphone or speech permission was denied.',
    'permissionTitle': 'Allow voice input for this action?',
    'permissionRationale':
        'BIL starts listening only after you choose voice food entry. You can review the recognized text before search, and nothing is logged automatically.',
    'settingsRecovery':
        'Microphone access is off. Enable it in system settings to use voice food entry; manual entry remains available.',
    'openSettings': 'Open system settings',
    'continueLabel': 'Continue',
    'timeout': 'No speech was detected before the time limit.',
    'noMatch': 'No usable food phrase was recognized.',
    'localeUnavailable':
        'This device has no recognizer for the selected app language.',
    'recognizerUnavailable':
        'This device has no available speech recognition service.',
    'unknown': 'Speech recognition stopped unexpectedly.',
  },
  'ar': {
    'title': 'قل اسم الطعام',
    'instructions':
        'اذكر الطعام والكمية إن رغبت. عدّل الكلمات المتعرّف عليها ثم وافق لاستخدامها في البحث. لن يُسجل شيء تلقائيًا.',
    'review': 'مراجعة الكلمات',
    'cancel': 'إلغاء',
    'use': 'استخدامها في بحث الطعام',
    'unavailable': 'الإدخال الصوتي غير متاح',
    'ok': 'حسنًا',
    'permissionDenied': 'رُفض إذن الميكروفون أو التعرف على الكلام.',
    'timeout': 'لم يُكتشف كلام قبل انتهاء المهلة.',
    'noMatch': 'لم يتم التعرف على عبارة طعام صالحة.',
    'localeUnavailable': 'لا يحتوي الجهاز على متعرّف للغة التطبيق المختارة.',
    'recognizerUnavailable': 'لا تتوفر خدمة تعرف صوتي على هذا الجهاز.',
    'unknown': 'توقف التعرف على الكلام بشكل غير متوقع.',
  },
  'fr': {
    'title': 'Dites le nom de l’aliment',
    'instructions':
        'Dictez un aliment et une quantité facultative. Modifiez le texte, puis validez-le pour la recherche. Rien n’est enregistré automatiquement.',
    'review': 'Vérifier les mots reconnus',
    'cancel': 'Annuler',
    'use': 'Utiliser pour la recherche',
    'unavailable': 'Saisie vocale indisponible',
    'ok': 'OK',
    'permissionDenied':
        'L’autorisation du micro ou de la reconnaissance a été refusée.',
    'timeout': 'Aucune parole détectée avant la fin du délai.',
    'noMatch': 'Aucune expression alimentaire utilisable reconnue.',
    'localeUnavailable':
        'Aucun module vocal pour la langue choisie sur cet appareil.',
    'recognizerUnavailable':
        'Aucun service de reconnaissance vocale disponible.',
    'unknown': 'La reconnaissance vocale s’est arrêtée inopinément.',
  },
  'es': {
    'title': 'Di el nombre del alimento',
    'instructions':
        'Di un alimento y una cantidad opcional. Edita el texto y apruébalo para buscar. Nada se registra automáticamente.',
    'review': 'Revisar palabras reconocidas',
    'cancel': 'Cancelar',
    'use': 'Usar para buscar alimentos',
    'unavailable': 'Entrada de voz no disponible',
    'ok': 'Aceptar',
    'permissionDenied': 'Se denegó el permiso del micrófono o reconocimiento.',
    'timeout': 'No se detectó voz antes del límite de tiempo.',
    'noMatch': 'No se reconoció una frase de alimento válida.',
    'localeUnavailable':
        'El dispositivo no tiene reconocimiento para el idioma elegido.',
    'recognizerUnavailable':
        'No hay servicio de reconocimiento de voz disponible.',
    'unknown': 'El reconocimiento de voz se detuvo inesperadamente.',
  },
  'tr': {
    'title': 'Yiyeceğin adını söyleyin',
    'instructions':
        'Yiyeceği ve isteğe bağlı miktarı söyleyin. Metni düzenleyip arama için onaylayın. Hiçbir şey otomatik kaydedilmez.',
    'review': 'Algılanan sözcükleri incele',
    'cancel': 'İptal',
    'use': 'Yiyecek aramasında kullan',
    'unavailable': 'Sesli giriş kullanılamıyor',
    'ok': 'Tamam',
    'permissionDenied': 'Mikrofon veya konuşma izni reddedildi.',
    'timeout': 'Süre dolmadan konuşma algılanmadı.',
    'noMatch': 'Kullanılabilir bir yiyecek ifadesi algılanmadı.',
    'localeUnavailable': 'Bu cihazda seçilen dil için tanıyıcı yok.',
    'recognizerUnavailable': 'Bu cihazda konuşma tanıma hizmeti yok.',
    'unknown': 'Konuşma tanıma beklenmedik şekilde durdu.',
  },
};
