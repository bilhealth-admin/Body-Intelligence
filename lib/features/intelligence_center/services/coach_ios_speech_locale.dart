import 'package:flutter/foundation.dart';

/// Selects a supported Arabic recognizer only when the iOS app interface is
/// Arabic. Other iOS languages keep the system recognizer, while Android
/// retains its platform language detection.
String? coachIosSpeechLocaleId({
  required TargetPlatform platform,
  required String interfaceLocaleTag,
  required String deviceLocaleTag,
  required Iterable<String> supportedLocaleIds,
}) {
  if (platform != TargetPlatform.iOS ||
      _speechLanguage(interfaceLocaleTag) != 'ar') {
    return null;
  }

  final supported = supportedLocaleIds
      .map(_normalizeSpeechLocale)
      .where((locale) => locale.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (supported.isEmpty) return null;

  final interface = _normalizeSpeechLocale(interfaceLocaleTag);
  final exactInterfaceMatch = _caseInsensitiveMatch(supported, interface);
  if (exactInterfaceMatch != null) return exactInterfaceMatch;

  final device = _normalizeSpeechLocale(deviceLocaleTag);
  if (_speechLanguage(device) == 'ar') {
    final deviceMatch = _caseInsensitiveMatch(supported, device);
    if (deviceMatch != null) return deviceMatch;
    final deviceRegion = _speechRegion(device);
    if (deviceRegion != null) {
      final regionalMatch = supported.where((locale) {
        return _speechLanguage(locale) == 'ar' &&
            _speechRegion(locale) == deviceRegion;
      }).firstOrNull;
      if (regionalMatch != null) return regionalMatch;
    }
  }

  for (final preferred in const ['ar-SA', 'ar-EG', 'ar-AE', 'ar']) {
    final match = _caseInsensitiveMatch(supported, preferred);
    if (match != null) return match;
  }
  return supported
      .where((locale) => _speechLanguage(locale) == 'ar')
      .firstOrNull;
}

String? _caseInsensitiveMatch(Iterable<String> values, String requested) {
  final normalized = requested.toLowerCase();
  if (normalized.isEmpty) return null;
  for (final value in values) {
    if (value.toLowerCase() == normalized) return value;
  }
  return null;
}

String _normalizeSpeechLocale(String value) =>
    value.trim().replaceAll('_', '-');

String _speechLanguage(String value) =>
    _normalizeSpeechLocale(value).split('-').first.toLowerCase();

String? _speechRegion(String value) {
  final parts = _normalizeSpeechLocale(value).split('-');
  if (parts.length < 2) return null;
  for (final part in parts.skip(1)) {
    if (part.length == 2 && part.toUpperCase() == part) return part;
    if (part.length == 2 && part.toLowerCase() == part) {
      return part.toUpperCase();
    }
  }
  return null;
}
