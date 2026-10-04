import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'community_post_image_picker.dart';

class CommunityPublishOperationConflict implements Exception {
  const CommunityPublishOperationConflict();
}

/// Explicit cancellation abandoned a verified historical operation whose post
/// is no longer available. This is not an acknowledgement of publication.
class CommunityPublishOperationUnavailable implements Exception {
  const CommunityPublishOperationUnavailable();
}

/// A durable, owner-scoped operation, not a client-side success flag. Only a
/// matching authoritative committed receipt can acknowledge publication.
class CommunityPublishOperationService {
  CommunityPublishOperationService(this.client, this.ownerId);

  final SupabaseClient client;
  final String ownerId;
  static const _bucket = 'community-post-images';
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final _inFlight = <String, Future<String>>{};
  static final _cancelling = <String>{};
  String get _journalKey => 'bil.community.publish.operation.v1.$ownerId';

  Future<String> publish(
    Map<String, dynamic> fields,
    List<CommunityPostImageDraft> images,
  ) async {
    final validated = <CommunityPostImageDraft>[];
    for (final image in images) {
      validated.add(await validateCommunityPostImageAsync(image.bytes));
    }
    final fingerprint = await compute(_publishFingerprint, (
      fields: fields,
      images: validated.map((image) => image.bytes).toList(),
    ));
    final running = _inFlight[ownerId];
    if (running != null || _cancelling.contains(ownerId)) {
      // Do not issue another mutation while the first outcome is unknown.
      throw const CommunityPublishOperationConflict();
    }
    final future = _publish(fields, validated, fingerprint);
    _inFlight[ownerId] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[ownerId], future)) _inFlight.remove(ownerId);
    }
  }

  Future<String> _publish(
    Map<String, dynamic> fields,
    List<CommunityPostImageDraft> images,
    String fingerprint,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    var journal = _readJournal(prefs);
    if (journal != null && journal['fingerprint'] != fingerprint) {
      throw const CommunityPublishOperationConflict();
    }
    if (journal == null) {
      final operationId = _uuid.v4();
      final payload = <String, dynamic>{
        ...fields,
        'media': [
          for (final image in images)
            {
              'object_path':
                  '$ownerId/$operationId/${_uuid.v4()}.${image.extension}',
              'mime_type': image.mimeType,
              'bytes': image.byteLength,
              'width': image.width,
              'height': image.height,
            },
        ],
      };
      journal = {
        'operation_id': operationId,
        'fingerprint': fingerprint,
        'payload': payload,
      };
      // Persist identity before any external side effect, including reservation.
      if (!await prefs.setString(_journalKey, jsonEncode(journal))) {
        throw StateError('Community operation could not be saved safely');
      }
    }
    final operationId = journal['operation_id'] as String;
    final payload = Map<String, dynamic>.from(journal['payload'] as Map);
    final prepared = _receipt(
      await client.rpc(
        'bil_begin_my_community_publish_operation_v1',
        params: {'p_operation_id': operationId, 'p_payload': payload},
      ),
      operationId,
      payload,
    );
    if (prepared['status'] == 'committed') {
      await _acknowledge(prefs);
      return operationId;
    }
    if (prepared['status'] != 'prepared') {
      throw StateError('Community operation is not available to publish');
    }
    final media = payload['media'] as List;
    for (var index = 0; index < images.length; index++) {
      await _upload(media[index]['object_path'] as String, images[index]);
    }
    final committed = _receipt(
      await client.rpc(
        'bil_publish_community_post_operation_v1',
        params: {'p_operation_id': operationId, 'p_payload': payload},
      ),
      operationId,
      payload,
    );
    if (committed['status'] != 'committed') {
      throw StateError('Community publication was not committed');
    }
    await _acknowledge(prefs);
    return operationId;
    // No failure cleanup here: a lost response is not proof of a failed commit.
  }

  Map<String, dynamic>? _readJournal(SharedPreferences prefs) {
    final raw = prefs.getString(_journalKey);
    if (raw == null) return null;
    final json = jsonDecode(raw);
    if (json is! Map ||
        json['operation_id'] is! String ||
        !_uuidPattern.hasMatch(json['operation_id'] as String) ||
        json['fingerprint'] is! String ||
        json['payload'] is! Map) {
      throw const FormatException('Invalid saved Community operation');
    }
    return Map<String, dynamic>.from(json);
  }

  Map<String, dynamic> _receipt(
    Object? response,
    String operationId,
    Map<String, dynamic> payload,
  ) {
    if (response is! Map ||
        response['operation_id'] != operationId ||
        response['owner_id'] != ownerId ||
        response['payload'] is! Map ||
        _canonicalJson(response['payload']) != _canonicalJson(payload) ||
        !const [
          'prepared',
          'committed',
          'aborted',
        ].contains(response['status']) ||
        (response['status'] == 'committed' &&
            (response['committed'] != true ||
                response['post_id'] != operationId)) ||
        (response['status'] != 'committed' &&
            (response['committed'] != false || response['post_id'] != null))) {
      throw const FormatException(
        'Invalid authoritative Community operation receipt',
      );
    }
    return Map<String, dynamic>.from(response);
  }

  Future<void> _upload(String path, CommunityPostImageDraft image) async {
    try {
      await client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            image.bytes,
            retryAttempts: 0,
            fileOptions: FileOptions(
              upsert: false,
              contentType: image.mimeType,
              cacheControl: '86400',
            ),
          );
    } on StorageException catch (error) {
      if (error.statusCode != '409' &&
          error.statusCode != '400' &&
          error.error != 'Duplicate') {
        rethrow;
      }
      // A retry may find the immutable object from a lost upload response.
      // Ownership/path alone is insufficient: verify the actual bytes.
      final existing = await client.storage.from(_bucket).download(path);
      final matches = await compute(_samePublishImage, (
        expected: image.bytes,
        actual: existing,
      ));
      if (!matches) throw StateError('Community retry media does not match');
    }
  }

  Future<void> _acknowledge(SharedPreferences prefs) async {
    final removed = await prefs.remove(_journalKey);
    // Legacy preferences clear their in-memory cache before the platform write
    // completes. Only readback can prove the durable identity was removed.
    await prefs.reload();
    if (prefs.containsKey(_journalKey)) {
      throw StateError(
        removed
            ? 'Community operation removal readback failed'
            : 'Community operation could not be acknowledged locally',
      );
    }
  }

  /// Cancellation is serialized on the server with commit. Never delete an
  /// image merely because a receipt lookup returned no row or timed out.
  Future<bool> cancelPending() async {
    if (_inFlight.containsKey(ownerId) || !_cancelling.add(ownerId)) {
      throw const CommunityPublishOperationConflict();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final journal = _readJournal(prefs);
      if (journal == null) return true;
      final operationId = journal['operation_id'] as String;
      final payload = Map<String, dynamic>.from(journal['payload'] as Map);
      final raw = await client.rpc(
        'bil_abort_my_community_publish_operation_v1',
        params: {'p_operation_id': operationId},
      );
      if (raw is! Map ||
          raw['operation_id'] != operationId ||
          raw['owner_id'] != ownerId) {
        throw const FormatException('Invalid Community cancellation receipt');
      }
      final result = Map<String, dynamic>.from(raw);
      if (result['status'] == 'unavailable') {
        if (result['payload'] is! Map ||
            _canonicalJson(result['payload']) != _canonicalJson(payload) ||
            result['post_id'] != operationId ||
            result['committed'] != false ||
            result['was_committed'] != true ||
            result['post_available'] != false ||
            result['cleanup_allowed'] != false ||
            result['aborted'] != false ||
            _canonicalJson(result['media_paths']) != _canonicalJson([])) {
          throw const FormatException('Unproved unavailable Community post');
        }
        // This explicit action abandons only the local pending identity. It
        // cannot publish anything or authorize removal of any uploaded object.
        await _acknowledge(prefs);
        throw const CommunityPublishOperationUnavailable();
      }
      if (result['status'] == 'committed') {
        _receipt(result, operationId, payload);
        await _acknowledge(prefs);
        return false;
      }
      if (result['status'] != 'aborted' || result['aborted'] != true) {
        throw const FormatException('Community cancellation was not verified');
      }
      if (result.containsKey('payload') && result['payload'] == null) {
        // An absent-operation tombstone wins against a delayed begin. No
        // upload could start before a verified prepared receipt, so there is
        // no server-authorized object list to remove in this case.
        if (result['committed'] != false ||
            result['post_id'] != null ||
            _canonicalJson(result['media_paths']) != _canonicalJson([])) {
          throw const FormatException('Invalid Community abort tombstone');
        }
        await _acknowledge(prefs);
        return true;
      }
      _receipt(result, operationId, payload);
      final expectedPaths = (payload['media'] as List)
          .map((item) => item['object_path'] as String)
          .toList();
      if (_canonicalJson(result['media_paths']) !=
          _canonicalJson(expectedPaths)) {
        throw const FormatException('Community cancellation was not verified');
      }
      if (expectedPaths.isNotEmpty) {
        await client.storage.from(_bucket).remove(expectedPaths);
      }
      await _acknowledge(prefs);
      return true;
    } finally {
      _cancelling.remove(ownerId);
    }
  }
}

String _publishFingerprint(
  ({Map<String, dynamic> fields, List<Uint8List> images}) input,
) => sha256
    .convert(
      utf8.encode(
        _canonicalJson({
          'fields': input.fields,
          'images': input.images
              .map((bytes) => sha256.convert(bytes).toString())
              .toList(),
        }),
      ),
    )
    .toString();

bool _samePublishImage(({Uint8List expected, Uint8List actual}) input) =>
    input.expected.length == input.actual.length &&
    sha256.convert(input.expected).toString() ==
        sha256.convert(input.actual).toString();

String _canonicalJson(Object? value) {
  Object? canonical(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(item[key])};
    }
    if (item is List) return item.map(canonical).toList();
    return item;
  }

  return jsonEncode(canonical(value));
}
