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
    required this.onHips,
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
  final VoidCallback onHips;
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
        tr('Sex', 'الجنس'),
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
      if (draft.sexConfirmed && draft.sex == BilSex.female)
        (
          tr('Hips', 'الورك'),
          Icons.accessibility_rounded,
          draft.hips != null,
          measurement(draft.hips, draft.units == BilUnits.metric ? 'cm' : 'in'),
          true,
          onHips,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF071B32), Color(0xFF087C91)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33066B83),
                blurRadius: 34,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF77E6E2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Your private body model', 'نموذج جسمك الخاص'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr(
                        'Add the essentials now. Optional measurements can wait.',
                        'أضف البيانات الأساسية الآن، ويمكن تأجيل القياسات الاختيارية.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFC7DDE7),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _GlassPanel(
          padding: EdgeInsets.zero,
          radius: 28,
          glow: true,
          child: Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                _CompactSetupRow(
                  title: fields[index].$1,
                  icon: fields[index].$2,
                  completed: fields[index].$3,
                  value: fields[index].$4,
                  optional: fields[index].$5,
                  onTap: fields[index].$6,
                ),
                if (index != fields.length - 1)
                  const Divider(height: 1, indent: 72, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactSetupRow extends StatelessWidget {
  const _CompactSetupRow({
    required this.title,
    required this.icon,
    required this.completed,
    required this.value,
    required this.optional,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool completed;
  final String value;
  final bool optional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = completed
        ? value
        : optional
        ? _bodyCanvasText(context, 'Optional', 'اختياري')
        : _bodyCanvasText(context, 'Required', 'مطلوب');
    return Semantics(
      button: true,
      label: title,
      value: status,
      selected: completed,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 13, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFFE2F8F1)
                      : const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: completed
                      ? const Color(0xFF07835D)
                      : const Color(0xFF1267C4),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: completed
                            ? const Color(0xFF4E6174)
                            : _BilColors.textDim,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: completed
                    ? const Color(0xFF0AA377)
                    : const Color(0xFF9AA7B5),
                size: completed ? 23 : 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
