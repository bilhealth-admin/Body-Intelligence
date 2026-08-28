part of 'weekly_report_page.dart';

class _Body extends ConsumerWidget {
  const _Body({required this.report});
  final WeeklyReportSnapshot report;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = report.days;
    final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
    final premiumActive = verifiedSubscription.value?.grants(
      CommerceEntitlement.advancedIntelligence,
    );
    final start = days.isEmpty ? '' : days.first.dayKey;
    final end = days.isEmpty ? '' : days.last.dayKey;
    final memberSince =
        ref.watch(accountCreatedAtProvider) ??
        ref
            .watch(userProfileProvider)
            .whenOrNull(data: (profile) => profile?.createdAt);
    final memberSinceCopy = memberSince == null
        ? _t(context, 'member_since_unavailable')
        : MaterialLocalizations.of(context).formatMediumDate(memberSince);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _WeeklyPulseHero(
          report: report,
          weekRange: _humanWeekRange(context, start, end),
          onChooseWeek: () async {
            final selected = ref.read(selectedWeeklyReportDateProvider);
            final today = ref.read(weeklyReportClockProvider)();
            final picked = await showDatePicker(
              context: context,
              initialDate: selected.isAfter(today) ? today : selected,
              firstDate: DateTime(2010),
              lastDate: today,
            );
            if (picked != null) {
              ref.read(selectedWeeklyReportDateProvider.notifier).state =
                  picked;
            }
          },
        ),
        const SizedBox(height: 20),
        _Food(report: report),
        const SizedBox(height: 20),
        _WeeklyEvidenceDeck(report: report),
        const SizedBox(height: 22),
        Text(
          _t(context, 'glance'),
          key: const Key('weekly-glance-anchor'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(_t(context, 'records_only')),
        Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'سجلت بيانات في ${report.trackedDays} من 7 أيام.'
              : _t(
                  context,
                  'tracked_days',
                ).replaceAll('{days}', '${report.trackedDays}'),
          key: const Key('weekly-tracked-days'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (verifiedSubscription.isLoading)
          const LinearProgressIndicator(key: Key('weekly-entitlement-loading'))
        else if (verifiedSubscription.hasError)
          ListTile(
            key: const Key('weekly-entitlement-error'),
            leading: const Icon(Icons.cloud_off_rounded),
            title: Text(_t(context, 'subscription_check_unavailable')),
            trailing: TextButton(
              onPressed: () =>
                  ref.invalidate(verifiedSubscriptionStateProvider),
              child: Text(context.strings.text('Retry')),
            ),
          ),
        _Section(
          key: const Key('weekly-calories-section'),
          title: _t(context, 'calories'),
          icon: Icons.local_fire_department_outlined,
          children: [
            _Value(
              _t(context, 'logged_calories'),
              '${report.totalCalories.toStringAsFixed(0)} kcal',
            ),
            _Value(
              _t(context, 'weekly_goal'),
              report.weeklyCalorieGoal == null
                  ? '—'
                  : '${report.weeklyCalorieGoal!.round()} kcal',
            ),
            if (report.totalVerifiedActiveEnergyKcal != null)
              _Value(
                _weeklySurfaceText(context, 'Active energy'),
                '${report.totalVerifiedActiveEnergyKcal!.round()} kcal',
              )
            else if (report.totalEstimatedBurnedCaloriesKcal == null)
              _Value(_t(context, 'burned_unavailable'), '—')
            else
              _Value(
                _t(context, 'estimated_exercise_energy'),
                '≈ ${report.totalEstimatedBurnedCaloriesKcal!.round()} kcal',
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_t(context, 'on_track')),
            ),
            const SizedBox(height: 8),
            _Bars(days: days),
            const SizedBox(height: 8),
            _ChartLegend(
              items: [
                (_t(context, 'legend_logged'), const Color(0xFF006D77)),
                if (report.weeklyCalorieGoal != null)
                  (_t(context, 'legend_goal'), const Color(0xFF8AA5AB)),
                (_t(context, 'legend_no_entry'), const Color(0xFFD7E2E4)),
              ],
            ),
            const SizedBox(height: 10),
            if (premiumActive == true)
              Semantics(
                key: const Key('weekly-calories-premium-cta'),
                container: true,
                label: _t(context, 'premium_active'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t(context, 'premium_active'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (premiumActive == false)
              _ResponsiveAction(
                key: const Key('weekly-go-premium'),
                onPressed: () => context.push('/plans'),
                icon: Icons.workspace_premium_outlined,
                label: _t(context, 'unlock_calorie_insights'),
                filled: true,
              )
            else
              Semantics(
                key: const Key('weekly-calories-premium-cta'),
                container: true,
                label: _t(context, 'checking_subscription'),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_t(context, 'checking_subscription'))),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
        _Section(
          key: const Key('weekly-frequent-section'),
          title: _t(context, 'frequent'),
          icon: Icons.restaurant_menu_rounded,
          children: report.frequentFoods.isEmpty
              ? [
                  const SizedBox(height: 18),
                  const Center(
                    child: Icon(Icons.soup_kitchen_outlined, size: 64),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _t(context, 'frequent_empty_action'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 18),
                ]
              : [
                  for (final item in report.frequentFoods.entries)
                    _Value(item.key, '${item.value}\u00D7'),
                ],
        ),
        _Section(
          title: _t(context, 'premium_insights'),
          icon: premiumActive == true
              ? Icons.workspace_premium_rounded
              : premiumActive == false
              ? Icons.lock_outline_rounded
              : Icons.hourglass_top_rounded,
          children: [
            Semantics(
              key: const Key('weekly-report-premium-state'),
              label: premiumActive == null
                  ? _t(context, 'subscription_check_unavailable')
                  : _weeklyPremiumState(context, premiumActive),
              button: premiumActive == false,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: premiumActive == false
                    ? () => context.push('/plans')
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    premiumActive == true
                        ? _t(context, 'premium_truth')
                        : premiumActive == false
                        ? _weeklyPremiumState(context, false)
                        : _t(context, 'subscription_check_unavailable'),
                  ),
                ),
              ),
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-macros-section'),
          title: _t(context, 'macros'),
          icon: Icons.donut_large_rounded,
          children: [
            _Value(
              _t(context, 'protein'),
              '${report.totalProteinG.toStringAsFixed(0)} g',
            ),
            _Value(
              _t(context, 'carbs'),
              '${report.totalCarbsG.toStringAsFixed(0)} g',
            ),
            _Value(
              _t(context, 'fat'),
              '${report.totalFatG.toStringAsFixed(0)} g',
            ),
            const SizedBox(height: 12),
            _MacroDistribution(report: report),
            const SizedBox(height: 8),
            _ResponsiveAction(
              key: const Key('weekly-macro-importer-link'),
              onPressed: () => context.push('/nutrition'),
              icon: Icons.add_chart_rounded,
              label: _weeklySurfaceText(context, 'Open nutrition importer'),
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-exercise-section'),
          title: _t(context, 'exercise_steps'),
          icon: Icons.directions_run_rounded,
          children: [
            Text(
              _weeklySurfaceText(
                context,
                'Connect a supported app or device to bring saved activity into your weekly picture.',
              ),
            ),
            const SizedBox(height: 6),
            _ResponsiveAction(
              key: const Key('weekly-connected-health-cta'),
              onPressed: () => context.push('/connected-health'),
              icon: Icons.devices_other,
              label: _weeklySurfaceText(context, 'Connect apps and devices'),
            ),
            _Value(_t(context, 'weekly_goal'), '—'),
            _Value(
              _t(context, 'exercise'),
              '${report.exerciseDays} ${_t(context, 'days')}',
            ),
            _Value(
              _t(context, 'steps'),
              report.totalSteps == null ? '—' : '${report.totalSteps}',
            ),
            const SizedBox(height: 8),
            _ActivityChart(days: days),
            _ChartLegend(
              items: [(_t(context, 'steps'), const Color(0xFF90CAF9))],
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-alltime-section'),
          title: _t(context, 'all_time'),
          icon: Icons.insights_rounded,
          children: [
            _Value(
              _weeklySurfaceText(context, 'Member since'),
              memberSinceCopy,
              key: const Key('weekly-member-since-value'),
            ),
            _Value(
              _weeklySurfaceText(context, 'Foods logged'),
              '${report.allTimeFoodCount}',
            ),
            _Value(_t(context, 'meals'), '${report.allTimeMealCount}'),
            _Value(_t(context, 'exercise'), '${report.allTimeExerciseDays}'),
            _Value(
              _t(context, 'steps'),
              report.allTimeSteps == null ? '—' : '${report.allTimeSteps}',
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-keep-section'),
          title: _t(context, 'keep_it_up'),
          icon: Icons.local_fire_department_rounded,
          children: [
            Center(
              child: Text(
                _weeklySurfaceText(
                  context,
                  'Continue to log in every day to keep your streak going.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '${report.loggingStreakDays} ${_t(context, 'days')}!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: const Color(0xFF1976D2),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}
