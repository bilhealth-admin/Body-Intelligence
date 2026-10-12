import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communityTranslationProvider = Provider<CommunityTranslationPort>(
  (ref) => const DeviceCommunityTranslation(),
);

class CommunityTranslationResult {
  const CommunityTranslationResult(
    this.texts,
    this.engine, {
    this.sameLanguage = false,
  });
  final Map<String, String> texts;
  final String engine;
  final bool sameLanguage;
}

abstract interface class CommunityTranslationPort {
  Future<CommunityTranslationResult> translate({
    required String requestId,
    required Map<String, String> texts,
    required String targetTag,
    String? statusLabel,
    String? cancelLabel,
  });
  Future<void> cancel(String requestId);
}

/// No UGC text, account identifiers or translation caches are sent to BIL/AI.
/// The native engine may download its language models after the user's tap.
class DeviceCommunityTranslation implements CommunityTranslationPort {
  const DeviceCommunityTranslation();
  static const channel = MethodChannel('bil/community_translation');
  @override
  Future<CommunityTranslationResult> translate({
    required String requestId,
    required Map<String, String> texts,
    required String targetTag,
    String? statusLabel,
    String? cancelLabel,
  }) async {
    if (texts.isEmpty ||
        texts.length > 2 ||
        texts.values.any((text) => text.length > 12000)) {
      throw const FormatException('invalid_translation_input');
    }
    final raw = await channel
        .invokeMapMethod<String, dynamic>('translate', {
          'requestId': requestId,
          'texts': texts,
          'targetTag': targetTag,
          'statusLabel': statusLabel,
          'cancelLabel': cancelLabel,
        })
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            unawaited(cancel(requestId));
            throw TimeoutException('translation_pending');
          },
        );
    final translated = raw?['texts'];
    final engine = raw?['engine'];
    if (translated is! Map ||
        !const {'apple', 'google'}.contains(engine) ||
        translated.length != texts.length ||
        texts.keys.any(
          (key) =>
              translated[key] is! String ||
              (texts[key]!.trim().isNotEmpty &&
                  (translated[key] as String).trim().isEmpty),
        )) {
      throw const FormatException('invalid_translation_result');
    }
    return CommunityTranslationResult(
      {for (final key in texts.keys) key: translated[key] as String},
      engine as String,
      sameLanguage: raw?['sameLanguage'] == true,
    );
  }

  @override
  Future<void> cancel(String requestId) async {
    try {
      await channel.invokeMethod<void>('cancel', {'requestId': requestId});
    } on PlatformException {
      /* Retired UI generations reject every late result. */
    } on MissingPluginException {
      /* Unsupported hosts keep the original text. */
    }
  }
}
