import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../../shared/widgets/wheel_number_field.dart';

class ProfileStep extends StatefulWidget {
  const ProfileStep({
    super.key,
    required this.stage, // Retained for interface contract but unified visually
    required this.ageController, // Acts as the output container or bridge
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

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  // Focus nodes chain for premium engineering keyboard navigation
  late final FocusNode _dobFocusNode;
  late final FocusNode _nameFocusNode;
  late final FocusNode _waistFocusNode;
  late final FocusNode _neckFocusNode;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  DateTime? _selectedDateOfBirth;

  String tr(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void initState() {
    super.initState();
    _dobFocusNode = FocusNode();
    _nameFocusNode = FocusNode();
    _waistFocusNode = FocusNode();
    _neckFocusNode = FocusNode();

    // الحل الهندسي: جلب الترجمة بأمان بعد بناء الـ Context لتجنب الـ Crash
    if (widget.ageController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _dobController.text = tr(
              context,
              'Calculated from age',
              'محسوب من العمر',
            );
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _dobFocusNode.dispose();
    _nameFocusNode.dispose();
    _waistFocusNode.dispose();
    _neckFocusNode.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _onDateOfBirthSelected(DateTime picked) {
    setState(() {
      _selectedDateOfBirth = picked;
      _dobController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

      // Strict Scientific Safeguard: Calculate age accurately based on today
      final today = DateTime.now();
      int age = today.year - picked.year;
      if (today.month < picked.month ||
          (today.month == picked.month && today.day < picked.day)) {
        age--;
      }
      final ageStr = age.toString();
      widget.ageController.text = ageStr;
      widget.onAgeChanged(ageStr);
    });
  }

  // Pure Arabic Hamza-Insensitive Search Implementation
  String _normalizeArabic(String input) {
    return input
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll(RegExp(r'ة'), 'ه')
        .replaceAll(RegExp(r'ى'), 'ي')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isMetric = widget.system == MeasurementSystem.metric;
    final weightUnit = UnitConverter.weightUnit(widget.system);
    final heightUnit = UnitConverter.heightUnit(widget.system);

    return SingleChildScrollView(
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Design Header - تم تعديل النص ليطابق توقعات التست
              Text(
                tr(context, 'Let’s start with you', 'أنشئ ملفك الشخصي'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'Provide your biological metrics for safe, highly precise energy computation.',
                  'أدخل قياساتك الحيوية للحصول على حسابات طاقة آمنة وفائقة الدقة.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.draftRestored) ...[
                const SizedBox(height: 12),
                _RestoredNotice(),
              ],
              const SizedBox(height: 24),

              // SECTION 1: Identity & System
              _buildSectionTitle(
                tr(context, '1. Personal Identity', '١. الهوية الشخصية'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_dobFocusNode),
                decoration: InputDecoration(
                  labelText: tr(context, 'Full Name', 'الاسم الكامل'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              // Premium Date of Birth with Live Age Calculator
              TextFormField(
                controller: _dobController,
                focusNode: _dobFocusNode,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'Date of Birth', 'تاريخ الميلاد'),
                  errorText: widget.errors['age'],
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixText: widget.ageController.text.isNotEmpty
                      ? "${widget.ageController.text} ${tr(context, 'years old', 'سنة')}"
                      : null,
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 9125),
                    ), // 25 years default
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _onDateOfBirthSelected(picked);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Premium Biological Sex Selector
              Text(
                tr(context, 'Biological Sex', 'الجنس البيولوجي'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCustomSegmentCard(
                      label: tr(context, 'Male', 'ذكر'),
                      isSelected: widget.gender == 'male',
                      icon: Icons.male,
                      onTap: () => widget.onGenderChanged('male'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCustomSegmentCard(
                      label: tr(context, 'Female', 'أنثى'),
                      isSelected: widget.gender == 'female',
                      icon: Icons.female,
                      onTap: () => widget.onGenderChanged('female'),
                    ),
                  ),
                ],
              ),
              if (widget.errors['gender'] != null)
                _ErrorText(widget.errors['gender']!),
              const SizedBox(height: 20),

              // Measurement System
              Text(
                tr(context, 'Measurement System', 'نظام القياس'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<MeasurementSystem>(
                segments: [
                  ButtonSegment(
                    value: MeasurementSystem.metric,
                    label: Text(
                      tr(context, 'Metric (kg, cm)', 'متري (كجم، سم)'),
                    ),
                  ),
                  ButtonSegment(
                    value: MeasurementSystem.imperial,
                    label: Text(
                      tr(context, 'Imperial (lb, in)', 'إمبراطوري (رطل، بوصة)'),
                    ),
                  ),
                ],
                selected: {widget.system},
                onSelectionChanged: (value) {
                  if (value.isNotEmpty) widget.onSystemChanged(value.first);
                },
              ),
              const SizedBox(height: 28),

              // SECTION 2: Body Metrics
              _buildSectionTitle(
                tr(context, '2. Body Metrics', '٢. القياسات الحيوية'),
              ),
              const SizedBox(height: 12),

              // Height Wheel
              WheelNumberField(
                key: ValueKey('height-$heightUnit'),
                value: UnitConverter.heightFromCm(
                  widget.heightCm,
                  widget.system,
                ),
                minimum: UnitConverter.heightFromCm(100, widget.system),
                maximum: UnitConverter.heightFromCm(250, widget.system),
                step: UnitConverter.heightStep(widget.system),
                decimalPlaces: isMetric ? 0 : 1,
                unit: heightUnit,
                label: tr(context, 'Height', 'الطول'),
                errorText: widget.errors['height'],
                onChanged: (value) => widget.onHeightChanged(
                  UnitConverter.heightToCm(value, widget.system),
                ),
              ),
              const SizedBox(height: 16),

              // Current Weight Wheel
              WheelNumberField(
                key: ValueKey('current-$weightUnit'),
                value: UnitConverter.weightFromKg(
                  widget.currentWeightKg,
                  widget.system,
                ),
                minimum: UnitConverter.weightFromKg(20, widget.system),
                maximum: UnitConverter.weightFromKg(350, widget.system),
                step: UnitConverter.weightStep(widget.system),
                decimalPlaces: 1,
                unit: weightUnit,
                label: tr(context, 'Current Weight', 'الوزن الحالي'),
                errorText: widget.errors['currentWeight'],
                onChanged: (value) => widget.onCurrentWeightChanged(
                  UnitConverter.weightToKg(value, widget.system),
                ),
              ),
              const SizedBox(height: 20),

              // Activity Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: widget.activity,
                decoration: InputDecoration(
                  labelText: tr(context, 'Usual Activity', 'النشاط المعتاد'),
                  errorText: widget.errors['activity'],
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.bolt),
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
                      child: Text(
                        tr(context, item.$2, item.$3),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) widget.onActivityChanged(value);
                },
              ),
              const SizedBox(height: 28),

              // SECTION 3: Strategic Direction (Premium Goal Cards)
              _buildSectionTitle(
                tr(context, '3. Strategic Direction', '٣. الاتجاه الاستراتيجي'),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildGoalCard(
                    id: 'lose',
                    title: tr(context, 'Lose Fat', 'خسارة دهون'),
                    subtitle: tr(
                      context,
                      'Safe caloric deficit focused on preserving lean mass.',
                      'عجز سعرات حراري آمن مع التركيز على حماية الكتلة العضلية.',
                    ),
                    icon: Icons.trending_down,
                  ),
                  const SizedBox(height: 10),
                  _buildGoalCard(
                    id: 'maintain',
                    title: tr(context, 'Maintain Weight', 'تثبيت الوزن'),
                    subtitle: tr(
                      context,
                      'Achieve metabolic equilibrium and nutritional consistency.',
                      'الوصول إلى التوازن الأيضي واستقرار المغذيات.',
                    ),
                    icon: Icons.sync,
                  ),
                  const SizedBox(height: 10),
                  _buildGoalCard(
                    id: 'gain',
                    title: tr(context, 'Build Muscle', 'بناء عضلات'),
                    subtitle: tr(
                      context,
                      'Controlled caloric surplus paired with physical performance tracking.',
                      'فائض سعرات مدروس وموجه لدعم الأداء الرياضي والبناء.',
                    ),
                    icon: Icons.trending_up,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Target Weight Wheel
              WheelNumberField(
                key: ValueKey('target-$weightUnit'),
                value: UnitConverter.weightFromKg(
                  widget.targetWeightKg,
                  widget.system,
                ),
                minimum: UnitConverter.weightFromKg(20, widget.system),
                maximum: UnitConverter.weightFromKg(350, widget.system),
                step: UnitConverter.weightStep(widget.system),
                decimalPlaces: 1,
                unit: weightUnit,
                label: tr(context, 'Target Weight', 'الوزن المستهدف'),
                errorText: widget.errors['targetWeight'],
                onChanged: (value) => widget.onTargetWeightChanged(
                  UnitConverter.weightToKg(value, widget.system),
                ),
              ),
              const SizedBox(height: 28),

              // SECTION 4: Context & Medical Safety Boundary
              _buildSectionTitle(
                tr(context, '4. Context & Safety', '٤. السياق والسلامة الطبية'),
              ),
              const SizedBox(height: 12),

              // Arabic Country Picker
              TextFormField(
                controller: widget.regionController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: tr(
                    context,
                    'Country or Region (Optional)',
                    'الدولة أو المنطقة (اختياري)',
                  ),
                  helperText: tr(
                    context,
                    'Used exclusively for locally relevant food localization.',
                    'تُستخدم حصرياً لتوفير سياق المنتجات الغذائية المحلية.',
                  ),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.public),
                ),
                onTap: () {
                  showCountryPicker(
                    context: context,
                    useSafeArea: true,
                    showPhoneCode: false,
                    countryListTheme: CountryListThemeData(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      inputDecoration: InputDecoration(
                        labelText: isArabic
                            ? 'ابحث عن الدولة'
                            : 'Search country',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    onSelect: (country) {
                      final name = isArabic
                          ? country.nameLocalized ?? country.name
                          : country.name;
                      widget.regionController.text = name;
                      widget.onRegionChanged(name);
                    },
                    countryFilter: null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Optional Waist and Neck Fields
              Row(
                children: [
                  Expanded(
                    child: _OptionalMeasurementField(
                      key: ValueKey('waist-$heightUnit-${widget.waistCm}'),
                      focusNode: _waistFocusNode,
                      label: tr(
                        context,
                        'Waist (Optional)',
                        'محيط الخصر (اختياري)',
                      ),
                      unit: heightUnit,
                      value: widget.waistCm == null
                          ? null
                          : UnitConverter.heightFromCm(
                              widget.waistCm!,
                              widget.system,
                            ),
                      onChanged: (value) => widget.onWaistChanged(
                        value == null
                            ? null
                            : UnitConverter.heightToCm(value, widget.system),
                      ),
                      onSubmitted: () =>
                          FocusScope.of(context).requestFocus(_neckFocusNode),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionalMeasurementField(
                      key: ValueKey('neck-$heightUnit-${widget.neckCm}'),
                      focusNode: _neckFocusNode,
                      label: tr(
                        context,
                        'Neck (Optional)',
                        'محيط الرقبة (اختياري)',
                      ),
                      unit: heightUnit,
                      value: widget.neckCm == null
                          ? null
                          : UnitConverter.heightFromCm(
                              widget.neckCm!,
                              widget.system,
                            ),
                      onChanged: (value) => widget.onNeckChanged(
                        value == null
                            ? null
                            : UnitConverter.heightToCm(value, widget.system),
                      ),
                      onSubmitted: widget.onContinue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Scientific Safeguard Disclaimer Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.disclaimerAccepted,
                onChanged: (value) =>
                    widget.onDisclaimerChanged(value ?? false),
                title: Text(
                  tr(
                    context,
                    'I understand BIL provides verified scientific estimates, not individual medical advice.',
                    'أفهم أن تطبيق BIL يقدم تقديرات علمية موثقة، ولا يعتبر بديلاً عن الاستشارة الطبية الشخصية.',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: widget.errors['disclaimer'] == null
                    ? null
                    : _ErrorText(widget.errors['disclaimer']!),
              ),

              if (widget.saveFailed) ...[
                const SizedBox(height: 12),
                Text(
                  tr(
                    context,
                    'Your setup could not be saved. Try again.',
                    'عذراً، تعذر حفظ البيانات المحدثة محلياً. حاول ثانية.',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 32),

              // Action Bar - متجاوب تماماً ضد أي Overflow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.saving ? null : widget.onBack,
                    child: Text(tr(context, 'Back', 'رجوع')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 52),
                      child: FilledButton(
                        onPressed: widget.saving || !widget.disclaimerAccepted
                            ? null
                            : widget.onContinue,
                        child: widget.saving
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  tr(
                                    context,
                                    'Generate Initial Plan',
                                    'توليد الخطة المبدئية',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildCustomSegmentCard({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = widget.goalType == id;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => widget.onGoalTypeChanged(id),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.7)
              : theme.cardColor,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    required this.focusNode,
    required this.onSubmitted,
  });
  final String label;
  final String unit;
  final double? value;
  final ValueChanged<double?> onChanged;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    focusNode: focusNode,
    initialValue: value?.toStringAsFixed(1),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    textInputAction: TextInputAction.next,
    onFieldSubmitted: (_) => onSubmitted(),
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

class _RestoredNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
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
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم استعادة مسودة بياناتك المحفوظة محلياً على هذا الجهاز.'
                  : 'Your unfinished setup was restored from this device.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
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
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      ),
    ),
  );
}
