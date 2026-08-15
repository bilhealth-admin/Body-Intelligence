import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/providers/commerce_providers.dart';
import '../community/data/community_repository.dart';
import '../settings/reference_settings_copy.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/user_profile_provider.dart';
import 'profile_summary_locale_copy.dart';

final profileFriendsCountProvider = FutureProvider<int?>((ref) async {
  if (!AppEnvironment.cloudConfigured) return null;
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return null;
  final rows = await CommunityRepository(client).loadFriendshipsWithProfiles();
  return rows.where((row) => row['status'] == 'accepted').length;
});

final profileMemberSinceProvider = Provider<DateTime?>((ref) {
  if (!AppEnvironment.cloudConfigured) return null;
  final value = Supabase.instance.client.auth.currentUser?.createdAt;
  return value == null ? null : DateTime.tryParse(value);
});

double? profileWeightProgress({
  required String goalType,
  required DateTime? goalCreatedAt,
  required List<({DateTime date, double weight})> weightsNewestFirst,
}) {
  final relevant = goalCreatedAt == null
      ? weightsNewestFirst
      : weightsNewestFirst
            .where((entry) => !entry.date.isBefore(goalCreatedAt))
            .toList(growable: false);
  if (relevant.length < 2) return null;
  final newest = relevant.first.weight;
  final baseline = relevant.last.weight;
  return switch (goalType) {
    'lose' => (baseline - newest).clamp(0, double.infinity).toDouble(),
    'gain' => (newest - baseline).clamp(0, double.infinity).toDouble(),
    _ => (newest - baseline).abs(),
  };
}

class ProfileSummaryPage extends ConsumerWidget {
  const ProfileSummaryPage({super.key});

  String _copy(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;
    const clean = <String, Map<String, String>>{
      'ar': {
        'BIL member': '\u0639\u0636\u0648 BIL',
        'Last login':
            '\u0622\u062e\u0631 \u062a\u0633\u062c\u064a\u0644 \u062f\u062e\u0648\u0644',
        'Member since': 'عضو منذ',
        'Weight lost':
            '\u0627\u0644\u0648\u0632\u0646 \u0627\u0644\u0645\u0641\u0642\u0648\u062f',
        'Weight gained': 'الوزن المكتسب',
        'Weight change': 'تغير الوزن',
        'Friends': '\u0627\u0644\u0623\u0635\u062f\u0642\u0627\u0621',
        'Go Premium':
            '\u0627\u0644\u0627\u0646\u062a\u0642\u0627\u0644 \u0625\u0644\u0649 Premium',
        'Edit Profile':
            '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a',
        'kg': '\u0643\u062c\u0645',
      },
    };
    final authored = clean[code]?[key];
    if (authored != null) return authored;
    final profileAuthored = profileSummaryAuthoredCopy[key]?[code];
    if (profileAuthored != null) return profileAuthored;
    final runtime = RuntimeCopy.resolve(
      key,
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
    );
    if (runtime != null) return runtime;
    final shared = ReferenceSettingsCopy.of(context)(key);
    if (shared != key) return shared;
    final translated = AppLocalizations.of(context).text(key);
    return translated;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final goalState = ref.watch(activeGoalProvider);
    final weightsState = ref.watch(weightHistoryProvider);
    final friendsState = ref.watch(profileFriendsCountProvider);
    final nameState = ref.watch(displayNameProvider);
    final photoState = ref.watch(profilePhotoProvider);
    final profile = profileState.value;
    final goal = goalState.value;
    final weights = weightsState.value;
    final storedName = nameState.value;
    final photo = photoState.value;
    final memberSince = ref.watch(profileMemberSinceProvider);
    final friends = friendsState.value;
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    final name = storedName?.trim().isNotEmpty == true
        ? storedName!.trim()
        : _copy(context, 'BIL member');
    final current = profile?.currentWeight;
    final target = profile?.targetWeight;
    final goalType =
        goal?.type ??
        (current == null || target == null
            ? 'maintain'
            : target < current
            ? 'lose'
            : target > current
            ? 'gain'
            : 'maintain');
    final progressLabel = goalType == 'lose'
        ? 'Weight lost'
        : goalType == 'gain'
        ? 'Weight gained'
        : 'Weight change';
    final progress = profileWeightProgress(
      goalType: goalType,
      goalCreatedAt: goal?.createdAt,
      weightsNewestFirst: [
        for (final entry in weights ?? const [])
          (date: entry.date, weight: entry.weight),
      ],
    );
    final colors = Theme.of(context).colorScheme;

    if (profileState.hasError ||
        goalState.hasError ||
        weightsState.hasError ||
        friendsState.hasError ||
        nameState.hasError ||
        photoState.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(_copy(context, 'BIL member'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42),
                const SizedBox(height: 12),
                Text(
                  _copy(context, 'Profile data could not be loaded.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(userProfileProvider);
                    ref.invalidate(activeGoalProvider);
                    ref.invalidate(weightHistoryProvider);
                    ref.invalidate(profileFriendsCountProvider);
                    ref.invalidate(displayNameProvider);
                    ref.invalidate(profilePhotoProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_copy(context, 'Retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (profileState.isLoading ||
        goalState.isLoading ||
        weightsState.isLoading ||
        friendsState.isLoading ||
        nameState.isLoading ||
        photoState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_copy(context, 'BIL member'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(centerTitle: true, title: Text(name)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: colors.surface,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _Avatar(photo: photo),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 3),
                      if (memberSince != null || profile != null)
                        Text.rich(
                          TextSpan(
                            text: '${_copy(context, 'Member since')}: ',
                            children: [
                              TextSpan(
                                text: MaterialLocalizations.of(context)
                                    .formatMediumDate(
                                      (memberSince ?? profile!.createdAt)
                                          .toLocal(),
                                    ),
                                style: TextStyle(color: colors.onSurface),
                              ),
                            ],
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: colors.surface,
            height: 88,
            child: Row(
              children: [
                _Metric(
                  value: weightsState.isLoading
                      ? '…'
                      : progress?.toStringAsFixed(1) ?? '\u2014',
                  unit: _copy(context, 'kg'),
                  label: _copy(context, progressLabel),
                  accent: true,
                ),
                Container(
                  width: 1,
                  height: 88,
                  color: Theme.of(context).dividerColor,
                ),
                _Metric(
                  value: friendsState.isLoading
                      ? '…'
                      : friends?.toString() ?? '\u2014',
                  label: _copy(context, 'Friends'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          subscription.when(
            loading: () => Container(
              color: colors.surface,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => Container(
              color: colors.surface,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () =>
                    ref.invalidate(verifiedSubscriptionStateProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.strings.text('Retry subscription check')),
              ),
            ),
            data: (value) => value.plan == CommercePlan.free
                ? Container(
                    color: colors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: FilledButton(
                      onPressed: () => context.push('/plans'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCB55),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                      ),
                      child: Text(_copy(context, 'Go Premium')),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          Material(
            color: colors.surface,
            child: InkWell(
              onTap: () => context.push('/profile-settings'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                child: Text(
                  _copy(context, 'Edit Profile'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colors.primary),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo});
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 42,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    backgroundImage: photo == null ? null : MemoryImage(photo!),
    child: photo == null
        ? Icon(
            Icons.person_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          )
        : null,
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.unit,
    this.accent = false,
  });
  final String value;
  final String label;
  final String? unit;
  final bool accent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              unit == null ? value : '$value $unit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: accent ? const Color(0xFF35C98A) : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
