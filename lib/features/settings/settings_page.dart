import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../core/units/measurement_units.dart';
import '../ads/presentation/safe_free_ad_anchor.dart';
import '../admin/services/ai_coach_admin_service.dart';
import '../cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/presentation/premium_crown_emblem.dart';
import '../commerce/providers/commerce_providers.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../weight/domain/weight_goal_progress.dart';
import '../wellness/presentation/wellness_copy.dart';
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
    final current = ref.watch(effectiveCurrentWeightProvider);
    final activeGoal = ref.watch(activeGoalProvider).value;
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final displayName = ref.watch(displayNameProvider).value;
    final photo = ref.watch(profilePhotoProvider).value;
    final photoUrl = ref.watch(profilePhotoPublicUrlProvider).value;
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    final cloudSyncStatus = ref.watch(cloudManualSyncStatusProvider);
    final adminAccess = ref.watch(aiCoachAdminAccessProvider);
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : copy('BIL member');
    // The active goal row is the durable goal authority. Falling back to the
    // profile keeps legacy/onboarding profiles readable before a goal row has
    // been created. Watching both streams makes this card update immediately
    // after the Health Goal editor commits either source.
    final target = activeGoal?.targetWeight ?? profile?.targetWeight;
    final goalProgress = _goalProgress(
      current: current,
      target: target,
      profileBaseline: profile?.currentWeight,
      storedGoalType: activeGoal?.type,
      storedTarget: activeGoal?.targetWeight,
      system: system,
    );
    final unit = copy(UnitConverter.weightUnit(system));

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
              currentWeight: _displayWeight(current, system),
              goalWeight: _displayWeight(target, system),
              remainingWeight: goalProgress.value,
              remainingLabel: copy(
                goalProgress.reached ? 'Already at goal' : 'Remaining',
              ),
              unit: unit,
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
                  : copy('Active'),
              onTap: () => context.push('/plans'),
            ),
          ),
          const SizedBox(height: 20),
          _MoreSection(
            title: copy('Account & profile'),
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
              _MoreRow(
                wellnessWorkoutVideosAndRoutinesTitle(context),
                '/wellness/workouts/routines',
              ),
              _MoreRow(
                copy('Apps & Devices'),
                '/connected-health',
                key: const Key('settings-connected-health-entry'),
              ),
              _MoreRow(copy('Steps'), '/connected-health/steps'),
            ],
          ),
          const SafeFreeAdAnchor(
            key: Key('more-free-ad-slot'),
            surface: SafeFreeAdSurface.more,
          ),
          if (AppEnvironment.communityConfigured) ...[
            _MoreSection(
              title: copy('Community'),
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
                kind: BilSemanticIconKind.preferences,
                onTap: () => _reviewSetupAgain(context, ref),
              ),
              _MoreRow(copy('Sharing & Privacy'), '/settings/sharing-privacy'),
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
            children: [
              _MoreRow(copy('Help'), '/help'),
              _CloudSyncRow(label: copy('Sync now'), status: cloudSyncStatus),
            ],
          ),
          if (adminAccess.asData?.value == true)
            _MoreSection(
              title: copy('Administration'),
              children: [
                _MoreRow(
                  copy('BIL Administration'),
                  '/admin/ai-coach',
                  key: const Key('settings-ai-coach-admin-entry'),
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
  const _MoreSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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

({String value, bool reached}) _goalProgress({
  required double? current,
  required double? target,
  required double? profileBaseline,
  required String? storedGoalType,
  required double? storedTarget,
  required MeasurementSystem system,
}) {
  if (current == null || target == null) return (value: '--', reached: false);
  final progress = resolveWeightGoalProgress(
    currentWeightKg: current,
    targetWeightKg: target,
    profileBaselineWeightKg: profileBaseline,
    storedGoalType: storedGoalType,
    storedTargetWeightKg: storedTarget,
  );
  return (
    value: UnitConverter.weightFromKg(
      progress.remainingKg,
      system,
    ).toStringAsFixed(1),
    reached: progress.reached,
  );
}

String _displayWeight(double? kilograms, MeasurementSystem system) =>
    kilograms == null
    ? '--'
    : UnitConverter.weightFromKg(kilograms, system).toStringAsFixed(1);

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.name,
    required this.photo,
    required this.photoUrl,
    required this.currentWeight,
    required this.goalWeight,
    required this.remainingWeight,
    required this.remainingLabel,
    required this.unit,
    required this.copy,
    required this.onTap,
  });

  final String name;
  final Uint8List? photo;
  final String? photoUrl;
  final String currentWeight;
  final String goalWeight;
  final String remainingWeight;
  final String remainingLabel;
  final String unit;
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
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        semanticsLabel: name,
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
                _Metric(currentWeight, copy('Current'), unit),
                _Metric(remainingWeight, remainingLabel, unit),
                _Metric(goalWeight, copy('Goal'), unit),
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
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '$value $unit',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
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

  @override
  Widget build(BuildContext context) {
    final semanticKind = BilSemanticIcons.kindForRoute(route);
    return Column(
      children: [
        ListTile(
          minTileHeight: 60,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          horizontalTitleGap: 12,
          leading: _isDanger
              ? Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                )
              : semanticKind == null
              ? Icon(
                  Icons.arrow_forward_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : BilSemanticIconBadge(
                  key: Key('more-semantic-icon-${semanticKind.name}'),
                  kind: semanticKind,
                  size: 36,
                  iconSize: 20,
                  shape: BoxShape.rectangle,
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
}

class _CloudSyncRow extends ConsumerWidget {
  const _CloudSyncRow({required this.label, required this.status});

  final String label;
  final CloudManualSyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      ListTile(
        key: const Key('settings-cloud-sync-status-row'),
        minTileHeight: 70,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        horizontalTitleGap: 12,
        leading: status.isSyncing
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : BilSemanticIconBadge(
                kind: BilSemanticIconKind.cloudSync,
                size: 36,
                iconSize: 20,
                shape: BoxShape.rectangle,
              ),
        title: Text(label),
        subtitle: CloudSyncStatusLine(status: status),
        onTap: status.isSyncing ? null : () => _runSync(context, ref),
      ),
    ],
  );

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    if (ref.read(cloudManualSyncStatusProvider).isSyncing) return;
    try {
      final result = await ref
          .read(cloudManualSyncStatusProvider.notifier)
          .runOnce();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              result.completed
                  ? 'Encrypted cloud sync completed.'
                  : 'Cloud sync could not run. Check Premium, consent, and internet.',
            ),
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'Cloud sync could not run. Check Premium, consent, and internet.',
            ),
          ),
        ),
      );
    }
  }
}

class _MoreActionRow extends StatelessWidget {
  const _MoreActionRow({
    required this.label,
    required this.kind,
    required this.onTap,
    super.key,
  });

  final String label;
  final BilSemanticIconKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 60,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        horizontalTitleGap: 12,
        leading: BilSemanticIconBadge(
          kind: kind,
          size: 36,
          iconSize: 20,
          shape: BoxShape.rectangle,
        ),
        title: Text(label),
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
