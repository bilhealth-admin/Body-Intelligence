import 'package:flutter/material.dart';

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
}) {
  final formKey = GlobalKey<FormState>();
  final controllers = List.generate(4, (_) => TextEditingController());
  var time = TimeOfDay.now();
  var saving = false;
  String? saveError;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
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

        return PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(copy('Quick Add macros', 'إضافة سريعة للمغذيات')),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restaurant_rounded),
                      title: Text(copy('Meal', 'الوجبة')),
                      trailing: Text(mealLabel),
                    ),
                    for (final field in <({String label, double max, int i})>[
                      (label: copy('Calories', 'السعرات'), max: 10000, i: 0),
                      (
                        label: copy('Protein (g)', 'البروتين (جم)'),
                        max: 2000,
                        i: 1,
                      ),
                      (
                        label: copy('Carbohydrates (g)', 'الكربوهيدرات (جم)'),
                        max: 2000,
                        i: 2,
                      ),
                      (label: copy('Fat (g)', 'الدهون (جم)'), max: 2000, i: 3),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          controller: controllers[field.i],
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(labelText: field.label),
                          validator: (raw) => validateNumber(raw, field.max),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(copy('Time', 'الوقت')),
                      trailing: Text(time.format(context)),
                      enabled: !saving,
                      onTap: saving
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: time,
                              );
                              if (picked != null) {
                                setDialogState(() => time = picked);
                              }
                            },
                    ),
                    if (saveError != null)
                      Text(
                        saveError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text(copy('Cancel', 'إلغاء')),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final known = controllers
                            .map((entry) => entry.text.trim().isNotEmpty)
                            .toList(growable: false);
                        final values = controllers
                            .map(
                              (entry) => entry.text.trim().isEmpty
                                  ? 0.0
                                  : double.parse(
                                      entry.text.trim().replaceAll(',', '.'),
                                    ),
                            )
                            .toList(growable: false);
                        if (values.every((entry) => entry == 0)) {
                          setDialogState(
                            () => saveError = copy(
                              'Enter at least one valid calorie or macro value.',
                              'أدخل قيمة صحيحة واحدة على الأقل للسعرات أو المغذيات.',
                            ),
                          );
                          return;
                        }
                        FocusScope.of(dialogContext).unfocus();
                        setDialogState(() {
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
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              saveError = copy(
                                'Could not save this entry. Try again.',
                                'تعذر حفظ هذه الإضافة. حاول مرة أخرى.',
                              );
                            });
                          }
                        }
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(copy('Add', 'إضافة')),
              ),
            ],
          ),
        );
      },
    ),
  );
}
