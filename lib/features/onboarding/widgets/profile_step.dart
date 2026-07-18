import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../../shared/widgets/wheel_number_field.dart';

class ProfileStep extends StatelessWidget {
  const ProfileStep({
    super.key,
    required this.ageController,
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.waistCm,
    required this.neckCm,
    required this.regionController,
    required this.gender,
    required this.activity,
    required this.goalType,
    required this.system,
    required this.disclaimerAccepted,
    required this.errors,
    required this.onHeightChanged,
    required this.onCurrentWeightChanged,
    required this.onTargetWeightChanged,
    required this.onWaistChanged,
    required this.onNeckChanged,
    required this.onGenderChanged,
    required this.onActivityChanged,
    required this.onGoalTypeChanged,
    required this.onSystemChanged,
    required this.onDisclaimerChanged,
    required this.onContinue,
    required this.scrollController,
  });

  final TextEditingController ageController;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final double? waistCm;
  final double? neckCm;
  final TextEditingController regionController;
  final String? gender;
  final String? activity;
  final String goalType;
  final MeasurementSystem system;
  final bool disclaimerAccepted;
  final Map<String, String> errors;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<double> onCurrentWeightChanged;
  final ValueChanged<double> onTargetWeightChanged;
  final ValueChanged<double?> onWaistChanged;
  final ValueChanged<double?> onNeckChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onActivityChanged;
  final ValueChanged<String> onGoalTypeChanged;
  final ValueChanged<MeasurementSystem> onSystemChanged;
  final ValueChanged<bool> onDisclaimerChanged;
  final VoidCallback onContinue;
  final ScrollController scrollController;

  String tr(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isMetric = system == MeasurementSystem.metric;
    final weightUnit = UnitConverter.weightUnit(system);
    final heightUnit = UnitConverter.heightUnit(system);
    final displayedHeight = UnitConverter.heightFromCm(heightCm, system);
    final displayedCurrent = UnitConverter.weightFromKg(
      currentWeightKg,
      system,
    );
    final displayedTarget = UnitConverter.weightFromKg(targetWeightKg, system);
    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.strings.text('Complete your profile'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.strings.text('Age'),
                  errorText: errors['age'],
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'Measurement system', 'نظام القياس'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<MeasurementSystem>(
                direction: MediaQuery.sizeOf(context).width < 480
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: [
                  ButtonSegment(
                    value: MeasurementSystem.metric,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(tr(context, 'Metric', 'متري')),
                  ),
                  ButtonSegment(
                    value: MeasurementSystem.imperial,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(tr(context, 'Imperial', 'إمبراطوري')),
                  ),
                ],
                selected: {system},
                showSelectedIcon: true,
                onSelectionChanged: (value) => onSystemChanged(value.single),
              ),
              const SizedBox(height: 12),
              Text(tr(context, 'Weight unit', 'وحدة الوزن')),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _UnitChoice(
                      label: tr(context, 'Kilograms', 'كيلوغرام'),
                      selected: isMetric,
                      onTap: () => onSystemChanged(MeasurementSystem.metric),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UnitChoice(
                      label: tr(context, 'Pounds', 'رطل'),
                      selected: !isMetric,
                      onTap: () => onSystemChanged(MeasurementSystem.imperial),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(tr(context, 'Height unit', 'وحدة الطول')),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _UnitChoice(
                      label: tr(context, 'Centimeters', 'سنتيمتر'),
                      selected: isMetric,
                      onTap: () => onSystemChanged(MeasurementSystem.metric),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UnitChoice(
                      label: tr(context, 'Inches', 'بوصة'),
                      selected: !isMetric,
                      onTap: () => onSystemChanged(MeasurementSystem.imperial),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, 'Biological sex', 'الجنس البيولوجي'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                direction: MediaQuery.sizeOf(context).width < 480
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: [
                  ButtonSegment(
                    value: 'male',
                    label: Text(tr(context, 'Male', 'ذكر')),
                  ),
                  ButtonSegment(
                    value: 'female',
                    label: Text(tr(context, 'Female', 'أنثى')),
                  ),
                ],
                emptySelectionAllowed: true,
                selected: gender == null ? {} : {gender!},
                showSelectedIcon: true,
                onSelectionChanged: (value) => onGenderChanged(value.single),
              ),
              if (errors['gender'] != null) _ErrorText(errors['gender']!),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: activity,
                decoration: InputDecoration(
                  labelText: context.strings.text('Activity level'),
                  errorText: errors['activity'],
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'sedentary',
                    child: Text(
                      tr(
                        context,
                        'Sedentary — mostly seated',
                        'خامل — جلوس معظم اليوم',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'light',
                    child: Text(
                      tr(
                        context,
                        'Lightly active — 1–3 days/week',
                        'نشاط خفيف — ١–٣ أيام أسبوعيًا',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'moderate',
                    child: Text(
                      tr(
                        context,
                        'Moderately active — 3–5 days/week',
                        'نشاط متوسط — ٣–٥ أيام أسبوعيًا',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text(
                      tr(
                        context,
                        'Very active — 6–7 days/week',
                        'نشاط مرتفع — ٦–٧ أيام أسبوعيًا',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'very_active',
                    child: Text(
                      tr(
                        context,
                        'Extra active — demanding training/work',
                        'نشاط فائق — تدريب أو عمل شاق',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onActivityChanged(value);
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: goalType,
                decoration: InputDecoration(
                  labelText: context.strings.text('Goal'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'lose',
                    child: Text(context.strings.text('Lose weight')),
                  ),
                  DropdownMenuItem(
                    value: 'maintain',
                    child: Text(context.strings.text('Maintain weight')),
                  ),
                  DropdownMenuItem(
                    value: 'gain',
                    child: Text(context.strings.text('Gain weight')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onGoalTypeChanged(value);
                },
              ),
              const SizedBox(height: 24),
              WheelNumberField(
                key: ValueKey('height-$heightUnit'),
                value: displayedHeight,
                minimum: UnitConverter.heightFromCm(100, system),
                maximum: UnitConverter.heightFromCm(250, system),
                step: UnitConverter.heightStep(system),
                decimalPlaces: isMetric ? 0 : 1,
                unit: heightUnit,
                label: tr(context, 'Height', 'الطول'),
                errorText: errors['height'],
                onChanged: (value) =>
                    onHeightChanged(UnitConverter.heightToCm(value, system)),
              ),
              const SizedBox(height: 20),
              WheelNumberField(
                key: ValueKey('current-$weightUnit'),
                value: displayedCurrent,
                minimum: UnitConverter.weightFromKg(20, system),
                maximum: UnitConverter.weightFromKg(350, system),
                step: UnitConverter.weightStep(system),
                decimalPlaces: 1,
                unit: weightUnit,
                label: tr(context, 'Current weight', 'الوزن الحالي'),
                errorText: errors['currentWeight'],
                onChanged: (value) => onCurrentWeightChanged(
                  UnitConverter.weightToKg(value, system),
                ),
              ),
              const SizedBox(height: 20),
              WheelNumberField(
                key: ValueKey('target-$weightUnit'),
                value: displayedTarget,
                minimum: UnitConverter.weightFromKg(20, system),
                maximum: UnitConverter.weightFromKg(350, system),
                step: UnitConverter.weightStep(system),
                decimalPlaces: 1,
                unit: weightUnit,
                label: tr(context, 'Goal weight', 'الوزن المستهدف'),
                errorText: errors['targetWeight'],
                onChanged: (value) => onTargetWeightChanged(
                  UnitConverter.weightToKg(value, system),
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  tr(context, 'Optional body context', 'سياق الجسم الاختياري'),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Region and measurements improve relevant context and remain on this device.',
                    'تساعد المنطقة والقياسات في تحسين السياق المناسب وتبقى على هذا الجهاز.',
                  ),
                ),
                children: [
                  TextField(
                    controller: regionController,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.countryName],
                    decoration: InputDecoration(
                      labelText: tr(
                        context,
                        'Country or region',
                        'الدولة أو المنطقة',
                      ),
                      helperText: tr(
                        context,
                        'Optional; used only for locally relevant food context.',
                        'اختياري؛ يُستخدم فقط لسياق الطعام المحلي المناسب.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _OptionalMeasurementField(
                          key: ValueKey('waist-$heightUnit-$waistCm'),
                          label: tr(context, 'Waist', 'محيط الخصر'),
                          unit: heightUnit,
                          value: waistCm == null
                              ? null
                              : UnitConverter.heightFromCm(waistCm!, system),
                          onChanged: (value) => onWaistChanged(
                            value == null
                                ? null
                                : UnitConverter.heightToCm(value, system),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OptionalMeasurementField(
                          key: ValueKey('neck-$heightUnit-$neckCm'),
                          label: tr(context, 'Neck', 'محيط الرقبة'),
                          unit: heightUnit,
                          value: neckCm == null
                              ? null
                              : UnitConverter.heightFromCm(neckCm!, system),
                          onChanged: (value) => onNeckChanged(
                            value == null
                                ? null
                                : UnitConverter.heightToCm(value, system),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'Timezone is detected from this device when you save.',
                      'يتم اكتشاف المنطقة الزمنية من هذا الجهاز عند الحفظ.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: disclaimerAccepted,
                onChanged: (value) => onDisclaimerChanged(value ?? false),
                title: Text(
                  context.strings.text(
                    'I understand BIL provides general information, not medical advice.',
                  ),
                ),
                subtitle: errors['disclaimer'] == null
                    ? null
                    : _ErrorText(errors['disclaimer']!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: onContinue,
                  child: Text(context.strings.text('Continue')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionalMeasurementField extends StatelessWidget {
  const _OptionalMeasurementField({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value?.toStringAsFixed(1),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, suffixText: unit),
    onChanged: (raw) {
      final normalized = raw.trim().replaceAll(',', '.');
      if (normalized.isEmpty) {
        onChanged(null);
        return;
      }
      final parsed = double.tryParse(normalized);
      if (parsed != null && parsed > 0) onChanged(parsed);
    },
  );
}

class _UnitChoice extends StatelessWidget {
  const _UnitChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.blue : Theme.of(context).dividerColor,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? Colors.blue : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
