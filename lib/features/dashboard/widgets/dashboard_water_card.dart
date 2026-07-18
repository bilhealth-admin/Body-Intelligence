import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.text('Water'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${widget.consumedMl} / $target ml'),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              label:
                  '${context.strings.text('Water progress')}: ${widget.consumedMl} / $target ml',
              value: '${(progress * 100).round()}%',
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(height: 6),
            Text(
              remaining > 0
                  ? '$remaining ml ${context.strings.text('remaining')}'
                  : context.strings.text('Hydration target reached'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
