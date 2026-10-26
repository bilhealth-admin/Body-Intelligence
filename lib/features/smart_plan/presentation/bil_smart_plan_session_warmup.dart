part of 'bil_smart_plan_page.dart';

/// Warmup and reference surfaces share the active session owner fence.
extension _BilSessionWarmup on _BilSmartPlanSessionState {
  Widget _sourceLink(String title, String url) => TextButton.icon(
    style: TextButton.styleFrom(foregroundColor: _smartPlanActionInk(context)),
    onPressed: () async {
      if (!_allowed()) return;
      var opened = false;
      try {
        opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } on Object {
        opened = false;
      }
      if (!opened && mounted && _allowed()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _smartPlanText(
                context,
                'The reference could not be opened. Try again.',
                'تعذّر فتح المرجع. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    },
    icon: const Icon(Icons.open_in_new_rounded),
    label: Text(title),
  );

  Widget _warmupSurface(String locale) {
    String t(String en, String ar) => _smartPlanText(context, en, ar);
    final home = widget.day.workout!.templateId.startsWith('home-');
    return ListView(
      key: const ValueKey('bil-smart-plan-warmup-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        BilSmartPlanPanel(
          artwork: BilSmartPlanArt.recovery,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.self_improvement_rounded, size: 32),
                const SizedBox(height: 12),
                Text(
                  t('Warm up before your session', 'الإحماء قبل جلستك'),
                  key: const ValueKey('bil-smart-plan-warmup'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  home
                      ? t(
                          'Allow at least 6 minutes. Start gently, take longer when needed, and stop if you feel pain or become unwell.',
                          'خصص 6 دقائق على الأقل. ابدأ بلطف وخذ وقتًا أطول عند الحاجة، وتوقف إذا شعرت بألم أو بتوعك.',
                        )
                      : t(
                          'Prepare with the movements from your BIL source plan. Keep the effort gentle; these are preparation sets, separate from your working sets.',
                          'استعد بحركات الإحماء من خطة BIL الموثقة. حافظ على جهد خفيف؛ هذه مجموعات تحضيرية منفصلة عن مجموعات التدريب.',
                        ),
                ),
                for (final step in _warmups) ...[
                  const SizedBox(height: 16),
                  Text(
                    (locale == 'ar' && step.titleAr != null)
                        ? step.titleAr!
                        : step.exerciseId == null
                        ? (locale == 'ar'
                              ? step.titleAr ?? step.title
                              : step.title)
                        : _warmupTitles[step.exerciseId]!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _rangeForDirection(
                      locale == 'ar'
                          ? step.doseAr ??
                                'مجموعة واحدة بتحكم؛ 6–10 تكرارات أو 20–30 ثانية.'
                          : step.dose,
                    ),
                  ),
                  if (step.exerciseId != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _smartPlanActionInk(context),
                      ),
                      onPressed: _opening
                          ? null
                          : () async {
                              if (!_allowed()) return;
                              _updateSessionState(() => _opening = true);
                              try {
                                await widget.openExercise(step.exerciseId!);
                              } finally {
                                if (mounted) {
                                  _updateSessionState(() => _opening = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(
                        t('View verified movement', 'عرض الحركة الموثقة'),
                      ),
                    ),
                ],
                if (home)
                  _sourceLink(
                    t('NHS warm-up reference', 'مرجع الإحماء من NHS'),
                    'https://www.nhs.uk/live-well/exercise/how-to-warm-up-before-exercising/',
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('bil-smart-plan-warmup-continue'),
                  onPressed: () {
                    if (_allowed()) {
                      _updateSessionState(() => _warmupReviewed = true);
                    }
                  },
                  icon: const BilCrystalArrow(
                    extent: 36,
                    child: Icon(Icons.arrow_forward_rounded),
                  ),
                  label: Text(
                    t('Continue to exercises', 'المتابعة إلى التمارين'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Reviewing this preparation does not record a completed workout.',
                    'مراجعة الإحماء لا تسجّل تمرينًا مكتملًا.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
