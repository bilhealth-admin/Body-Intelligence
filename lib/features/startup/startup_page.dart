import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_page.dart';
import '../onboarding/onboarding_page.dart';
import '../profile/providers/user_profile_provider.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return profile.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, s) => Scaffold(
        body: Center(
          child: Text(e.toString()),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const OnboardingPage();
        }

        return const DashboardPage();
      },
    );
  }
}