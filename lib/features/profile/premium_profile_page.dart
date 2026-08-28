import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';
import '../../shared/widgets/bil_mobile_list.dart';
import '../../shared/widgets/bil_account_avatar.dart';
import '../nutrition/domain/dietary_preferences.dart';
import '../nutrition_plans/domain/nutrition_pathway_catalog.dart';
import '../onboarding/domain/adult_eligibility.dart';
import 'dietary_system_labels.dart';
import 'domain/goal_timeline_estimator.dart';
import 'goal_timeline_card.dart';
import 'providers/user_profile_provider.dart';
import 'profile_locale_copy.dart';
import 'services/profile_photo_service.dart';

part 'premium_profile_components.dart';
part 'premium_profile_actions.dart';
part 'premium_profile_editors.dart';

class PremiumProfilePage extends ConsumerStatefulWidget {
  const PremiumProfilePage({super.key});

  @override
  ConsumerState<PremiumProfilePage> createState() => _PremiumProfilePageState();
}

class _PremiumProfilePageState extends ConsumerState<PremiumProfilePage> {
  bool loaded = false;
  bool hydrating = false;
  Object? hydrateError;
  bool saving = false;
  String name = 'BIL';
  String gender = 'male';
  String activity = 'moderate';
  String location = '';
  String postalCode = '';
  String timeZone = '';
  String email = '';
  String units = 'metric';
  DateTime? dateOfBirth;
  int age = 30;
  double height = 170;
  bool _heightEditorOpen = false;
  double weight = 70;
  double target = 70;
  bool exercises = true;

  void _updateState(VoidCallback update) => setState(update);

  String tr(String english, String arabic) =>
      profileLocaleText(context, english, arabic);

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final goalAsync = ref.watch(activeGoalProvider);
    final dietaryAsync = ref.watch(dietaryPreferencesProvider);
    final activePathwayId = ref.watch(activeNutritionPathwayProvider).value;
    final photoAsync = ref.watch(profilePhotoProvider);
    final photoUrl = ref.watch(profilePhotoPublicUrlProvider).value;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: SecondaryPageAppBar(
          title: Text(tr('Profile', 'الملف الشخصي')),
          showDashboardAction: false,
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(userProfileProvider),
              child: Text(tr('Try again', 'إعادة المحاولة')),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Text(
                  tr('Complete your profile first.', 'أكمل إعداد ملفك أولًا.'),
                ),
              );
            }
            if (goalAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (goalAsync.hasError) {
              return Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(activeGoalProvider),
                  child: Text(tr('Try again', 'إعادة المحاولة')),
                ),
              );
            }
            if (photoAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (photoAsync.hasError) {
              return Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(profilePhotoProvider),
                  child: Text(tr('Try again', 'إعادة المحاولة')),
                ),
              );
            }
            if (hydrateError != null) {
              return Center(
                child: FilledButton(
                  onPressed: () => hydrate(profile),
                  child: Text(tr('Try again', 'إعادة المحاولة')),
                ),
              );
            }
            if (!loaded) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => hydrate(profile),
              );
              return const Center(child: CircularProgressIndicator());
            }
            final photo = photoAsync.value;
            final dietaryPreferences =
                dietaryAsync.value ?? const DietaryPreferences();
            final activePathway = nutritionPathways
                .where((pathway) => pathway.id == activePathwayId)
                .firstOrNull;
            final timelineGoalType = target < weight
                ? 'lose'
                : target > weight
                ? 'gain'
                : 'maintain';
            final goalTimeline = GoalTimelineEstimator.estimate(
              currentWeightKg: weight,
              targetWeightKg: target,
              goalType: timelineGoalType,
              asOf: DateTime.now(),
            );
            return AbsorbPointer(
              absorbing: saving,
              child: ListView(
                key: const Key('premium-profile-list'),
                padding: const EdgeInsets.only(bottom: 128),
                children: [
                  _Section(tr('Personal details', 'البيانات الشخصية')),
                  _Row(
                    key: const Key('profile-display-name-row'),
                    icon: Icons.badge_outlined,
                    label: tr('Display name', 'الاسم الظاهر'),
                    value: name,
                    onTap: () async {
                      final value = await edit(
                        tr('Display name', 'الاسم الظاهر'),
                        name,
                      );
                      if (value?.isNotEmpty == true) {
                        setState(() => name = value!);
                      }
                    },
                  ),
                  _Row(
                    key: const Key('profile-photo-row'),
                    icon: Icons.photo_camera_outlined,
                    label: tr('Profile photo', 'الصورة الشخصية'),
                    value: photo == null && (photoUrl?.trim().isEmpty ?? true)
                        ? tr('Add photo', 'إضافة صورة')
                        : tr('Change photo', 'تغيير الصورة'),
                    onTap: pickPhoto,
                  ),
                  _Row(
                    key: const Key('profile-email-row'),
                    icon: Icons.alternate_email_rounded,
                    label: tr('Email address', 'البريد الإلكتروني'),
                    value: email.isEmpty ? tr('Not added', 'غير مضاف') : email,
                    onTap: () =>
                        openSettingsRoute('/settings/account-email', profile),
                  ),
                  _Section(tr('Body details', 'بيانات الجسم')),
                  _Row(
                    key: const Key('profile-height-row'),
                    icon: Icons.height_rounded,
                    label: tr('Height', 'الطول'),
                    value: heightLabel,
                    onTap: editHeight,
                  ),
                  _Row(
                    key: const Key('profile-sex-row'),
                    icon: Icons.wc_rounded,
                    label: tr('Sex', 'الجنس'),
                    value: gender == 'female'
                        ? tr('Female', 'أنثى')
                        : tr('Male', 'ذكر'),
                    onTap: () async {
                      final value = await choose(tr('Sex', 'الجنس'), {
                        'male': tr('Male', 'ذكر'),
                        'female': tr('Female', 'أنثى'),
                      });
                      if (value != null) {
                        setState(() => gender = value);
                      }
                    },
                  ),
                  _Row(
                    key: const Key('profile-date-of-birth-row'),
                    icon: Icons.cake_outlined,
                    label: tr('Date of birth', 'تاريخ الميلاد'),
                    value: birthDateLabel,
                    onTap: editDateOfBirth,
                  ),
                  _Section(tr('Location & preferences', 'الموقع والتفضيلات')),
                  _Row(
                    key: const Key('profile-location-row'),
                    icon: Icons.location_on_outlined,
                    label: tr('Location', 'الموقع'),
                    value: location.isEmpty
                        ? tr('Not set', 'غير محدد')
                        : location,
                    onTap: () =>
                        openSettingsRoute('/location-settings', profile),
                  ),
                  textRow(
                    Icons.markunread_mailbox_outlined,
                    tr('Postal code', 'الرمز البريدي'),
                    postalCode,
                    tr('Postal code', 'الرمز البريدي'),
                    (v) => postalCode = v,
                  ),
                  _Row(
                    key: const Key('profile-timezone-row'),
                    icon: Icons.schedule_rounded,
                    label: tr('Time zone', 'المنطقة الزمنية'),
                    value: timeZone,
                    onTap: () =>
                        openSettingsRoute('/location-settings', profile),
                  ),
                  _Row(
                    key: const Key('profile-units-row'),
                    icon: Icons.straighten_rounded,
                    label: tr('Units', 'الوحدات'),
                    value: units == 'metric'
                        ? tr('Metric · kg, cm, ml', 'متري · كغ، سم، مل')
                        : tr('Imperial · lb, ft', 'إمبراطوري · رطل، قدم'),
                    onTap: () => openSettingsRoute('/settings/units', profile),
                  ),
                  _Row(
                    key: const Key('profile-dietary-system-row'),
                    icon: Icons.restaurant_menu_rounded,
                    label: tr('Dietary system', 'النظام الغذائي'),
                    value: dietaryAsync.isLoading
                        ? tr('Loading…', 'جارٍ التحميل…')
                        : dietaryAsync.hasError
                        ? tr('Unavailable', 'غير متاح')
                        : activePathway == null
                        ? dietarySystemSummary(context, dietaryPreferences)
                        : tr(activePathway.enTitle, activePathway.arTitle),
                    onTap: () => context.push('/plan?origin=profile'),
                  ),
                  _Row(
                    key: const Key('profile-goals-row'),
                    icon: Icons.flag_outlined,
                    label: tr('Goals', 'الأهداف'),
                    value: tr(
                      'Update weight, nutrition, and fitness goals',
                      'حدّث أهداف الوزن والتغذية واللياقة',
                    ),
                    onTap: () => openSettingsRoute('/goals', profile),
                  ),
                  _Section(tr('Health goals', 'الأهداف الصحية')),
                  GoalTimelineCard(estimate: goalTimeline),
                  _Row(
                    icon: Icons.monitor_weight_outlined,
                    label: tr('Current weight', 'الوزن الحالي'),
                    value: '${weight.toStringAsFixed(1)} kg',
                    onTap: () => editNumber(
                      tr('Current weight', 'الوزن الحالي'),
                      weight,
                      20,
                      500,
                      (v) => weight = v,
                    ),
                  ),
                  _Row(
                    icon: Icons.flag_outlined,
                    label: tr('Goal weight', 'الوزن المستهدف'),
                    value: '${target.toStringAsFixed(1)} kg',
                    onTap: () => editNumber(
                      tr('Goal weight', 'الوزن المستهدف'),
                      target,
                      20,
                      500,
                      (v) => target = v,
                    ),
                  ),
                  _Row(
                    icon: Icons.directions_run_rounded,
                    label: tr('Activity level', 'مستوى النشاط'),
                    value: activityLabel,
                    onTap: () async {
                      final value =
                          await choose(tr('Activity level', 'مستوى النشاط'), {
                            'sedentary': tr('Sedentary', 'حركة محدودة'),
                            'light': tr('Lightly active', 'نشاط خفيف'),
                            'moderate': tr('Moderately active', 'نشاط متوسط'),
                            'active': tr('Active', 'نشاط مرتفع'),
                            'very_active': tr('Very active', 'نشاط مكثف'),
                          });
                      if (value != null) {
                        setState(() => activity = value);
                      }
                    },
                  ),
                  _Row(
                    icon: Icons.tune_rounded,
                    label: tr('Calories & macro plan', 'خطة السعرات والماكروز'),
                    value: tr(
                      'Plan details & recommendations',
                      'تفاصيل الخطة والتوصيات',
                    ),
                    onTap: () => context.push('/plan?origin=profile'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: OutlinedButton.icon(
                      key: const Key('advanced-body-measurements-action'),
                      onPressed: () =>
                          context.push('/advanced-body-measurements'),
                      icon: const Icon(Icons.straighten_rounded),
                      label: Text(
                        tr(
                          'Advanced body measurements',
                          'قياسات الجسم المتقدمة',
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: FilledButton.icon(
                      key: const Key('profile-settings-save'),
                      onPressed: saving
                          ? null
                          : () => save(profile, goalAsync.value),
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(tr('Save health profile', 'حفظ الملف الصحي')),
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
