import 'package:flutter/material.dart';

import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/bil_wordmark.dart';

typedef QuickMacroCopy = String Function(String english, String arabic);

final class QuickMacroDraft {
  const QuickMacroDraft({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.caloriesKnown,
    required this.proteinKnown,
    required this.carbohydratesKnown,
    required this.fatKnown,
    required this.time,
  });

  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final bool caloriesKnown;
  final bool proteinKnown;
  final bool carbohydratesKnown;
  final bool fatKnown;
  final TimeOfDay time;
}

Future<bool?> showQuickMacroEntryDialog({
  required BuildContext context,
  required QuickMacroCopy copy,
  required String mealLabel,
  required Future<void> Function(QuickMacroDraft draft) onSave,
  TimeOfDay? initialTime,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _QuickMacroEntryDialog(
      copy: copy,
      mealLabel: mealLabel,
      onSave: onSave,
      initialTime: initialTime,
    ),
  );
}

class _QuickMacroEntryDialog extends StatefulWidget {
  const _QuickMacroEntryDialog({
    required this.copy,
    required this.mealLabel,
    required this.onSave,
    this.initialTime,
  });

  final QuickMacroCopy copy;
  final String mealLabel;
  final Future<void> Function(QuickMacroDraft draft) onSave;
  final TimeOfDay? initialTime;

  @override
  State<_QuickMacroEntryDialog> createState() => _QuickMacroEntryDialogState();
}

class _QuickMacroEntryDialogState extends State<_QuickMacroEntryDialog> {
  final formKey = GlobalKey<FormState>();
  final controllers = List.generate(4, (_) => TextEditingController());
  late TimeOfDay time = widget.initialTime ?? TimeOfDay.now();
  bool saving = false;
  String? saveError;

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final mealLabel = widget.mealLabel;
    final onSave = widget.onSave;
    final dialogContext = context;
    String? validateNumber(String? raw, double maximum) {
      final normalized = (raw ?? '').trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      final parsed = double.tryParse(normalized);
      if (parsed == null ||
          !parsed.isFinite ||
          parsed < 0 ||
          parsed > maximum) {
        return copy('Enter a non-negative number.', 'أدخل رقمًا غير سالب.');
      }
      return null;
    }

    final fields = <({String label, double max, int i, String suffix})>[
      (label: copy('Calories', 'السعرات'), max: 10000, i: 0, suffix: 'kcal'),
      (label: copy('Protein', 'البروتين'), max: 2000, i: 1, suffix: 'g'),
      (
        label: copy('Carbohydrates', 'الكربوهيدرات'),
        max: 2000,
        i: 2,
        suffix: 'g',
      ),
      (label: copy('Fat', 'الدهون'), max: 2000, i: 3, suffix: 'g'),
    ];

    Future<void> save() async {
      if (saving || !mounted) return;
      if (!formKey.currentState!.validate()) return;
      final known = controllers
          .map((entry) => entry.text.trim().isNotEmpty)
          .toList(growable: false);
      final values = controllers
          .map((entry) {
            final raw = entry.text.trim();
            return raw.isEmpty ? 0.0 : double.parse(raw.replaceAll(',', '.'));
          })
          .toList(growable: false);
      if (values.every((entry) => entry == 0)) {
        setState(
          () => saveError = copy(
            'Enter at least one valid calorie or macro value.',
            'أدخل قيمة صحيحة واحدة على الأقل للسعرات أو المغذيات.',
          ),
        );
        return;
      }
      FocusScope.of(dialogContext).unfocus();
      setState(() {
        saving = true;
        saveError = null;
      });
      try {
        await onSave(
          QuickMacroDraft(
            calories: values[0],
            protein: values[1],
            carbohydrates: values[2],
            fat: values[3],
            caloriesKnown: known[0],
            proteinKnown: known[1],
            carbohydratesKnown: known[2],
            fatKnown: known[3],
            time: time,
          ),
        );
        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
      } catch (_) {
        if (dialogContext.mounted) {
          setState(() {
            saving = false;
            saveError = copy(
              'Could not save this entry. Try again.',
              'تعذر حفظ هذه الإضافة. حاول مرة أخرى.',
            );
          });
        }
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !saving,
      child: Dialog(
        key: const Key('quick-macro-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0xFF0B1220), Color(0xFF111E35)]
                    : const [Color(0xFFF9FBFF), Color(0xFFEAF1FF)],
              ),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BilFullWordmark(
                      key: Key('quick-macro-wordmark'),
                      height: 32,
                      alignment: Alignment.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      copy('Quick Add macros', 'إضافة المغذيات سريعًا'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'BILDisplay',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoTile(
                      kind: BilSemanticIconKind.meal,
                      label: copy('Meal', 'الوجبة'),
                      value: mealLabel,
                    ),
                    const SizedBox(height: 10),
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          key: Key('quick-macro-field-${field.i}'),
                          controller: controllers[field.i],
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: field.i == 3
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: (_) {
                            if (field.i < 3) {
                              FocusScope.of(context).nextFocus();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: field.label,
                            suffixText: field.suffix,
                            filled: true,
                            fillColor: scheme.surface.withValues(alpha: .82),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (raw) => validateNumber(raw, field.max),
                        ),
                      ),
                    _InfoTile(
                      kind: BilSemanticIconKind.time,
                      label: copy('Time', 'الوقت'),
                      value: time.format(context),
                      enabled: !saving,
                      onTap: saving
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: time,
                              );
                              if (mounted && picked != null) {
                                setState(() => time = picked);
                              }
                            },
                    ),
                    if (saveError != null) ...[
                      const SizedBox(height: 10),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          saveError!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                            child: Text(copy('Cancel', 'إلغاء')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: saving ? null : save,
                            child: saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(copy('Add', 'إضافة')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.kind,
    required this.label,
    required this.value,
    this.enabled = true,
    this.onTap,
  });
  final BilSemanticIconKind kind;
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .78),
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      dense: true,
      enabled: enabled,
      onTap: onTap,
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: BilSemanticIconBadge(
        kind: kind,
        size: 36,
        iconSize: 20,
        shape: BoxShape.rectangle,
      ),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    ),
  );
}
