part of 'weekly_report_page.dart';

class _Message extends StatelessWidget {
  const _Message(this.value, {this.onRetry});

  final String value;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('weekly-report-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                // A production MaterialApp always installs the BIL delegate,
                // but an error state must remain renderable in minimal hosts
                // (tests, previews, and defensive embedding) as well.
                label: Text(strings?.text('Retry') ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
