import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local, bounded resume history. No media URL, token, or account data is saved.
abstract final class WellnessVideoResume {
  static const storageKey = 'bil.workout.video.resume.v1';
  static const _maximumEntries = 100;
  static const _maximumPosition = Duration(hours: 24);
  static const _storageTimeout = Duration(seconds: 1);
  static final _digest = RegExp(r'^[a-f0-9]{64}$');
  static Future<void> _pendingWrite = Future<void>.value();

  static Map<String, int> _read(SharedPreferences preferences) {
    try {
      final raw = jsonDecode(preferences.getString(storageKey) ?? '{}');
      if (raw is! Map<String, dynamic>) return {};
      return {
        for (final entry in raw.entries)
          if (_digest.hasMatch(entry.key) &&
              entry.value is int &&
              (entry.value as int) > 0 &&
              (entry.value as int) <= _maximumPosition.inMilliseconds)
            entry.key: entry.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Duration> load(String digest) async {
    if (!_digest.hasMatch(digest)) return Duration.zero;
    try {
      await _pendingWrite.timeout(_storageTimeout);
      final preferences = await SharedPreferences.getInstance().timeout(
        _storageTimeout,
      );
      return Duration(milliseconds: _read(preferences)[digest] ?? 0);
    } catch (_) {
      // Resume history is optional; a storage failure cannot block Play.
      return Duration.zero;
    }
  }

  static Future<void> save(String digest, Duration position) {
    if (!_digest.hasMatch(digest)) return Future.value();
    final operation = _pendingWrite.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance().timeout(
          _storageTimeout,
        );
        final history = _read(preferences)..remove(digest);
        if (position > Duration.zero && position <= _maximumPosition) {
          history[digest] = position.inMilliseconds;
        }
        while (history.length > _maximumEntries) {
          history.remove(history.keys.first);
        }
        await preferences
            .setString(storageKey, jsonEncode(history))
            .timeout(_storageTimeout);
      } catch (_) {
        // Never surface private storage errors as a playback failure.
      }
    });
    _pendingWrite = operation;
    return operation;
  }
}
