part of '../bil_flagship_onboarding.dart';

class _CompactBodyCanvas extends StatelessWidget {
  const _CompactBodyCanvas({
    required this.draft,
    required this.isArabic,
    required this.age,
    required this.onWeight,
    required this.onHeight,
    required this.onWaist,
    required this.onNeck,
    required this.onBirthDate,
    required this.onSex,
    required this.onGoal,
    required this.onActivity,
  });

  final BilOnboardingDraft draft;
  final bool isArabic;
  final int? age;
  final VoidCallback onWeight;
  final VoidCallback onHeight;
  final VoidCallback onWaist;
  final VoidCallback onNeck;
  final VoidCallback onBirthDate;
  final VoidCallback onSex;
  final VoidCallback onGoal;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => _bodyCanvasText(context, en, ar);
    String measurement(double? value, String unit) => value == null
        ? ''
        : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} $unit';
    final fields = [
      (
        tr('Weight', 'الوزن'),
        Icons.monitor_weight_outlined,
        draft.weight != null,
        measurement(draft.weight, draft.units == BilUnits.metric ? 'kg' : 'lb'),
        false,
        onWeight,
      ),
      (
        tr('Height', 'الطول'),
        Icons.height_rounded,
        draft.height != null,
        measurement(draft.height, draft.units == BilUnits.metric ? 'cm' : 'in'),
        false,
        onHeight,
      ),
      (
        tr('Age', 'العمر'),
        Icons.cake_outlined,
        age != null,
        age?.toString() ?? '',
        false,
        onBirthDate,
      ),
      (
        tr('Biological sex', 'الجنس'),
        !draft.sexConfirmed
            ? Icons.wc_outlined
            : draft.sex == BilSex.male
            ? Icons.male_rounded
            : Icons.female_rounded,
        draft.sexConfirmed,
        draft.sexConfirmed
            ? (draft.sex == BilSex.male
                  ? tr('Male', 'ذكر')
                  : tr('Female', 'أنثى'))
            : '',
        false,
        onSex,
      ),
      (
        tr('Goal', 'الهدف'),
        Icons.track_changes_rounded,
        draft.goalConfirmed,
        draft.goalConfirmed
            ? switch (draft.goal) {
                BilGoal.loseFat => tr('Lose fat', 'خسارة الدهون'),
                BilGoal.maintain => tr('Maintain', 'الحفاظ على الوزن'),
                BilGoal.buildMuscle => tr('Build muscle', 'بناء العضلات'),
              }
            : '',
        false,
        onGoal,
      ),
      (
        tr('Waist', 'الخصر'),
        Icons.straighten_rounded,
        draft.waist != null,
        measurement(draft.waist, draft.units == BilUnits.metric ? 'cm' : 'in'),
        true,
        onWaist,
      ),
      (
        tr('Neck', 'الرقبة'),
        Icons.accessibility_new_rounded,
        draft.neck != null,
        measurement(draft.neck, draft.units == BilUnits.metric ? 'cm' : 'in'),
        true,
        onNeck,
      ),
      (
        tr('Activity', 'النشاط'),
        Icons.directions_run_rounded,
        draft.activityConfirmed,
        draft.activityConfirmed
            ? switch (draft.activity) {
                BilActivity.low => tr('Low', 'منخفض'),
                BilActivity.light => tr('Light', 'خفيف'),
                BilActivity.moderate => tr('Moderate', 'متوسط'),
                BilActivity.high => tr('High', 'مرتفع'),
                BilActivity.veryHigh => tr('Very high', 'مرتفع جدًا'),
              }
            : '',
        false,
        onActivity,
      ),
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _BilColors.stroke),
          ),
          child: Row(
            children: [
              const _IconOrb(icon: Icons.person_outline_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  tr(
                    'Add the essentials now. Optional measurements can wait.',
                    'أضف البيانات الأساسية الآن، ويمكن تأجيل القياسات الاختيارية.',
                  ),
                  style: const TextStyle(
                    color: _BilColors.textMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 620
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: cardWidth,
                    child: _PrivateFieldCard(
                      title: field.$1,
                      icon: field.$2,
                      completed: field.$3,
                      value: field.$4,
                      optional: field.$5,
                      onTap: field.$6,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
