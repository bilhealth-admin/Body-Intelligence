import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
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
        loading: () => Semantics(
          label: context.strings.text('Loading your latest body data'),
          child: const LinearProgressIndicator(
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.strings.text(
                'Your latest body data could not be loaded.',
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => ref.invalidate(latestWeightProvider),
              icon: const Icon(Icons.refresh),
              label: Text(context.strings.text('Try again')),
            ),
          ],
        ),
        data: (weight) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              arabic ? 'مرحبًا بعودتك' : 'Welcome back',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              weight == null
                  ? (arabic ? 'ابدأ أول تسجيل لك' : 'Start your first log')
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
                  ? (arabic
                        ? 'سجّل وزنك ووجباتك لبناء ذكاء BIL المحلي.'
                        : 'Record your weight and meals to build your local BIL intelligence.')
                  : (arabic
                        ? 'بياناتك المحلية جاهزة للمراجعة.'
                        : 'Your local data is ready for review.'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
