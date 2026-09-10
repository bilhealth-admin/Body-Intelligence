import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/invalid_route_page.dart';
import '../services/ai_coach_admin_service.dart';
import 'admin_console_copy.dart';
import 'admin_notification_controls.dart';
import 'admin_subscription_pages.dart';
import 'ai_coach_reset_admin_page.dart';
import 'community_member_access_admin_panel.dart';
import 'community_moderator_admin_panel.dart';

class AiCoachAdminPage extends ConsumerWidget {
  const AiCoachAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(aiCoachAdminAccessProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const InvalidRoutePage(),
        data: (allowed) => allowed
            ? _console(context)
            : const InvalidRoutePage(key: Key('admin-ai-coach-access-denied')),
      );

  Widget _console(BuildContext context) {
    String copy(String key) => adminConsoleCopy(context, key);
    Widget action(String key, IconData icon, Widget Function() page) => Card(
      child: ListTile(
        key: Key('admin-action-$key'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(icon),
        title: Text(copy(key)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page())),
      ),
    );
    Widget tab(List<Widget> children) =>
        ListView(padding: const EdgeInsets.all(16), children: children);
    Widget panel(String key, Widget child) =>
        AdminFunctionPage(title: copy(key), child: child);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy('title')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: const Key('admin-tab-reset'), text: copy('reset')),
              Tab(
                key: const Key('admin-tab-community'),
                text: copy('community'),
              ),
              Tab(key: const Key('admin-tab-free'), text: copy('free')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            tab([
              action(
                'global',
                Icons.restart_alt,
                () => const AiCoachResetAdminPage(global: true),
              ),
              action(
                'individual',
                Icons.person_outline,
                () => const AiCoachResetAdminPage(global: false),
              ),
              action(
                'notifications',
                Icons.campaign_outlined,
                () => panel('notifications', const AdminNotificationControls()),
              ),
            ]),
            tab([
              Card(
                child: ListTile(
                  key: const Key('admin-action-approvals'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(copy('approvals')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/community/moderation'),
                ),
              ),
              action(
                'moderators',
                Icons.admin_panel_settings_outlined,
                () => panel('moderators', const CommunityModeratorAdminPanel()),
              ),
              action(
                'members',
                Icons.person_off_outlined,
                () => panel('members', const CommunityMemberAccessAdminPanel()),
              ),
            ]),
            tab([
              action(
                'premium',
                Icons.workspace_premium_outlined,
                () => panel(
                  'premium',
                  const AdminSubscriptionGrantForm(aiCoach: false),
                ),
              ),
              action(
                'ai',
                Icons.auto_awesome,
                () => panel(
                  'ai',
                  const AdminSubscriptionGrantForm(aiCoach: true),
                ),
              ),
              action(
                'list',
                Icons.manage_accounts_outlined,
                () => panel('list', const AdminSubscriptionList()),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Every opened function also watches the current account's admin authority.
class AdminFunctionPage extends ConsumerWidget {
  const AdminFunctionPage({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(aiCoachAdminAccessProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const InvalidRoutePage(),
        data: (allowed) => allowed
            ? Scaffold(
                appBar: AppBar(title: Text(title)),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    KeyedSubtree(
                      key: ValueKey(
                        ref.watch(aiCoachAdminSessionProvider).asData?.value,
                      ),
                      child: child,
                    ),
                  ],
                ),
              )
            : const InvalidRoutePage(key: Key('admin-function-access-denied')),
      );
}
