import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../../core/units/measurement_units.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/domain/subscription_state.dart';
import '../commerce/providers/commerce_providers.dart';
import '../community/data/community_repository.dart';
import '../settings/reference_settings_copy.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/profile_auth_identity_provider.dart';
import 'providers/user_profile_provider.dart';
import 'profile_summary_locale_copy.dart';
import '../../shared/widgets/bil_account_avatar.dart';
import '../visual_2026/bil_calm_visual_scope.dart';

final profileFriendsCountProvider = FutureProvider<int?>((ref) async {
  if (!AppEnvironment.cloudConfigured) return null;
  // An account switch must invalidate a pending friendship read. Never expose
  // an old owner's friendship count on the newly signed-in profile.
  final owner = ref.watch(profileAuthIdentityProvider).value?.ownerId;
  if (owner == null) return null;
  final client = Supabase.instance.client;
  if (client.auth.currentUser?.id != owner) return null;
  final rows = await CommunityRepository(client).loadFriendshipsWithProfiles();
  if (!ref.mounted || client.auth.currentUser?.id != owner) return null;
  return rows.where((row) => row['status'] == 'accepted').length;
});

final profileMemberSinceProvider = Provider<DateTime?>((ref) {
  if (!AppEnvironment.cloudConfigured) return null;
  final owner = ref.watch(profileAuthIdentityProvider).value?.ownerId;
  if (owner == null) return null;
  final client = Supabase.instance.client;
  if (client.auth.currentUser?.id != owner) return null;
  final value = client.auth.currentUser?.createdAt;
  return value == null ? null : DateTime.tryParse(value);
});

/// Signed all-time scale-weight change in kilograms.
///
/// The baseline is the earliest recorded weight observation and the current
/// value is the latest recorded observation. This intentionally does not use
/// the editable profile weight or the active goal date: neither is a stable
/// measurement baseline. A negative result means loss and a positive result
/// means gain. At least two recorded observations are required.
double? profileWeightChangeKg({
  required List<({DateTime date, double weight})> weights,
}) {
  final chronological =
      weights
          .where((entry) => entry.weight.isFinite && entry.weight > 0)
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
  if (chronological.length < 2) return null;
  return chronological.last.weight - chronological.first.weight;
}

/// Localized, signed display value for a canonical kilogram difference.
String formatProfileWeightChange({
  required double changeKg,
  required MeasurementSystem system,
  required String localeTag,
}) {
  final converted = UnitConverter.weightFromKg(changeKg, system);
  final rounded = double.parse(converted.toStringAsFixed(1));
  final normalized = rounded == 0 ? 0.0 : rounded;
  final magnitude = NumberFormat('0.0', localeTag).format(normalized.abs());
  if (normalized > 0) return '+$magnitude';
  if (normalized < 0) return '-$magnitude';
  return magnitude;
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
        'lb': '\u0631\u0637\u0644',
        'Loading profile…': 'جارٍ تحميل الملف الشخصي…',
        'Loading profile is taking longer than expected.':
            'تحميل الملف الشخصي يستغرق وقتًا أطول من المعتاد.',
        'Some profile details are unavailable.':
            'بعض تفاصيل الملف غير متاحة حاليًا.',
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
    final weightsState = ref.watch(weightHistoryProvider);
    final systemState = ref.watch(measurementSystemProvider);
    final friendsState = ref.watch(profileFriendsCountProvider);
    final nameState = ref.watch(displayNameProvider);
    final avatar = ref.watch(profileAvatarStateProvider);
    final photoUrl = avatar.url;
    final profile = profileState.value;
    final weights = weightsState.value;
    final storedName = nameState.value;
    final photo = avatar.bytes;
    final memberSince = ref.watch(profileMemberSinceProvider);
    final friends = friendsState.value;
    final subscription = ref.watch(verifiedSubscriptionAccessProvider);
    final name = storedName?.trim().isNotEmpty == true
        ? storedName!.trim()
        : _copy(context, 'BIL member');
    final weightChangeKg = profileWeightChangeKg(
      weights: [
        for (final entry in weights ?? const [])
          (date: entry.date, weight: entry.weight),
      ],
    );
    final system = systemState.value ?? MeasurementSystem.metric;
    final localeTag = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final weightChangeValue = weightChangeKg == null
        ? null
        : formatProfileWeightChange(
            changeKg: weightChangeKg,
            system: system,
            localeTag: localeTag,
          );
    final weightUnit = _copy(context, UnitConverter.weightUnit(system));
    final colors = Theme.of(context).colorScheme;

    return BilCalmVisualScope(
      builder: (context) => Scaffold(
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
                  _Avatar(
                    photo: photo,
                    networkUrl: photoUrl,
                    ownerId: avatar.owner,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
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
            if (profileState.hasError ||
                (profileState.isLoading && !profileState.hasValue))
              ProfilePrimaryLoadNotice(
                key: ValueKey('bil-profile-loading:${avatar.owner ?? 'local'}'),
                failed: profileState.hasError,
                onRetry: () => ref.invalidate(userProfileProvider),
                loadingText: _copy(context, 'Loading profile…'),
                slowText: _copy(
                  context,
                  'Loading profile is taking longer than expected.',
                ),
                errorText: _copy(context, 'Profile data could not be loaded.'),
                retryText: _copy(context, 'Retry'),
              ),
            if (weightsState.hasError ||
                systemState.hasError ||
                friendsState.hasError ||
                nameState.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _copy(context, 'Some profile details are unavailable.'),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('bil-profile-details-retry'),
                      onPressed: () {
                        if (weightsState.hasError) {
                          ref.invalidate(weightHistoryProvider);
                        }
                        if (systemState.hasError) {
                          ref.invalidate(measurementSystemProvider);
                        }
                        if (friendsState.hasError) {
                          ref.invalidate(profileFriendsCountProvider);
                        }
                        if (nameState.hasError) {
                          ref.invalidate(displayNameProvider);
                        }
                      },
                      child: Text(_copy(context, 'Retry')),
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
                    value: weightsState.isLoading && !weightsState.hasValue
                        ? '…'
                        : weightChangeValue ?? '\u2014',
                    unit: weightUnit,
                    label: _copy(context, 'Weight change'),
                    semanticValue: weightChangeValue == null
                        ? _copy(context, 'Insufficient data')
                        : '$weightChangeValue $weightUnit',
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
                  icon: const BilGlassPressFeedback(
                    child: Icon(Icons.refresh_rounded),
                  ),
                  label: Text(context.strings.text('Retry subscription check')),
                ),
              ),
              data: (value) =>
                  value.authority != EntitlementAuthority.verifiedServer
                  ? Container(
                      color: colors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(verifiedSubscriptionStateProvider),
                        icon: const BilGlassPressFeedback(
                          child: Icon(Icons.refresh_rounded),
                        ),
                        label: Text(
                          context.strings.text('Retry subscription check'),
                        ),
                      ),
                    )
                  : value.plan == CommercePlan.free
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
      ),
    );
  }
}

/// A bounded, recoverable state for the *primary* profile read. Secondary
/// sources always render independently in the summary and never reach here.
class ProfilePrimaryLoadNotice extends StatefulWidget {
  const ProfilePrimaryLoadNotice({
    super.key,
    required this.failed,
    required this.onRetry,
    required this.loadingText,
    required this.slowText,
    required this.errorText,
    required this.retryText,
  });

  final bool failed;
  final VoidCallback onRetry;
  final String loadingText;
  final String slowText;
  final String errorText;
  final String retryText;

  @override
  State<ProfilePrimaryLoadNotice> createState() =>
      _ProfilePrimaryLoadNoticeState();
}

class _ProfilePrimaryLoadNoticeState extends State<ProfilePrimaryLoadNotice> {
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    if (!widget.failed) _startTimer();
  }

  void _startTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && !widget.failed) setState(() => _slow = true);
    });
  }

  @override
  void didUpdateWidget(covariant ProfilePrimaryLoadNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failed && !widget.failed) {
      _slow = false;
      _startTimer();
    } else if (!oldWidget.failed && widget.failed) {
      _slowTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsRetry = widget.failed || _slow;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          if (needsRetry)
            const Icon(Icons.info_outline_rounded, size: 20)
          else
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.failed
                  ? widget.errorText
                  : _slow
                  ? widget.slowText
                  : widget.loadingText,
            ),
          ),
          if (needsRetry)
            TextButton(
              key: const ValueKey('bil-profile-primary-retry'),
              onPressed: () {
                setState(() => _slow = false);
                if (!widget.failed) _startTimer();
                widget.onRetry();
              },
              child: Text(widget.retryText),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photo,
    required this.networkUrl,
    required this.ownerId,
  });
  final Uint8List? photo;
  final String? networkUrl;
  final String? ownerId;

  @override
  Widget build(BuildContext context) => BilAccountAvatar(
    key: ValueKey('bil-profile-avatar:${ownerId ?? 'local'}'),
    radius: 42,
    ownerId: ownerId,
    photoBytes: photo,
    networkUrl: networkUrl,
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.unit,
    this.semanticValue,
    this.accent = false,
  });
  final String value;
  final String label;
  final String? unit;
  final String? semanticValue;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final displayedValue = unit == null ? value : '$value $unit';
    return Expanded(
      child: Semantics(
        container: true,
        label: '$label, ${semanticValue ?? displayedValue}',
        child: ExcludeSemantics(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    displayedValue,
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
        ),
      ),
    );
  }
}
