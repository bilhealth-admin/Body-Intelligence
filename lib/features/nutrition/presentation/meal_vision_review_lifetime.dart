part of 'meal_vision_premium_review.dart';

enum MealVisionReviewDecisionKind { accepted, retry, cancelled, retired }

/// Matching only validates a draft. It never authorizes a diary write.
class MealVisionReviewDecision {
  const MealVisionReviewDecision.accepted()
    : kind = MealVisionReviewDecisionKind.accepted,
      message = null;
  const MealVisionReviewDecision.retry(this.message)
    : kind = MealVisionReviewDecisionKind.retry;
  const MealVisionReviewDecision.cancelled()
    : kind = MealVisionReviewDecisionKind.cancelled,
      message = null;
  const MealVisionReviewDecision.retired()
    : kind = MealVisionReviewDecisionKind.retired,
      message = null;

  final MealVisionReviewDecisionKind kind;
  final String? message;
}

/// One Coach request can retire only the dialogs it explicitly registered.
/// It stores neither image paths nor navigation contexts after retirement.
class MealVisionReviewLifetime {
  bool _active = true;
  final _retire = <VoidCallback>{};
  bool get isActive => _active;

  void _attach(VoidCallback close) {
    if (_active) {
      _retire.add(close);
    } else {
      close();
    }
  }

  void _detach(VoidCallback close) => _retire.remove(close);

  void retire() {
    if (!_active) return;
    _active = false;
    final callbacks = _retire.toList(growable: false).reversed;
    _retire.clear();
    for (final close in callbacks) {
      close();
    }
  }
}

Widget guardMealVisionReview({
  required Widget child,
  MealVisionReviewLifetime? lifetime,
}) => lifetime == null
    ? child
    : _MealVisionReviewLifetimeGuard(lifetime: lifetime, child: child);

class _MealVisionReviewLifetimeGuard extends StatefulWidget {
  const _MealVisionReviewLifetimeGuard({
    required this.lifetime,
    required this.child,
  });
  final MealVisionReviewLifetime lifetime;
  final Widget child;
  @override
  State<_MealVisionReviewLifetimeGuard> createState() =>
      _MealVisionReviewLifetimeGuardState();
}

class _MealVisionReviewLifetimeGuardState
    extends State<_MealVisionReviewLifetimeGuard> {
  MealVisionReviewLifetime? _scheduledFor;
  @override
  void initState() {
    super.initState();
    widget.lifetime._attach(_onRetire);
  }

  void _onRetire() {
    final lifetime = widget.lifetime;
    if (identical(_scheduledFor, lifetime)) return;
    _scheduledFor = lifetime;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(widget.lifetime, lifetime) ||
          lifetime.isActive) {
        return;
      }
      final route = ModalRoute.of(context);
      final navigator = route?.navigator;
      if (route != null &&
          route.isActive &&
          navigator != null &&
          navigator.mounted) {
        // Removing this exact owned route leaves unrelated routes above it intact.
        navigator.removeRoute(route);
      }
    });
    // addPostFrameCallback alone does not request a frame. An idle matching
    // dialog must retire without waiting for another user input or rebuild.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(covariant _MealVisionReviewLifetimeGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lifetime, widget.lifetime)) {
      oldWidget.lifetime._detach(_onRetire);
      widget.lifetime._attach(_onRetire);
    }
  }

  @override
  void dispose() {
    widget.lifetime._detach(_onRetire);
    _scheduledFor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
