import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final checkInDue = ref.watch(dailyCheckInDueProvider);

    if (profile.hasError || checkInDue.hasError) {
      return _StartupError(
        onRetry: () {
          ref.invalidate(userProfileProvider);
          ref.invalidate(dailyCheckInDueProvider);
        },
      );
    }
    if (checkInDue.isLoading) {
      return const _StartupSurface();
    }

    return profile.when(
      loading: () => const _StartupSurface(),
      error: (_, _) => _StartupError(
        onRetry: () {
          ref.invalidate(userProfileProvider);
          ref.invalidate(dailyCheckInDueProvider);
        },
      ),
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
            label: context.strings.text('BIL is preparing your local data'),
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

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storage_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  context.strings.text('Could not open your local data'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.strings.text(
                    'Your data was not reset or uploaded. Try opening it again.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.strings.text('Try again')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
