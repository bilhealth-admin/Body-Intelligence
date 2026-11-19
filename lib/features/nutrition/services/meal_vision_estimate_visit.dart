import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/database/app_database.dart';
import '../presentation/meal_vision_consent_gate.dart';
import '../presentation/meal_vision_premium_review.dart'
    show MealVisionReviewLifetime;

/// Captured before the first picker/consent/credit await. A delivered owner ABA
/// retires this photo and its owned review routes permanently.
class MealVisionEstimateVisit {
  MealVisionEstimateVisit._(
    this._client,
    this.database,
    this._isCurrentDatabase,
  ) : ownerId = database.localOwnerId! {
    var delivered = _client.auth.currentUser?.id;
    _ownerChanges = _client.auth.onAuthStateChange.listen((state) {
      final next = state.session?.user.id;
      if (next != delivered) _retire();
      delivered = next;
    }, onError: (Object _, StackTrace _) => _retire());
  }
  static MealVisionEstimateVisit? capture({
    required AppDatabase database,
    required bool Function() isCurrentDatabase,
  }) {
    final client = mealVisionConsentClient();
    final owner = database.localOwnerId;
    if (client == null ||
        owner == null ||
        client.auth.currentUser?.id != owner ||
        !isCurrentDatabase()) {
      return null;
    }
    return MealVisionEstimateVisit._(client, database, isCurrentDatabase);
  }

  final SupabaseClient _client;
  final AppDatabase database;
  final String ownerId;
  final bool Function() _isCurrentDatabase;
  final lifetime = MealVisionReviewLifetime();
  StreamSubscription<AuthState>? _ownerChanges;
  bool _retired = false;
  bool get current {
    if (_retired || !lifetime.isActive) return false;
    try {
      return _client.auth.currentUser?.id == ownerId && _isCurrentDatabase();
    } on Object {
      return false;
    }
  }

  void _retire() {
    _retired = true;
    lifetime.retire();
  }

  void dispose() {
    _retire();
    unawaited(_ownerChanges?.cancel());
  }
}
