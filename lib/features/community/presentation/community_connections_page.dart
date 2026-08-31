import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../data/community_repository.dart';

part 'community_connections_copy.dart';

SupabaseClient? _initializedConnectionsClient() {
  if (!AppEnvironment.cloudConfigured) return null;
  try {
    final supabase = Supabase.instance;
    return supabase.isInitialized ? supabase.client : null;
  } on AssertionError {
    return null;
  } on StateError {
    return null;
  }
}

class CommunityConnectionsPage extends ConsumerStatefulWidget {
  const CommunityConnectionsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  ConsumerState<CommunityConnectionsPage> createState() =>
      _CommunityConnectionsPageState();
}

class _CommunityConnectionsPageState
    extends ConsumerState<CommunityConnectionsPage> {
  CommunityRepository? _repository;
  Future<List<Map<String, dynamic>>> _connections = Future.value(const []);
  int _tab = 0;
  final Set<String> _busyConnections = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _reload();
      return;
    }
    final client = _initializedConnectionsClient();
    if (client?.auth.currentUser == null) return;
    _repository = CommunityRepository(client!);
    _reload();
  }

  void _reload() {
    _connections = _repository!.loadFriendshipsWithProfiles();
  }

  Future<void> _respond(String id, {required bool accept}) async {
    if (!_busyConnections.add(id)) return;
    setState(() {});
    try {
      await _repository!.respondToFriendship(id, accept: accept);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(id));
    }
  }

  Future<void> _remove(String id) async {
    if (!_busyConnections.add(id)) return;
    setState(() {});
    try {
      await _repository!.removeFriendship(id);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(id));
    }
  }

  Future<void> _block(String operationId, String userId) async {
    if (!_busyConnections.add(operationId)) return;
    setState(() {});
    try {
      await _repository!.blockMember(userId);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(operationId));
    }
  }

  Future<void> _reportUser(String operationId, String userId) async {
    if (!_busyConnections.add(operationId)) return;
    setState(() {});
    try {
      await _repository!.report(
        targetKind: 'profile',
        targetId: userId,
        reason: 'user_reported_from_connections',
      );
      if (mounted) {
        final copy = _ConnectionsCopy.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.reportSubmitted)));
      }
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(operationId));
    }
  }

  void _showFailure() {
    final copy = _ConnectionsCopy.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.actionFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final copy = _ConnectionsCopy.of(context);
    final subscription = ref.watch(verifiedSubscriptionStateProvider).value;
    final friendsUnlocked =
        subscription?.authority == EntitlementAuthority.verifiedServer &&
        (subscription?.grants(CommerceEntitlement.communityFriends) ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.findPeople,
            onPressed: _repository == null
                ? null
                : () => context.push('/community/people'),
            icon: const Icon(Icons.person_search_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: _ConnectionTab(
                  key: const Key('community-connections-all-tab'),
                  label: copy.all,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              Expanded(
                child: _ConnectionTab(
                  key: const Key('community-connections-requests-tab'),
                  label: copy.requests,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _repository == null
          ? _ConnectionsUnavailable(copy: copy)
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _connections,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _ConnectionsLoading(
                    label: context.strings.text('Loading...'),
                  );
                }
                if (snapshot.hasError) {
                  return _ConnectionsLoadError(
                    copy: copy,
                    onRetry: () => setState(_reload),
                  );
                }
                final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
                    .map(_ConnectionRow.tryParse)
                    .whereType<_ConnectionRow>()
                    .toList(growable: false);
                final visibleRows = rows
                    .where((row) {
                      final status = row.status;
                      return _tab == 0
                          ? status == 'accepted'
                          : status == 'pending';
                    })
                    .toList(growable: false);
                if (visibleRows.isEmpty) {
                  return _EmptyConnections(copy: copy);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _connections;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleRows.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ConnectionsEducation(copy: copy);
                      }
                      final row = visibleRows[index - 1];
                      final otherId = row.otherUserId;
                      final status = row.status;
                      final incoming =
                          row.addresseeId == _repository!.currentUserId;
                      final name = row.displayName ?? copy.member;
                      final avatar = row.avatarUrl;
                      final busy = _busyConnections.contains(row.id);
                      if (status == 'pending' && incoming && !friendsUnlocked) {
                        return _LockedIncomingConnectionCard(
                          rowId: row.id,
                          name: name,
                          avatarUrl: avatar,
                          status: copy.status(status, incoming: incoming),
                          declineLabel: copy.decline,
                          busy: busy,
                          onDecline: () => _respond(row.id, accept: false),
                        );
                      }
                      return Card(
                        child: ListTile(
                          leading: BilAccountAvatar(
                            radius: 20,
                            networkUrl: avatar,
                          ),
                          title: Text(name),
                          subtitle: Text(
                            copy.status(status, incoming: incoming),
                          ),
                          trailing: status == 'pending' && incoming
                              ? Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: copy.decline,
                                      onPressed: busy
                                          ? null
                                          : () =>
                                                _respond(row.id, accept: false),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                    IconButton.filled(
                                      tooltip: copy.accept,
                                      onPressed: busy
                                          ? null
                                          : () =>
                                                _respond(row.id, accept: true),
                                      icon: Icon(
                                        Icons.check_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ],
                                )
                              : status == 'accepted'
                              ? Wrap(
                                  spacing: 2,
                                  children: [
                                    IconButton(
                                      tooltip: copy.message,
                                      onPressed: busy
                                          ? null
                                          : () => context.push(
                                              '/community/chat/$otherId',
                                              extra: name,
                                            ),
                                      icon: const Icon(
                                        Icons.chat_bubble_outline,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !busy,
                                      tooltip: copy.manage,
                                      onSelected: (value) {
                                        if (value == 'remove') {
                                          _remove(row.id);
                                        }
                                        if (value == 'block') {
                                          _block(row.id, otherId);
                                        }
                                        if (value == 'report') {
                                          _reportUser(row.id, otherId);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Text(copy.remove),
                                        ),
                                        PopupMenuItem(
                                          value: 'report',
                                          child: Text(copy.report),
                                        ),
                                        PopupMenuItem(
                                          value: 'block',
                                          child: Text(copy.block),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _LockedIncomingConnectionCard extends StatelessWidget {
  const _LockedIncomingConnectionCard({
    required this.rowId,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.declineLabel,
    required this.busy,
    required this.onDecline,
  });

  final String rowId;
  final String name;
  final String? avatarUrl;
  final String status;
  final String declineLabel;
  final bool busy;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BilAccountAvatar(radius: 20, networkUrl: avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onDecline,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(declineLabel),
                ),
                FilledButton.tonal(
                  key: ValueKey('community-premium-accept-$rowId'),
                  onPressed: () => context.push('/plans?focus=subscription'),
                  child: Text(
                    context.strings.text('View membership plans'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionRow {
  const _ConnectionRow({
    required this.id,
    required this.otherUserId,
    required this.addresseeId,
    required this.status,
    this.displayName,
    this.avatarUrl,
  });
  final String id, otherUserId, addresseeId, status;
  final String? displayName, avatarUrl;

  static _ConnectionRow? tryParse(Map<String, dynamic> row) {
    final id = row['id'];
    final other = row['other_user_id'];
    final addressee = row['addressee_id'];
    final status = row['status'];
    if (id is! String ||
        id.isEmpty ||
        other is! String ||
        other.isEmpty ||
        addressee is! String ||
        addressee.isEmpty ||
        status is! String ||
        !const {'pending', 'accepted'}.contains(status)) {
      return null;
    }
    final profile = row['profile'];
    if (profile != null && profile is! Map<String, dynamic>) return null;
    final name = profile is Map<String, dynamic>
        ? profile['display_name']
        : null;
    final avatar = profile is Map<String, dynamic>
        ? profile['avatar_url']
        : null;
    if (name != null && name is! String ||
        avatar != null && avatar is! String) {
      return null;
    }
    return _ConnectionRow(
      id: id,
      otherUserId: other,
      addresseeId: addressee,
      status: status,
      displayName: name as String?,
      avatarUrl: avatar as String?,
    );
  }
}

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: selected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _ConnectionsEducation extends StatelessWidget {
  const _ConnectionsEducation({required this.copy});
  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: const Icon(Icons.shield_outlined),
      title: Text(copy.educationTitle),
      subtitle: Text(copy.educationBody),
    ),
  );
}

class _ConnectionsUnavailable extends StatelessWidget {
  const _ConnectionsUnavailable({required this.copy});

  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_off_outlined, size: 52),
              const SizedBox(height: 16),
              Text(
                copy.signInRequired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('community-connections-add-friends'),
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(copy.signIn),
              ),
              const SizedBox(height: 18),
              _ConnectionsEducation(copy: copy),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConnectionsLoadError extends StatelessWidget {
  const _ConnectionsLoadError({required this.copy, required this.onRetry});

  final _ConnectionsCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52),
          const SizedBox(height: 12),
          Text(copy.loadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.retry),
          ),
        ],
      ),
    ),
  );
}

class _ConnectionsLoading extends StatelessWidget {
  const _ConnectionsLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({required this.copy});
  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 56),
          const SizedBox(height: 12),
          Text(copy.empty, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/community/people'),
            icon: const Icon(Icons.person_search_rounded),
            label: Text(copy.findPeople),
          ),
        ],
      ),
    ),
  );
}
