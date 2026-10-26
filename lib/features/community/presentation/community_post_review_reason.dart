import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_copy.dart';

/// Display only: a confirmed author-only explanation; no review/grant action.
class CommunityPostReviewReason extends StatefulWidget {
  const CommunityPostReviewReason({
    super.key,
    required this.repository,
    required this.post,
    this.ownerIsCurrent,
    this.ownerChanges,
  });
  final CommunityRepository repository;
  final CommunityPost post;
  final ValueGetter<bool>? ownerIsCurrent;
  final Listenable? ownerChanges;
  @override
  State<CommunityPostReviewReason> createState() => _PostReviewReasonState();
}

class _PostReviewReasonState extends State<CommunityPostReviewReason> {
  late Future<String?> _reason;
  StreamSubscription<AuthState>? _auth;
  String? _deliveredOwner;
  bool _retired = false;
  bool get _current {
    try {
      return !_retired &&
          (widget.ownerIsCurrent?.call() ?? true) &&
          widget.repository.currentUserId == widget.post.authorId;
    } on AuthException {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _retired = false;
    final auth = widget.repository.communitySocialClient.auth;
    _deliveredOwner = auth.currentUser?.id;
    _auth = auth.onAuthStateChange.listen((event) {
      final next = event.session?.user.id;
      if (next != _deliveredOwner) _retire();
      _deliveredOwner = next;
    }, onError: (Object _, StackTrace _) => _retire());
    widget.ownerChanges?.addListener(_retire);
    _reason = _current
        ? widget.repository.loadMyPostReviewReason(widget.post)
        : Future.value(null);
  }

  void _retire() {
    if (mounted) setState(() => _retired = true);
  }

  void _unbind(CommunityPostReviewReason old) {
    old.ownerChanges?.removeListener(_retire);
    unawaited(_auth?.cancel());
    _auth = null;
  }

  @override
  void didUpdateWidget(covariant CommunityPostReviewReason old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository ||
        old.post.id != widget.post.id ||
        old.post.body != widget.post.body ||
        old.ownerChanges != widget.ownerChanges ||
        _retired) {
      _unbind(old);
      _bind();
    }
  }

  @override
  void dispose() {
    _unbind(widget);
    super.dispose();
  }

  void _retry() {
    if (!_current) return;
    final pending = widget.repository.loadMyPostReviewReason(widget.post);
    setState(() {
      _reason = pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: _reason,
      builder: (context, snapshot) {
        if (!_current || snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return TextButton.icon(
            key: const Key('community-review-reason-retry'),
            onPressed: _retry,
            icon: const BilNavigationFeedback(
              child: Icon(Icons.refresh_rounded),
            ),
            label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
          );
        }
        final reason = snapshot.data;
        if (reason == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                communityText(
                  context,
                  'Reason for this decision',
                  'سبب هذا القرار',
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                reason,
                textDirection: BilWrittenLanguageResolver.directionFor(
                  reason,
                  fallback: Directionality.of(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
