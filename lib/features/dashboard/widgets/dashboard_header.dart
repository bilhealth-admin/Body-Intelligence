import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
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
    final topRadius = BorderRadius.circular(PremiumDesignTokens.radiusXl);

    return Semantics(
      container: true,
      header: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PremiumDesignTokens.spaceXl),
        decoration: BoxDecoration(
          borderRadius: topRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
          ),
        ),
        child: latestWeight.when(
          loading: () => Semantics(
            label: context.strings.text(
              'Loading your latest body data and next best action context',
            ),
            child: const LinearProgressIndicator(
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.strings.text(
                  'Today could not load your latest local body data.',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              Text(
                context.strings.text(
                  'Your local records remain safe on this device. Retry to refresh the hero context.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                  onPressed: () => ref.invalidate(latestWeightProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.strings.text('Try again')),
                ),
              ),
            ],
          ),
          data: (weight) {
            final heroTitle = weight == null
                ? context.strings.text('Start today with one trusted check-in')
                : context.strings.text(
                    'Today starts from your latest evidence',
                  );
            final heroValue = weight == null
                ? (arabic ? 'أول تسجيل' : 'First check-in')
                : '${UnitConverter.weightFromKg(weight.weight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}';
            final heroContext = weight == null
                ? context.strings.text(
                    'BIL will explain change only after comparable local measurements exist.',
                  )
                : context.strings.text(
                    'This value is from your local record and is shown without claiming trend certainty.',
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  heroTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                Text(
                  heroValue,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PremiumDesignTokens.spaceMd),
                Text(
                  heroContext,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
