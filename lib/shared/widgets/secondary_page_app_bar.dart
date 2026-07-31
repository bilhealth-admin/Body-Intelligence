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
  });

  final Widget title;
  final List<Widget>? actions;
  final String dashboardPath;

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
      title: title,
      leading: IconButton(
        key: const Key('secondary-page-back'),
        tooltip: arabic ? 'رجوع' : 'Back',
        onPressed: leaveSecondaryPage,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      actions: [
        IconButton(
          key: const Key('secondary-page-dashboard'),
          tooltip: arabic ? 'العودة إلى لوحة اليوم' : 'Return to Today',
          onPressed: () => context.go(dashboardPath),
          icon: const Icon(Icons.dashboard_rounded),
        ),
        ...?actions,
      ],
    );
  }
}
