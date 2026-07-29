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

    assert(state.hasFailure, 'DashboardDataGate only handles non-ready states.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.strings.text('Today could not read all local data'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.text(
                'No current insight is shown because it may be stale. Existing records remain in local storage; retry when storage is available.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.strings.text('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
