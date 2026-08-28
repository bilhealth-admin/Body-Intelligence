import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../../core/units/measurement_units.dart';
import '../../nutrition/services/bil_speech_to_text.dart';

enum SpokenWeightUnit { kilograms, pounds }

final class SpokenWeightCandidate {
  const SpokenWeightCandidate({
    required this.value,
    required this.unit,
    required this.transcript,
  });

  final double value;
  final SpokenWeightUnit unit;
  final String transcript;

  double get kilograms => unit == SpokenWeightUnit.kilograms
      ? value
      : value / UnitConverter.poundsPerKilogram;
}

/// Parses a spoken weight without tying speech language to the interface.
///
/// Speech engines normally return digits even when number words were spoken.
/// The Unicode digit normalization covers BIL's supported writing systems; an
/// English word-number fallback handles recognizers that preserve words.
abstract final class SpokenWeightParser {
  static final RegExp _numericValue = RegExp(r'\d{1,3}(?:[\.,]\d{1,2})?');

  static SpokenWeightCandidate? parse(
    String raw, {
    required MeasurementSystem fallbackSystem,
  }) {
    final transcript = raw.trim();
    if (transcript.isEmpty || transcript.length > 160) return null;
    final normalized = _normalizeDigits(transcript).toLowerCase();
    final value = _parseSpokenNumber(normalized);
    if (value == null || !value.isFinite) return null;

    final unit =
        _detectUnit(normalized) ??
        (fallbackSystem == MeasurementSystem.metric
            ? SpokenWeightUnit.kilograms
            : SpokenWeightUnit.pounds);
    final candidate = SpokenWeightCandidate(
      value: value,
      unit: unit,
      transcript: transcript,
    );
    if (candidate.kilograms < 20 || candidate.kilograms > 350) return null;
    return candidate;
  }

  static double? _parseSpokenNumber(String value) {
    final numeric = _numericValue.firstMatch(value)?.group(0);
    if (numeric != null) {
      return double.tryParse(numeric.replaceAll(',', '.'));
    }
    return _parseEnglishNumberWords(value) ?? _parseArabicNumberWords(value);
  }

  static SpokenWeightUnit? _detectUnit(String value) {
    if (RegExp(
      r'(^|\s)(lb|lbs|pound|pounds|libra|libras|livre|livres|pfund|رطل|أرطال|磅|фунт|фунта|фунтов)(\s|$)',
      unicode: true,
    ).hasMatch(value)) {
      return SpokenWeightUnit.pounds;
    }
    if (RegExp(
      r'(^|\s)(kg|kgs|kilo|kilos|kilogram|kilograms|kilogramme|kilogrammes|كيلو|كيلوجرام|كيلوغرام|كجم|公斤|キロ|킬로|кг)(\s|$)',
      unicode: true,
    ).hasMatch(value)) {
      return SpokenWeightUnit.kilograms;
    }
    return null;
  }

  static double? _parseEnglishNumberWords(String value) {
    const small = <String, int>{
      'zero': 0,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'eleven': 11,
      'twelve': 12,
      'thirteen': 13,
      'fourteen': 14,
      'fifteen': 15,
      'sixteen': 16,
      'seventeen': 17,
      'eighteen': 18,
      'nineteen': 19,
      'twenty': 20,
      'thirty': 30,
      'forty': 40,
      'fifty': 50,
      'sixty': 60,
      'seventy': 70,
      'eighty': 80,
      'ninety': 90,
    };
    final tokens = value.replaceAll('-', ' ').split(RegExp(r'\s+'));
    final decimalIndex = tokens.indexWhere(
      (token) => token == 'point' || token == 'dot' || token == 'decimal',
    );
    final wholeTokens = decimalIndex < 0
        ? tokens
        : tokens.take(decimalIndex).toList(growable: false);
    final whole = _parseEnglishInteger(wholeTokens, small);
    if (whole == null) return null;
    if (decimalIndex < 0) return whole.toDouble();
    final fraction = StringBuffer();
    for (final token in tokens.skip(decimalIndex + 1)) {
      final digit = small[token];
      if (digit == null || digit < 0 || digit > 9) continue;
      fraction.write(digit);
      if (fraction.length >= 2) break;
    }
    if (fraction.isEmpty) return whole.toDouble();
    return double.parse('$whole.${fraction.toString()}');
  }

  static int? _parseEnglishInteger(
    Iterable<String> tokens,
    Map<String, int> small,
  ) {
    var total = 0;
    var current = 0;
    var sawNumber = false;
    for (final token in tokens) {
      if (token == 'and') continue;
      if (token == 'hundred') {
        if (current == 0) return null;
        current *= 100;
        sawNumber = true;
        continue;
      }
      if (token == 'thousand') {
        if (current == 0) return null;
        total += current * 1000;
        current = 0;
        sawNumber = true;
        continue;
      }
      final part = small[token];
      if (part != null) {
        current += part;
        sawNumber = true;
      }
    }
    return sawNumber ? total + current : null;
  }

  static double? _parseArabicNumberWords(String value) {
    const values = <String, int>{
      'صفر': 0,
      'واحد': 1,
      'واحدة': 1,
      'احد': 1,
      'اثنان': 2,
      'اثنين': 2,
      'اثنتان': 2,
      'اثنتين': 2,
      'اتنين': 2,
      'ثلاثة': 3,
      'ثلاث': 3,
      'اربعة': 4,
      'اربع': 4,
      'خمسة': 5,
      'خمس': 5,
      'ستة': 6,
      'ست': 6,
      'سبعة': 7,
      'سبع': 7,
      'ثمانية': 8,
      'ثمان': 8,
      'تمانية': 8,
      'تسعة': 9,
      'تسع': 9,
      'عشرة': 10,
      'عشر': 10,
      'عشرين': 20,
      'ثلاثين': 30,
      'اربعين': 40,
      'خمسين': 50,
      'ستين': 60,
      'سبعين': 70,
      'ثمانين': 80,
      'تمانين': 80,
      'تسعين': 90,
      'مئة': 100,
      'مائة': 100,
      'ميه': 100,
      'مئتان': 200,
      'مائتان': 200,
    };
    final normalized = value
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');
    final rawTokens = normalized.split(RegExp(r'\s+'));
    final decimalIndex = rawTokens.indexWhere(
      (token) => token == 'فاصلة' || token == 'نقطة',
    );
    final wholeTokens = decimalIndex < 0
        ? rawTokens
        : rawTokens.take(decimalIndex).toList(growable: false);
    var whole = 0;
    var sawNumber = false;
    for (var raw in wholeTokens) {
      if (raw.length > 1 && raw.startsWith('و')) raw = raw.substring(1);
      final part = values[raw];
      if (part == null) continue;
      whole += part;
      sawNumber = true;
    }
    if (!sawNumber) return null;
    if (decimalIndex < 0) return whole.toDouble();
    final fraction = StringBuffer();
    for (var raw in rawTokens.skip(decimalIndex + 1)) {
      if (raw.length > 1 && raw.startsWith('و')) raw = raw.substring(1);
      final digit = values[raw];
      if (digit == null || digit < 0 || digit > 9) continue;
      fraction.write(digit);
      if (fraction.length >= 2) break;
    }
    if (fraction.isEmpty) return whole.toDouble();
    return double.parse('$whole.${fraction.toString()}');
  }

  static String _normalizeDigits(String value) {
    const digitSets = <String>[
      '٠١٢٣٤٥٦٧٨٩',
      '۰۱۲۳۴۵۶۷۸۹',
      '०१२३४५६७८९',
      '০১২৩৪৫৬৭৮৯',
      '๐๑๒๓๔๕๖๗๘๙',
      '０１２３４５６７８９',
    ];
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      var replacement = character;
      for (final digits in digitSets) {
        final index = digits.indexOf(character);
        if (index >= 0) {
          replacement = index.toString();
          break;
        }
      }
      buffer.write(replacement);
    }
    return buffer.toString().replaceAll('\u066B', '.').replaceAll('\u066C', '');
  }
}

/// Captures a multilingual transcript and returns a reviewed value only.
/// Saving remains the responsibility of the surrounding weight dialog.
final class WeightVoiceInputService {
  WeightVoiceInputService(this._speech);

  final SpeechToText _speech;

  Future<SpokenWeightCandidate?> capture({
    required BuildContext context,
    required MeasurementSystem fallbackSystem,
  }) async {
    if (!await _ensurePermission(context) || !context.mounted) return null;
    var transcript = '';
    var userEdited = false;
    var failed = false;
    var listening = true;
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
      final allowed = locales
          .map((locale) => locale.localeId)
          .where((locale) => locale.trim().isNotEmpty)
          .toList(growable: false);
      await _speech.listen(
        onResult: (result) {
          transcript = result.recognizedWords.trim();
          listening = !result.isFinal;
          if (!userEdited) {
            editor.value = TextEditingValue(
              text: transcript,
              selection: TextSelection.collapsed(offset: transcript.length),
            );
          }
          refresh?.call(() {});
        },
        listenOptions: SpeechListenOptions(
          localeId: null,
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
            final candidate = SpokenWeightParser.parse(
              editor.text,
              fallbackSystem: fallbackSystem,
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
                onChanged: (_) {
                  userEdited = true;
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: context.strings.text(
                    listening ? 'Listening…' : 'Weight',
                  ),
                  errorText: failed || (!listening && candidate == null)
                      ? context.strings.text('Voice input unavailable')
                      : null,
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
                  label: Text(context.strings.text('Done')),
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
