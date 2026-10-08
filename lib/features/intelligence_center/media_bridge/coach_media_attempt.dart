import '../domain/food_v2/coach_food_v2.dart';

/// A local lifetime for one media request. No provider or repository is opened.
///
/// The caller must capture a fresh owner scope for each attempt and advance the
/// account observer's epoch on every account transition, including A -> B -> A.
/// Cancel this attempt when leaving the route or observing a permission loss;
/// a callback cannot detect a transition that its readers never observed.
final class CoachMediaAttempt {
  CoachMediaAttempt({
    required this.ownerScope,
    required this.conversationEpoch,
    required this.requestGeneration,
    required this.readConversationEpoch,
    required this.readRequestGeneration,
    required this.isAuthorized,
  }) {
    if (conversationEpoch < 0) {
      throw ArgumentError.value(conversationEpoch, 'conversationEpoch');
    }
    if (requestGeneration < 0) {
      throw ArgumentError.value(requestGeneration, 'requestGeneration');
    }
  }

  final CoachFoodOwnerScope ownerScope;
  final int conversationEpoch;
  final int requestGeneration;
  final int Function() readConversationEpoch;
  final int Function() readRequestGeneration;
  final bool Function() isAuthorized;

  bool _claimed = false;
  bool _cancelled = false;
  bool _disposed = false;

  bool get isClaimed => _claimed;
  bool get isCancelled => _cancelled;
  bool get isDisposed => _disposed;

  /// Remains checkable after [tryClaim], including after an asynchronous stop,
  /// review, or other operation. Claiming a result does not authorize a write.
  ///
  /// A failed read or observed loss of authority permanently invalidates this
  /// attempt. Restoring permission or switching back cannot revive it.
  bool get isCurrent {
    if (_cancelled || _disposed) return false;
    try {
      ownerScope.check();
      if (readConversationEpoch() != conversationEpoch ||
          readRequestGeneration() != requestGeneration ||
          !isAuthorized()) {
        cancel();
        return false;
      }
      return !_cancelled && !_disposed;
    } on Object {
      // Provider readers can throw after their owner has been disposed. Treat
      // that as unavailable authorization, never as permission to continue.
      cancel();
      return false;
    }
  }

  bool get canAcceptResult {
    if (_claimed) return false;
    // An injected reader can synchronously notify listeners. Recheck the
    // claim after those reads so a reentrant claimant cannot claim twice.
    return isCurrent && !_claimed;
  }

  /// At most one result can cross the boundary for this attempt. A later
  /// attempt may legitimately contain exactly the same image or transcript.
  bool tryClaim() {
    if (!canAcceptResult) return false;
    _claimed = true;
    return true;
  }

  void cancel() => _cancelled = true;

  void dispose() {
    _disposed = true;
    cancel();
  }
}
