import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'circle_management_models.dart';

/// Durable identity for an operation whose authoritative server outcome may
/// outlive the current Flutter process. Payloads, BIL Codes, circle copy and
/// image bytes are deliberately excluded; only hashes and immutable IDs are
/// stored locally.
class CircleOperationJournalEntry {
  const CircleOperationJournalEntry({
    required this.ownerId,
    required this.key,
    required this.requestId,
    required this.operation,
    required this.fingerprint,
    required this.acknowledged,
    this.target,
    this.inviteId,
    this.mediaId,
    this.mediaKind,
    this.mediaReservation,
  });

  static const version = 1;
  static final _digest = RegExp(r'^[0-9a-f]{64}$');
  static const _operations = <String>{
    'create',
    'invite_send',
    'invite_accept',
    'invite_decline',
    'invite_cancel',
    'media_prepare',
    'media_finish',
    'media_cancel',
  };

  final String ownerId;
  final String key;
  final String requestId;
  final String operation;
  final String fingerprint;
  final bool acknowledged;
  final String? target;
  final String? inviteId;
  final String? mediaId;
  final CircleMediaKind? mediaKind;
  final CircleMediaReservation? mediaReservation;

  Map<String, dynamic> toJson() => {
    'v': version,
    'owner_id': ownerId,
    'key': key,
    'request_id': requestId,
    'operation': operation,
    'fingerprint': fingerprint,
    'acknowledged': acknowledged,
    if (target != null) 'target': target,
    if (inviteId != null) 'invite_id': inviteId,
    if (mediaId != null) 'media_id': mediaId,
    if (mediaKind != null) 'media_kind': mediaKind!.name,
    if (mediaReservation != null)
      'media_reservation': {
        'id': mediaReservation!.id,
        'owner_id': mediaReservation!.ownerId,
        'circle_slug': mediaReservation!.circleSlug,
        'slot': mediaReservation!.kind.name,
        'status': mediaReservation!.status,
        'bucket': mediaReservation!.media.bucket,
        'object_path': mediaReservation!.media.objectPath,
        'mime_type': mediaReservation!.media.mimeType,
        'bytes': mediaReservation!.media.byteLength,
        'width': mediaReservation!.media.width,
        'height': mediaReservation!.media.height,
      },
  };

  factory CircleOperationJournalEntry.fromJson(
    Object? value, {
    required String expectedOwnerId,
  }) {
    final json = circleMap(value);
    if (json['v'] != version ||
        json['owner_id'] != expectedOwnerId ||
        json['key'] is! String ||
        (json['key'] as String).isEmpty ||
        (json['key'] as String).runes.length > 180 ||
        json['operation'] is! String ||
        !_operations.contains(json['operation']) ||
        json['fingerprint'] is! String ||
        !_digest.hasMatch(json['fingerprint'] as String) ||
        json['acknowledged'] is! bool) {
      throw const FormatException('Invalid saved circle operation');
    }
    final target = json['target'];
    if (target != null) circleValidateSlug(circleText(target, maximum: 48));
    final inviteId = json['invite_id'];
    if (inviteId != null) circleUuid(inviteId);
    final mediaId = json['media_id'];
    if (mediaId != null) circleUuid(mediaId);
    final mediaKind = json['media_kind'] == null
        ? null
        : circleEnum(json['media_kind'], CircleMediaKind.values);
    final mediaReservation = json['media_reservation'] == null
        ? null
        : CircleMediaReservation.fromJson(circleMap(json['media_reservation']));
    if (mediaReservation != null &&
        (mediaReservation.ownerId != expectedOwnerId ||
            mediaReservation.status != 'reserved' ||
            mediaReservation.id != mediaId ||
            mediaReservation.kind != mediaKind ||
            mediaReservation.circleSlug != target)) {
      throw const FormatException('Invalid saved circle media reservation');
    }
    return CircleOperationJournalEntry(
      ownerId: circleUuid(json['owner_id']),
      key: json['key'] as String,
      requestId: circleUuid(json['request_id']),
      operation: json['operation'] as String,
      fingerprint: json['fingerprint'] as String,
      acknowledged: json['acknowledged'] as bool,
      target: target as String?,
      inviteId: inviteId as String?,
      mediaId: mediaId as String?,
      mediaKind: mediaKind,
      mediaReservation: mediaReservation,
    );
  }
}

abstract interface class CircleOperationJournal {
  Future<List<CircleOperationJournalEntry>> load(String ownerId);
  Future<void> upsert(String ownerId, CircleOperationJournalEntry entry);
  Future<void> remove(String ownerId, String key);
}

class SharedPreferencesCircleOperationJournal
    implements CircleOperationJournal {
  SharedPreferencesCircleOperationJournal({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;
  static final Map<String, Future<void>> _tails = {};

  String _storageKey(String ownerId) {
    circleUuid(ownerId);
    return 'bil.community.circle.operations.v1.$ownerId';
  }

  Future<T> _serialized<T>(String ownerId, Future<T> Function() action) {
    final previous = _tails[ownerId] ?? Future<void>.value();
    final gate = Completer<void>();
    final gateFuture = gate.future;
    _tails[ownerId] = gateFuture;
    return () async {
      try {
        try {
          await previous;
        } on Object {
          // A previous caller receives its own persistence error. The queue must
          // keep moving so a later explicit retry can repair local state.
        }
        return await action();
      } finally {
        gate.complete();
        if (identical(_tails[ownerId], gateFuture)) _tails.remove(ownerId);
      }
    }();
  }

  Future<List<CircleOperationJournalEntry>> _read(
    SharedPreferences preferences,
    String ownerId,
  ) async {
    await preferences.reload();
    final raw = preferences.getString(_storageKey(ownerId));
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.length > 32) {
      throw const FormatException('Invalid saved circle operation journal');
    }
    final entries = <CircleOperationJournalEntry>[];
    final keys = <String>{};
    for (final value in decoded) {
      final entry = CircleOperationJournalEntry.fromJson(
        value,
        expectedOwnerId: ownerId,
      );
      if (!keys.add(entry.key)) {
        throw const FormatException('Duplicate saved circle operation');
      }
      entries.add(entry);
    }
    return entries;
  }

  Future<void> _write(
    SharedPreferences preferences,
    String ownerId,
    List<CircleOperationJournalEntry> entries,
  ) async {
    if (entries.isEmpty) {
      await preferences.remove(_storageKey(ownerId));
      await preferences.reload();
      if (preferences.containsKey(_storageKey(ownerId))) {
        throw StateError('Circle operation journal removal was not durable');
      }
      return;
    }
    final raw = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    if (!await preferences.setString(_storageKey(ownerId), raw)) {
      throw StateError('Circle operation journal could not be saved');
    }
    await preferences.reload();
    if (preferences.getString(_storageKey(ownerId)) != raw) {
      throw StateError('Circle operation journal write was not durable');
    }
  }

  @override
  Future<List<CircleOperationJournalEntry>> load(String ownerId) =>
      _serialized(ownerId, () async {
        final preferences = await _preferences();
        return _read(preferences, ownerId);
      });

  @override
  Future<void> upsert(String ownerId, CircleOperationJournalEntry entry) =>
      _serialized(ownerId, () async {
        if (entry.ownerId != ownerId) {
          throw const FormatException('Circle journal owner mismatch');
        }
        final preferences = await _preferences();
        final entries = await _read(preferences, ownerId);
        final next = <CircleOperationJournalEntry>[
          for (final value in entries)
            if (value.key != entry.key) value,
          entry,
        ];
        if (next.length > 32) {
          throw StateError('Circle operation journal capacity exceeded');
        }
        await _write(preferences, ownerId, next);
      });

  @override
  Future<void> remove(String ownerId, String key) =>
      _serialized(ownerId, () async {
        final preferences = await _preferences();
        final entries = await _read(preferences, ownerId);
        await _write(
          preferences,
          ownerId,
          entries.where((entry) => entry.key != key).toList(),
        );
      });
}

@visibleForTesting
class MemoryCircleOperationJournal implements CircleOperationJournal {
  final Map<String, Map<String, CircleOperationJournalEntry>> _entries = {};

  @override
  Future<List<CircleOperationJournalEntry>> load(String ownerId) async =>
      List.unmodifiable((_entries[ownerId] ?? const {}).values);

  @override
  Future<void> upsert(String ownerId, CircleOperationJournalEntry entry) async {
    if (entry.ownerId != ownerId) {
      throw const FormatException('Circle journal owner mismatch');
    }
    (_entries[ownerId] ??= {})[entry.key] = entry;
  }

  @override
  Future<void> remove(String ownerId, String key) async {
    _entries[ownerId]?.remove(key);
  }
}
