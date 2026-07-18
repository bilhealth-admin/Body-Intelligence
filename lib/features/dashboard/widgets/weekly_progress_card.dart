import 'package:flutter/material.dart';

class WeeklyProgressCard extends StatelessWidget {
  const WeeklyProgressCard({
    super.key,
    required this.start,
    required this.today,
    required this.goal,
    required this.unit,
  });

  final double start;
  final double today;
  final double goal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final difference = today - start;
    String value(double number) => '${number.toStringAsFixed(1)} $unit';
    final entries = <(String, String)>[
      (arabic ? 'بداية الأسبوع' : 'Week start', value(start)),
      (arabic ? 'اليوم' : 'Today', value(today)),
      (arabic ? 'الهدف' : 'Goal', value(goal)),
      (
        arabic ? 'الفرق' : 'Difference',
        '${difference > 0 ? '+' : ''}${value(difference)}',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              arabic ? 'التقدم الأسبوعي' : 'Weekly progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: entries
                    .map(
                      (entry) => SizedBox(
                        width: constraints.maxWidth >= 520
                            ? (constraints.maxWidth - 36) / 4
                            : (constraints.maxWidth - 12) / 2,
                        child: Semantics(
                          label: '${entry.$1}: ${entry.$2}',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.$1),
                              Text(
                                entry.$2,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
