import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../engine/data_honesty_engine.dart';

class ConfidenceRing extends StatelessWidget {
  const ConfidenceRing({
    super.key,
    required this.score,
    required this.reliability,
    this.size = 58,
  });

  final int score;
  final DataReliability reliability;
  final double size;

  String label(BuildContext context) => switch (reliability) {
    DataReliability.insufficient => context.strings.text('Insufficient data'),
    DataReliability.emerging => context.strings.text('Emerging confidence'),
    DataReliability.useful => context.strings.text('Useful confidence'),
    DataReliability.strong => context.strings.text('Strong confidence'),
  };

  Color color(BuildContext context) => switch (reliability) {
    DataReliability.insufficient => Theme.of(context).colorScheme.error,
    DataReliability.emerging => Colors.orange.shade700,
    DataReliability.useful => Colors.blue.shade700,
    DataReliability.strong => Colors.green.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final semanticLabel = label(context);
    final ringColor = color(context);
    return Semantics(
      label: '${context.strings.text('Analysis reliability')}: $semanticLabel',
      value: '$score%',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: score.clamp(0, 100) / 100,
                strokeWidth: 5,
                color: ringColor,
                backgroundColor: ringColor.withValues(alpha: 0.16),
              ),
            ),
            Text(
              '$score',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
