import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';

class FirstValueHandoffCard extends StatelessWidget {
  const FirstValueHandoffCard({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      emphasized: true,
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.strings.text('Your private starting point is ready'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFE7EDF3),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            context.strings.text(
              'BIL saved your profile and starting targets on this device.',
            ),
            style: const TextStyle(color: Color(0xFFB8C5D1), height: 1.45),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: Color(0xFFDCE5EC),
              ),
              const SizedBox(width: PremiumDesignTokens.spaceXs),
              Expanded(
                child: Text(
                  context.strings.text(
                    'BIL does not have a comparable daily measurement yet, so it will not claim a trend.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFC1CCD6),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.monitor_weight_outlined),
            label: Text(context.strings.text('Record first check-in')),
          ),
        ],
      ),
    );
  }
}
