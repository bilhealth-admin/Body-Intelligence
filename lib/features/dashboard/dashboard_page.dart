import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/dashboard_grid.dart';
import 'widgets/dashboard_header.dart';
import '../../app/localization/app_localizations.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BIL'),
        actions: [
          IconButton(
            tooltip: context.strings.text('Daily check-in'),
            icon: const Icon(Icons.monitor_weight_outlined),
            onPressed: () => context.go('/daily-check-in'),
          ),
          IconButton(
            tooltip: 'Life context',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.go('/context'),
          ),
          IconButton(
            tooltip: 'Food catalog',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => context.go('/nutrition'),
          ),
          IconButton(
            tooltip: 'Analytics',
            icon: const Icon(Icons.analytics),
            onPressed: () => context.go('/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.strings.text('Add Daily Entry')),
        onPressed: () => context.go('/daily-log'),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardHeader(),
              SizedBox(height: 20),
              DashboardGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
