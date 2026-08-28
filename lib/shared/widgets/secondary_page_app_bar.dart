import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Canonical navigation chrome for pages that live outside the primary shell.
///
/// Back behavior is deterministic:
/// - pop when the page was pushed and history exists;
/// - otherwise return safely to the Dashboard (direct link or `context.go`).
class SecondaryPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SecondaryPageAppBar({
    super.key,
    required this.title,
    this.actions,
    this.dashboardPath = '/dashboard',
    this.showDashboardAction = true,
    this.onBack,
  });

  final Widget title;
  final List<Widget>? actions;
  final String dashboardPath;
  final bool showDashboardAction;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    void leaveSecondaryPage() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(dashboardPath);
      }
    }

    return AppBar(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      title: title,
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: IconButton.filled(
          key: const Key('secondary-page-back'),
          tooltip: arabic ? 'رجوع' : 'Back',
          onPressed: onBack ?? leaveSecondaryPage,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      actions: [
        if (showDashboardAction)
          IconButton.filled(
            key: const Key('secondary-page-dashboard'),
            tooltip: arabic ? 'العودة إلى لوحة اليوم' : 'Return to Today',
            onPressed: () => context.go(dashboardPath),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            icon: const Icon(Icons.dashboard_outlined),
          ),
        if (showDashboardAction) const SizedBox(width: 8),
        ...?actions,
      ],
    );
  }
}
