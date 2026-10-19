import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'community_owner_operation.dart';

final communityTranslationProvider = Provider<CommunityTranslationPort>(
  (ref) => CloudCommunityTranslation(),
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

/// Authenticated, explicit translation. The server key never reaches the app.
/// Retired visits and changed accounts cannot apply a late response.
class CloudCommunityTranslation implements CommunityTranslationPort {
  CloudCommunityTranslation({SupabaseClient? client})
    : _providedClient = client;
  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;
  final _active = <String>{};
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
        texts.keys.any((key) => key != 'title' && key != 'body') ||
        texts.values.any((text) => text.length > 12000)) {
      throw const FormatException('invalid_translation_input');
    }
    final client = _client;
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const FormatException('translation_session_required');
    }
    _active.add(requestId);
    try {
      return await CommunityOwnerOperation.run(
        client: client,
        ownerId: owner,
        isCurrentOwner: () => _active.contains(requestId),
        action: (operation) async {
          final response = await client.functions
              .invoke(
                'community-translate',
                body: {'texts': texts, 'targetTag': targetTag},
              )
              .timeout(const Duration(seconds: 18));
          if (!_active.contains(requestId) ||
              client.auth.currentUser?.id != owner) {
            throw const FormatException('translation_cancelled');
          }
          final data = response.data;
          final output = data is Map ? data['texts'] : null;
          if (response.status != 200 ||
              data is! Map ||
              data['engine'] != 'google' ||
              output is! Map ||
              output.length != texts.length ||
              texts.keys.any(
                (key) =>
                    output[key] is! String ||
                    (texts[key]!.trim().isNotEmpty &&
                        (output[key] as String).trim().isEmpty),
              )) {
            throw const FormatException('invalid_translation_result');
          }
          return CommunityTranslationResult(
            {for (final key in texts.keys) key: output[key] as String},
            'google',
            sameLanguage: data['sameLanguage'] == true,
          );
        },
      );
    } on CommunityOwnerOperationCancelled {
      throw const FormatException('translation_cancelled');
    } finally {
      _active.remove(requestId);
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    _active.remove(requestId);
  }
}
