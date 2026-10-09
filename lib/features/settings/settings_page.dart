import '../community/presentation/community_attention_scope.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../app/theme/bil_flat_icon.dart';
import '../../core/units/measurement_units.dart';
import '../ads/presentation/safe_free_ad_anchor.dart';
import '../admin/services/ai_coach_admin_service.dart';
import '../cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/domain/subscription_state.dart';
import '../commerce/providers/commerce_providers.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../weight/domain/weight_goal_progress.dart';
import '../wellness/presentation/wellness_copy.dart';
import '../../shared/widgets/bil_account_avatar.dart';
import 'reference_settings_copy.dart';
import 'cloud_sync_status_presentation.dart';

part 'settings_page_actions.dart';
part 'settings_page_polish.dart';

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
    final subscription = ref.watch(verifiedSubscriptionAccessProvider);
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          copy('More'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
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
            const SizedBox(height: 6),
            subscription.when(
              loading: () => _PremiumMembershipLink(
                label: copy('Checking subscription'),
                isChecking: true,
              ),
              error: (_, _) => _PremiumMembershipLink(
                label: copy('Retry subscription check'),
                isRetry: true,
                onTap: () => ref.invalidate(verifiedSubscriptionStateProvider),
              ),
              data: (value) =>
                  value.authority != EntitlementAuthority.verifiedServer
                  ? _PremiumMembershipLink(
                      label: copy('Retry subscription check'),
                      isRetry: true,
                      onTap: () =>
                          ref.invalidate(verifiedSubscriptionStateProvider),
                    )
                  : _PremiumMembershipLink(
                      label: value.plan == CommercePlan.free
                          ? copy('Explore Premium')
                          : copy('Active'),
                      onTap: () => context.push('/plans'),
                    ),
            ),
            const SizedBox(height: 4),
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
                  _MoreRow(copy('Friends'), '/community/connections'),
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
                  kind: BilSemanticIconKind.notes,
                  onTap: () => _reviewSetupAgain(context, ref),
                ),
                _MoreRow(
                  copy('Sharing & Privacy'),
                  '/settings/sharing-privacy',
                ),
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
                _MoreRow(
                  context.strings.text('Health sources & methodology'),
                  '/health-information-sources',
                  key: const Key('settings-health-sources-entry'),
                ),
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
      ),
    );
  }
}

class _PremiumMembershipLink extends StatelessWidget {
  const _PremiumMembershipLink({
    required this.label,
    this.onTap,
    this.isChecking = false,
    this.isRetry = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isChecking;
  final bool isRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.brightness == Brightness.dark
        ? const Color(0xFFE2C78E)
        : const Color(0xFF8B6429);
    final directionalIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('more-premium-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ReferenceSettingsCopy.of(context)('BIL Premium'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isChecking)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: gold,
                    ),
                  )
                else
                  Icon(
                    isRetry ? Icons.refresh_rounded : directionalIcon,
                    size: 18,
                    color: gold,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 6),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                BilAccountAvatar(
                  radius: 28,
                  photoBytes: photo,
                  networkUrl: photoUrl,
                ),
                const SizedBox(width: 12),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
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
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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

  BilSemanticIconKind get _fallbackKind => switch (Uri.parse(route).path) {
    '/admin/ai-coach' => BilSemanticIconKind.moderation,
    _ => BilSemanticIconKind.preferences,
  };

  @override
  Widget build(BuildContext context) {
    final path = Uri.parse(route).path;
    // Community and Coach entrances keep their established semantic icons.
    // Other destinations show a flat glyph only when it adds wayfinding value.
    final protectedEntry = const <String>{
      '/intelligence-center',
      '/community',
      '/community/connections',
      '/community/messages',
    }.contains(path);
    final showIcon = protectedEntry ||
        const <String>{
          '/goals',
          '/history',
          '/weekly-report',
          '/challenges',
          '/analytics/nutrition',
          '/nutrition',
          '/wellness/fasting',
          '/wellness/sleep',
          '/wellness/recipes',
          '/wellness/workouts/routines',
          '/connected-health',
          '/connected-health/steps',
          '/notification-settings',
        }.contains(path);
    final semanticKind = BilSemanticIcons.kindForRoute(route) ?? _fallbackKind;
    return Column(
      children: [
        ListTile(
          minTileHeight: protectedEntry ? 60 : 54,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          horizontalTitleGap: 8,
          leading: showIcon
              ? _MorePremiumIcon(kind: semanticKind, danger: _isDanger)
              : null,
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: _isDanger ? Theme.of(context).colorScheme.error : null,
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (route == '/community/messages' ||
                  route == '/community' ||
                  route == '/community/connections') ...[
                CommunityUnreadBadge(
                  kind: route == '/community/messages'
                      ? CommunityAttentionKind.messages
                      : route == '/community/connections'
                      ? CommunityAttentionKind.requests
                      : CommunityAttentionKind.all,
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 22,
                color: const Color(0xFF61738D),
              ),
            ],
          ),
          onTap: () => context.push(route),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: .7,
            indent: showIcon ? 58 : 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: .42),
          ),
      ],
    );
  }
}
