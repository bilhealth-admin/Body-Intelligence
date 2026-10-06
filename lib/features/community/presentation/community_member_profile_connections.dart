part of 'community_hub_page.dart';

class _CommunityProfileConnectionsSheet extends StatefulWidget {
  const _CommunityProfileConnectionsSheet({
    required this.visit,
    required this.profile,
    required this.kind,
  });

  final _CommunityProfileVisit visit;
  final CommunityProfileOverview profile;
  final CommunityProfileConnectionKind kind;

  @override
  State<_CommunityProfileConnectionsSheet> createState() =>
      _CommunityProfileConnectionsSheetState();
}

class _CommunityProfileConnectionsSheetState
    extends State<_CommunityProfileConnectionsSheet> {
  late CommunityProfileConnectionKind _activeKind = widget.kind;
  late Future<List<CommunityProfileConnection>> _connections = _loadConnections(
    _activeKind,
  );
  String? _followBusyUserId;

  Future<List<CommunityProfileConnection>> _loadConnections(
    CommunityProfileConnectionKind kind,
  ) => widget.visit.run(() async {
    final rows = await widget.visit.repository.loadProfileConnections(
      userId: widget.profile.userId,
      kind: kind,
    );
    widget.visit.check();
    if (!mounted) throw const CommunityOwnerOperationCancelled();
    return rows;
  });

  void _switchKind(CommunityProfileConnectionKind kind) {
    if (kind == _activeKind || !widget.visit.isCurrent()) return;
    setState(() {
      _activeKind = kind;
      _connections = _loadConnections(kind);
    });
  }

  Future<void> _toggleFollow(CommunityProfileConnection member) async {
    if (!widget.visit.isCurrent() ||
        _followBusyUserId != null ||
        member.relationship == CommunityRelationshipStatus.self ||
        (!member.viewerFollows && !member.allowFollows)) {
      return;
    }
    setState(() => _followBusyUserId = member.userId);
    try {
      await widget.visit.run(() async {
        if (member.viewerFollows) {
          await widget.visit.repository.unfollow(member.userId);
        } else {
          await widget.visit.repository.follow(member.userId);
        }
        widget.visit.check();
        if (!mounted) return;
        final updated = await _loadConnections(_activeKind);
        widget.visit.check();
        if (!mounted) return;
        setState(() {
          _connections = Future.value(updated);
        });
      });
    } on CommunityOwnerOperationCancelled {
      // No follow-up reads or errors are shown in the next viewer's visit.
    } catch (_) {
      if (mounted && widget.visit.isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update follow state.',
                'تعذر تحديث حالة المتابعة.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && widget.visit.isCurrent()) {
        setState(() => _followBusyUserId = null);
      }
    }
  }

  Widget _buildList(
    BuildContext context,
  ) => FutureBuilder<List<CommunityProfileConnection>>(
    future: _connections,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text(
            communityText(
              context,
              'This list is unavailable right now.',
              'هذه القائمة غير متاحة الآن.',
            ),
          ),
        );
      }
      final rows = snapshot.data ?? const <CommunityProfileConnection>[];
      if (rows.isEmpty) {
        return Center(
          child: Text(
            communityText(
              context,
              'Nothing to show here yet.',
              'لا يوجد ما يمكن عرضه هنا بعد.',
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = rows[index];
          return ListTile(
            leading: BilAccountAvatar(radius: 22, networkUrl: member.avatarUrl),
            title: Text(member.displayName),
            subtitle: member.handle == null
                ? null
                : Text('@${member.handle!}', textDirection: TextDirection.ltr),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (member.relationship != CommunityRelationshipStatus.self &&
                    (member.viewerFollows || member.allowFollows))
                  TextButton(
                    key: Key('community-connection-follow-${member.userId}'),
                    onPressed: _followBusyUserId == null
                        ? () => _toggleFollow(member)
                        : null,
                    child: _followBusyUserId == member.userId
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            member.viewerFollows
                                ? communityText(context, 'Following', 'يتابع')
                                : communityText(context, 'Follow', 'متابعة'),
                          ),
                  ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ],
            ),
            onTap: () {
              if (!widget.visit.isCurrent()) return;
              Navigator.pop(context);
              context.push('/community/profile/${member.userId}');
            },
          );
        },
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final socialTabs = widget.kind != CommunityProfileConnectionKind.friends;
    final initialIndex = widget.kind == CommunityProfileConnectionKind.following
        ? 1
        : 0;

    final content = SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          if (socialTabs)
            TabBar(
              key: const Key('community-profile-follow-tabs'),
              onTap: (index) => _switchKind(
                index == 0
                    ? CommunityProfileConnectionKind.followers
                    : CommunityProfileConnectionKind.following,
              ),
              tabs: [
                Tab(text: communityText(context, 'Followers', 'المتابعون')),
                Tab(text: communityText(context, 'Following', 'يتابع')),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                communityText(context, 'Friends', 'الأصدقاء'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildList(context)),
        ],
      ),
    );

    if (!socialTabs) return content;
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: content,
    );
  }
}
