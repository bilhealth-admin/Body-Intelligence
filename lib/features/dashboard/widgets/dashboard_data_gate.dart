import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/dashboard_runtime_state.dart';
import 'dashboard_loading_skeleton.dart';

/// Presentation-only boundary for dashboard input readiness.
class DashboardDataGate extends StatelessWidget {
  const DashboardDataGate({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final DashboardRuntimeState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const DashboardLoadingSkeleton();
    }

    assert(
      state.hasFailure,
      'DashboardDataGate only handles non-ready states.',
    );
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('dashboard-premium-error-state'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: theme.brightness == Brightness.light
              ? const [
                  BoxShadow(
                    color: Color(0x14071822),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.strings.text('Today could not read all local data'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.text(
                'No current insight is shown because it may be stale. Existing records remain in local storage; retry when storage is available.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.strings.text('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
