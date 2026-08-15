import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/services/app_settings_provider.dart';
import '../../app/services/data_export_service.dart';
import '../../app/services/local_data_lifecycle_service.dart';
import '../../app/services/local_recovery_service.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/seed_data.dart';
import '../foods/providers/food_provider.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/providers/commerce_providers.dart';
import '../profile/providers/user_profile_provider.dart';
import 'reference_settings_copy.dart';

part 'settings_page_actions.dart';

/// The bottom-navigation "More" destination. Its hierarchy intentionally
/// mirrors the supplied reference: account summary first, product destinations
/// second, and Settings/Privacy/Help/Sync at the end.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ReferenceSettingsCopy.of(context);
    final profile = ref.watch(userProfileProvider).value;
    final displayName = ref.watch(displayNameProvider).value;
    final photo = ref.watch(profilePhotoProvider).value;
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : copy('BIL member');
    final current = profile?.currentWeight;
    final target = profile?.targetWeight;
    final remaining = current == null || target == null
        ? '--'
        : (target - current).abs().toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(copy('More'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          _ProfileSummary(
            name: name,
            photo: photo,
            currentWeight: current?.toStringAsFixed(1) ?? '--',
            goalWeight: target?.toStringAsFixed(1) ?? '--',
            lostWeight: remaining,
            copy: copy,
            onTap: () => context.push('/profile-summary'),
          ),
          const Divider(height: 1),
          subscription.when(
            loading: () =>
                _MoreStatusRow(context.strings.text('Checking subscription')),
            error: (_, _) => _MoreStatusRow(
              context.strings.text('Retry subscription check'),
              onTap: () => ref.invalidate(verifiedSubscriptionStateProvider),
            ),
            data: (value) => value.plan == CommercePlan.free
                ? _MoreRow(copy('Explore Premium'), '/plans', emphasized: true)
                : _MoreRow(copy('Premium'), '/plans', emphasized: true),
          ),
          _MoreRow(copy('My Profile'), '/profile-summary'),
          _MoreRow(
            context.strings.text('Language'),
            '/settings/language',
            key: const Key('more-language-entry'),
          ),
          _MoreRow(copy('Intermittent Fasting'), '/wellness/fasting'),
          _MoreRow(copy('Sleep'), '/wellness/sleep'),
          _MoreRow(copy('Recipe Discovery'), '/wellness/recipes'),
          _MoreRow(copy('Workout Routines'), '/wellness/workouts/routines'),
          _MoreRow(copy('Goals'), '/goals'),
          _MoreRow(copy('Progress'), '/history'),
          _MoreRow(
            copy('Weekly Report'),
            '/weekly-report',
            key: const Key('settings-weekly-report-entry'),
          ),
          _MoreRow(context.strings.text('Challenges'), '/challenges'),
          _MoreRow(
            'AI Coach',
            '/intelligence-center',
            key: const Key('more-ai-coach-entry'),
          ),
          _MoreRow('AI Coach settings', '/settings/ai-coach'),
          _MoreRow(copy('Nutrition'), '/analytics/nutrition'),
          _MoreRow(copy('My Meals, Recipes & Foods'), '/nutrition'),
          _MoreRow(
            copy('Reminders'),
            '/notification-settings',
            key: const Key('settings-notifications-entry'),
          ),
          _MoreRow(
            copy('Apps & Devices'),
            '/connected-health',
            key: const Key('settings-connected-health-entry'),
          ),
          _MoreRow(copy('Steps'), '/connected-health/steps'),
          _MoreRow(copy('Learn'), '/wellness/learn'),
          if (AppEnvironment.communityConfigured) ...[
            _MoreRow(copy('Community'), '/community'),
            _MoreRow(copy('Friends'), '/community/people'),
            _MoreRow(copy('Messages'), '/community/messages'),
          ],
          _MoreRow(copy('Settings'), '/settings/preferences'),
          _MoreRow(copy('Privacy'), '/settings/sharing-privacy'),
          _MoreRow(
            copy('Advertising privacy'),
            '/advertising-privacy',
            key: const Key('settings-advertising-privacy-entry'),
          ),
          _MoreRow(copy('Help'), '/help'),
          _MoreRow(copy('Sync'), '/connected-health', showDivider: false),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.name,
    required this.photo,
    required this.currentWeight,
    required this.goalWeight,
    required this.lostWeight,
    required this.copy,
    required this.onTap,
  });

  final String name;
  final Uint8List? photo;
  final String currentWeight;
  final String goalWeight;
  final String lostWeight;
  final String Function(String) copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  backgroundImage: photo == null ? null : MemoryImage(photo!),
                  child: photo == null
                      ? const Icon(Icons.person_rounded, size: 38)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy('View profile'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Metric(currentWeight, copy('Current'), copy('kg')),
                _Metric(lostWeight, copy('Remaining'), copy('kg')),
                _Metric(goalWeight, copy('Goal'), copy('kg')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.unit);
  final String value;
  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value $unit',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _MoreRow extends StatelessWidget {
  const _MoreRow(
    this.label,
    this.route, {
    super.key,
    this.emphasized = false,
    this.showDivider = true,
  });
  final String label;
  final String route;
  final bool emphasized;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 58,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            color: emphasized ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB7B9BD),
        ),
        onTap: () => context.push(route),
      ),
      if (showDivider) const Divider(height: 1, indent: 22),
    ],
  );
}

class _MoreStatusRow extends StatelessWidget {
  const _MoreStatusRow(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 58,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        leading: onTap == null
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        title: Text(label),
        onTap: onTap,
      ),
      const Divider(height: 1, indent: 22),
    ],
  );
}
