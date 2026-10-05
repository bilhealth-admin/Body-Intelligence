import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A Community page reached from a cold notification tap may be a route root.
/// Never depend on a previous route, trust a return URL, or exit the process.
class CommunityReturnButton extends StatelessWidget {
  const CommunityReturnButton({super.key});

  @override
  Widget build(BuildContext context) => BackButton(
    key: const Key('community-safe-return'),
    onPressed: () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        // Also works for Community subpages pushed with MaterialPageRoute.
        navigator.pop();
        return;
      }
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
        return;
      }
      router.go('/dashboard');
    },
  );
}
