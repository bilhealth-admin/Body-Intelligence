import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/dashboard_grid.dart';
import 'widgets/dashboard_header.dart';
import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/dashboard_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> refresh(BuildContext context, WidgetRef ref) async {
    try {
      await Future.wait([
        ref.refresh(latestWeightProvider.future),
        ref.refresh(weightHistoryProvider.future),
        ref.refresh(userProfileProvider.future),
        ref.refresh(todayMealsProvider.future),
        ref.refresh(todayWaterProvider.future),
        ref.refresh(allMealsProvider.future),
        ref.refresh(allWaterProvider.future),
        ref.refresh(weightReminderSkippedTodayProvider.future),
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Today is up to date.'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text(
                'Some local Today data could not be refreshed.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BIL'),
        actions: [
          IconButton(
            tooltip: context.strings.text('Daily check-in'),
            icon: const Icon(Icons.monitor_weight_outlined),
            onPressed: () => context.go('/daily-check-in'),
          ),
          IconButton(
            tooltip: context.strings.text('Life context'),
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.go('/context'),
          ),
          IconButton(
            tooltip: context.strings.text('Food catalog'),
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => context.go('/nutrition'),
          ),
          IconButton(
            tooltip: context.strings.text('Analytics'),
            icon: const Icon(Icons.analytics),
            onPressed: () => context.go('/analytics'),
          ),
          IconButton(
            tooltip: context.strings.text('Weight history'),
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/history'),
          ),
          IconButton(
            tooltip: context.strings.text('Settings'),
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => refresh(context, ref),
          child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardHeader(),
                SizedBox(height: 20),
                DashboardGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
