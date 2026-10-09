import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';

class FirstValueHandoffCard extends StatefulWidget {
  const FirstValueHandoffCard({
    super.key,
    required this.onContinue,
    this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  @override
  State<FirstValueHandoffCard> createState() => _FirstValueHandoffCardState();
}

class _FirstValueHandoffCardState extends State<FirstValueHandoffCard> {
  bool _skippedThisSession = false;

  @override
  Widget build(BuildContext context) {
    if (_skippedThisSession) return const SizedBox.shrink();
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
                fontWeight: FontWeight.w700,
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
          Row(
            children: [
              if (widget.onSkip != null)
                TextButton(
                  key: const Key('first-value-guide-skip'),
                  onPressed: widget.onSkip == null
                      ? null
                      : () {
                          // Never trap a reviewer while local storage retries.
                          setState(() => _skippedThisSession = true);
                          widget.onSkip?.call();
                        },
                  child: Text(context.strings.text('Skip')),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onContinue,
                icon: const Icon(Icons.monitor_weight_outlined),
                label: Text(context.strings.text('Record first check-in')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
