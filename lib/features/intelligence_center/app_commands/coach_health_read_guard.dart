import 'dart:async';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/coach_context_preferences.dart';

final class CoachHealthContextUnavailable implements Exception {
  const CoachHealthContextUnavailable();
}

/// Local read permission belongs to one owner visit and one context category.
/// A delivered revoke remains revoked even if the setting is enabled again.
/// This does not request cloud consent or native health permissions.
final class CoachHealthReadGuard {
  CoachHealthReadGuard._(this.preferences, this.focus, this.checkOwner);

  final PreferencesRepository preferences;
  final CoachContextFocus? focus;
  final void Function() checkOwner;
  StreamSubscription<String?>? _subscription;
  bool _revoked = false;
  bool _closed = false;

  static Future<CoachHealthReadGuard> capture({
    required PreferencesRepository preferences,
    required CoachContextFocus? focus,
    required void Function() checkOwner,
  }) async {
    final guard = CoachHealthReadGuard._(preferences, focus, checkOwner);
    checkOwner();
    if (focus == null) return guard;
    try {
      guard._subscription = preferences
          .watch(CoachContextPreferences.storageKey)
          .listen((raw) {
            if (!CoachContextPreferences.decode(raw).includes(focus)) {
              guard._revoked = true;
            }
          }, onError: (Object _, StackTrace _) => guard._revoked = true);
      await guard.verify();
      return guard;
    } on Object {
      // close marks the visit revoked before its first await. An asynchronous
      // stream cancellation must not delay a permission-denied UI response.
      unawaited(guard.close().catchError((Object _) {}));
      rethrow;
    }
  }

  void check() {
    checkOwner();
    if (_closed || _revoked) throw const CoachHealthContextUnavailable();
  }

  Future<void> verify() async {
    check();
    try {
      if (focus != null) {
        final raw = await preferences.get(CoachContextPreferences.storageKey);
        if (!CoachContextPreferences.decode(raw).includes(focus!)) {
          _revoked = true;
        }
      }
    } finally {
      check();
    }
  }

  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
  }
}

CoachContextFocus? coachHealthFocus(String toolId, Map<String, Object?> args) =>
    switch (toolId) {
      'read_fasting' => CoachContextFocus.habits,
      'preview_plan' => CoachContextFocus.nutrition,
      'read_health_progress' => CoachContextFocus.analytics,
      'read_health_history' => switch (args['topic']) {
        'daily' => CoachContextFocus.nutrition,
        'sleep' => CoachContextFocus.habits,
        'activity' => CoachContextFocus.training,
        _ => CoachContextFocus.analytics,
      },
      _ => null,
    };
