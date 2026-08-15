import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/services/app_settings_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';

class ReferenceDiarySettingsPage extends ConsumerWidget {
  const ReferenceDiarySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PreferenceListPage(
      title: _diaryText(context, 'Diary settings'),
      children: const [
        _PremiumFeature(
          'Show carbs, protein and fat by meal',
          'View carbs, protein and fat by gram or percent.',
          '/settings/diary/macro-display',
        ),
        _StoredSwitch(
          'diary.showAllMeals',
          'Show all meals in diary tabs',
          true,
        ),
        _UnavailablePreference('Use multi-add by default'),
        _StoredSwitch('diary.foodInsights', 'Show diary food insights', true),
        _StoredSwitch(
          'diary.alwaysShowWater',
          'Always show water in diary',
          true,
        ),
        _PreferenceRoute('Default search tab', '/settings/diary/search-tab'),
        _PreferenceRoute('Diary sharing', '/settings/diary/sharing'),
        _PreferenceRoute('Customize meal names', '/settings/diary/meal-names'),
        _StoredChoice(
          'diary.nutrientDashboard',
          'Customize nutrient dashboard',
          ['Calories and macros', 'Heart healthy', 'Low carb', 'Custom'],
          'Calories and macros',
        ),
        _StoredSwitch('diary.useNetCarbs', 'Track net carbs', false),
        _StoredSwitch(
          'diary.showFoodTimestamps',
          'Show food timestamps',
          false,
        ),
      ],
    );
  }
}

class _UnavailablePreference extends StatelessWidget {
  const _UnavailablePreference(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: false,
    title: Text(_diaryText(context, label)),
    subtitle: Text(context.strings.text('Unavailable')),
    trailing: const Icon(Icons.lock_outline_rounded),
  );
}

class _PreferenceRoute extends StatelessWidget {
  const _PreferenceRoute(this.label, this.route);
  final String label, route;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(_diaryText(context, label)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(route),
  );
}

class ReferenceEmailSettingsPage extends ConsumerWidget {
  const ReferenceEmailSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PreferenceListPage(
      title: context.strings.text('Email settings'),
      children: const [
        _EmailDeliveryNotice(),
        _UnavailableEmailPreference('New feature announcements'),
        _UnavailableEmailPreference('Healthy living tips'),
        _UnavailableEmailPreference('Healthy recipes'),
        _UnavailableEmailPreference('Workout recommendations'),
        _UnavailableEmailPreference('Gear recommendations and offers'),
        _UnavailableEmailPreference('Weekly digest'),
        _UnavailableEmailPreference('People can find me by email address'),
        _SectionLabel('Send me an email when'),
        _UnavailableEmailPreference('Someone sends me a message'),
        _UnavailableEmailPreference('Someone sends me a friend request'),
        _UnavailableEmailPreference('Someone invites me to a group'),
        _UnavailableEmailPreference('Someone accepts my friend request'),
        _UnavailableEmailPreference('Someone accepts my group invitation'),
        SizedBox(height: 96),
      ],
    );
  }
}

class _EmailDeliveryNotice extends StatelessWidget {
  const _EmailDeliveryNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
    child: Text(
      context.strings.text(
        'Email delivery is not configured yet. These controls stay off until BIL can verify server delivery.',
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    ),
  );
}

class _UnavailableEmailPreference extends StatelessWidget {
  const _UnavailableEmailPreference(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    minTileHeight: 58,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
    title: Text(_diaryText(context, label)),
    subtitle: Text(context.strings.text('Unavailable')),
    value: false,
    onChanged: null,
  );
}

class ReferenceUnitPreferencesPage extends ConsumerWidget {
  const ReferenceUnitPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PreferenceListPage(
      title: _diaryText(context, 'Unit preferences'),
      children: const [
        _SectionLabel('Weight'),
        _StoredChoice('units.weight', 'Weight', [
          'Pounds',
          'Kilograms',
          'Stone',
        ], 'Kilograms'),
        _SectionLabel('Height'),
        _StoredChoice('units.height', 'Height', [
          'Feet/Inches',
          'Centimeters',
        ], 'Centimeters'),
        _SectionLabel('Distance'),
        _StoredChoice('units.distance', 'Distance', [
          'Miles',
          'Kilometers',
        ], 'Kilometers'),
        _SectionLabel('Energy'),
        _StoredChoice('units.energy', 'Energy', [
          'Calories',
          'Kilojoules',
        ], 'Calories'),
        _SectionLabel('Water'),
        _StoredChoice('units.water', 'Water', [
          'Cups',
          'Milliliters',
          'Fluid ounces',
        ], 'Milliliters'),
      ],
    );
  }
}

class ReferenceAppearancePage extends ConsumerWidget {
  const ReferenceAppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appSettingsProvider).themeMode;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_diaryText(context, 'App appearance')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          const _SectionLabel('Select theme'),
          const Divider(height: 1),
          RadioGroup<String>(
            groupValue: mode,
            onChanged: (value) {
              if (value != null) {
                ref.read(appSettingsProvider.notifier).setThemeMode(value);
              }
            },
            child: Column(
              children: [
                for (final entry in const [
                  ('system', 'System default'),
                  ('light', 'Light theme'),
                  ('dark', 'Dark theme'),
                ]) ...[
                  RadioListTile<String>(
                    value: entry.$1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    title: Text(
                      _diaryText(context, entry.$2),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    activeColor: const Color(0xFF0A6FF5),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                  const Divider(height: 1, indent: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReferenceDiarySearchTabPage extends ConsumerStatefulWidget {
  const ReferenceDiarySearchTabPage({super.key});
  @override
  ConsumerState<ReferenceDiarySearchTabPage> createState() =>
      _DiarySearchTabState();
}

class _DiarySearchTabState extends ConsumerState<ReferenceDiarySearchTabPage> {
  String selected = 'my_foods';
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
      final value = await ref
          .read(preferencesRepositoryProvider)
          .get('diary.defaultSearchTab');
      if (!mounted) return;
      setState(() {
        if (const {'my_foods', 'meals', 'recipes'}.contains(value)) {
          selected = value!;
        }
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

  Future<void> _select(String value) async {
    if (saving || loading || error != null || value == selected) return;
    final previous = selected;
    setState(() {
      selected = value;
      saving = true;
    });
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set('diary.defaultSearchTab', value);
    } catch (_) {
      if (mounted) {
        setState(() => selected = previous);
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
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: loading
        ? Scaffold(
            appBar: AppBar(
              title: Text(_diaryText(context, 'Default search tab')),
            ),
            body: const Center(child: CircularProgressIndicator()),
          )
        : error != null
        ? Scaffold(
            appBar: AppBar(
              title: Text(_diaryText(context, 'Default search tab')),
            ),
            body: Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.strings.text('Retry')),
              ),
            ),
          )
        : _ChoiceScaffold(
            title: _diaryText(context, 'Default search tab'),
            options: const ['my_foods', 'meals', 'recipes'],
            selected: selected,
            enabled: !saving,
            label: (value) => _diaryText(context, value),
            onSelected: _select,
          ),
  );
}

class ReferenceDiarySharingPage extends ConsumerStatefulWidget {
  const ReferenceDiarySharingPage({super.key});
  @override
  ConsumerState<ReferenceDiarySharingPage> createState() =>
      _DiarySharingState();
}

class _DiarySharingState extends ConsumerState<ReferenceDiarySharingPage> {
  String selected = 'private';
  bool loading = true;
  bool saving = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    _loadSharing();
  }

  Future<void> _loadSharing() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await ref
          .read(preferencesRepositoryProvider)
          .get('diary.sharing');
      if (!mounted) return;
      setState(() {
        if (const {'private', 'public', 'friends', 'locked'}.contains(value)) {
          selected = value!;
        }
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

  Future<void> _select(String value) async {
    if (saving || loading || error != null || value == selected) return;
    String? accessKeyHash;
    if (value == 'locked') {
      final controller = TextEditingController();
      final key = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_diaryText(context, 'Create access key')),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _diaryText(context, 'Access key'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_diaryText(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(_diaryText(context, 'Save')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (key == null || key.length < 6) {
        if (mounted && key != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _diaryText(context, 'Key must contain at least 6 characters'),
              ),
            ),
          );
        }
        return;
      }
      accessKeyHash = sha256.convert(utf8.encode(key)).toString();
    }
    setState(() => saving = true);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .mutate(
            set: {
              'diary.sharing': value,
              'diary.sharingKeySha256': ?accessKeyHash,
            },
            remove: accessKeyHash == null
                ? const ['diary.sharingKeySha256']
                : const [],
          );
      if (mounted) setState(() => selected = value);
    } catch (_) {
      if (mounted) {
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
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: Text(_diaryText(context, 'Diary sharing'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: FilledButton.icon(
                onPressed: _loadSharing,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.strings.text('Retry')),
              ),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    _diaryText(
                      context,
                      'Diary sharing is not available yet. Your diary remains private.',
                    ),
                  ),
                ),
                for (final option in const ['private'])
                  ListTile(
                    title: Text(_diaryText(context, option)),
                    trailing: selected == option
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: saving ? null : () => _select(option),
                  ),
                for (final option in const ['public', 'friends', 'locked'])
                  Semantics(
                    enabled: false,
                    label:
                        '${_diaryText(context, option)}, ${context.strings.text('Unavailable')}',
                    child: ListTile(
                      title: Text(
                        _diaryText(context, option),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      subtitle: Text(
                        context.strings.text('Unavailable'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Icons.lock_outline_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class ReferenceMealNamesPage extends ConsumerStatefulWidget {
  const ReferenceMealNamesPage({super.key});
  @override
  ConsumerState<ReferenceMealNamesPage> createState() => _MealNamesState();
}

class _MealNamesState extends ConsumerState<ReferenceMealNamesPage> {
  static const _defaults = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  final controllers = List.generate(4, (_) => TextEditingController());
  bool loading = true;
  bool saving = false;
  Object? loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final values = await Future.wait([
        for (var i = 0; i < 4; i++)
          ref.read(preferencesRepositoryProvider).get('diary.mealName.$i'),
      ]);
      if (!mounted) {
        return;
      }
      for (var i = 0; i < 4; i++) {
        controllers[i].text = values[i] ?? _diaryText(context, _defaults[i]);
      }
      setState(() => loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = error;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final set = <String, String>{};
      for (var i = 0; i < 4; i++) {
        final value = controllers[i].text.trim();
        final key = 'diary.mealName.$i';
        // An explicit empty value hides the supported meal slot. A missing
        // preference means "use the localized default" and is not equivalent.
        set[key] = value;
      }
      await ref.read(preferencesRepositoryProvider).mutate(set: set);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_diaryText(context, 'Saved'))));
      }
    } catch (_) {
      if (mounted) {
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
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_diaryText(context, 'Customize meal names')),
        actions: [
          TextButton(
            onPressed: loading || saving ? null : _save,
            child: Text(_diaryText(context, 'Save')),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.strings.text('Retry')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _diaryText(
                    context,
                    'Customize the four supported meal names. Empty slots are hidden from the diary.',
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[i],
                      enabled: !saving,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: '${_diaryText(context, 'Meal')} ${i + 1}',
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

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

class _StoredNumber extends ConsumerStatefulWidget {
  const _StoredNumber(this.keyName, this.label, this.defaultValue, this.suffix);
  final String keyName;
  final String label;
  final String? defaultValue;
  final String suffix;
  @override
  ConsumerState<_StoredNumber> createState() => _StoredNumberState();
}

@visibleForTesting
bool validStoredNutritionGoal(String key, String suffix, String input) {
  final number = double.tryParse(input);
  if (number == null || !number.isFinite || number < 0) return false;
  if (key == 'goal.calories') return number >= 1 && number <= 10000;
  if (key.endsWith('Percent') || suffix == '%') return number <= 100;
  if (suffix == 'mg') return number <= 1000000;
  return number <= 10000;
}

class _StoredNumberState extends ConsumerState<_StoredNumber> {
  String? value;
  String? retainedDraft;
  bool loading = true;
  bool saving = false;
  Object? error;
  bool editorOpen = false;

  bool _valid(String input) {
    return validStoredNutritionGoal(widget.keyName, widget.suffix, input);
  }

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
      final candidate = saved ?? widget.defaultValue;
      setState(() {
        value = candidate != null && _valid(candidate) ? candidate : null;
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

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(_nutritionGoalText(context, widget.label)),
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
        : Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value == null
                  ? '—'
                  : widget.suffix == '%'
                  ? '$value%'
                  : '$value${widget.suffix.isEmpty ? '' : ' ${widget.suffix}'}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF0A6FF5),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
    onTap: loading || saving || error != null
        ? null
        : () async {
            if (editorOpen) return;
            editorOpen = true;
            final controller = TextEditingController(
              text: retainedDraft ?? value ?? '',
            );
            String? next;
            try {
              next = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  var dialogSaving = false;
                  String? dialogError;
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) => PopScope(
                      canPop: !dialogSaving,
                      child: AlertDialog(
                        title: Text(_nutritionGoalText(context, widget.label)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              autofocus: true,
                              enabled: !dialogSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            if (dialogError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                dialogError!,
                                style: TextStyle(
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.error,
                                ),
                              ),
                            ],
                            if (dialogSaving) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: dialogSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: Text(context.strings.text('Cancel')),
                          ),
                          FilledButton(
                            onPressed: dialogSaving
                                ? null
                                : () async {
                                    final draft = controller.text.trim();
                                    if (draft.isNotEmpty && !_valid(draft)) {
                                      setDialogState(
                                        () => dialogError = context.strings
                                            .text('Review values and retry.'),
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      dialogSaving = true;
                                      dialogError = null;
                                    });
                                    if (mounted) {
                                      setState(() => saving = true);
                                    }
                                    try {
                                      final repository = ref.read(
                                        preferencesRepositoryProvider,
                                      );
                                      if (draft.isEmpty) {
                                        await repository.remove(widget.keyName);
                                      } else {
                                        await repository.set(
                                          widget.keyName,
                                          draft,
                                        );
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext, draft);
                                      }
                                    } catch (_) {
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          dialogSaving = false;
                                          dialogError = context.strings.text(
                                            'Could not save changes.',
                                          );
                                        });
                                      }
                                      if (mounted) {
                                        setState(() => saving = false);
                                      }
                                    }
                                  },
                            child: Text(context.strings.text('Save')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } finally {
              await WidgetsBinding.instance.endOfFrame;
              await Future<void>.delayed(const Duration(milliseconds: 250));
              controller.dispose();
              editorOpen = false;
            }
            final saved = next;
            if (saved == null || !mounted || !context.mounted) {
              return;
            }
            setState(() {
              value = saved.isEmpty ? null : saved;
              retainedDraft = null;
              saving = false;
            });
          },
  );
}

class _DerivedMacroGrams extends ConsumerStatefulWidget {
  const _DerivedMacroGrams();

  @override
  ConsumerState<_DerivedMacroGrams> createState() => _DerivedMacroGramsState();
}

class _DerivedMacroGramsState extends ConsumerState<_DerivedMacroGrams> {
  int generation = 0;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(preferencesRepositoryProvider);
    return StreamBuilder<List<String?>>(
      key: ValueKey(generation),
      stream: Stream<List<String?>>.multi((controller) {
        final values = List<String?>.filled(4, null);
        final ready = List<bool>.filled(4, false);
        final keys = [
          'goal.calories',
          'goal.carbsPercent',
          'goal.proteinPercent',
          'goal.fatPercent',
        ];
        final subscriptions = <dynamic>[];
        for (var index = 0; index < keys.length; index++) {
          subscriptions.add(
            repository.watch(keys[index]).listen((value) {
              values[index] = value;
              ready[index] = true;
              if (ready.every((item) => item)) {
                controller.add(List.of(values));
              }
            }, onError: controller.addError),
          );
        }
        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text(context.strings.text('Unavailable')),
            trailing: TextButton.icon(
              onPressed: () => setState(() => generation += 1),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.strings.text('Retry')),
            ),
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final grams = deriveMacroGrams(snapshot.data!);
        final valid = grams != null;
        const labels = ['Carbohydrates', 'Protein', 'Fat'];
        return Column(
          children: [
            if (!valid)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _nutritionGoalText(
                    context,
                    'Set calories and percentages totaling 100% to calculate grams.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (var index = 0; index < labels.length; index++)
              ListTile(
                title: Text(_nutritionGoalText(context, labels[index])),
                trailing: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    valid ? '${grams[index].toStringAsFixed(1)} g' : '—',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFF0A6FF5),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
List<double>? deriveMacroGrams(List<String?> stored) {
  if (stored.length != 4) return null;
  final parsed = stored.map((value) => double.tryParse(value ?? '')).toList();
  if (!parsed.every((value) => value != null && value.isFinite && value >= 0)) {
    return null;
  }
  final calories = parsed[0]!;
  final carbs = parsed[1]!;
  final protein = parsed[2]!;
  final fat = parsed[3]!;
  if (calories <= 0 ||
      calories > 10000 ||
      carbs > 100 ||
      protein > 100 ||
      fat > 100 ||
      (carbs + protein + fat - 100).abs() >= 0.01) {
    return null;
  }
  return [
    calories * carbs / 400,
    calories * protein / 400,
    calories * fat / 900,
  ];
}

String _diaryText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _diarySupplementalCopy[key]?[code] ??
      _diaryCopy[code]?[key] ??
      context.strings.text(key);
}

const _diarySupplementalCopy = <String, Map<String, String>>{
  'Diary sharing is not available yet. Your diary remains private.': {
    'ar': 'مشاركة اليوميات غير متاحة بعد. تظل يومياتك خاصة.',
    'fr':
        'Le partage du journal n’est pas encore disponible. Votre journal reste privé.',
    'es':
        'Compartir el diario aún no está disponible. Tu diario sigue siendo privado.',
    'tr': 'Günlük paylaşımı henüz kullanılamıyor. Günlüğünüz gizli kalır.',
  },
  'Customize the four supported meal names. Empty slots are hidden from the diary.': {
    'ar':
        'خصّص أسماء الوجبات الأربع المدعومة. تُخفى الخانات الفارغة من اليوميات.',
    'fr':
        'Personnalisez les quatre noms de repas pris en charge. Les champs vides sont masqués dans le journal.',
    'es':
        'Personaliza los cuatro nombres de comidas disponibles. Los campos vacíos se ocultan del diario.',
    'tr':
        'Desteklenen dört öğün adını özelleştirin. Boş alanlar günlükte gizlenir.',
  },
};

String _nutritionGoalText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return (_nutritionGoalCopy[code] ?? _nutritionGoalCopy['en']!)[key] ??
      _diaryText(context, key);
}

const _nutritionGoalCopy = <String, Map<String, String>>{
  'en': {},
  'ar': {
    'Set calories and percentages totaling 100% to calculate grams.':
        'حدّد السعرات والنسب بحيث يكون مجموعها 100٪ لحساب الغرامات.',
    'Daily macro goals in grams': 'أهداف المغذيات الكبرى اليومية بالجرام',
    'Calorie and macro goals': 'أهداف السعرات والعناصر الكبرى',
    'Default goal': 'الهدف الافتراضي',
    'Additional nutrient goals': 'أهداف المغذيات الإضافية',
    'Calories': 'السعرات',
    'Carbohydrates': 'الكربوهيدرات',
    'Protein': 'البروتين',
    'Fat': 'الدهون',
    'Saturated fat': 'الدهون المشبعة',
    'Polyunsaturated fat': 'الدهون المتعددة غير المشبعة',
    'Monounsaturated fat': 'الدهون الأحادية غير المشبعة',
    'Trans fat': 'الدهون المتحولة',
    'Cholesterol': 'الكوليسترول',
    'Sodium': 'الصوديوم',
    'Potassium': 'البوتاسيوم',
    'Fiber': 'الألياف',
    'Sugar': 'السكر',
    'Vitamin A': 'فيتامين أ',
    'Vitamin C': 'فيتامين ج',
    'Calcium': 'الكالسيوم',
    'Iron': 'الحديد',
    'Cancel': 'إلغاء',
    'Save': 'حفظ',
  },
  'fr': {
    'Daily macro goals in grams': 'Objectifs quotidiens de macros en grammes',
    'Calorie and macro goals': 'Objectifs calories et macronutriments',
    'Default goal': 'Objectif par défaut',
    'Additional nutrient goals': 'Objectifs nutritionnels supplémentaires',
    'Calories': 'Calories',
    'Carbohydrates': 'Glucides',
    'Protein': 'Protéines',
    'Fat': 'Lipides',
    'Saturated fat': 'Graisses saturées',
    'Polyunsaturated fat': 'Graisses polyinsaturées',
    'Monounsaturated fat': 'Graisses monoinsaturées',
    'Trans fat': 'Graisses trans',
    'Cholesterol': 'Cholestérol',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Fiber': 'Fibres',
    'Sugar': 'Sucres',
    'Vitamin A': 'Vitamine A',
    'Vitamin C': 'Vitamine C',
    'Calcium': 'Calcium',
    'Iron': 'Fer',
    'Cancel': 'Annuler',
    'Save': 'Enregistrer',
  },
  'es': {
    'Daily macro goals in grams': 'Objetivos diarios de macros en gramos',
    'Calorie and macro goals': 'Objetivos de calorías y macronutrientes',
    'Default goal': 'Objetivo predeterminado',
    'Additional nutrient goals': 'Objetivos de nutrientes adicionales',
    'Calories': 'Calorías',
    'Carbohydrates': 'Carbohidratos',
    'Protein': 'Proteína',
    'Fat': 'Grasas',
    'Saturated fat': 'Grasas saturadas',
    'Polyunsaturated fat': 'Grasas poliinsaturadas',
    'Monounsaturated fat': 'Grasas monoinsaturadas',
    'Trans fat': 'Grasas trans',
    'Cholesterol': 'Colesterol',
    'Sodium': 'Sodio',
    'Potassium': 'Potasio',
    'Fiber': 'Fibra',
    'Sugar': 'Azúcar',
    'Vitamin A': 'Vitamina A',
    'Vitamin C': 'Vitamina C',
    'Calcium': 'Calcio',
    'Iron': 'Hierro',
    'Cancel': 'Cancelar',
    'Save': 'Guardar',
  },
  'tr': {
    'Daily macro goals in grams': 'Gram cinsinden günlük makro hedefleri',
    'Calorie and macro goals': 'Kalori ve makro hedefleri',
    'Default goal': 'Varsayılan hedef',
    'Additional nutrient goals': 'Ek besin hedefleri',
    'Calories': 'Kalori',
    'Carbohydrates': 'Karbonhidrat',
    'Protein': 'Protein',
    'Fat': 'Yağ',
    'Saturated fat': 'Doymuş yağ',
    'Polyunsaturated fat': 'Çoklu doymamış yağ',
    'Monounsaturated fat': 'Tekli doymamış yağ',
    'Trans fat': 'Trans yağ',
    'Cholesterol': 'Kolesterol',
    'Sodium': 'Sodyum',
    'Potassium': 'Potasyum',
    'Fiber': 'Lif',
    'Sugar': 'Şeker',
    'Vitamin A': 'A vitamini',
    'Vitamin C': 'C vitamini',
    'Calcium': 'Kalsiyum',
    'Iron': 'Demir',
    'Cancel': 'İptal',
    'Save': 'Kaydet',
  },
};

const _diaryCopy = <String, Map<String, String>>{
  'en': {
    'my_foods': 'My foods',
    'meals': 'Meals',
    'recipes': 'Recipes',
    'private': 'Private',
    'public': 'Public',
    'friends': 'Friends only',
    'locked': 'Locked with a key',
    'Diary sharing is not available yet. Your diary remains private.':
        'Diary sharing is not available yet. Your diary remains private.',
    'Customize the four supported meal names. Empty slots are hidden from the diary.':
        'Customize the four supported meal names. Empty slots are hidden from the diary.',
  },
  'ar': {
    'Unit preferences': 'تفضيلات الوحدات',
    'Weight': 'الوزن',
    'Pounds': 'أرطال',
    'Kilograms': 'كيلوغرامات',
    'Stone': 'ستون',
    'Height': 'الطول',
    'Feet/Inches': 'قدم/بوصة',
    'Centimeters': 'سنتيمترات',
    'Distance': 'المسافة',
    'Miles': 'أميال',
    'Kilometers': 'كيلومترات',
    'Energy': 'الطاقة',
    'Calories': 'سعرات حرارية',
    'Kilojoules': 'كيلوجول',
    'Water': 'الماء',
    'Cups': 'أكواب',
    'Milliliters': 'ملليلترات',
    'Fluid ounces': 'أونصات سائلة',
    'App appearance': 'مظهر التطبيق',
    'Select theme': 'اختر المظهر',
    'System default': 'إعداد النظام',
    'Light theme': 'المظهر الفاتح',
    'Dark theme': 'المظهر الداكن',
    'Diary settings': 'إعدادات اليوميات',
    'Show carbs, protein and fat by meal':
        'عرض الكربوهيدرات والبروتين والدهون لكل وجبة',
    'View carbs, protein and fat by gram or percent.':
        'اعرض العناصر الكبرى بالغرام أو بالنسبة المئوية.',
    'Show all meals in diary tabs': 'عرض جميع الوجبات في تبويبات اليوميات',
    'Use multi-add by default': 'استخدام الإضافة المتعددة افتراضيًا',
    'Show diary food insights': 'عرض رؤى الطعام في اليوميات',
    'Always show water in diary': 'إظهار الماء دائمًا في اليوميات',
    'Default search tab': 'تبويب البحث الافتراضي',
    'Diary sharing': 'مشاركة اليوميات',
    'Customize meal names': 'تخصيص أسماء الوجبات',
    'Customize nutrient dashboard': 'تخصيص لوحة العناصر الغذائية',
    'Calories and macros': 'السعرات والعناصر الكبرى',
    'Heart healthy': 'صحي للقلب',
    'Low carb': 'منخفض الكربوهيدرات',
    'Custom': 'مخصص',
    'Track net carbs': 'تتبّع صافي الكربوهيدرات',
    'Show food timestamps': 'عرض توقيت الطعام',
    'Learn how when you eat impacts your energy, workouts and more.':
        'تعرّف على تأثير توقيت الطعام في طاقتك وتمارينك.',
    'all': 'الكل',
    'my_foods': 'أطعمتي',
    'meals': 'الوجبات',
    'recipes': 'الوصفات',
    'private': 'خاص',
    'public': 'عام',
    'friends': 'الأصدقاء فقط',
    'locked': 'مقفل بمفتاح',
    'sharing_warning':
        'قد تكشف مشاركة اليوميات وزنك وعاداتك الغذائية للأشخاص الذين تختارهم. اختر نطاقًا مناسبًا.',
    'Create access key': 'إنشاء مفتاح وصول',
    'Access key': 'مفتاح الوصول',
    'Key must contain at least 6 characters': 'يجب ألا يقل المفتاح عن 6 أحرف',
    'meal_names_hint': 'اكتب حتى ستة أسماء. تُخفى الخانات الفارغة من اليوميات.',
    'meal_names_hint_four':
        'خصّص أسماء الوجبات الأربع. تُخفى الخانات الفارغة من اليوميات.',
    'Meal': 'الوجبة',
    'Save': 'حفظ',
    'Saved': 'تم الحفظ',
    'Cancel': 'إلغاء',
    'Breakfast': 'الفطور',
    'Lunch': 'الغداء',
    'Dinner': 'العشاء',
    'Snack': 'الوجبات الخفيفة',
  },
  'fr': {
    'Unit preferences': 'Préférences d’unités',
    'Weight': 'Poids',
    'Pounds': 'Livres',
    'Kilograms': 'Kilogrammes',
    'Stone': 'Stones',
    'Height': 'Taille',
    'Feet/Inches': 'Pieds/pouces',
    'Centimeters': 'Centimètres',
    'Distance': 'Distance',
    'Miles': 'Miles',
    'Kilometers': 'Kilomètres',
    'Energy': 'Énergie',
    'Calories': 'Calories',
    'Kilojoules': 'Kilojoules',
    'Water': 'Eau',
    'Cups': 'Tasses',
    'Milliliters': 'Millilitres',
    'Fluid ounces': 'Onces liquides',
    'App appearance': "Apparence de l’application",
    'Select theme': 'Choisir le thème',
    'System default': 'Réglage du système',
    'Light theme': 'Thème clair',
    'Dark theme': 'Thème sombre',
    'Diary settings': 'Paramètres du journal',
    'Show carbs, protein and fat by meal':
        'Afficher glucides, protéines et lipides par repas',
    'View carbs, protein and fat by gram or percent.':
        'Afficher les macronutriments en grammes ou en pourcentage.',
    'Show all meals in diary tabs': 'Afficher tous les repas dans les onglets',
    'Use multi-add by default': "Utiliser l’ajout multiple par défaut",
    'Show diary food insights': 'Afficher les analyses alimentaires',
    'Always show water in diary': "Toujours afficher l’eau",
    'Default search tab': 'Onglet de recherche par défaut',
    'Diary sharing': 'Partage du journal',
    'Customize meal names': 'Personnaliser les noms des repas',
    'Customize nutrient dashboard': 'Personnaliser le tableau nutritionnel',
    'Calories and macros': 'Calories et macronutriments',
    'Heart healthy': 'Santé du cœur',
    'Low carb': 'Faible en glucides',
    'Custom': 'Personnalisé',
    'Track net carbs': 'Suivre les glucides nets',
    'Show food timestamps': 'Afficher les heures des aliments',
    'Learn how when you eat impacts your energy, workouts and more.':
        "Découvrez comment l’heure des repas influence votre énergie et vos entraînements.",
    'all': 'Tous',
    'my_foods': 'Mes aliments',
    'meals': 'Repas',
    'recipes': 'Recettes',
    'private': 'Privé',
    'public': 'Public',
    'friends': 'Amis uniquement',
    'locked': 'Verrouillé par une clé',
    'sharing_warning':
        'Le partage peut révéler votre poids et vos habitudes alimentaires aux personnes choisies.',
    'Create access key': 'Créer une clé d’accès',
    'Access key': 'Clé d’accès',
    'Key must contain at least 6 characters':
        'La clé doit contenir au moins 6 caractères',
    'meal_names_hint':
        'Saisissez jusqu’à six noms. Les champs vides sont masqués dans le journal.',
    'Meal': 'Repas',
    'Save': 'Enregistrer',
    'Saved': 'Enregistré',
    'Cancel': 'Annuler',
  },
  'es': {
    'Unit preferences': 'Preferencias de unidades',
    'Weight': 'Peso',
    'Pounds': 'Libras',
    'Kilograms': 'Kilogramos',
    'Stone': 'Stones',
    'Height': 'Altura',
    'Feet/Inches': 'Pies/pulgadas',
    'Centimeters': 'Centímetros',
    'Distance': 'Distancia',
    'Miles': 'Millas',
    'Kilometers': 'Kilómetros',
    'Energy': 'Energía',
    'Calories': 'Calorías',
    'Kilojoules': 'Kilojulios',
    'Water': 'Agua',
    'Cups': 'Tazas',
    'Milliliters': 'Mililitros',
    'Fluid ounces': 'Onzas líquidas',
    'App appearance': 'Apariencia de la aplicación',
    'Select theme': 'Elegir tema',
    'System default': 'Configuración del sistema',
    'Light theme': 'Tema claro',
    'Dark theme': 'Tema oscuro',
    'Diary settings': 'Ajustes del diario',
    'Show carbs, protein and fat by meal':
        'Mostrar carbohidratos, proteínas y grasas por comida',
    'View carbs, protein and fat by gram or percent.':
        'Ver macronutrientes en gramos o porcentaje.',
    'Show all meals in diary tabs': 'Mostrar todas las comidas en las pestañas',
    'Use multi-add by default': 'Usar adición múltiple por defecto',
    'Show diary food insights': 'Mostrar información alimentaria',
    'Always show water in diary': 'Mostrar siempre el agua',
    'Default search tab': 'Pestaña de búsqueda predeterminada',
    'Diary sharing': 'Compartir diario',
    'Customize meal names': 'Personalizar nombres de comidas',
    'Customize nutrient dashboard': 'Personalizar panel de nutrientes',
    'Calories and macros': 'Calorías y macronutrientes',
    'Heart healthy': 'Saludable para el corazón',
    'Low carb': 'Bajo en carbohidratos',
    'Custom': 'Personalizado',
    'Track net carbs': 'Registrar carbohidratos netos',
    'Show food timestamps': 'Mostrar horas de alimentos',
    'Learn how when you eat impacts your energy, workouts and more.':
        'Descubre cómo el horario influye en tu energía y entrenamientos.',
    'all': 'Todos',
    'my_foods': 'Mis alimentos',
    'meals': 'Comidas',
    'recipes': 'Recetas',
    'private': 'Privado',
    'public': 'Público',
    'friends': 'Solo amigos',
    'locked': 'Bloqueado con clave',
    'sharing_warning':
        'Compartir puede mostrar tu peso y hábitos alimentarios a las personas elegidas.',
    'Create access key': 'Crear clave de acceso',
    'Access key': 'Clave de acceso',
    'Key must contain at least 6 characters':
        'La clave debe tener al menos 6 caracteres',
    'meal_names_hint':
        'Escribe hasta seis nombres. Los campos vacíos se ocultan en el diario.',
    'Meal': 'Comida',
    'Save': 'Guardar',
    'Saved': 'Guardado',
    'Cancel': 'Cancelar',
  },
  'tr': {
    'Unit preferences': 'Birim tercihleri',
    'Weight': 'Ağırlık',
    'Pounds': 'Pound',
    'Kilograms': 'Kilogram',
    'Stone': 'Stone',
    'Height': 'Boy',
    'Feet/Inches': 'Fit/inç',
    'Centimeters': 'Santimetre',
    'Distance': 'Mesafe',
    'Miles': 'Mil',
    'Kilometers': 'Kilometre',
    'Energy': 'Enerji',
    'Calories': 'Kalori',
    'Kilojoules': 'Kilojul',
    'Water': 'Su',
    'Cups': 'Bardak',
    'Milliliters': 'Mililitre',
    'Fluid ounces': 'Sıvı ons',
    'App appearance': 'Uygulama görünümü',
    'Select theme': 'Tema seçin',
    'System default': 'Sistem ayarı',
    'Light theme': 'Açık tema',
    'Dark theme': 'Koyu tema',
    'Diary settings': 'Günlük ayarları',
    'Show carbs, protein and fat by meal':
        'Öğün başına karbonhidrat, protein ve yağ göster',
    'View carbs, protein and fat by gram or percent.':
        'Makroları gram veya yüzde olarak görüntüleyin.',
    'Show all meals in diary tabs': 'Tüm öğünleri günlük sekmelerinde göster',
    'Use multi-add by default': 'Çoklu eklemeyi varsayılan kullan',
    'Show diary food insights': 'Günlük beslenme analizlerini göster',
    'Always show water in diary': 'Günlükte suyu her zaman göster',
    'Default search tab': 'Varsayılan arama sekmesi',
    'Diary sharing': 'Günlük paylaşımı',
    'Customize meal names': 'Öğün adlarını özelleştir',
    'Customize nutrient dashboard': 'Besin panelini özelleştir',
    'Calories and macros': 'Kalori ve makrolar',
    'Heart healthy': 'Kalp dostu',
    'Low carb': 'Düşük karbonhidrat',
    'Custom': 'Özel',
    'Track net carbs': 'Net karbonhidratı izle',
    'Show food timestamps': 'Yiyecek saatlerini göster',
    'Learn how when you eat impacts your energy, workouts and more.':
        'Yemek saatlerinin enerji ve egzersize etkisini öğrenin.',
    'all': 'Tümü',
    'my_foods': 'Yiyeceklerim',
    'meals': 'Öğünler',
    'recipes': 'Tarifler',
    'private': 'Özel',
    'public': 'Herkese açık',
    'friends': 'Yalnızca arkadaşlar',
    'locked': 'Anahtarla kilitli',
    'sharing_warning':
        'Günlüğü paylaşmak kilonuzu ve yeme alışkanlıklarınızı seçtiğiniz kişilere gösterebilir.',
    'Create access key': 'Erişim anahtarı oluştur',
    'Access key': 'Erişim anahtarı',
    'Key must contain at least 6 characters':
        'Anahtar en az 6 karakter olmalıdır',
    'meal_names_hint': 'En fazla altı ad yazın. Boş alanlar günlükte gizlenir.',
    'Meal': 'Öğün',
    'Save': 'Kaydet',
    'Saved': 'Kaydedildi',
    'Cancel': 'İptal',
  },
};
