import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../foods/providers/food_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final seed = ref.watch(seedCatalogProvider);
    final checkInDue = ref.watch(dailyCheckInDueProvider);

    if (seed.hasError) {
      return Scaffold(body: Center(child: Text(seed.error.toString())));
    }
    if (seed.isLoading || checkInDue.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
