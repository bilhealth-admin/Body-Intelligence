part of 'reference_preferences_pages.dart';

class _ChoiceScaffold extends StatelessWidget {
  const _ChoiceScaffold({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });
  final String title, selected;
  final List<String> options;
  final String Function(String) label;
  final ValueChanged<String> onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      children: [
        for (final option in options)
          ListTile(
            title: Text(label(option)),
            trailing: selected == option
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: enabled ? () => onSelected(option) : null,
          ),
      ],
    ),
  );
}

class ReferenceNutritionGoalsPage extends ConsumerWidget {
  const ReferenceNutritionGoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PreferenceListPage(
      title: _nutritionGoalText(context, 'Calorie and macro goals'),
      children: const [
        _SectionLabel('Default goal'),
        _StoredNumber('goal.calories', 'Calories', null, ''),
        _StoredNumber('goal.carbsPercent', 'Carbohydrates', null, '%'),
        _StoredNumber('goal.proteinPercent', 'Protein', null, '%'),
        _StoredNumber('goal.fatPercent', 'Fat', null, '%'),
        _SectionLabel('Daily macro goals in grams'),
        _DerivedMacroGrams(),
        _SectionLabel('Additional nutrient goals'),
        _StoredNumber('goal.saturatedFat', 'Saturated fat', null, 'g'),
        _StoredNumber(
          'goal.polyunsaturatedFat',
          'Polyunsaturated fat',
          null,
          'g',
        ),
        _StoredNumber(
          'goal.monounsaturatedFat',
          'Monounsaturated fat',
          null,
          'g',
        ),
        _StoredNumber('goal.transFat', 'Trans fat', null, 'g'),
        _StoredNumber('goal.cholesterol', 'Cholesterol', null, 'mg'),
        _StoredNumber('goal.sodium', 'Sodium', null, 'mg'),
        _StoredNumber('goal.potassium', 'Potassium', null, 'mg'),
        _StoredNumber('goal.fiber', 'Fiber', null, 'g'),
        _StoredNumber('goal.sugar', 'Sugar', null, 'g'),
        _StoredNumber('goal.vitaminA', 'Vitamin A', null, '%'),
        _StoredNumber('goal.vitaminC', 'Vitamin C', null, '%'),
        _StoredNumber('goal.calcium', 'Calcium', null, '%'),
        _StoredNumber('goal.iron', 'Iron', null, '%'),
      ],
    );
  }
}

class _PreferenceListPage extends StatelessWidget {
  const _PreferenceListPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: FittedBox(fit: BoxFit.scaleDown, child: Text(title, maxLines: 1)),
    ),
    body: ListView.separated(
      padding: const EdgeInsets.only(bottom: 64),
      itemCount: children.length,
      itemBuilder: (_, index) => children[index],
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
    child: Text(
      _nutritionGoalText(context, label),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _PremiumFeature extends ConsumerWidget {
  const _PremiumFeature(this.title, this.subtitle, this.route);
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(verifiedSubscriptionStateProvider);
    final active =
        entitlement.value?.grants(CommerceEntitlement.advancedIntelligence) ??
        false;
    final language = Localizations.localeOf(context).languageCode;
    final status = active
        ? switch (language) {
            'ar' => 'ميزة Pro مفعّلة',
            'fr' => 'Fonction Pro active',
            'es' => 'Función Pro activa',
            'tr' => 'Pro özellik etkin',
            _ => 'Pro feature active',
          }
        : switch (language) {
            'ar' => 'ميزة Pro مقفلة',
            'fr' => 'Fonction Pro verrouillée',
            'es' => 'Función Pro bloqueada',
            'tr' => 'Pro özellik kilitli',
            _ => 'Pro feature locked',
          };
    return ListTile(
      minTileHeight: 76,
      title: Text(_diaryText(context, title)),
      subtitle: Text(_diaryText(context, subtitle)),
      trailing: Semantics(
        label: status,
        child: AnimatedContainer(
          key: const Key('diary-premium-feature-state'),
          duration: const Duration(milliseconds: 220),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFFFD76A), Color(0xFFE79000)],
                  )
                : null,
            color: active
                ? null
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: active
                  ? const Color(0xFFFFE6A5)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x44E79000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: Icon(
            active
                ? Icons.workspace_premium_rounded
                : entitlement.hasError
                ? Icons.refresh_rounded
                : Icons.lock_outline_rounded,
            color: active
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      enabled: entitlement.hasValue,
      onTap: !entitlement.hasValue
          ? entitlement.hasError
                ? () => ref.invalidate(verifiedSubscriptionStateProvider)
                : null
          : () => context.push(active ? route : '/plans'),
    );
  }
}

class _StoredSwitch extends ConsumerStatefulWidget {
  const _StoredSwitch(this.keyName, this.label, this.defaultValue);
  final String keyName;
  final String label;
  final bool defaultValue;
  @override
  ConsumerState<_StoredSwitch> createState() => _StoredSwitchState();
}

class _StoredSwitchState extends ConsumerState<_StoredSwitch> {
  late bool value = widget.defaultValue;
  bool loading = true;
  bool saving = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(preferencesRepositoryProvider)
          .get(widget.keyName);
      if (!mounted) return;
      setState(() {
        value = saved == null ? widget.defaultValue : saved == 'true';
        loading = false;
      });
    } catch (caught) {
      if (mounted) {
        setState(() {
          loading = false;
          error = caught;
        });
      }
    }
  }

  Future<void> _change(bool next) async {
    if (saving || loading || error != null) return;
    final previous = value;
    setState(() {
      value = next;
      saving = true;
    });
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set(widget.keyName, '$next');
    } catch (_) {
      if (mounted) {
        setState(() => value = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.strings.text('Could not save changes.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => error != null
      ? ListTile(
          title: Text(_diaryText(context, widget.label)),
          subtitle: Text(
            context.strings.text('Saved setting could not be loaded.'),
          ),
          trailing: TextButton(
            onPressed: _load,
            child: Text(context.strings.text('Retry')),
          ),
        )
      : SwitchListTile(
          minTileHeight: 58,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          title: Text(_diaryText(context, widget.label)),
          value: value,
          onChanged: loading || saving ? null : _change,
          secondary: loading || saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        );
}

class _StoredChoice extends ConsumerStatefulWidget {
  const _StoredChoice(
    this.keyName,
    this.label,
    this.options,
    this.defaultValue,
  );
  final String keyName;
  final String label;
  final List<String> options;
  final String defaultValue;
  @override
  ConsumerState<_StoredChoice> createState() => _StoredChoiceState();
}

class _StoredChoiceState extends ConsumerState<_StoredChoice> {
  String? value;
  bool loading = true;
  bool saving = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(preferencesRepositoryProvider)
          .get(widget.keyName);
      if (!mounted) return;
      setState(() {
        value = saved == null
            ? widget.defaultValue
            : widget.options.contains(saved)
            ? saved
            : widget.defaultValue;
        loading = false;
      });
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = cause;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(_diaryText(context, widget.label)),
    trailing: loading || saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : error != null
        ? TextButton(
            onPressed: _load,
            child: Text(context.strings.text('Retry')),
          )
        : Text(
            _diaryText(context, value!),
            style: const TextStyle(color: Color(0xFF0A6FF5)),
          ),
    onTap: loading || saving || error != null || value == null
        ? null
        : () async {
            final selected = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => _ReferenceChoicePage(
                  title: widget.label,
                  options: widget.options,
                  selected: value!,
                  diaryWarning: widget.keyName == 'diary.sharing',
                ),
              ),
            );
            if (selected == null || !mounted) return;
            final previous = value;
            setState(() {
              value = selected;
              saving = true;
            });
            try {
              final repository = ref.read(preferencesRepositoryProvider);
              if (widget.keyName == 'units.weight') {
                await repository.setMany({
                  widget.keyName: selected,
                  'units': selected == 'Pounds' || selected == 'Stone'
                      ? 'imperial'
                      : 'metric',
                });
              } else {
                await repository.set(widget.keyName, selected);
              }
            } catch (_) {
              if (mounted && context.mounted) {
                setState(() => value = previous);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.strings.text('Could not save changes.'),
                    ),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => saving = false);
            }
          },
  );
}

class _ReferenceChoicePage extends StatefulWidget {
  const _ReferenceChoicePage({
    required this.title,
    required this.options,
    required this.selected,
    required this.diaryWarning,
  });
  final String title;
  final List<String> options;
  final String selected;
  final bool diaryWarning;

  @override
  State<_ReferenceChoicePage> createState() => _ReferenceChoicePageState();
}

class _ReferenceChoicePageState extends State<_ReferenceChoicePage> {
  late String selected = widget.selected;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: Text(context.strings.text(widget.title)),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_rounded),
          onPressed: () => Navigator.pop(context, selected),
        ),
      ],
    ),
    body: ListView(
      children: [
        _SectionLabel(
          widget.diaryWarning
              ? 'Choose your diary sharing option'
              : 'Choose your ${widget.title.toLowerCase()}',
        ),
        if (widget.diaryWarning)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              context.strings.text(
                'If you share your diary, your weight and eating habits may be visible to the people you choose.',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        for (final option in widget.options)
          Column(
            children: [
              ListTile(
                minTileHeight: 66,
                title: Text(context.strings.text(option)),
                trailing: selected == option
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0A6FF5))
                    : null,
                onTap: () => setState(() => selected = option),
              ),
              const Divider(height: 1),
            ],
          ),
      ],
    ),
  );
}
