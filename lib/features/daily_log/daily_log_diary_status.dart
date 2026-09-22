part of 'daily_log_page.dart';

extension _DailyLogDiaryStatus on _DailyLogPageState {
  Widget _diaryStatus(
    AsyncValue<AuthoritativeDailyLedger> ledger,
  ) => PremiumSurface(
    key: const Key('daily-log-lifecycle-card'),
    child: ledger.when(
      skipLoadingOnRefresh: false,
      loading: () => const _DailyLedgerSkeleton(),
      error: (_, _) => ActionableErrorState(
        title: _tr(
          'Diary status could not be loaded.',
          'تعذر تحميل حالة اليوميات.',
        ),
        onRetry: () => ref.invalidate(selectedDailyLedgerProvider),
      ),
      data: (snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            snapshot.state == DayLifecycleState.closed
                ? _tr('Diary completed', 'اكتملت اليوميات')
                : _tr('Complete diary', 'إكمال اليوميات'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.state == DayLifecycleState.closed
                ? _tr(
                    'This day is frozen as a reviewed nutrition snapshot. Reopen it before making changes.',
                    'تم تثبيت هذا اليوم كلقطة تغذية تمت مراجعتها. أعد فتحه قبل إجراء تغييرات.',
                  )
                : _tr(
                    'Review today’s entries, then complete the diary to preserve an authoritative snapshot.',
                    'راجع مدخلات اليوم، ثم أكمل اليوميات لحفظ لقطة موثوقة.',
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: Key(
              snapshot.state == DayLifecycleState.closed
                  ? 'daily-log-reopen-day'
                  : 'daily-log-complete-day',
            ),
            onPressed: snapshot.state == DayLifecycleState.closed
                ? _reopenDiary
                : _completeDiary,
            icon: Icon(
              snapshot.state == DayLifecycleState.closed
                  ? Icons.lock_open_rounded
                  : Icons.task_alt_rounded,
            ),
            label: Text(
              snapshot.state == DayLifecycleState.closed
                  ? _tr('Reopen diary', 'إعادة فتح اليوميات')
                  : _tr('Complete diary', 'إكمال اليوميات'),
            ),
          ),
        ],
      ),
    ),
  );
}
