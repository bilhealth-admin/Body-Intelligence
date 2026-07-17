import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/daily_log/providers/daily_log_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(latestDailyLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: logs.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, s) => Center(
          child: Text(e.toString()),
        ),
        data: (log) {
          if (log == null) {
            return const Center(
              child: Text('No data yet'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.monitor_weight),
                title: Text('${log.weight ?? '--'} kg'),
                subtitle: Text(log.date.toString()),
              ),
              ListTile(
                leading: const Icon(Icons.local_fire_department),
                title: Text('${log.calories ?? '--'} kcal'),
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text('${log.protein ?? '--'} g Protein'),
              ),
              ListTile(
                leading: const Icon(Icons.water_drop),
                title: Text('${log.water ?? '--'} ml Water'),
              ),
            ],
          );
        },
      ),
    );
  }
}