import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/units/measurement_units.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestWeight = ref.watch(latestWeightProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
        ),
      ),
      child: latestWeight.when(
        loading: () => const Text(
          'Loading your latest data…',
          style: TextStyle(color: Colors.white),
        ),
        error: (error, _) =>
            Text(error.toString(), style: const TextStyle(color: Colors.white)),
        data: (weight) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              weight == null
                  ? 'Start your first log'
                  : '${UnitConverter.weightFromKg(weight.weight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              weight == null
                  ? 'Record your weight and meals to build your local BIL intelligence.'
                  : 'Your local data is ready for review.',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
