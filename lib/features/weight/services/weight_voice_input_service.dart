import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/runtime_copy_check_in.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../../core/units/measurement_units.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import 'spoken_weight_parser.dart';

export 'spoken_weight_parser.dart';

typedef WeightVoicePermissionGate = Future<bool> Function(BuildContext context);

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
    final gate = permissionGate;
    final permissionGranted = gate == null
        ? await _ensurePermission(context)
        : await gate(context);
    if (!permissionGranted || !context.mounted) return null;
    var userEdited = false;
    var failed = false;
    var listening = true;
    var reviewUnit = fallbackSystem == MeasurementSystem.metric
        ? SpokenWeightUnit.kilograms
        : SpokenWeightUnit.pounds;
    final interfaceLocale = Localizations.localeOf(context).toLanguageTag();
    var recognizedLocale = interfaceLocale;
    StateSetter? refresh;
    Timer? timer;
    final editor = TextEditingController();
    try {
      final available = await _speech.initialize(
        onError: (_) {
          failed = true;
          listening = false;
          refresh?.call(() {});
        },
      );
      if (!available || !context.mounted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.strings.text('Voice input unavailable')),
            ),
          );
        }
        return null;
      }
      final locales = await _speech.locales();
      final availableLocaleIds = locales
          .map((locale) => locale.localeId)
          .where((locale) => locale.trim().isNotEmpty)
          .toList(growable: false);
      // Android exposes every JVM locale here, not only BIL's release
      // languages. Sending that unbounded list to the recognizer can exceed
      // platform intent limits. Keep at most one recognizer locale per BIL
      // locale (two for the supported Portuguese and Chinese variants).
      final allowed = _releaseSpeechLocales(availableLocaleIds);
      final preferredLocale = _preferredSpeechLocale(allowed, interfaceLocale);
      await _speech.listen(
        onResult: (result) {
          listening = !result.isFinal;
          if (!userEdited) {
            recognizedLocale = result.localeId?.trim().isNotEmpty == true
                ? result.localeId!.trim()
                : preferredLocale ?? interfaceLocale;
            final parsed = SpokenWeightParser.parse(
              result.recognizedWords,
              fallbackSystem: fallbackSystem,
              localeTag: recognizedLocale,
            );
            if (parsed != null) reviewUnit = parsed.unit;
            final reviewedNumber = parsed == null
                ? ''
                : _formatReviewedNumber(parsed.value);
            editor.value = TextEditingValue(
              // The field and returned candidate are numeric evidence only.
              // Raw recognizer text does not leave this callback.
              text: reviewedNumber,
              selection: TextSelection.collapsed(offset: reviewedNumber.length),
            );
          }
          refresh?.call(() {});
        },
        listenOptions: SpeechListenOptions(
          // iOS does not support Android's automatic language switching, so
          // seed both platforms with the selected BIL interface language.
          localeId: preferredLocale,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          autoDetectLanguage: true,
          allowedLocaleIds: allowed,
        ),
      );
      timer = Timer(const Duration(seconds: 21), () async {
        listening = false;
        if (_speech.isListening) await _speech.stop();
        refresh?.call(() {});
      });
      if (!context.mounted) return null;

      SpokenWeightCandidate? accepted;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            final reviewSystem = reviewUnit == SpokenWeightUnit.kilograms
                ? MeasurementSystem.metric
                : MeasurementSystem.imperial;
            final candidate = SpokenWeightParser.parse(
              editor.text,
              fallbackSystem: reviewSystem,
              localeTag: recognizedLocale,
            );
            return AlertDialog(
              icon: Icon(
                listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
              ),
              title: Text(context.strings.text('Add weight')),
              content: TextField(
                key: const Key('spoken-weight-review-field'),
                controller: editor,
                autofocus: false,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  userEdited = true;
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: context.strings.text(
                    listening ? 'Listening…' : 'Weight',
                  ),
                  errorText: failed
                      ? context.strings.text('Voice input unavailable')
                      : !listening && candidate == null
                      ? _invalidWeightText(context)
                      : null,
                  suffixText: reviewUnit == SpokenWeightUnit.kilograms
                      ? 'kg'
                      : 'lb',
                  suffixIcon: candidate == null
                      ? null
                      : const Icon(Icons.check_circle_outline_rounded),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    refresh = null;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(context.strings.text('Cancel')),
                ),
                FilledButton.icon(
                  key: const Key('use-spoken-weight'),
                  onPressed: candidate == null
                      ? null
                      : () {
                          accepted = candidate;
                          refresh = null;
                          Navigator.pop(dialogContext);
                        },
                  icon: const Icon(Icons.done_rounded),
                  label: Text(
                    CheckInRuntimeCopy.resolve(
                          'Apply',
                          Localizations.localeOf(context).toLanguageTag(),
                        ) ??
                        context.strings.text('Apply'),
                  ),
                ),
              ],
            );
          },
        ),
      );
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
      refresh = null;
      timer?.cancel();
      if (_speech.isListening) {
        try {
          await _speech.cancel();
        } on Object {
          // The platform recognizer may have closed after the final result.
        }
      }
      await _speech.dispose();
      editor.dispose();
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
    var capability = BilRuntimeCapability.microphone;
    var current = await policy.status(capability);
    if (current == BilRuntimePermissionState.granted &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      capability = BilRuntimeCapability.speechRecognition;
      current = await policy.status(capability);
    }
    if (current == BilRuntimePermissionState.granted) return true;
    if (!context.mounted) return false;
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.strings.text('Voice input unavailable')),
          content: Text(
            context.strings.text(
              'Microphone access is off. Enable it in system settings to add weight by voice; manual entry remains available.',
            ),
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
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Allow voice input for this action?')),
        content: Text(
          context.strings.text(
            'BIL starts listening only after you choose voice weight entry. Review the recognized value before saving.',
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
