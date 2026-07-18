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
            tooltip: context.strings.text('Life context'),
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.go('/context'),
          ),
          IconButton(
            tooltip: context.strings.text('Food catalog'),
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => context.go('/nutrition'),
          ),
          IconButton(
            tooltip: context.strings.text('Analytics'),
            icon: const Icon(Icons.analytics),
            onPressed: () => context.go('/analytics'),
          ),
          IconButton(
            tooltip: context.strings.text('Weight history'),
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/history'),
          ),
          IconButton(
            tooltip: context.strings.text('Settings'),
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
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
