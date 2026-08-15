import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';
import '../../shared/widgets/bil_mobile_list.dart';
import 'providers/user_profile_provider.dart';
import 'profile_locale_copy.dart';

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

  String tr(String english, String arabic) =>
      profileLocaleText(context, english, arabic);

  Future<void> hydrate(UserProfileData profile) async {
    if (loaded || hydrating) {
      return;
    }
    setState(() {
      hydrating = true;
      hydrateError = null;
    });
    try {
      final repo = ref.read(preferencesRepositoryProvider);
      final values = await Future.wait([
        repo.get('displayName'),
        repo.get('profileLocation'),
        repo.get('profilePostalCode'),
        repo.get('profileTimeZone'),
        repo.get('profileEmail'),
        repo.get('units'),
        repo.get('profileDateOfBirth'),
        repo.get('countryRegion'),
        repo.get('cityName'),
        repo.get('timezoneName'),
        repo.get('units.height'),
      ]);
      if (!mounted) return;
      setState(() {
        name = values[0]?.trim().isNotEmpty == true ? values[0]!.trim() : 'BIL';
        final canonicalLocation = [values[8], values[7]]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(', ');
        location = canonicalLocation.isNotEmpty
            ? canonicalLocation
            : values[1] ?? '';
        postalCode = values[2] ?? '';
        timeZone = values[9]?.trim().isNotEmpty == true
            ? values[9]!
            : values[3]?.trim().isNotEmpty == true
            ? values[3]!
            : DateTime.now().timeZoneName;
        email = values[4] ?? '';
        units = values[10] == 'Feet/Inches' || values[5] == 'imperial'
            ? 'imperial'
            : 'metric';
        dateOfBirth = DateTime.tryParse(values[6] ?? '');
        gender = profile.gender;
        activity = profile.activityLevel;
        age = profile.age;
        height = profile.height;
        weight = profile.currentWeight;
        target = profile.targetWeight;
        exercises = profile.exercises;
        loaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => hydrateError = error);
    } finally {
      if (mounted) setState(() => hydrating = false);
    }
  }

  Future<void> pickPhoto() async {
    const types = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    );
    final file = await openFile(acceptedTypeGroups: [types]);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Choose an image smaller than 5 MB.',
              'اختر صورة أصغر من 5 ميجابايت.',
            ),
          ),
        ),
      );
      return;
    }
    await ref
        .read(preferencesRepositoryProvider)
        .set('profilePhoto', base64Encode(bytes));
  }

  Future<String?> edit(
    String title,
    String value, {
    bool number = false,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(labelText: title),
              onSubmitted: (value) => Navigator.pop(sheetContext, value.trim()),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(sheetContext, controller.text.trim()),
              child: Text(tr('Apply', 'اعتماد')),
            ),
          ],
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return result;
  }

  Future<T?> choose<T>(String title, Map<T, String> options) =>
      showModalBottomSheet<T>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final option in options.entries)
              ListTile(
                title: Text(option.value),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, option.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );

  Future<void> save(UserProfileData profile, Goal? activeGoal) async {
    if (saving) return;
    final snapshot = (
      name: name,
      gender: gender,
      activity: activity,
      location: location,
      postalCode: postalCode,
      timeZone: timeZone,
      email: email,
      units: units,
      dateOfBirth: dateOfBirth,
      age: age,
      height: height,
      weight: weight,
      target: target,
      exercises: exercises,
    );
    setState(() => saving = true);
    try {
      final database = ref.read(databaseProvider);
      await database.transaction(() async {
        await ref
            .read(userProfileRepositoryProvider)
            .save(
              gender: snapshot.gender,
              age: snapshot.age,
              height: snapshot.height,
              currentWeight: snapshot.weight,
              targetWeight: snapshot.target,
              activityLevel: snapshot.activity,
              exercises: snapshot.exercises,
              medicalConditions: profile.medicalConditions,
              waist: profile.waist,
              neck: profile.neck,
              chest: profile.chest,
              arm: profile.arm,
              thigh: profile.thigh,
            );
        await ref
            .read(goalRepositoryProvider)
            .save(
              uuid: activeGoal?.uuid,
              profileUuid: profile.uuid,
              type: snapshot.target < snapshot.weight
                  ? 'lose'
                  : snapshot.target > snapshot.weight
                  ? 'gain'
                  : 'maintain',
              targetWeight: snapshot.target,
              targetDate: activeGoal?.targetDate,
            );
        await ref
            .read(preferencesRepositoryProvider)
            .setManyInCurrentTransaction({
              'displayName': snapshot.name,
              'profileLocation': snapshot.location,
              'profilePostalCode': snapshot.postalCode,
              'profileTimeZone': snapshot.timeZone,
              'profileEmail': snapshot.email,
              'units': snapshot.units,
              'profileDateOfBirth':
                  snapshot.dateOfBirth?.toIso8601String() ?? '',
            });
      });
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Your health profile is updated.',
                'تم تحديث ملفك الصحي بأمان.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Your health profile could not be saved. Try again.',
                'تعذّر حفظ ملفك الصحي. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final goalAsync = ref.watch(activeGoalProvider);
    final photoAsync = ref.watch(profilePhotoProvider);
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
                    value: photo == null
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
                    onTap: () => context.push('/plan'),
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

  Widget textRow(
    IconData icon,
    String label,
    String value,
    String title,
    ValueChanged<String> apply,
  ) => _Row(
    icon: icon,
    label: label,
    value: value.isEmpty ? tr('Not set', 'غير محدد') : value,
    onTap: () async {
      final result = await edit(title, value);
      if (result != null) {
        setState(() => apply(result));
      }
    },
  );

  Future<void> editNumber(
    String title,
    double current,
    double min,
    double max,
    ValueChanged<double> apply,
  ) async {
    final value = await edit(title, current.toStringAsFixed(1), number: true);
    final parsed = double.tryParse(value?.replaceAll(',', '.') ?? '');
    if (parsed != null && parsed >= min && parsed <= max) {
      setState(() => apply(parsed));
    }
  }

  Future<void> editDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(now.year - age),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: tr('Date of birth', 'تاريخ الميلاد'),
    );
    if (selected == null || !mounted) return;
    var years = now.year - selected.year;
    if (now.month < selected.month ||
        (now.month == selected.month && now.day < selected.day)) {
      years--;
    }
    setState(() {
      dateOfBirth = selected;
      age = years;
    });
  }

  Future<void> editHeight() async {
    if (_heightEditorOpen) return;
    _heightEditorOpen = true;
    var editorUnit = units == 'imperial' ? 'imperial' : 'metric';
    final controller = TextEditingController(
      text: editorUnit == 'metric'
          ? height.toStringAsFixed(0)
          : (height / 2.54).toStringAsFixed(1),
    );
    double? result;
    try {
      result = await showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        tr('Your height', 'طولك'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final parsed = double.tryParse(
                          controller.text.replaceAll(',', '.'),
                        );
                        if (parsed == null) return;
                        Navigator.pop(
                          sheetContext,
                          editorUnit == 'metric' ? parsed : parsed * 2.54,
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'imperial',
                      label: Text(tr('Feet/Inches', 'قدم/بوصة')),
                    ),
                    ButtonSegment(
                      value: 'metric',
                      label: Text(tr('Centimeters', 'سنتيمترات')),
                    ),
                  ],
                  selected: {editorUnit},
                  onSelectionChanged: (selection) {
                    final next = selection.first;
                    if (next == editorUnit) return;
                    editorUnit = next;
                    controller.text = next == 'metric'
                        ? height.toStringAsFixed(0)
                        : (height / 2.54).toStringAsFixed(1);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('profile-height-editor'),
                  controller: controller,
                  autofocus: false,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    suffixText: editorUnit == 'metric' ? 'cm' : 'in',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      // A modal sheet can finish before Flutter has removed its overlay
      // entries. The controller is still owned by the outgoing TextField,
      // so disposing it before that transition completes can tear down an
      // inherited dependency and trigger `_dependents.isEmpty`.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      controller.dispose();
      _heightEditorOpen = false;
    }
    final nextHeight = result;
    if (nextHeight != null &&
        nextHeight >= 100 &&
        nextHeight <= 250 &&
        mounted) {
      setState(() => height = nextHeight);
    }
  }

  Future<void> openSettingsRoute(String route, UserProfileData profile) async {
    await context.push(route);
    if (!mounted) return;
    loaded = false;
    await hydrate(profile);
  }

  String get heightLabel {
    if (units == 'metric') return '${height.round()} cm';
    final totalInches = height / 2.54;
    return '${totalInches ~/ 12} ft, ${(totalInches % 12).round()} in';
  }

  String get birthDateLabel {
    final value = dateOfBirth;
    if (value == null) return tr('Not set', 'غير محدد');
    return MaterialLocalizations.of(context).formatMediumDate(value);
  }

  String get activityLabel => switch (activity) {
    'sedentary' => tr('Sedentary', 'حركة محدودة'),
    'light' => tr('Lightly active', 'نشاط خفيف'),
    'active' => tr('Active', 'نشاط مرتفع'),
    'very_active' => tr('Very active', 'نشاط مكثف'),
    _ => tr('Moderately active', 'نشاط متوسط'),
  };
}

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    required this.photo,
    required this.onPhoto,
  });
  final String name;
  final Uint8List? photo;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        children: [
          InkWell(
            onTap: onPhoto,
            borderRadius: BorderRadius.circular(46),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: colors.primaryContainer,
                  foregroundImage: photo == null ? null : MemoryImage(photo!),
                  child: photo == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 44,
                          color: colors.primary,
                        )
                      : null,
                ),
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.primary,
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  profileLocaleText(
                    context,
                    'Edit profile and photo',
                    'تعديل الملف والصورة',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => BilMobileSectionHeader(label);
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      BilMobileListRow(label: label, value: value, onTap: onTap);
}
