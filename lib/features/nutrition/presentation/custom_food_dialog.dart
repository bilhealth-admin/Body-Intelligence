part of '../food_page.dart';

class _FoodDraft {
  const _FoodDraft({
    required this.name,
    required this.arabicName,
    required this.barcode,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.calcium,
    required this.magnesium,
    required this.sugar,
    required this.caloriesKnown,
    required this.proteinKnown,
    required this.carbsKnown,
    required this.fatsKnown,
  });
  final String name;
  final String? arabicName;
  final String? barcode;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double? fiber;
  final double? sodium;
  final double? potassium;
  final double? calcium;
  final double? magnesium;
  final double? sugar;
  final bool caloriesKnown;
  final bool proteinKnown;
  final bool carbsKnown;
  final bool fatsKnown;
}

class _CustomFoodDialog extends StatefulWidget {
  const _CustomFoodDialog({this.initialBarcode, this.food, this.onSave});

  final String? initialBarcode;
  final Food? food;
  final Future<void> Function(_FoodDraft draft)? onSave;

  @override
  State<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<_CustomFoodDialog> {
  final formKey = GlobalKey<FormState>();
  final controllers = List.generate(15, (_) => TextEditingController());
  bool saving = false;
  String? saveError;

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    if (food == null) {
      controllers[2].text = widget.initialBarcode ?? '';
      return;
    }
    final values = <String>[
      food.name,
      food.arabicName ?? '',
      food.barcode ?? '',
      food.servingSize.toString(),
      food.servingUnit,
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.calories,
          )
          ? food.calories.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.protein,
          )
          ? food.protein.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.carbohydrates,
          )
          ? food.carbs.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.fat,
          )
          ? food.fats.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.fiber,
          )
          ? food.fiber.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.sodium,
          )
          ? food.sodium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.potassium,
          )
          ? food.potassium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.calcium,
          )
          ? food.calcium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.magnesium,
          )
          ? food.magnesium.toString()
          : '',
      NutrientEvidenceMask.contains(
            food.nutrientEvidenceMask,
            TrackedNutrient.sugar,
          )
          ? food.sugar.toString()
          : '',
    ];
    for (var index = 0; index < values.length; index++) {
      controllers[index].text = values[index];
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => customFoodText(context, key);
    const labels = <String>[
      'English name',
      'Arabic name',
      'Barcode',
      'Serving size',
      'Serving unit',
      'Calories',
      'Protein',
      'Carbohydrates',
      'Fat',
      'Fiber',
      'Sodium',
      'Potassium',
      'Calcium',
      'Magnesium',
      'Sugar',
    ];
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(
          t(widget.food == null ? 'Create custom food' : 'Edit custom food'),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(labels.length, (index) {
                  return TextFormField(
                    controller: controllers[index],
                    enabled: !saving,
                    decoration: InputDecoration(labelText: t(labels[index])),
                    keyboardType: index >= 3 && index != 4
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    validator: (value) {
                      if (index == 0 &&
                          (value == null || value.trim().isEmpty)) {
                        return t('Required');
                      }
                      if ((index == 3 || index == 4) &&
                          (value == null || value.trim().isEmpty)) {
                        return t('Required');
                      }
                      if (index == 2 && value?.trim().isNotEmpty == true) {
                        final barcode = value!.trim();
                        if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
                          return t('Enter a valid 8 to 14 digit barcode');
                        }
                      }
                      if (index >= 3 && index != 4) {
                        if (index >= 5 && (value == null || value.isEmpty)) {
                          return null;
                        }
                        final number = double.tryParse(
                          (value ?? '').replaceAll(',', '.'),
                        );
                        if (number == null ||
                            !number.isFinite ||
                            number < 0 ||
                            (index == 3 && number <= 0) ||
                            (index == 3 && number > 100000) ||
                            (index == 5 && number > 10000) ||
                            (index >= 6 && index <= 9 && number > 2000) ||
                            (index == 14 && number > 2000) ||
                            (index >= 10 && index <= 13 && number > 1000000)) {
                          return t('Enter a non-negative number');
                        }
                      }
                      return null;
                    },
                  );
                }),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    double number(int index) => double.parse(
                      controllers[index].text.replaceAll(',', '.'),
                    );
                    double? optionalNumber(int index) =>
                        controllers[index].text.trim().isEmpty
                        ? null
                        : number(index);
                    double coreValue(int index) =>
                        controllers[index].text.trim().isEmpty
                        ? 0
                        : number(index);
                    final draft = _FoodDraft(
                      name: controllers[0].text.trim(),
                      arabicName: controllers[1].text.trim().isEmpty
                          ? null
                          : controllers[1].text.trim(),
                      barcode: controllers[2].text.trim().isEmpty
                          ? null
                          : controllers[2].text.trim(),
                      servingSize: number(3),
                      servingUnit: controllers[4].text.trim(),
                      calories: coreValue(5),
                      protein: coreValue(6),
                      carbs: coreValue(7),
                      fats: coreValue(8),
                      fiber: optionalNumber(9),
                      sodium: optionalNumber(10),
                      potassium: optionalNumber(11),
                      calcium: optionalNumber(12),
                      magnesium: optionalNumber(13),
                      sugar: optionalNumber(14),
                      caloriesKnown: controllers[5].text.trim().isNotEmpty,
                      proteinKnown: controllers[6].text.trim().isNotEmpty,
                      carbsKnown: controllers[7].text.trim().isNotEmpty,
                      fatsKnown: controllers[8].text.trim().isNotEmpty,
                    );
                    if (widget.onSave == null) {
                      Navigator.pop(context, draft);
                      return;
                    }
                    setState(() {
                      saving = true;
                      saveError = null;
                    });
                    try {
                      await widget.onSave!(draft);
                      if (context.mounted) Navigator.pop(context, draft);
                    } catch (error) {
                      if (mounted) {
                        setState(() {
                          saving = false;
                          saveError =
                              error is StateError &&
                                  error.toString().contains(
                                    'barcode already exists',
                                  )
                              ? t('A food with this barcode already exists.')
                              : t(
                                  'Could not save this food. Review the values and try again.',
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
                : Text(t('Save')),
          ),
        ],
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: false,
        icon: saveError == null
            ? null
            : Text(
                saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
