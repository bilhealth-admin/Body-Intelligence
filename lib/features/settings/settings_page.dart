import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/services/app_settings_provider.dart';
import '../../app/services/data_export_service.dart';
import '../../app/services/external_capabilities.dart';
import '../../core/units/measurement_units.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/seed_data.dart';
import '../foods/providers/food_provider.dart';
import '../profile/providers/user_profile_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _showInfo(BuildContext context, String title, String body) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final database = ref.read(databaseProvider);
    final profile = await database
        .select(database.userProfile)
        .getSingleOrNull();
    final weights = await database.select(database.weightEntries).get();
    final meals = await database.select(database.meals).get();
    final mealItems = await database.select(database.mealItems).get();
    final water = await database.select(database.waterEntries).get();
    final foods = await database.select(database.foods).get();
    final goals = await database.select(database.goals).get();
    final dailyLogs = await database.select(database.dailyLogs).get();
    final contexts = await database.select(database.lifeContextEntries).get();
    final memories = await database.select(database.decisionMemories).get();
    final preferences = await database.select(database.preferences).get();
    final document = const JsonEncoder.withIndent('  ').convert({
      'format': 'BIL local export v2',
      'exportedAt': DateTime.now().toIso8601String(),
      'canonicalUnits': {
        'weight': 'kg',
        'height': 'cm',
        'water': 'ml',
        'nutrientMass': 'g or mg as identified by field',
      },
      'selectedDisplayUnits':
          await ref.read(preferencesRepositoryProvider).get('units') ??
          'metric',
      'profile': profile?.toJson(),
      'goals': goals.map((row) => row.toJson()).toList(),
      'weights': weights.map((row) => row.toJson()).toList(),
      'dailyLogs': dailyLogs.map((row) => row.toJson()).toList(),
      'foods': foods.map((row) => row.toJson()).toList(),
      'meals': meals.map((row) => row.toJson()).toList(),
      'mealItems': mealItems.map((row) => row.toJson()).toList(),
      'waterEntries': water.map((row) => row.toJson()).toList(),
      'lifeContext': contexts.map((row) => row.toJson()).toList(),
      'decisionMemory': memories.map((row) => row.toJson()).toList(),
      'preferences': preferences.map((row) => row.toJson()).toList(),
    });
    await const DataExportService().copyText(document);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local data export copied to the clipboard.'),
        ),
      );
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset all local data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This permanently removes your profile, goals, logs, meals, custom foods, and settings. Type RESET to continue.',
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'RESET'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text == 'RESET'),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return;
    final database = ref.read(databaseProvider);
    await database.transaction(() async {
      await database.delete(database.decisionMemories).go();
      await database.delete(database.lifeContextEntries).go();
      await database.delete(database.mealItems).go();
      await database.delete(database.meals).go();
      await database.delete(database.favorites).go();
      await database.delete(database.recentFoods).go();
      await database.delete(database.waterEntries).go();
      await database.delete(database.goals).go();
      await database.delete(database.planSettings).go();
      await database.delete(database.weightEntries).go();
      await database.delete(database.dailyLogs).go();
      await database.delete(database.userProfile).go();
      await database.delete(database.foods).go();
      await database.delete(database.preferences).go();
    });
    await SeedData.seedStarterCatalog(ref.read(foodRepositoryProvider));
    if (context.mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final measurementSystem =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: settings.localeCode,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.language),
              labelText: context.strings.text('Language'),
            ),
            items: const [
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (value) =>
                ref.read(appSettingsProvider.notifier).setLocale(value ?? 'en'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: settings.themeMode,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.dark_mode),
              labelText: context.strings.text('Appearance'),
            ),
            items: [
              DropdownMenuItem(
                value: 'system',
                child: Text(context.strings.text('System')),
              ),
              DropdownMenuItem(
                value: 'light',
                child: Text(context.strings.text('Light')),
              ),
              DropdownMenuItem(
                value: 'dark',
                child: Text(context.strings.text('Dark')),
              ),
            ],
            onChanged: (value) => ref
                .read(appSettingsProvider.notifier)
                .setThemeMode(value ?? 'system'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.contrast),
            value: settings.highContrast,
            onChanged: (value) =>
                ref.read(appSettingsProvider.notifier).setHighContrast(value),
            title: const Text('High contrast'),
            subtitle: const Text(
              'Increase separation between text, controls, and surfaces.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.motion_photos_off_outlined),
            value: settings.reduceMotion,
            onChanged: (value) =>
                ref.read(appSettingsProvider.notifier).setReduceMotion(value),
            title: const Text('Reduce motion'),
            subtitle: const Text('Minimize nonessential interface animation.'),
          ),
          const Divider(height: 32),
          DropdownButtonFormField<String>(
            key: ValueKey(measurementSystem),
            initialValue: measurementSystem.name,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.straighten),
              labelText: context.strings.text('Units'),
            ),
            items: [
              DropdownMenuItem(
                value: 'metric',
                child: Text(context.strings.text('Metric (kg, cm)')),
              ),
              DropdownMenuItem(
                value: 'imperial',
                child: Text(context.strings.text('Imperial (lb, in)')),
              ),
            ],
            onChanged: (value) => ref
                .read(preferencesRepositoryProvider)
                .set('units', value ?? 'metric'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(context.strings.text('Profile and goals')),
            onTap: () => context.go('/onboarding'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Targets and plan'),
            subtitle: const Text(
              'Compare recommendations, assumptions, and your overrides.',
            ),
            onTap: () => context.go('/plan'),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: Text(context.strings.text('Analytics')),
            onTap: () => context.go('/analytics'),
          ),
          ListTile(
            leading: const Icon(Icons.psychology_alt_outlined),
            title: const Text('Decision Memory'),
            subtitle: const Text(
              'Review, rate, disable, or delete remembered actions.',
            ),
            onTap: () => context.go('/decision-memory'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(context.strings.text('Privacy')),
            subtitle: const Text('Your MVP data remains on this device.'),
            onTap: () => _showInfo(
              context,
              'Privacy',
              'BIL stores profile, weight, meals, foods, water, and preferences locally in SQLite. No data is uploaded while cloud services are disabled.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: Text(context.strings.text('Health disclaimer')),
            onTap: () => _showInfo(
              context,
              'Health disclaimer',
              'BIL provides general tracking information and cautious hypotheses. It does not diagnose, treat, or replace advice from a qualified healthcare professional.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all),
            title: Text(context.strings.text('Export local data')),
            subtitle: const Text('Copy a JSON export to the clipboard.'),
            onTap: () => _export(context, ref),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('App version'),
            subtitle: Text('1.0.0+1'),
          ),
          const Divider(height: 32),
          Text(
            'Connected capabilities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          for (final capability in ExternalCapability.values)
            Builder(
              builder: (context) {
                final status = ExternalCapabilities.status(capability);
                return ListTile(
                  enabled: status.available,
                  leading: Icon(switch (capability) {
                    ExternalCapability.account => Icons.account_circle_outlined,
                    ExternalCapability.sync => Icons.cloud_sync_outlined,
                    ExternalCapability.ai => Icons.auto_awesome_outlined,
                    ExternalCapability.commerce =>
                      Icons.workspace_premium_outlined,
                    ExternalCapability.community => Icons.groups_outlined,
                    ExternalCapability.coach => Icons.support_agent_outlined,
                    ExternalCapability.updates => Icons.system_update_outlined,
                  }),
                  title: Text(switch (capability) {
                    ExternalCapability.account => 'Account',
                    ExternalCapability.sync => context.strings.text(
                      'Cloud sync',
                    ),
                    ExternalCapability.ai => 'Ask BIL',
                    ExternalCapability.commerce =>
                      'Subscriptions and purchases',
                    ExternalCapability.community => 'Community',
                    ExternalCapability.coach => 'Coach platform',
                    ExternalCapability.updates => 'Remote update channel',
                  }),
                  subtitle: Text(status.reason),
                  trailing: Icon(
                    status.available
                        ? Icons.check_circle_outline
                        : Icons.lock_outline,
                  ),
                );
              },
            ),
          const Divider(height: 32),
          ListTile(
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            leading: const Icon(Icons.delete_forever),
            title: Text(context.strings.text('Reset local data')),
            onTap: () => _reset(context, ref),
          ),
        ],
      ),
    );
  }
}
