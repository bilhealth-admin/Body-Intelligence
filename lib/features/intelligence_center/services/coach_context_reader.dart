import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/coach_context_snapshot.dart';
import 'coach_context_provider.dart';

/// Keeps an imperative turn subscribed until its bounded context read settles.
/// A bare read of `.future` can be retired by a dependency update while no
/// widget listens, leaving that turn awaiting the retired computation.
Future<CoachContextSnapshot> readCoachContextSnapshot(
  ProviderContainer container, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final owner = container.read(verifiedEntitlementOwnerIdProvider);
  final repository = container.read(preferencesRepositoryProvider);
  final cancelled = Completer<CoachContextSnapshot>();
  void cancel() {
    if (!cancelled.isCompleted) {
      cancelled.completeError(StateError('coach_context_owner_changed'));
    }
  }

  final ownerSubscription = container.listen(
    verifiedEntitlementOwnerIdProvider,
    (previous, next) {
      if (next != owner) cancel();
    },
  );
  final repositorySubscription = container.listen(
    preferencesRepositoryProvider,
    (previous, next) {
      if (!identical(next, repository)) cancel();
    },
  );
  final subscription = container.listen(
    coachContextSnapshotProvider,
    (_, _) {},
  );
  try {
    return await Future.any([
      container.read(coachContextSnapshotProvider.future),
      cancelled.future,
    ]).timeout(timeout);
  } finally {
    subscription.close();
    repositorySubscription.close();
    ownerSubscription.close();
  }
}
