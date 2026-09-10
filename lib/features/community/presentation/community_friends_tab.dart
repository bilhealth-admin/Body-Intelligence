part of 'community_hub_page.dart';

class _NaturalCommunityText extends StatelessWidget {
  const _NaturalCommunityText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final direction = BilWrittenLanguageResolver.directionFor(
      text,
      fallback: Directionality.of(context),
    );
    return Directionality(
      textDirection: direction,
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _FriendsTab extends StatefulWidget {
  const _FriendsTab({required this.repository});
  final CommunityRepository repository;

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab>
    with AutomaticKeepAliveClientMixin<_FriendsTab> {
  late Future<List<Map<String, dynamic>>> _friendships = widget.repository
      .loadFriendshipsWithProfiles();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final request = widget.repository.loadFriendshipsWithProfiles();
    setState(() {
      _friendships = request;
    });
    try {
      await request;
    } on Object {
      // The FutureBuilder retains an explicit retry state.
    }
  }

  Future<void> _open(String route) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await context.push(route);
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: const Key('community-friends-manage'),
                onPressed: () => _open('/community/connections'),
                icon: const Icon(Icons.people_outline_rounded, size: 18),
                label: Text(
                  communityText(
                    context,
                    'Friends and requests',
                    'الأصدقاء والطلبات',
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _open('/community/people'),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  communityText(context, 'Find people', 'البحث عن أصدقاء'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _friendships,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return _InlineError(onRetry: _refresh);
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        communityText(
                          context,
                          'No requests or friendships yet.',
                          'لا توجد طلبات أو صداقات بعد.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final profile = row['profile'] as Map<String, dynamic>?;
                    final otherId = row['other_user_id'] as String;
                    final name =
                        profile?['display_name'] as String? ??
                        communityText(context, 'BIL member', 'عضو BIL');
                    final accepted = row['status'] == 'accepted';
                    return Card(
                      child: ListTile(
                        leading: BilAccountAvatar(
                          radius: 20,
                          networkUrl: profile?['avatar_url'] as String?,
                        ),
                        title: Text(name),
                        subtitle: Text(switch (row['status']) {
                          'accepted' => communityText(
                            context,
                            'Friend',
                            'صديق',
                          ),
                          'pending' => communityText(
                            context,
                            'Request pending',
                            'الطلب قيد الانتظار',
                          ),
                          _ => communityText(
                            context,
                            'Unavailable',
                            'غير متاح',
                          ),
                        }),
                        trailing: accepted
                            ? const Icon(Icons.chat_bubble_outline_rounded)
                            : const Icon(Icons.hourglass_top_rounded),
                        onTap: accepted
                            ? () => _open(
                                '/community/chat/$otherId?name=${Uri.encodeQueryComponent(name)}',
                              )
                            : () => _open('/community/connections'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
