import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../../shared/widgets/wheel_number_field.dart';

class ProfileStep extends StatelessWidget {
  const ProfileStep({
    super.key,
    required this.stage,
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
    required this.draftRestored,
    required this.saving,
    required this.saveFailed,
    required this.errors,
    required this.onAgeChanged,
    required this.onRegionChanged,
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
    required this.onBack,
    required this.onContinue,
    required this.scrollController,
  });

  static const totalStages = 4;
  final int stage;
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
  final bool draftRestored;
  final bool saving;
  final bool saveFailed;
  final Map<String, String> errors;
  final ValueChanged<String> onAgeChanged;
  final ValueChanged<String> onRegionChanged;
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
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final ScrollController scrollController;

  String tr(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.strings.text('Let’s start with you'),
      context.strings.text('Your starting point'),
      context.strings.text('Where do you want to go?'),
      context.strings.text('Your choice and safety'),
    ];
    final reasons = [
      context.strings.text(
        'Age and biological sex are used only in established energy equations. Choose the units that feel natural to you.',
      ),
      context.strings.text(
        'Height, current weight, and usual activity establish your starting energy estimate.',
      ),
      context.strings.text(
        'Your direction shapes targets. BIL keeps the estimate cautious and you can change it later.',
      ),
      context.strings.text(
        'Extra context is optional and stays on this device. Review the safety boundary before finishing.',
      ),
    ];
    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: context.strings.text('Setup progress'),
                value: context.strings.text(
                  'Step ${stage + 1} of $totalStages',
                ),
                child: ExcludeSemantics(
                  child: Row(
                    children: List.generate(
                      totalStages,
                      (index) => Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: index == totalStages - 1 ? 0 : 6,
                          ),
                          child: LinearProgressIndicator(
                            value: index <= stage ? 1 : 0,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  titles[stage],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(reasons[stage]),
              if (draftRestored && stage == 0) ...[
                const SizedBox(height: 12),
                _RestoredNotice(),
              ],
              const SizedBox(height: 24),
              if (stage == 0) _aboutYou(context),
              if (stage == 1) _startingPoint(context),
              if (stage == 2) _direction(context),
              if (stage == 3) _contextAndSafety(context),
              if (saveFailed) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    context.strings.text(
                      'Your setup could not be saved. Your draft remains on this device; try again.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (stage > 0)
                    TextButton.icon(
                      onPressed: saving ? null : onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.strings.text('Back')),
                    ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: saving ? null : onContinue,
                      child: saving
                          ? Semantics(
                              label: context.strings.text(
                                'Saving your setup locally',
                              ),
                              child: const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Text(
                              context.strings.text(
                                stage == totalStages - 1
                                    ? 'Finish setup'
                                    : 'Continue',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutYou(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: ageController,
        onChanged: onAgeChanged,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.strings.text('Age'),
          errorText: errors['age'],
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 20),
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
          ButtonSegment(value: 'male', label: Text(tr(context, 'Male', 'ذكر'))),
          ButtonSegment(
            value: 'female',
            label: Text(tr(context, 'Female', 'أنثى')),
          ),
        ],
        emptySelectionAllowed: true,
        selected: gender == null ? {} : {gender!},
        onSelectionChanged: (value) => onGenderChanged(value.single),
      ),
      if (errors['gender'] != null) _ErrorText(errors['gender']!),
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
            label: Text(tr(context, 'Metric — kg, cm', 'متري — كجم، سم')),
          ),
          ButtonSegment(
            value: MeasurementSystem.imperial,
            label: Text(
              tr(context, 'Imperial — lb, in', 'إمبراطوري — رطل، بوصة'),
            ),
          ),
        ],
        selected: {system},
        onSelectionChanged: (value) => onSystemChanged(value.single),
      ),
    ],
  );

  Widget _startingPoint(BuildContext context) {
    final isMetric = system == MeasurementSystem.metric;
    final weightUnit = UnitConverter.weightUnit(system);
    final heightUnit = UnitConverter.heightUnit(system);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WheelNumberField(
          key: ValueKey('height-$heightUnit'),
          value: UnitConverter.heightFromCm(heightCm, system),
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
          value: UnitConverter.weightFromKg(currentWeightKg, system),
          minimum: UnitConverter.weightFromKg(20, system),
          maximum: UnitConverter.weightFromKg(350, system),
          step: UnitConverter.weightStep(system),
          decimalPlaces: 1,
          unit: weightUnit,
          label: tr(context, 'Current weight', 'الوزن الحالي'),
          errorText: errors['currentWeight'],
          onChanged: (value) =>
              onCurrentWeightChanged(UnitConverter.weightToKg(value, system)),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: activity,
          decoration: InputDecoration(
            labelText: context.strings.text('Usual activity'),
            errorText: errors['activity'],
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final item in const [
              (
                'sedentary',
                'Sedentary — mostly seated',
                'خامل — جلوس معظم اليوم',
              ),
              (
                'light',
                'Lightly active — 1–3 days/week',
                'نشاط خفيف — ١–٣ أيام أسبوعيًا',
              ),
              (
                'moderate',
                'Moderately active — 3–5 days/week',
                'نشاط متوسط — ٣–٥ أيام أسبوعيًا',
              ),
              (
                'active',
                'Very active — 6–7 days/week',
                'نشاط مرتفع — ٦–٧ أيام أسبوعيًا',
              ),
              (
                'very_active',
                'Extra active — demanding training/work',
                'نشاط فائق — تدريب أو عمل شاق',
              ),
            ])
              DropdownMenuItem(
                value: item.$1,
                child: Text(tr(context, item.$2, item.$3)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onActivityChanged(value);
          },
        ),
      ],
    );
  }

  Widget _direction(BuildContext context) {
    final weightUnit = UnitConverter.weightUnit(system);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
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
        const SizedBox(height: 20),
        WheelNumberField(
          key: ValueKey('target-$weightUnit'),
          value: UnitConverter.weightFromKg(targetWeightKg, system),
          minimum: UnitConverter.weightFromKg(20, system),
          maximum: UnitConverter.weightFromKg(350, system),
          step: UnitConverter.weightStep(system),
          decimalPlaces: 1,
          unit: weightUnit,
          label: tr(context, 'Goal weight', 'الوزن المستهدف'),
          errorText: errors['targetWeight'],
          onChanged: (value) =>
              onTargetWeightChanged(UnitConverter.weightToKg(value, system)),
        ),
      ],
    );
  }

  Widget _contextAndSafety(BuildContext context) {
    final heightUnit = UnitConverter.heightUnit(system);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: regionController,
          onChanged: onRegionChanged,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.countryName],
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Country or region (optional)',
              'الدولة أو المنطقة (اختياري)',
            ),
            helperText: tr(
              context,
              'Used only for locally relevant food context.',
              'تُستخدم فقط لسياق الطعام المحلي المناسب.',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              _OptionalMeasurementField(
                key: ValueKey('waist-$heightUnit-$waistCm'),
                label: tr(context, 'Waist (optional)', 'محيط الخصر (اختياري)'),
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
              _OptionalMeasurementField(
                key: ValueKey('neck-$heightUnit-$neckCm'),
                label: tr(context, 'Neck (optional)', 'محيط الرقبة (اختياري)'),
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
            ];
            if (constraints.maxWidth < 520) {
              return Column(
                children: [fields[0], const SizedBox(height: 12), fields[1]],
              );
            }
            return Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
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
      ],
    );
  }
}

class _RestoredNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.restore),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.strings.text(
                  'Your unfinished setup was restored from this device.',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
    decoration: InputDecoration(
      labelText: label,
      suffixText: unit,
      border: const OutlineInputBorder(),
    ),
    onChanged: (raw) {
      final normalized = raw.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return onChanged(null);
      final parsed = double.tryParse(normalized);
      if (parsed != null && parsed > 0) onChanged(parsed);
    },
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
