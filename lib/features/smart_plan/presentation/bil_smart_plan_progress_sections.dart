part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanProgressSections on _BilSmartPlanPageState {
  Widget _progress(BilSmartPlan plan) {
    final week = BilSmartPlanWeekReview(
      plan,
      ref.read(bilSmartPlanClockProvider)(),
    );
    final done = plan.days
        .where((day) => day.workout?.completed == true)
        .length;
    final scheduled = plan.days.where((day) => day.workout != null).length;
    return _panel(
      artwork: BilSmartPlanArt.progress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilSmartPlanSectionTitle(
            title: _t('Training progress', 'تقدم التدريب'),
            subtitle: _t(
              'Only confirmed sessions count as completed.',
              'تُحتسب الجلسات المؤكدة فقط بوصفها مكتملة.',
            ),
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: plan.workoutCompletion),
          const SizedBox(height: 10),
          Text(
            '$done / $scheduled${_t(' confirmed sessions', ' جلسات مؤكدة')}',
          ),
          const SizedBox(height: 14),
          BilSmartPlanMetricPair(
            first: BilSmartPlanMetric(
              label: _t('Confirmed', 'المؤكدة'),
              value: done.toString(),
              icon: Icons.check_circle_outline_rounded,
            ),
            second: BilSmartPlanMetric(
              label: _t('Scheduled', 'المجدولة'),
              value: scheduled.toString(),
              icon: Icons.calendar_today_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Nutrition suggestions do not count as actual intake. Review the diary for recorded food.',
              'الوجبات المقترحة لا تُحسب كطعام مأكول. راجع سجل الطعام للاستهلاك الفعلي.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _t('Last seven days', 'آخر سبعة أيام'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${_t('Confirmed sessions: ', 'جلسات مؤكدة: ')}${week.confirmed} / ${week.scheduled}',
          ),
          Text(
            '${_t('Past sessions awaiting confirmation: ', 'جلسات سابقة دون تأكيد: ')}${week.unconfirmedPast}',
          ),
          Text(
            _t(
              'An unconfirmed session may simply be unrecorded. Review it before changing your schedule.',
              'قد تكون الجلسة غير المؤكدة غير مسجلة فقط. راجعها قبل تعديل جدولك.',
            ),
          ),
          if (plan.days.any((day) => day.phase.startsWith('gym-month-'))) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(
                _t('Plan phases and review', 'مراحل الخطة والمراجعة'),
              ),
              subtitle: Text(
                _t(
                  'Source guidance does not automatically change your approved training frequency.',
                  'إرشادات المصدر لا تغيّر عدد جلساتك المعتمد تلقائيًا.',
                ),
              ),
              children: [
                for (final phaseId in plan.days.map((day) => day.phase).toSet())
                  FutureBuilder<Map<String, String>?>(
                    future: const BilSmartPlanPrescriptions().phase(phaseId),
                    builder: (context, snapshot) {
                      final phase = snapshot.data;
                      if (phase == null) return const SizedBox.shrink();
                      final locale = BilLocalePolicy.canonicalTag(
                        Localizations.localeOf(context),
                      );
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              smartPlanSourcePhaseText(phase['name']!, locale),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              smartPlanSourcePhaseText(
                                phase['progression']!,
                                locale,
                              ),
                            ),
                            Text(
                              smartPlanSourcePhaseText(
                                phase['deload']!,
                                locale,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          if (plan.changes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ExpansionTile(
              key: const ValueKey('bil-smart-plan-revision-history'),
              title: Text(_t('Plan revision history', 'سجل إصدارات الخطة')),
              subtitle: Text(
                _t(
                  'Compare recent confirmed changes. Previous versions are read only.',
                  'قارن التعديلات المؤكدة الأخيرة. الإصدارات السابقة للقراءة فقط.',
                ),
              ),
              children: [
                for (final change in plan.changes)
                  ListTile(
                    title: Text(
                      '${change.revision} · ${_changeReason(change.reason)}',
                    ),
                    subtitle: Text(BilPlanDate.iso(change.at.toLocal())),
                    trailing: const Icon(Icons.compare_arrows_rounded),
                    onTap: () => _showRevision(plan, change.revision),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _overview(BilSmartPlan plan) => _panel(
    artwork: BilSmartPlanArt.overview,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: _smartPlanActionInk(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _horizonName(plan.horizon),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.startDate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusName(plan.status),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _smartPlanActionInk(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_t('A clear plan, one day at a time.', 'خطتك واضحة، يومًا بيوم.')),
        const SizedBox(height: 14),
        BilSmartPlanMetricPair(
          first: BilSmartPlanMetric(
            label: _t('Days in plan', 'أيام الخطة'),
            value: plan.days.length.toString(),
            icon: Icons.date_range_rounded,
          ),
          second: BilSmartPlanMetric(
            label: _t('Scheduled workouts', 'التمارين المجدولة'),
            value: plan.days
                .where((day) => day.workout != null)
                .length
                .toString(),
            icon: Icons.fitness_center_rounded,
          ),
        ),
        if (!_catalogBlocked &&
            (plan.status == BilPlanStatus.draft ||
                plan.status == BilPlanStatus.paused)) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _changeStatus(BilPlanStatus.active),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_t('Approve and activate', 'اعتماد وتفعيل')),
          ),
        ],
      ],
    ),
  );
}
