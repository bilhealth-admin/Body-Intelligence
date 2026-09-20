import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/environment/app_environment.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../commerce/domain/commerce_plan.dart';
import '../commerce/providers/commerce_providers.dart';
import 'reference_settings_copy.dart';

/// Exact settings information architecture from the supplied reference.
class ReferenceSettingsHomePage extends ConsumerWidget {
  const ReferenceSettingsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ReferenceSettingsCopy.of(context);
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
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 14, 8),
                  leadingSize: 24,
                  leadingToTitle: 12,
                  leading: const Icon(
                    CupertinoIcons.square_arrow_right,
                    color: CupertinoColors.systemRed,
                    size: 22,
                  ),
                  title: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Text(
                      copy('Logout'),
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: () => _logout(context),
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

  Future<void> _logout(BuildContext context) async {
    if (AppEnvironment.cloudConfigured) {
      try {
        final supabase = Supabase.instance;
        if (!supabase.isInitialized) {
          throw StateError('Cloud session is not ready');
        }
        await supabase.client.auth.signOut();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.strings.text(
                  'Could not sign out. Check your connection and retry.',
                ),
              ),
            ),
          );
        }
        return;
      }
    }
    if (context.mounted) context.go('/login');
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
          BilSemanticIconBadge(
            kind: kind,
            size: 26,
            iconSize: 15,
            shape: BoxShape.rectangle,
          ),
          const SizedBox(width: 8),
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
      leadingSize: 34,
      leadingToTitle: 12,
      leading: kind == null
          ? Icon(
              CupertinoIcons.circle,
              size: 19,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            )
          : BilSemanticIconBadge(
              kind: kind,
              size: 34,
              iconSize: 19,
              shape: BoxShape.rectangle,
            ),
      title: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Text(label),
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
