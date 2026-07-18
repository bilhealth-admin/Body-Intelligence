import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final checkInDue = ref.watch(dailyCheckInDueProvider);

    if (checkInDue.isLoading) {
      return const _StartupSurface();
    }

    return profile.when(
      loading: () => const _StartupSurface(),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text(error.toString()))),
      data: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (user == null) {
            context.go('/onboarding');
          } else if (checkInDue.value == true) {
            context.go('/daily-check-in');
          } else {
            context.go('/dashboard');
          }
        });

        return const _StartupSurface();
      },
    );
  }
}

class _StartupSurface extends StatelessWidget {
  const _StartupSurface();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Semantics(
            label: 'BIL is preparing your local data',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                Text('BIL', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
