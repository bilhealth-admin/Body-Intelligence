import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/dashboard_grid.dart';
import 'widgets/dashboard_header.dart';
import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import '../life_context/providers/life_context_provider.dart';
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
        ref.refresh(todayLifeContextProvider.future),
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
    final showFirstValue = ref.watch(firstValueHandoffProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const _TodayAppBarTitle(),
        actions: [
          IconButton(
            tooltip: context.strings.text('Food catalog'),
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/nutrition'),
          ),
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
            tooltip: context.strings.text('Profile'),
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => refresh(context, ref),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showFirstValue) ...[
                  FirstValueHandoffCard(
                    onContinue: () async {
                      await ref
                          .read(preferencesRepositoryProvider)
                          .remove('firstValueHandoffPending');
                      if (context.mounted) context.go('/daily-check-in');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const DashboardHeader(),
                const SizedBox(height: 20),
                const DashboardGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstValueHandoffCard extends StatelessWidget {
  const FirstValueHandoffCard({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.strings.text('Your private starting point is ready'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.text(
                'BIL saved your profile and starting targets on this device.',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.text(
                      'BIL does not have a comparable daily measurement yet, so it will not claim a trend.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.monitor_weight_outlined),
              label: Text(context.strings.text('Record first check-in')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TodayAppBarTitle extends ConsumerWidget {
  const _TodayAppBarTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealsProvider).value ?? const [];
    final water = ref.watch(todayWaterProvider).value ?? const [];
    final weight = ref.watch(todayWeightProvider).value;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final hasRecord = weight != null || meals.isNotEmpty || water.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(MaterialLocalizations.of(context).formatMediumDate(now)),
        Text(
          hasRecord
              ? (arabic ? 'تسجيل اليوم قيد التقدم' : 'Today in progress')
              : (arabic ? 'ابدأ تسجيل اليوم' : 'Start today'),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
