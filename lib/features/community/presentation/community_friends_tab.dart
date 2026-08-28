part of 'community_hub_page.dart';

class _NaturalCommunityText extends StatelessWidget {
  const _NaturalCommunityText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final direction = RegExp(r'[\u0600-\u08ff]').hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Text(text, textAlign: TextAlign.start),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.repository});
  final CommunityRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: repository.loadFriendshipsWithProfiles(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) return const _InlineError();
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty) {
        return Center(
          child: Text(
            communityText(
              context,
              'No requests or friendships yet.',
              'لا توجد طلبات أو صداقات بعد.',
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final profile = row['profile'] as Map<String, dynamic>?;
          final otherId = row['other_user_id'] as String;
          final name = profile?['display_name'] as String? ?? 'BIL member';
          final accepted = row['status'] == 'accepted';
          return Card(
            child: ListTile(
              leading: BilAccountAvatar(
                radius: 20,
                networkUrl: profile?['avatar_url'] as String?,
              ),
              title: Text(name),
              subtitle: Text(row['status'] as String? ?? 'pending'),
              trailing: accepted
                  ? const Icon(Icons.chat_bubble_outline_rounded)
                  : const Icon(Icons.hourglass_top_rounded),
              onTap: accepted
                  ? () => context.push(
                      '/community/chat/$otherId?name=${Uri.encodeQueryComponent(name)}',
                    )
                  : null,
            ),
          );
        },
      );
    },
  );
}
