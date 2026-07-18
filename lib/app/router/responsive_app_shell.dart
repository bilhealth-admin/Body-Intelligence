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
    if (!wide) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: navigate,
          destinations: destinations,
        ),
      );
    }
    return Scaffold(
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
