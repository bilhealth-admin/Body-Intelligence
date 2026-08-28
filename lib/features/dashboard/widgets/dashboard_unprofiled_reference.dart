part of 'dashboard_grid.dart';

class _UnprofiledReferenceDashboard extends StatelessWidget {
  const _UnprofiledReferenceDashboard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.hero,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? hero;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PremiumDashboardBenchmark(
        arabic: Localizations.localeOf(context).languageCode == 'ar',
        actionTitle: actionLabel,
        actionReason: message,
        actionEvidence: '',
        confidence: '',
        onAction: onAction,
        dailyIntelligence: const SizedBox.shrink(),
        hero: hero,
        bodyTwinSummary: dashboardFiveLocaleText(
          'No body trend data recorded yet.',
          'لم تُسجل بيانات اتجاهات الجسم بعد.',
        ),
        bodyTwinEvidence: '',
        nutritionSummary: dashboardFiveLocaleText(
          'No nutrition data recorded yet.',
          'لم تُسجل بيانات تغذية بعد.',
        ),
        nutritionEvidence: '',
        trendSummary: dashboardFiveLocaleText(
          'No trend data recorded yet.',
          'لم تُسجل بيانات اتجاهات بعد.',
        ),
        trendEvidence: '',
        loggingItems: [
          DashboardLoggingItem(
            label: dashboardFiveLocaleText('Weight', 'الوزن'),
            recorded: false,
          ),
          DashboardLoggingItem(
            label: dashboardFiveLocaleText('Meals', 'الوجبات'),
            recorded: false,
          ),
          DashboardLoggingItem(
            label: dashboardFiveLocaleText('Water', 'الماء'),
            recorded: false,
          ),
        ],
        caloriesConsumed: 0,
        caloriesGoal: 0,
        stepTrendValues: const [],
        visibleSections: const {DashboardSectionIds.aiCoach},
      ),
      DashboardProfileRequiredCard(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    ],
  );
}
