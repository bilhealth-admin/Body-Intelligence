import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/environment/app_environment.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../shared/widgets/bil_native_settings_icon.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/providers/commerce_providers.dart';
import '../profile/providers/profile_auth_identity_provider.dart';
import 'reference_settings_copy.dart';

/// Explicitly local sign-out: never revoke the member's other devices.
final settingsSignOutProvider = Provider<Future<void> Function(String)>((ref) {
  return (expectedOwnerId) async {
    if (!AppEnvironment.supabaseRuntimeReady) {
      throw StateError('Cloud session is not ready');
    }
    await signOutSettingsSession(
      Supabase.instance.client.auth,
      expectedOwnerId,
    );
  };
});

Future<void> signOutSettingsSession(
  GoTrueClient auth,
  String expectedOwnerId,
) async {
  if (auth.currentUser?.id != expectedOwnerId) {
    throw StateError('The active account changed');
  }
  try {
    await auth.signOut(scope: SignOutScope.local);
  } catch (_) {
    // GoTrue clears the local session before contacting the revocation API.
    // A network error must not claim that a cleared device session is signed in.
    if (auth.currentUser != null) rethrow;
  }
  if (auth.currentUser != null) throw StateError('The active account changed');
}

/// Grouped settings with a native-symbol pilot. iOS visual approval is separate.
class ReferenceSettingsHomePage extends ConsumerStatefulWidget {
  const ReferenceSettingsHomePage({super.key});

  @override
  ConsumerState<ReferenceSettingsHomePage> createState() =>
      _ReferenceSettingsHomePageState();
}

class _ReferenceSettingsHomePageState
    extends ConsumerState<ReferenceSettingsHomePage> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final copy = ReferenceSettingsCopy.of(context);
    final identity = ref.watch(profileAuthIdentityProvider);
    final ownerId = identity.asData?.value.ownerId;
    final sessionReady = identity.hasValue && !identity.hasError;
    final showPremiumUpsell = ref
        .watch(verifiedSubscriptionStateProvider)
        .when(
          data: (value) => value.plan == CommercePlan.free,
          loading: () => false,
          error: (_, _) => false,
        );
    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      appBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground
            .resolveFrom(context)
            .withValues(alpha: .92),
        border: null,
        middle: Text(
          copy('Settings'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SettingsGroup(
              title: copy('Account & profile'),
              kind: BilSemanticIconKind.profile,
              children: [
                _SettingsRow(copy('Profile'), '/profile-settings'),
                _SettingsRow(copy('App Appearance'), '/settings/appearance'),
                _SettingsRow(copy('Language'), '/settings/language'),
              ],
            ),
            _SettingsGroup(
              title: copy('Diary & goals'),
              kind: BilSemanticIconKind.goals,
              children: [
                _SettingsRow(copy('Diary Settings'), '/settings/diary'),
              ],
            ),
            _SettingsGroup(
              title: copy('Privacy & notifications'),
              kind: BilSemanticIconKind.privacy,
              children: [
                _SettingsRow(
                  copy('Sharing & Privacy'),
                  '/settings/sharing-privacy',
                ),
              ],
            ),
            _SettingsGroup(
              title: copy('Health preferences'),
              kind: BilSemanticIconKind.health,
              children: [
                _SettingsRow(copy('My Exercises'), '/wellness/workouts/log'),
                _SettingsRow(
                  copy('Weekly Nutrition Settings'),
                  '/settings/nutrition-goals',
                ),
                _SettingsRow(
                  copy('Exercise calories'),
                  '/settings/exercise-calories',
                ),
                _SettingsRow(
                  copy('Push Notifications'),
                  '/notification-settings',
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 8),
              backgroundColor: Colors.transparent,
              children: [
                CupertinoListTile(
                  key: Key(
                    ownerId == null ? 'settings-sign-in' : 'settings-sign-out',
                  ),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 14, 8),
                  leadingSize: 24,
                  leadingToTitle: 12,
                  leading: _signingOut || !sessionReady
                      ? const CupertinoActivityIndicator()
                      : Icon(
                          ownerId == null
                              ? CupertinoIcons.person_crop_circle
                              : CupertinoIcons.square_arrow_right,
                          color: ownerId == null
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemRed,
                          size: 22,
                        ),
                  title: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Text(
                      ownerId == null
                          ? context.strings.text('Sign in')
                          : copy('Logout'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ownerId == null
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.systemRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: !sessionReady || _signingOut
                      ? null
                      : ownerId == null
                      ? () => context.push('/login')
                      : () => _logout(ownerId),
                ),
              ],
            ),
            if (showPremiumUpsell)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 34),
                child: Column(
                  children: [
                    Text(
                      copy('BIL Premium'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC857),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 13,
                        ),
                      ),
                      onPressed: () => context.push('/plans'),
                      child: Text(
                        copy('Start 7-day free trial'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(String ownerId) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await ref.read(settingsSignOutProvider)(ownerId);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ReferenceSettingsCopy.of(context)(
                'Could not sign out. Check your connection and retry.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.kind,
    required this.children,
  });
  final String title;
  final BilSemanticIconKind kind;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: CupertinoListSection.insetGrouped(
      margin: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
      backgroundColor: Colors.transparent,
      header: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: CupertinoColors.label
                    .resolveFrom(context)
                    .withValues(alpha: .82),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      children: children,
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.label, this.route);
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final kind = BilSemanticIcons.kindForRoute(route);
    return CupertinoListTile(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 14, 8),
      leadingSize: 29,
      leadingToTitle: 12,
      leading: kind == null
          ? Icon(
              CupertinoIcons.circle,
              size: 19,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            )
          : BilNativeSettingsIcon(kind: kind),
      title: Tooltip(
        message: label,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? CupertinoIcons.chevron_back
            : CupertinoIcons.chevron_forward,
        size: 18,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      onTap: () => context.push(route),
    );
  }
}
