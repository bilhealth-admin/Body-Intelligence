import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../ads/presentation/safe_free_ad_anchor.dart';
import '../cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/presentation/premium_crown_emblem.dart';
import '../commerce/providers/commerce_providers.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../../shared/widgets/bil_account_avatar.dart';
import 'reference_settings_copy.dart';
import 'cloud_sync_status_presentation.dart';

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
    final latestWeight = ref.watch(latestWeightProvider).value?.weight;
    final displayName = ref.watch(displayNameProvider).value;
    final photo = ref.watch(profilePhotoProvider).value;
    final photoUrl = ref.watch(profilePhotoPublicUrlProvider).value;
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    final cloudSyncStatus = ref.watch(cloudManualSyncStatusProvider);
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : copy('BIL member');
    final profileWeight = profile?.currentWeight;
    final current = latestWeight ?? profileWeight;
    final target = profile?.targetWeight;
    final remaining = _remainingToGoal(
      current: current,
      target: target,
      profileBaseline: profileWeight,
    );

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(copy('More'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: _ProfileSummary(
              name: name,
              photo: photo,
              photoUrl: photoUrl,
              currentWeight: current?.toStringAsFixed(1) ?? '--',
              goalWeight: target?.toStringAsFixed(1) ?? '--',
              lostWeight: remaining,
              copy: copy,
              onTap: () => context.push('/profile-summary'),
            ),
          ),
          const SizedBox(height: 12),
          subscription.when(
            loading: () =>
                _PremiumMembershipCard(label: copy('Checking subscription')),
            error: (_, _) => _PremiumMembershipCard(
              label: copy('Retry subscription check'),
              onTap: () => ref.invalidate(verifiedSubscriptionStateProvider),
            ),
            data: (value) => _PremiumMembershipCard(
              label: value.plan == CommercePlan.free
                  ? copy('Start 7-day free trial')
                  : copy('Premium'),
              onTap: () => context.push('/plans'),
            ),
          ),
          const SizedBox(height: 20),
          _MoreSection(
            title: copy('Account & profile'),
            icon: Icons.person_outline_rounded,
            children: [
              _MoreRow(copy('My Profile'), '/profile-summary'),
              _MoreRow(
                copy('Language'),
                '/settings/language',
                key: const Key('more-language-entry'),
              ),
              _MoreRow(
                copy('Location & local time'),
                '/location-settings',
                key: const Key('more-location-settings-entry'),
                showDivider: false,
              ),
            ],
          ),
          _MoreSection(
            title: copy('Diary & goals'),
            icon: Icons.track_changes_rounded,
            children: [
              _MoreRow(copy('Goals'), '/goals'),
              _MoreRow(copy('Progress'), '/history'),
              _MoreRow(
                copy('Weekly Report'),
                '/weekly-report',
                key: const Key('settings-weekly-report-entry'),
              ),
              _MoreRow(copy('Challenges'), '/challenges'),
              _MoreRow(copy('Nutrition'), '/analytics/nutrition'),
              _MoreRow(
                copy('My Meals, Recipes & Foods'),
                '/nutrition?from=settings',
                showDivider: false,
              ),
            ],
          ),
          _MoreSection(
            title: copy('Health preferences'),
            icon: Icons.favorite_outline_rounded,
            children: [
              _MoreRow(
                copy('AI Coach'),
                '/intelligence-center',
                key: const Key('more-ai-coach-entry'),
              ),
              _MoreRow(copy('AI Coach settings'), '/settings/ai-coach'),
              _MoreRow(copy('Intermittent Fasting'), '/wellness/fasting'),
              _MoreRow(copy('Sleep'), '/wellness/sleep'),
              _MoreRow(copy('Recipe Discovery'), '/wellness/recipes'),
              _MoreRow(copy('Workout Routines'), '/wellness/workouts/routines'),
              _MoreRow(
                copy('Apps & Devices'),
                '/connected-health',
                key: const Key('settings-connected-health-entry'),
              ),
              _MoreRow(copy('Steps'), '/connected-health/steps'),
              _MoreRow(copy('Learn'), '/wellness/learn', showDivider: false),
            ],
          ),
          const SafeFreeAdAnchor(
            key: Key('more-free-ad-slot'),
            surface: SafeFreeAdSurface.more,
          ),
          if (AppEnvironment.communityConfigured) ...[
            _MoreSection(
              title: copy('Community'),
              icon: Icons.people_outline_rounded,
              children: [
                _MoreRow(copy('Community'), '/community'),
                _MoreRow(copy('Friends'), '/community/people'),
                _MoreRow(
                  copy('Messages'),
                  '/community/messages',
                  showDivider: false,
                ),
              ],
            ),
          ],
          _MoreSection(
            title: copy('Privacy & notifications'),
            icon: Icons.shield_outlined,
            children: [
              _MoreRow(copy('Settings'), '/settings/preferences'),
              _MoreRow(
                copy('Reminders'),
                '/notification-settings',
                key: const Key('settings-notifications-entry'),
              ),
              _MoreActionRow(
                key: const Key('settings-review-onboarding'),
                label: copy('Review initial setup'),
                description: copy(
                  'Reopen onboarding without deleting your profile or records.',
                ),
                icon: Icons.tune_rounded,
                onTap: () => _reviewSetupAgain(context, ref),
              ),
              _MoreRow(copy('Privacy'), '/settings/sharing-privacy'),
              _MoreRow(
                copy('Advertising privacy'),
                '/advertising-privacy',
                key: const Key('settings-advertising-privacy-entry'),
                showDivider: false,
              ),
            ],
          ),
          _MoreSection(
            title: copy('Help'),
            icon: Icons.support_agent_rounded,
            children: [
              _MoreRow(copy('Help'), '/help'),
              _CloudSyncRow(label: copy('Sync'), status: cloudSyncStatus),
              _MoreRow(
                copy('Delete account'),
                '/help/delete-account',
                key: const Key('settings-delete-account-entry'),
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumMembershipCard extends StatelessWidget {
  const _PremiumMembershipCard({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF13243A), Color(0xFF07111D)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99F6D477)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const PremiumCrownEmblem(size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReferenceSettingsCopy.of(context)('BIL Premium'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFE59A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD8E1EA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap == null)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFD469),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFFFFE59A),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    ),
  );
}

String _remainingToGoal({
  required double? current,
  required double? target,
  required double? profileBaseline,
}) {
  if (current == null || target == null) return '--';
  final gaining = profileBaseline != null && target > profileBaseline;
  final remaining = gaining ? target - current : current - target;
  return remaining.clamp(0, double.infinity).toStringAsFixed(1);
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.name,
    required this.photo,
    required this.photoUrl,
    required this.currentWeight,
    required this.goalWeight,
    required this.lostWeight,
    required this.copy,
    required this.onTap,
  });

  final String name;
  final Uint8List? photo;
  final String? photoUrl;
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
                BilAccountAvatar(
                  radius: 34,
                  photoBytes: photo,
                  networkUrl: photoUrl,
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
  const _MoreRow(this.label, this.route, {super.key, this.showDivider = true});
  final String label;
  final String route;
  final bool showDivider;

  bool get _isDanger => route == '/help/delete-account';
  bool get _isFeatured => route == '/intelligence-center';

  IconData get _icon => switch (Uri.parse(route).path) {
    '/profile-summary' => Icons.person_outline_rounded,
    '/settings/language' => Icons.language_rounded,
    '/location-settings' => Icons.schedule_rounded,
    '/wellness/fasting' => Icons.hourglass_bottom_rounded,
    '/wellness/sleep' => Icons.bedtime_outlined,
    '/wellness/recipes' => Icons.restaurant_menu_rounded,
    '/wellness/workouts/routines' => Icons.fitness_center_rounded,
    '/goals' => Icons.flag_outlined,
    '/history' => Icons.monitor_weight_outlined,
    '/weekly-report' => Icons.assessment_outlined,
    '/challenges' => Icons.emoji_events_outlined,
    '/intelligence-center' => Icons.auto_awesome_rounded,
    '/settings/ai-coach' => Icons.tune_rounded,
    '/analytics/nutrition' => Icons.pie_chart_outline_rounded,
    '/nutrition' => Icons.menu_book_outlined,
    '/notification-settings' => Icons.notifications_none_rounded,
    '/connected-health' => Icons.watch_outlined,
    '/connected-health/steps' => Icons.directions_walk_rounded,
    '/wellness/learn' => Icons.school_outlined,
    '/community' => Icons.people_outline_rounded,
    '/community/people' => Icons.person_add_alt_rounded,
    '/community/messages' => Icons.chat_bubble_outline_rounded,
    '/settings/preferences' => Icons.settings_outlined,
    '/settings/sharing-privacy' => Icons.lock_outline_rounded,
    '/help/delete-account' => Icons.delete_outline_rounded,
    '/advertising-privacy' => Icons.ads_click_outlined,
    '/help' => Icons.help_outline_rounded,
    _ => Icons.arrow_forward_rounded,
  };

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 60,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(
          _icon,
          color: _isDanger
              ? Theme.of(context).colorScheme.error
              : _isFeatured
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: _isDanger ? Theme.of(context).colorScheme.error : null,
            fontWeight: _isFeatured ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB7B9BD),
        ),
        onTap: () => context.push(route),
      ),
      if (showDivider) const Divider(height: 1, indent: 54),
    ],
  );
}

class _CloudSyncRow extends StatelessWidget {
  const _CloudSyncRow({required this.label, required this.status});

  final String label;
  final CloudManualSyncStatus status;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        key: const Key('settings-cloud-sync-status-row'),
        minTileHeight: 70,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: status.isSyncing
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_sync_outlined),
        title: Text(label),
        subtitle: CloudSyncStatusLine(status: status),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB7B9BD),
        ),
        onTap: () => context.push('/settings/sharing-privacy'),
      ),
      const Divider(height: 1, indent: 54),
    ],
  );
}

class _MoreActionRow extends StatelessWidget {
  const _MoreActionRow({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 68,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(description),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB7B9BD),
        ),
        onTap: onTap,
      ),
      const Divider(height: 1, indent: 22),
    ],
  );
}
