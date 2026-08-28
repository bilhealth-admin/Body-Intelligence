part of 'premium_profile_page.dart';

extension _PremiumProfileEditors on _PremiumProfilePageState {
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
        _updateState(() => apply(result));
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
      _updateState(() => apply(parsed));
    }
  }

  Future<void> editDateOfBirth() async {
    final now = DateTime.now();
    final latestEligible = BilAdultEligibility.latestEligibleBirthDate(on: now);
    final current = dateOfBirth ?? DateTime(now.year - age);
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isAfter(latestEligible) ? latestEligible : current,
      firstDate: DateTime(now.year - 120),
      lastDate: latestEligible,
      helpText: tr('Date of birth', 'تاريخ الميلاد'),
    );
    if (selected == null || !mounted) return;
    var years = now.year - selected.year;
    if (now.month < selected.month ||
        (now.month == selected.month && now.day < selected.day)) {
      years--;
    }
    _updateState(() {
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
      _updateState(() => height = nextHeight);
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
