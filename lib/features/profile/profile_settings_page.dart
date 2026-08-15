import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../core/units/measurement_units.dart';
import 'profile_locale_copy.dart';
import 'providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() =>
      _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  String t(String english, String arabic) =>
      profileLocaleText(context, english, arabic);
  final formKey = GlobalKey<FormState>();
  final displayName = TextEditingController();
  final age = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final target = TextEditingController();
  final neck = TextEditingController();
  final waist = TextEditingController();
  final hips = TextEditingController();
  final chest = TextEditingController();
  final arm = TextEditingController();
  final thigh = TextEditingController();

  String gender = 'male';
  String activity = 'moderate';
  bool exercises = true;
  int weeklyExerciseSessions = 3;
  String exerciseType = 'mixed';
  String dietApproach = 'balanced';
  bool experiencePreferencesLoaded = false;
  bool initialized = false;
  bool saving = false;
  bool dirty = false;
  MeasurementSystem measurementSystem = MeasurementSystem.metric;

  @override
  void dispose() {
    age.dispose();
    displayName.dispose();
    height.dispose();
    weight.dispose();
    target.dispose();
    neck.dispose();
    waist.dispose();
    hips.dispose();
    chest.dispose();
    arm.dispose();
    thigh.dispose();
    super.dispose();
  }

  void hydrate(UserProfileData profile, MeasurementSystem system) {
    if (initialized) return;
    initialized = true;
    measurementSystem = system;
    gender = profile.gender;
    activity = profile.activityLevel;
    exercises = profile.exercises;
    age.text = profile.age.toString();
    height.text = profile.height.toStringAsFixed(1);
    weight.text = profile.currentWeight.toStringAsFixed(1);
    target.text = profile.targetWeight.toStringAsFixed(1);
    neck.text = _optionalText(profile.neck);
    waist.text = _optionalText(profile.waist);
    chest.text = _optionalText(profile.chest);
    arm.text = _optionalText(profile.arm);
    thigh.text = _optionalText(profile.thigh);
    unawaited(_loadLatestMeasurements());
    unawaited(_loadExperiencePreferences());
  }

  String _optionalText(double? centimeters) {
    if (centimeters == null) return '';
    final value = UnitConverter.heightFromCm(centimeters, measurementSystem);
    return value.toStringAsFixed(1);
  }

  double? _optionalNumberCm(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.parse(raw);
    return UnitConverter.heightToCm(value, measurementSystem);
  }

  Future<void> _loadLatestMeasurements() async {
    final latest = await ref
        .read(bodyMeasurementRepositoryProvider)
        .getLatest();
    if (!mounted || latest == null) return;
    setState(() {
      neck.text = _optionalText(latest.neckCm);
      waist.text = _optionalText(latest.waistCm);
      hips.text = _optionalText(latest.hipsCm);
      chest.text = _optionalText(latest.chestCm);
      arm.text = _optionalText(latest.armCm);
      thigh.text = _optionalText(latest.thighCm);
    });
  }

  Future<void> _loadExperiencePreferences() async {
    if (experiencePreferencesLoaded) return;
    experiencePreferencesLoaded = true;
    final repository = ref.read(preferencesRepositoryProvider);
    final values = await Future.wait([
      repository.get('weeklyExerciseSessions'),
      repository.get('exerciseType'),
      repository.get('dietApproach'),
      repository.get('displayName'),
    ]);
    if (!mounted) return;
    setState(() {
      weeklyExerciseSessions = int.tryParse(values[0] ?? '') ?? 3;
      exerciseType = values[1] ?? 'mixed';
      dietApproach = values[2] ?? 'balanced';
      displayName.text = values[3]?.trim() ?? '';
    });
  }

  String? validate(String? value, double min, double max) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed < min || parsed > max
        ? '$min – $max'
        : null;
  }

  String? validateOptional(String? value, double min, double max) {
    if ((value ?? '').trim().isEmpty) return null;
    return validate(value, min, max);
  }

  Widget _measurementField(
    TextEditingController controller,
    String english,
    String arabic,
  ) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText:
          '${t(english, arabic)} (${measurementSystem == MeasurementSystem.imperial ? 'in' : 'cm'})',
      prefixIcon: const Icon(Icons.straighten_rounded),
    ),
    validator: (value) => measurementSystem == MeasurementSystem.imperial
        ? validateOptional(value, 8, 120)
        : validateOptional(value, 20, 300),
  );

  Future<void> leave() async {
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t('Discard changes?', 'تجاهل التغييرات؟')),
          content: Text(
            t('You have unsaved changes.', 'لديك تغييرات لم تُحفظ.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('Keep editing', 'متابعة التعديل')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t('Discard', 'تجاهل')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  Future<void> save(UserProfileData profile) async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final currentWeight = double.parse(weight.text.replaceAll(',', '.'));
      final targetWeight = double.parse(target.text.replaceAll(',', '.'));
      final neckCm = _optionalNumberCm(neck);
      final waistCm = _optionalNumberCm(waist);
      final hipsCm = _optionalNumberCm(hips);
      final chestCm = _optionalNumberCm(chest);
      final armCm = _optionalNumberCm(arm);
      final thighCm = _optionalNumberCm(thigh);
      await ref
          .read(userProfileRepositoryProvider)
          .save(
            gender: gender,
            age: int.parse(age.text),
            height: double.parse(height.text.replaceAll(',', '.')),
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            activityLevel: activity,
            exercises: exercises,
            medicalConditions: profile.medicalConditions,
            waist: waistCm,
            neck: neckCm,
            chest: chestCm,
            arm: armCm,
            thigh: thighCm,
          );
      await ref
          .read(bodyMeasurementRepositoryProvider)
          .saveForDay(
            date: DateTime.now(),
            neckCm: neckCm,
            waistCm: waistCm,
            hipsCm: hipsCm,
            chestCm: chestCm,
            armCm: armCm,
            thighCm: thighCm,
          );
      ref.invalidate(bodyMeasurementHistoryProvider);
      final activeGoal = ref.read(activeGoalProvider).value;
      await ref
          .read(goalRepositoryProvider)
          .save(
            uuid: activeGoal?.uuid,
            profileUuid: profile.uuid,
            type: targetWeight < currentWeight
                ? 'lose'
                : targetWeight > currentWeight
                ? 'gain'
                : 'maintain',
            targetWeight: targetWeight,
            targetDate: activeGoal?.targetDate,
          );
      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.set(
        'weeklyExerciseSessions',
        exercises ? weeklyExerciseSessions.toString() : '0',
      );
      await preferences.set('exerciseType', exerciseType);
      await preferences.set('dietApproach', dietApproach);
      await preferences.set('displayName', displayName.text.trim());
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      if (!mounted) return;
      setState(() => dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Your profile and plan were saved.', 'تم حفظ ملفك وخطتك.'),
          ),
        ),
      );
      context.go('/settings');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('My profile & plan', 'ملفي وخطتي')),
          leading: IconButton(
            key: const Key('profile-settings-back'),
            tooltip: t('Back to settings', 'العودة إلى الإعدادات'),
            onPressed: leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(userProfileProvider),
              child: Text(t('Try again', 'إعادة المحاولة')),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Text(t('No local profile.', 'لا يوجد ملف محلي.')),
              );
            }
            final systemAsync = ref.watch(measurementSystemProvider);
            if (!systemAsync.hasValue) {
              return const Center(child: CircularProgressIndicator());
            }
            hydrate(profile, systemAsync.requireValue);
            final photo = ref.watch(profilePhotoProvider).value;
            return Form(
              key: formKey,
              onChanged: () {
                if (!dirty) setState(() => dirty = true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 42,
                      foregroundImage: photo == null
                          ? null
                          : MemoryImage(photo),
                      child: photo == null
                          ? const Icon(Icons.person_rounded, size: 42)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: displayName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: t('Display name', 'الاسم الظاهر'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) > 60
                        ? (t('Maximum 60 characters', 'الحد الأقصى 60 حرفًا'))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'Your profile photo can be changed from the account icon on Today.',
                      'يمكن تعديل الصورة الشخصية من رمز الحساب في الصفحة الرئيسية.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t('Body profile', 'بيانات الجسم'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: InputDecoration(labelText: t('Sex', 'الجنس')),
                    items: [
                      DropdownMenuItem(
                        value: 'male',
                        child: Text(t('Male', 'ذكر')),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text(t('Female', 'أنثى')),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      gender = value ?? gender;
                      dirty = true;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t('Age', 'العمر')),
                    validator: (value) => validate(value, 13, 120),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: t('Height (cm)', 'الطول (سم)'),
                    ),
                    validator: (value) => validate(value, 100, 250),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: t('Current weight (kg)', 'الوزن الحالي (كغ)'),
                    ),
                    validator: (value) => validate(value, 20, 500),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('Body measurements', 'قياسات الجسم'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t(
                      'Optional. Saving creates or updates today’s private measurement record.',
                      'اختياري. ينشئ الحفظ سجل قياسات خاصًا لليوم أو يحدّثه.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _measurementField(neck, 'Neck', 'الرقبة'),
                  const SizedBox(height: 12),
                  _measurementField(waist, 'Waist', 'الخصر'),
                  const SizedBox(height: 12),
                  _measurementField(hips, 'Hips', 'الورك'),
                  const SizedBox(height: 12),
                  _measurementField(chest, 'Chest', 'الصدر'),
                  const SizedBox(height: 12),
                  _measurementField(arm, 'Arm', 'الذراع'),
                  const SizedBox(height: 12),
                  _measurementField(thigh, 'Thigh', 'الفخذ'),
                  const SizedBox(height: 24),
                  Text(
                    t('Goal & activity', 'الهدف والنشاط'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: t('Target weight (kg)', 'الوزن المستهدف (كغ)'),
                    ),
                    validator: (value) => validate(value, 20, 500),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: activity,
                    decoration: InputDecoration(
                      labelText: t('Activity level', 'مستوى النشاط'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text(t('Low movement', 'حركة محدودة')),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text(t('Light activity', 'نشاط خفيف')),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text(t('Balanced activity', 'نشاط متوازن')),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(t('High activity', 'نشاط مرتفع')),
                      ),
                      DropdownMenuItem(
                        value: 'very_active',
                        child: Text(t('Intense activity', 'نشاط مكثف')),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      activity = value ?? activity;
                      dirty = true;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: exercises,
                    title: Text(t('I exercise', 'أمارس التمارين')),
                    subtitle: Text(
                      t(
                        'Frequency and type improve context without claiming exact calorie burn.',
                        'سنستخدم التكرار والنوع لتفسير نشاطك، لا لادعاء حرق دقيق.',
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      exercises = value;
                      dirty = true;
                    }),
                  ),
                  if (exercises) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey(weeklyExerciseSessions),
                      initialValue: weeklyExerciseSessions,
                      decoration: InputDecoration(
                        labelText: t(
                          'Exercise sessions per week',
                          'مرات التمرين أسبوعيًا',
                        ),
                      ),
                      items: [
                        for (var sessions = 1; sessions <= 7; sessions++)
                          DropdownMenuItem(
                            value: sessions,
                            child: Text(
                              profileWeeklySessionsText(context, sessions),
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        weeklyExerciseSessions =
                            value ?? weeklyExerciseSessions;
                        dirty = true;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: exerciseType,
                      decoration: InputDecoration(
                        labelText: t(
                          'Primary exercise type',
                          'نوع التمرين الأساسي',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'walking',
                          child: Text(t('Walking', 'المشي')),
                        ),
                        DropdownMenuItem(
                          value: 'strength',
                          child: Text(
                            t('Strength & gym', 'تمارين المقاومة والجيم'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'cardio',
                          child: Text(t('Cardio', 'كارديو')),
                        ),
                        DropdownMenuItem(
                          value: 'swimming',
                          child: Text(t('Swimming', 'السباحة')),
                        ),
                        DropdownMenuItem(
                          value: 'cycling',
                          child: Text(t('Cycling', 'ركوب الدراجة')),
                        ),
                        DropdownMenuItem(
                          value: 'mixed',
                          child: Text(t('Mixed training', 'برنامج مختلط')),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        exerciseType = value ?? exerciseType;
                        dirty = true;
                      }),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    t('Nutrition approach', 'أسلوب التغذية'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: dietApproach,
                    decoration: InputDecoration(
                      labelText: t('My plan style', 'اسم خطتي'),
                      helperText: t(
                        'This guides presentation and preferences, not core scientific facts.',
                        'هذا يغيّر طريقة العرض والتفضيلات، وليس الحقائق العلمية الأساسية.',
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'balanced',
                        child: Text(t('Smart Balance', 'توازن ذكي')),
                      ),
                      DropdownMenuItem(
                        value: 'high_protein',
                        child: Text(t('Protein Forward', 'بروتين أعلى')),
                      ),
                      DropdownMenuItem(
                        value: 'low_carb',
                        child: Text(t('Lower Carb', 'كربوهيدرات أقل')),
                      ),
                      DropdownMenuItem(
                        value: 'keto',
                        child: Text(t('Keto', 'كيتو')),
                      ),
                      DropdownMenuItem(
                        value: 'mediterranean',
                        child: Text(t('Mediterranean', 'متوسطي')),
                      ),
                      DropdownMenuItem(
                        value: 'plant_forward',
                        child: Text(t('Plant Forward', 'نباتي مرن')),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      dietApproach = value ?? dietApproach;
                      dirty = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('profile-settings-save'),
                    onPressed: saving ? null : () => save(profile),
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      t(
                        'Save and return to settings',
                        'حفظ والعودة إلى الإعدادات',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: leave,
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(t('Back to settings', 'العودة إلى الإعدادات')),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
