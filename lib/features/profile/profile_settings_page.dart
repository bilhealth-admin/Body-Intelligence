import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../core/units/measurement_units.dart';
import '../../shared/widgets/bil_account_avatar.dart';
import 'profile_locale_copy.dart';
import 'providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../nutrition/domain/dietary_preferences.dart';

part 'profile_settings_actions.dart';

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() =>
      _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  String t(String english, String arabic) =>
      profileLocaleText(context, english, arabic);

  void _updateState(VoidCallback update) {
    if (mounted) setState(update);
  }

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
  DietaryPattern dietaryPattern = DietaryPattern.omnivore;
  Set<DietaryRequirement> dietaryRequirements = <DietaryRequirement>{};
  Set<DietaryAllergen> dietaryAllergens = <DietaryAllergen>{};
  Set<String> dietaryExcludedIngredients = <String>{};
  bool experiencePreferencesLoaded = false;
  bool initialized = false;
  bool formHydrated = false;
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
            if (!formHydrated) {
              return const Center(child: CircularProgressIndicator());
            }
            final photo = ref.watch(profilePhotoProvider).value;
            final photoUrl = ref.watch(profilePhotoPublicUrlProvider).value;
            return Form(
              key: formKey,
              onChanged: () {
                if (!dirty) setState(() => dirty = true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
                children: [
                  Center(
                    child: BilAccountAvatar(
                      radius: 42,
                      photoBytes: photo,
                      networkUrl: photoUrl,
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DietaryPattern>(
                    initialValue: dietaryPattern,
                    decoration: InputDecoration(
                      labelText: t('Dietary pattern', 'النمط الغذائي'),
                      helperText: t(
                        'Used to filter meal and recipe suggestions.',
                        'يُستخدم لتصفية اقتراحات الوجبات والوصفات.',
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: DietaryPattern.omnivore,
                        child: Text(t('Omnivore', 'متنوع')),
                      ),
                      DropdownMenuItem(
                        value: DietaryPattern.pescatarian,
                        child: Text(t('Pescatarian', 'نباتي مع الأسماك')),
                      ),
                      DropdownMenuItem(
                        value: DietaryPattern.vegetarian,
                        child: Text(t('Vegetarian', 'نباتي')),
                      ),
                      DropdownMenuItem(
                        value: DietaryPattern.vegan,
                        child: Text(t('Vegan', 'نباتي صرف')),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      dietaryPattern = value ?? dietaryPattern;
                      dirty = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('Dietary requirements', 'متطلبات غذائية'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final requirement in DietaryRequirement.values)
                        FilterChip(
                          label: Text(switch (requirement) {
                            DietaryRequirement.halal => t('Halal', 'حلال'),
                            DietaryRequirement.kosher => t('Kosher', 'كوشير'),
                            DietaryRequirement.glutenFree => t(
                              'Gluten-free',
                              'خالٍ من الغلوتين',
                            ),
                            DietaryRequirement.lactoseFree => t(
                              'Lactose-free',
                              'خالٍ من اللاكتوز',
                            ),
                          }),
                          selected: dietaryRequirements.contains(requirement),
                          onSelected: (selected) => setState(() {
                            selected
                                ? dietaryRequirements.add(requirement)
                                : dietaryRequirements.remove(requirement);
                            dirty = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t(
                      'Exclude declared allergens from suggestions',
                      'استبعاد مسببات الحساسية المحددة من الاقتراحات',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final allergen in DietaryAllergen.values)
                        FilterChip(
                          label: Text(switch (allergen) {
                            DietaryAllergen.milk => t('Milk', 'الحليب'),
                            DietaryAllergen.egg => t('Egg', 'البيض'),
                            DietaryAllergen.fish => t('Fish', 'السمك'),
                            DietaryAllergen.shellfish => t(
                              'Shellfish',
                              'المحار',
                            ),
                            DietaryAllergen.peanut => t(
                              'Peanut',
                              'الفول السوداني',
                            ),
                            DietaryAllergen.treeNut => t(
                              'Tree nuts',
                              'المكسرات',
                            ),
                            DietaryAllergen.wheat => t('Wheat', 'القمح'),
                            DietaryAllergen.soy => t('Soy', 'الصويا'),
                            DietaryAllergen.sesame => t('Sesame', 'السمسم'),
                          }),
                          selected: dietaryAllergens.contains(allergen),
                          onSelected: (selected) => setState(() {
                            selected
                                ? dietaryAllergens.add(allergen)
                                : dietaryAllergens.remove(allergen);
                            dirty = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'Ingredient labels and medical restrictions still require your review.',
                      'لا تزال ملصقات المكونات والقيود الطبية بحاجة إلى مراجعتك.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
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
