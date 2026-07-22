import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import 'providers/user_profile_provider.dart';

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() =>
      _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  final formKey = GlobalKey<FormState>();
  final age = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final target = TextEditingController();

  String gender = 'male';
  String activity = 'moderate';
  bool exercises = true;
  bool initialized = false;
  bool saving = false;
  bool dirty = false;

  @override
  void dispose() {
    age.dispose();
    height.dispose();
    weight.dispose();
    target.dispose();
    super.dispose();
  }

  void hydrate(UserProfileData profile) {
    if (initialized) return;
    initialized = true;
    gender = profile.gender;
    activity = profile.activityLevel;
    exercises = profile.exercises;
    age.text = profile.age.toString();
    height.text = profile.height.toStringAsFixed(1);
    weight.text = profile.currentWeight.toStringAsFixed(1);
    target.text = profile.targetWeight.toStringAsFixed(1);
  }

  String? validate(String? value, double min, double max) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed < min || parsed > max
        ? '$min – $max'
        : null;
  }

  Future<void> leave() async {
    if (dirty) {
      final ar = Localizations.localeOf(context).languageCode == 'ar';
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(ar ? 'تجاهل التغييرات؟' : 'Discard changes?'),
          content: Text(
            ar ? 'لديك تغييرات لم تُحفظ.' : 'You have unsaved changes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(ar ? 'متابعة التعديل' : 'Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(ar ? 'تجاهل' : 'Discard'),
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
            waist: profile.waist,
            neck: profile.neck,
            chest: profile.chest,
            arm: profile.arm,
            thigh: profile.thigh,
          );
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
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      if (!mounted) return;
      setState(() => dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'تم حفظ ملفك وخطتك.'
                : 'Your profile and plan were saved.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final profileAsync = ref.watch(userProfileProvider);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(ar ? 'ملفي وخطتي' : 'My profile & plan'),
          leading: IconButton(
            key: const Key('profile-settings-back'),
            tooltip: ar ? 'العودة إلى الإعدادات' : 'Back to settings',
            onPressed: leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(userProfileProvider),
              child: Text(ar ? 'إعادة المحاولة' : 'Try again'),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Text(ar ? 'لا يوجد ملف محلي.' : 'No local profile.'),
              );
            }
            hydrate(profile);
            return Form(
              key: formKey,
              onChanged: () {
                if (!dirty) setState(() => dirty = true);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    ar ? 'بيانات الجسم' : 'Body profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: InputDecoration(
                      labelText: ar ? 'الجنس' : 'Sex',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'male',
                        child: Text(ar ? 'ذكر' : 'Male'),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text(ar ? 'أنثى' : 'Female'),
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
                    decoration: InputDecoration(
                      labelText: ar ? 'العمر' : 'Age',
                    ),
                    validator: (value) => validate(value, 13, 120),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: ar ? 'الطول (سم)' : 'Height (cm)',
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
                      labelText: ar
                          ? 'الوزن الحالي (كغ)'
                          : 'Current weight (kg)',
                    ),
                    validator: (value) => validate(value, 20, 500),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    ar ? 'الهدف والنشاط' : 'Goal & activity',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: ar
                          ? 'الوزن المستهدف (كغ)'
                          : 'Target weight (kg)',
                    ),
                    validator: (value) => validate(value, 20, 500),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: activity,
                    decoration: InputDecoration(
                      labelText: ar ? 'مستوى النشاط' : 'Activity level',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text(ar ? 'حركة محدودة' : 'Low movement'),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text(ar ? 'نشاط خفيف' : 'Light activity'),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text(ar ? 'نشاط متوازن' : 'Balanced activity'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(ar ? 'نشاط مرتفع' : 'High activity'),
                      ),
                      DropdownMenuItem(
                        value: 'very_active',
                        child: Text(ar ? 'نشاط مكثف' : 'Intense activity'),
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
                    title: Text(ar ? 'أمارس التمارين' : 'I exercise'),
                    onChanged: (value) => setState(() {
                      exercises = value;
                      dirty = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('profile-settings-save'),
                    onPressed: saving ? null : () => save(profile),
                    icon: const Icon(Icons.save_rounded),
                    label: Text(ar ? 'حفظ التغييرات' : 'Save changes'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: leave,
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(
                      ar ? 'العودة إلى الإعدادات' : 'Back to settings',
                    ),
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
