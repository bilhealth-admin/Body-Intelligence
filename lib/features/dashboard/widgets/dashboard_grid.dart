import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_log/providers/daily_log_provider.dart';
import 'stat_card.dart';

class DashboardGrid extends ConsumerWidget {
  const DashboardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestLog = ref.watch(latestDailyLogProvider);

    return latestLog.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Text(error.toString()),
      ),
      data: (log) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.05,
          children: [
            StatCard(
              title: 'Weight',
              value: log?.weight != null
                  ? '${log!.weight!.toStringAsFixed(1)} kg'
                  : '--',
              icon: Icons.monitor_weight,
              color: Colors.blue,
            ),
            StatCard(
              title: 'Calories',
              value: log?.calories?.toString() ?? '--',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
            StatCard(
              title: 'Protein',
              value: log?.protein != null
                  ? '${log!.protein} g'
                  : '--',
              icon: Icons.fitness_center,
              color: Colors.green,
            ),
            StatCard(
              title: 'Water',
              value: log?.water != null
                  ? '${(log!.water! / 1000).toStringAsFixed(1)} L'
                  : '--',
              icon: Icons.water_drop,
              color: Colors.cyan,
            ),
          ],
        );
      },
    );
  }
}