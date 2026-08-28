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

part 'reference_preferences_controls.dart';
part 'reference_preferences_numeric.dart';
part 'reference_preferences_macros.dart';

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
