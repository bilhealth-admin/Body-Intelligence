import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../life_context/providers/life_context_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/dashboard_composition.dart';
import 'widgets/dashboard_experience_frame.dart';
import 'widgets/dashboard_grid.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_shell.dart';
import 'widgets/dashboard_top_bar.dart';
import 'widgets/first_value_handoff_card.dart';

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
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final showFirstValue = ref.watch(firstValueHandoffProvider).value ?? false;
    final displayName = ref.watch(displayNameProvider).value;

    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardTopBar(
          arabic: arabic,
          displayName: displayName,
          onProfile: () => context.go('/settings'),
        ),
        const SizedBox(height: 18),
        if (showFirstValue) ...[
          FirstValueHandoffCard(
            onContinue: () async {
              await ref
                  .read(preferencesRepositoryProvider)
                  .remove('firstValueHandoffPending');
              if (context.mounted) {
                context.go('/daily-check-in');
              }
            },
          ),
          const SizedBox(height: 18),
        ],
        const DashboardHeader(),
      ],
    );

    return DashboardShell(
      onRefresh: () => refresh(context, ref),
      child: DashboardComposition(
        hero: hero,
        content: DashboardExperienceFrame(
          arabic: arabic,
          child: const DashboardGrid(),
        ),
      ),
    );
  }
}
