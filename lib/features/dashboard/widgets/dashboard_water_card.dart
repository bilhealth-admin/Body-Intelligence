import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';

class DashboardWaterCard extends StatefulWidget {
  const DashboardWaterCard({
    super.key,
    required this.consumedMl,
    required this.targetMl,
    required this.onAdd,
  });

  final int consumedMl;
  final int targetMl;
  final Future<void> Function(int amountMl) onAdd;

  @override
  State<DashboardWaterCard> createState() => _DashboardWaterCardState();
}

class _DashboardWaterCardState extends State<DashboardWaterCard> {
  bool saving = false;

  Future<void> add(int amountMl) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.onAdd(amountMl);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> customAmount() async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomWaterDialog(),
    );
    if (amount != null) await add(amount);
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetMl;
    final remaining = (target - widget.consumedMl).clamp(0, target);
    final progress = target <= 0
        ? 0.0
        : (widget.consumedMl / target).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(PremiumDesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: PremiumDesignTokens.spaceXs),
                Expanded(
                  child: Text(
                    context.strings.text('Water'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${widget.consumedMl} / $target ml'),
              ],
            ),
            SizedBox(height: PremiumDesignTokens.spaceSm),
            Semantics(
              label:
                  '${context.strings.text('Water progress')}: ${widget.consumedMl} / $target ml',
              value: '${(progress * 100).round()}%',
              child: SizedBox(
                height: 72,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, phase, _) => CustomPaint(
                    painter: _WaterWavePainter(
                      progress: progress,
                      phase: phase,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: PremiumDesignTokens.spaceXs - 2),
            Text(
              remaining > 0
                  ? '$remaining ml ${context.strings.text('remaining')}'
                  : context.strings.text('Hydration target reached'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: PremiumDesignTokens.spaceMd - 4),
            Wrap(
              spacing: PremiumDesignTokens.spaceXs,
              runSpacing: PremiumDesignTokens.spaceXs,
              children: [
                for (final amount in const [250, 500, 750])
                  FilledButton.tonal(
                    onPressed: saving ? null : () => add(amount),
                    child: Text('+$amount ml'),
                  ),
                OutlinedButton.icon(
                  onPressed: saving ? null : customAmount,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.strings.text('Custom amount')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterWavePainter extends CustomPainter {
  const _WaterWavePainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final double phase;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final bounds = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, radius),
      Paint()..color = backgroundColor.withValues(alpha: 0.45),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(bounds, radius));
    final fillStart = size.width * (1 - progress * phase);
    final path = Path()..moveTo(fillStart, 0);
    const amplitude = 4.0;
    for (double y = 0; y <= size.height; y += 2) {
      final wave = math.sin((y / size.height * math.pi * 4) + phase * math.pi);
      path.lineTo(fillStart + wave * amplitude, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.78));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _CustomWaterDialog extends StatefulWidget {
  const _CustomWaterDialog();

  @override
  State<_CustomWaterDialog> createState() => _CustomWaterDialogState();
}

class _CustomWaterDialogState extends State<_CustomWaterDialog> {
  final controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final amount = int.tryParse(controller.text.trim());
    if (amount == null || amount < 1 || amount > 5000) {
      setState(
        () => error = context.strings.text(
          'Enter a water amount from 1 to 5000 ml.',
        ),
      );
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.strings.text('Custom water amount')),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: context.strings.text('Amount in milliliters'),
        suffixText: 'ml',
        errorText: error,
      ),
      onSubmitted: (_) => submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.text('Cancel')),
      ),
      FilledButton(
        onPressed: submit,
        child: Text(context.strings.text('Add water')),
      ),
    ],
  );
}
