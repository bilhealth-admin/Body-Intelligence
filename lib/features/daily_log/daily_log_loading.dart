part of 'daily_log_page.dart';

class _DailyLedgerSkeleton extends StatelessWidget {
  const _DailyLedgerSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      key: const Key('daily-log-ledger-loading-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 150,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ],
    );
  }
}
