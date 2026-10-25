import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A visible, always-working Back action for routes opened without history.
/// Never derive a destination from an external URL or notification payload.
class BilSafeReturnButton extends StatefulWidget {
  const BilSafeReturnButton({super.key, required this.fallbackLocation});

  final String fallbackLocation;

  @override
  State<BilSafeReturnButton> createState() => _BilSafeReturnButtonState();
}

class _BilSafeReturnButtonState extends State<BilSafeReturnButton> {
  // A fast double tap must not pop the caller after this route has closed.
  bool _navigationPending = false;

  void _handleBack() {
    if (_navigationPending) return;
    // Navigator.pop does not consult PopScope's canPop flag. Respect an
    // unsaved editor or in-progress save on both warm and cold routes.
    if (ModalRoute.of(context)?.popDisposition ==
        RoutePopDisposition.doNotPop) {
      return;
    }
    _navigationPending = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(widget.fallbackLocation);
  }

  @override
  Widget build(BuildContext context) =>
      BackButton(key: const Key('bil-safe-return'), onPressed: _handleBack);
}
