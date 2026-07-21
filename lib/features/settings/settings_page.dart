import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/services/app_settings_provider.dart';
import '../../app/services/data_export_service.dart';
import '../../app/services/local_data_lifecycle_service.dart';
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
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.strings.text('Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final database = ref.read(databaseProvider);
      final displayUnits =
          await ref.read(preferencesRepositoryProvider).get('units') ??
          'metric';
      final document = await LocalDataLifecycleService(
        database,
      ).exportJson(displayUnits: displayUnits);
      await const DataExportService().copyText(document);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Local data export copied to the clipboard.'),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      final arabic = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            arabic
                ? 'تعذر إنشاء التصدير المحلي. لم يتم حذف أو رفع أي بيانات.'
                : 'The local export could not be created. No data was deleted or uploaded.',
          ),
        ),
      );
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Reset all local data?')),
        content: Text(
          context.strings.text(
            'This permanently removes your profile, goals, logs, meals, custom foods, and settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.strings.text('Reset')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    BuildContext? progressDialogContext;
    final progressDialogReady = Completer<void>();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          progressDialogContext = dialogContext;
          if (!progressDialogReady.isCompleted) {
            progressDialogReady.complete();
          }

          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      context.strings.text(
                        'Deleting local data. Please wait...',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await progressDialogReady.future;

    try {
      final database = ref.read(databaseProvider);
      await LocalDataLifecycleService(database).clearAll();
      await SeedData.seedStarterCatalog(ref.read(foodRepositoryProvider));

      ref.invalidate(userProfileProvider);
      ref.invalidate(measurementSystemProvider);
      ref.invalidate(appSettingsProvider);
      ref.invalidate(foodRepositoryProvider);

      final dialogContext = progressDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }

      if (!context.mounted) return;

      await Future<void>.delayed(Duration.zero);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/onboarding');
        }
      });
    } catch (_) {
      final dialogContext = progressDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'Your data was not reset or uploaded. Try opening it again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.strings.text;
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
            title: Text(t('High contrast')),
            subtitle: Text(
              t('Increase separation between text, controls, and surfaces.'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.motion_photos_off_outlined),
            value: settings.reduceMotion,
            onChanged: (value) =>
                ref.read(appSettingsProvider.notifier).setReduceMotion(value),
            title: Text(t('Reduce motion')),
            subtitle: Text(t('Minimize nonessential interface animation.')),
          ),
          const Divider(height: 32),
          const _RegionTimezoneTile(),
          const SizedBox(height: 8),
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
            title: Text(t('Targets and plan')),
            subtitle: Text(
              t('Compare recommendations, assumptions, and your overrides.'),
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
            title: Text(t('Decision Memory')),
            subtitle: Text(
              t('Review, rate, disable, or delete remembered actions.'),
            ),
            onTap: () => context.go('/decision-memory'),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(t('Life context')),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'اختر لكل سجل ما إذا كان يمكن استخدامه في الاستنتاجات المحلية، أو احذفه.'
                  : 'Choose per record whether it may inform local insights, or delete it.',
            ),
            onTap: () => context.go('/context'),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(t('Personal experiments')),
            subtitle: Text(
              t('Test a cautious hypothesis and record limitations.'),
            ),
            onTap: () => context.go('/experiments'),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: Text(context.strings.text('Share Studio')),
            subtitle: Text(
              context.strings.text(
                'Create a privacy-safe progress image. Weight stays hidden.',
              ),
            ),
            onTap: () => context.go('/share-studio'),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(context.strings.text('Challenges')),
            subtitle: Text(
              context.strings.text(
                'Behavior-first private challenges with evidence-based progress.',
              ),
            ),
            onTap: () => context.go('/challenges'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(context.strings.text('Privacy')),
            subtitle: Text(t('Your data remains on this device.')),
            onTap: () => _showInfo(
              context,
              t('Privacy'),
              t(
                'BIL stores profile, weight, meals, foods, water, and preferences locally in SQLite. No data is uploaded while cloud services are disabled.',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: Text(context.strings.text('Health disclaimer')),
            onTap: () => _showInfo(
              context,
              t('Health disclaimer'),
              t(
                'BIL provides general tracking information and cautious hypotheses. It does not diagnose, treat, or replace advice from a qualified healthcare professional.',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all),
            title: Text(context.strings.text('Export local data')),
            subtitle: Text(t('Copy a JSON export to the clipboard.')),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(t('App version')),
            subtitle: const Text('1.0.0+1'),
          ),
          const Divider(height: 32),
          Text(
            t('Connected capabilities'),
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
                    ExternalCapability.account => t('Account'),
                    ExternalCapability.sync => context.strings.text(
                      'Cloud sync',
                    ),
                    ExternalCapability.ai => t('Ask BIL'),
                    ExternalCapability.commerce => t(
                      'Subscriptions and purchases',
                    ),
                    ExternalCapability.community => t('Community'),
                    ExternalCapability.coach => t('Coach platform'),
                    ExternalCapability.updates => t('Remote update channel'),
                  }),
                  subtitle: Text(t(status.reason)),
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

class _RegionTimezoneTile extends ConsumerStatefulWidget {
  const _RegionTimezoneTile();

  @override
  ConsumerState<_RegionTimezoneTile> createState() =>
      _RegionTimezoneTileState();
}

class _RegionTimezoneTileState extends ConsumerState<_RegionTimezoneTile> {
  String? region;
  String? timezone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(preferencesRepositoryProvider);
    final values = await Future.wait([
      repository.get('countryRegion'),
      repository.get('timezoneName'),
    ]);
    if (mounted) {
      setState(() {
        region = values[0];
        timezone = values[1];
      });
    }
  }

  Future<void> _edit() async {
    final regionController = TextEditingController(text: region ?? '');
    final timezoneController = TextEditingController(
      text: timezone ?? DateTime.now().timeZoneName,
    );
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          arabic ? 'المنطقة والمنطقة الزمنية' : 'Region and timezone',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: regionController,
              autofillHints: const [AutofillHints.countryName],
              decoration: InputDecoration(
                labelText: arabic ? 'الدولة أو المنطقة' : 'Country or region',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timezoneController,
              decoration: InputDecoration(
                labelText: arabic ? 'المنطقة الزمنية' : 'Timezone',
                helperText: arabic
                    ? 'تُستخدم للعرض المحلي فقط ولا تغيّر السجلات السابقة.'
                    : 'Used for local display only; existing records are unchanged.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(arabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              regionController.text.trim(),
              timezoneController.text.trim(),
            )),
            child: Text(arabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    regionController.dispose();
    timezoneController.dispose();
    if (result == null) return;
    final repository = ref.read(preferencesRepositoryProvider);
    if (result.$1.isEmpty) {
      await repository.remove('countryRegion');
    } else {
      await repository.set('countryRegion', result.$1);
    }
    if (result.$2.isEmpty) {
      await repository.remove('timezoneName');
    } else {
      await repository.set('timezoneName', result.$2);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public),
      title: Text(arabic ? 'المنطقة والمنطقة الزمنية' : 'Region and timezone'),
      subtitle: Text(
        [
              if (region?.isNotEmpty == true) region!,
              if (timezone?.isNotEmpty == true) timezone!,
            ].isEmpty
            ? (arabic
                  ? 'غير محدد — يُستخدم إعداد الجهاز'
                  : 'Not set — device defaults are used')
            : [
                if (region?.isNotEmpty == true) region!,
                if (timezone?.isNotEmpty == true) timezone!,
              ].join(' · '),
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: _edit,
    );
  }
}
