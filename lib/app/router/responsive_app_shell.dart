import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';

class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({super.key, required this.child});

  final Widget child;

  static const paths = <String>[
    '/dashboard',
    '/daily-log',
    '/nutrition',
    '/history',
    '/analytics',
    '/settings',
  ];

  int selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = paths.indexWhere(location.startsWith);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final index = selectedIndex(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: context.strings.text('Today'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.edit_note),
        label: context.strings.text('Diary'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.restaurant_menu),
        label: context.strings.text('Discover'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.monitor_weight_outlined),
        label: context.strings.text('Progress'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.analytics_outlined),
        label: context.strings.text('Insights'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        label: context.strings.text('More'),
      ),
    ];
    void navigate(int next) => context.go(paths[next]);
    void quickAdd() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              ListTile(
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إضافة سريعة'
                      : 'Quick Add',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'اختر إجراءً واحدًا. لن يتم حفظ شيء دون تأكيدك.'
                      : 'Choose one action. Nothing is saved without your confirmation.',
                ),
              ),
              _QuickAction(
                icon: Icons.monitor_weight_outlined,
                label: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'قياس الوزن اليومي'
                    : 'Daily weight check-in',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/daily-check-in');
                },
              ),
              _QuickAction(
                icon: Icons.restaurant_menu,
                label: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'وجبة أو ماء'
                    : 'Meal or water',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/daily-log');
                },
              ),
              _QuickAction(
                icon: Icons.search,
                label: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'بحث أو طعام مخصص'
                    : 'Search or create food',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/nutrition');
                },
              ),
              _QuickAction(
                icon: Icons.event_note_outlined,
                label: context.strings.text('Life context'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/context');
                },
              ),
              ListTile(
                enabled: false,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Ask BIL'),
                subtitle: const Text(
                  'Unavailable until the server-side AI consent and rate-limit boundary is configured.',
                ),
                trailing: const Icon(Icons.lock_outline),
              ),
            ],
          ),
        ),
      ),
    );
    final quickButton = FloatingActionButton(
      onPressed: quickAdd,
      tooltip: 'Quick Add',
      child: const Icon(Icons.add),
    );
    if (!wide) {
      return Scaffold(
        body: child,
        floatingActionButton: quickButton,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: navigate,
          destinations: destinations,
        ),
      );
    }
    return Scaffold(
      floatingActionButton: quickButton,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: navigate,
            labelType: NavigationRailLabelType.all,
            destinations: destinations
                .map(
                  (item) => NavigationRailDestination(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
