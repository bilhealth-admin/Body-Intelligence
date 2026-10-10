import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A visible, always-working Back action for routes opened without history.
/// Never derive a destination from an external URL or notification payload.
class BilSafeReturnButton extends StatelessWidget {
  const BilSafeReturnButton({
    super.key,
    required this.fallbackLocation,
  });

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) => BackButton(
    key: const Key('bil-safe-return'),
    onPressed: () {
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
      router.go(fallbackLocation);
    },
  );
}
