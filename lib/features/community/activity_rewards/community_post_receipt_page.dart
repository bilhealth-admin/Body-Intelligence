import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../data/community_post_cloud_store.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../domain/community_polls.dart';
import '../presentation/community_copy.dart';
import '../presentation/community_return_button.dart';

/// Owner-scoped destination for a moderation receipt. It deliberately renders
/// the post read-only; editing/publishing remains owned by the existing composer.
class CommunityPostReceiptPage extends StatefulWidget {
  const CommunityPostReceiptPage({
    required this.postId,
    this.repository,
    super.key,
  });

  final String postId;
  final CommunityRepository? repository;

  @override
  State<CommunityPostReceiptPage> createState() =>
      _CommunityPostReceiptPageState();
}

class _CommunityPostReceiptPageState extends State<CommunityPostReceiptPage> {
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  CommunityRepository? _repository;
  StreamSubscription<AuthState>? _auth;
  late Future<CommunityPost> _post;
  int _generation = 0;
  String? _visitOwner;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _bindOwner();
    _post = _load();
  }

  @override
  void didUpdateWidget(covariant CommunityPostReceiptPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        !identical(oldWidget.repository, widget.repository)) {
      _repository = widget.repository ?? _productionRepository();
      _generation++;
      _bindOwner();
      _post = _load();
    }
  }

  CommunityRepository? _productionRepository() {
    if (!AppEnvironment.communityConfigured) return null;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return null;
      }
      return CommunityRepository(supabase.client);
    } on AssertionError {
      return null;
    } on StateError {
      return null;
    }
  }

  String? _owner() {
    try {
      return _repository?.currentUserId;
    } on AuthException {
      return null;
    }
  }

  void _bindOwner() {
    unawaited(_auth?.cancel());
    _auth = null;
    final repository = _repository;
    _visitOwner = _owner();
    if (repository == null) return;
    var deliveredOwner = repository.communitySocialClient.auth.currentUser?.id;
    _auth = repository.communitySocialClient.auth.onAuthStateChange.listen((
      state,
    ) {
      final next = state.session?.user.id;
      final changed = next != deliveredOwner;
      deliveredOwner = next;
      if (!mounted || !identical(repository, _repository)) return;
      if (!changed && _owner() == _visitOwner) return;
      _generation++;
      _visitOwner = _owner();
      setState(() => _post = _load());
    }, onError: (Object _, StackTrace _) {});
  }

  bool _isCurrent(
    CommunityRepository repository,
    String owner,
    int generation,
  ) =>
      mounted &&
      identical(repository, _repository) &&
      _owner() == owner &&
      _visitOwner == owner &&
      _generation == generation;

  Future<CommunityPost> _load() async {
    final repository = _repository;
    final owner = _visitOwner;
    final generation = _generation;
    if (repository == null || owner == null) {
      throw const AuthException('Sign-in required');
    }
    if (!_uuid.hasMatch(widget.postId)) {
      throw const FormatException('Invalid Community post receipt destination');
    }
    final store = repository.communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Community post lookup is unavailable');
    }

    final lookup = store as CommunityPostLookupContract;
    return repository.runForCommunityOwner(
      () async {
        final posts = await lookup.loadPostsByIds([widget.postId]);
        if (!_isCurrent(repository, owner, generation)) {
          throw const AuthException('Community receipt owner changed');
        }
        if (posts.length != 1 || posts.single.authorId != owner) {
          throw StateError('Moderated post is unavailable to this owner');
        }
        var post = posts.single;
        try {
          final polls = await repository.loadCommunityPolls([post.id]);
          if (!_isCurrent(repository, owner, generation)) {
            throw const AuthException('Community receipt owner changed');
          }
          if (polls.length == 1 && polls.single.postId == post.id) {
            post = post.withPoll(polls.single);
          }
        } on AuthException {
          rethrow;
        } on Object {
          // Poll display is secondary to the owner being able to inspect the post.
        }
        return post;
      },
      ownerId: owner,
      isCurrentOwner: () => _isCurrent(repository, owner, generation),
    );
  }

  void _retry() => setState(() => _post = _load());

  @override
  void dispose() {
    _generation++;
    unawaited(_auth?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      title: Text(
        communityText(context, 'Post review result', 'نتيجة مراجعة المنشور'),
      ),
    ),
    body: FutureBuilder<CommunityPost>(
      future: _post,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    communityText(
                      context,
                      'This post could not be loaded for the current account.',
                      'تعذر تحميل هذا المنشور للحساب الحالي.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      communityText(context, 'Retry', 'إعادة المحاولة'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return _ReceiptPostBody(post: snapshot.requireData);
      },
    ),
  );
}

class _ReceiptPostBody extends StatelessWidget {
  const _ReceiptPostBody({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final poll = post.poll;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Chip(
            avatar: Icon(
              post.moderationStatus == CommunityPostModerationStatus.approved
                  ? Icons.check_circle_outline_rounded
                  : Icons.edit_note_rounded,
            ),
            label: Text(
              post.moderationStatus == CommunityPostModerationStatus.approved
                  ? communityText(context, 'Approved', 'تم الاعتماد')
                  : communityText(context, 'Needs changes', 'يحتاج تعديلات'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          post.body,
          textDirection: BilWrittenLanguageResolver.directionFor(
            post.body,
            fallback: Directionality.of(context),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (post.mediaItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ReceiptMediaGrid(
            items: post.mediaItems.take(4).toList(growable: false),
          ),
        ],
        if (poll != null) ...[
          const SizedBox(height: 16),
          _ReceiptPollPreview(postId: post.id, poll: poll),
        ],
      ],
    );
  }
}

class _ReceiptMediaGrid extends StatelessWidget {
  const _ReceiptMediaGrid({required this.items});
  final List<CommunityPostMedia> items;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: items.length == 1 ? 1 : 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1,
    ),
    itemBuilder: (context, index) {
      final item = items[index];
      return ClipRRect(
        key: Key('community-receipt-media-$index'),
        borderRadius: BorderRadius.circular(14),
        child: item.url == null
            ? const ColoredBox(
                color: Color(0xFFE8EBF0),
                child: Icon(Icons.broken_image_outlined),
              )
            : Image.network(
                item.url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFE8EBF0),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
      );
    },
  );
}

class _ReceiptPollPreview extends StatelessWidget {
  const _ReceiptPollPreview({required this.postId, required this.poll});
  final String postId;
  final CommunityPoll poll;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('community-receipt-poll-$postId'),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            poll.question,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Text(option.text),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
