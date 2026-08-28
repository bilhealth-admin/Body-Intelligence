part of '../bil_flagship_onboarding.dart';

extension _BodySetupCanvasActions on _BodySetupCanvas {
  Future<void> _editBirthDate(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _BirthDateEditor(initialDate: draft.birthDate, isArabic: isArabic),
    );
    if (picked == null) return;
    draft.birthDate = picked;
    onChanged();
  }

  Future<void> _editMeasurement(
    BuildContext context, {
    required _CanvasField type,
  }) async {
    final config = switch (type) {
      _CanvasField.weight => _EditorConfig(
        title: tr(context, 'Weight', 'الوزن'),
        value: draft.weight,
        min: draft.units == BilUnits.metric ? 30 : 66,
        max: draft.units == BilUnits.metric ? 300 : 660,
        unit: draft.units == BilUnits.metric ? 'kg' : 'lb',
        decimals: 1,
      ),
      _CanvasField.height => _EditorConfig(
        title: tr(context, 'Height', 'الطول'),
        value: draft.height,
        min: draft.units == BilUnits.metric ? 120 : 48,
        max: draft.units == BilUnits.metric ? 230 : 90,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
      ),
      _CanvasField.waist => _EditorConfig(
        title: tr(context, 'Waist', 'الخصر'),
        value: draft.waist,
        min: draft.units == BilUnits.metric ? 45 : 18,
        max: draft.units == BilUnits.metric ? 200 : 79,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
        optional: true,
      ),
      _CanvasField.neck => _EditorConfig(
        title: tr(context, 'Neck', 'الرقبة'),
        value: draft.neck,
        min: draft.units == BilUnits.metric ? 20 : 8,
        max: draft.units == BilUnits.metric ? 80 : 32,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
        optional: true,
      ),
      _CanvasField.hips => _EditorConfig(
        title: tr(context, 'Hips', 'الورك'),
        value: draft.hips,
        min: draft.units == BilUnits.metric ? 45 : 18,
        max: draft.units == BilUnits.metric ? 220 : 87,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
        optional: true,
      ),
    };

    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CanvasNumberEditor(config: config, isArabic: isArabic),
    );
    if (result == null) return;

    final value = result.clear ? null : result.value;
    switch (type) {
      case _CanvasField.weight:
        draft.weight = value;
      case _CanvasField.height:
        draft.height = value;
      case _CanvasField.waist:
        draft.waist = value;
      case _CanvasField.neck:
        draft.neck = value;
      case _CanvasField.hips:
        draft.hips = value;
    }
    onChanged();
  }

  Future<void> _editSex(BuildContext context) async {
    final value = await _showChoiceSheet<BilSex>(
      context,
      title: tr(context, 'Sex', 'الجنس'),
      current: draft.sex,
      choices: [
        _SheetChoice(
          BilSex.male,
          tr(context, 'Male', 'ذكر'),
          Icons.male_rounded,
        ),
        _SheetChoice(
          BilSex.female,
          tr(context, 'Female', 'أنثى'),
          Icons.female_rounded,
        ),
      ],
    );
    if (value == null) return;
    draft.sex = value;
    draft.sexConfirmed = true;
    onChanged();
  }

  Future<void> _editGoal(BuildContext context) async {
    final value = await _showChoiceSheet<BilGoal>(
      context,
      title: tr(context, 'Goal', 'الهدف'),
      current: draft.goal,
      choices: [
        _SheetChoice(
          BilGoal.loseFat,
          tr(context, 'Lose fat', 'خسارة دهون'),
          Icons.trending_down_rounded,
        ),
        _SheetChoice(
          BilGoal.maintain,
          tr(context, 'Maintain', 'تثبيت الوزن'),
          Icons.balance_rounded,
        ),
        _SheetChoice(
          BilGoal.buildMuscle,
          tr(context, 'Build muscle', 'بناء عضلات'),
          Icons.fitness_center_rounded,
        ),
      ],
    );
    if (value == null) return;
    draft.goal = value;
    draft.goalConfirmed = true;
    onChanged();
  }

  Future<void> _editActivity(BuildContext context) async {
    final value = await _showChoiceSheet<BilActivity>(
      context,
      title: tr(context, 'Activity', 'النشاط'),
      current: draft.activity,
      choices: [
        _SheetChoice(
          BilActivity.low,
          tr(context, 'Low', 'منخفض'),
          Icons.weekend_outlined,
        ),
        _SheetChoice(
          BilActivity.light,
          tr(context, 'Light', 'خفيف'),
          Icons.directions_walk_rounded,
        ),
        _SheetChoice(
          BilActivity.moderate,
          tr(context, 'Moderate', 'متوسط'),
          Icons.fitness_center_rounded,
        ),
        _SheetChoice(
          BilActivity.high,
          tr(context, 'High', 'مرتفع'),
          Icons.directions_run_rounded,
        ),
        _SheetChoice(
          BilActivity.veryHigh,
          tr(context, 'Very high', 'مرتفع جدًا'),
          Icons.bolt_rounded,
        ),
      ],
    );
    if (value == null) return;
    draft.activity = value;
    draft.activityConfirmed = true;
    onChanged();
  }

  Future<T?> _showChoiceSheet<T>(
    BuildContext context, {
    required String title,
    required T current,
    required List<_SheetChoice<T>> choices,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CanvasChoiceSheet<T>(
        title: title,
        current: current,
        choices: choices,
      ),
    );
  }
}
