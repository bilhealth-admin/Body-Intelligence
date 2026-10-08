import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../activity_rewards/community_moderation_visit.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../domain/community_polls.dart';
import 'community_copy.dart';
part 'community_post_moderation_widgets.dart';

class CommunityPostModerationPage extends StatefulWidget {
  const CommunityPostModerationPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityPostModerationPage> createState() =>
      _CommunityPostModerationPageState();
}

class _CommunityPostModerationPageState
    extends State<CommunityPostModerationPage> {
  CommunityRepository? _repository;
  late Future<_CommunityModerationQueue> _queue;
  final Set<String> _busyTargets = <String>{};
  CommunityModerationVisit? _visit;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _bindVisit();
    _queue = _load();
  }

  @override
  void didUpdateWidget(covariant CommunityPostModerationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _visit?.dispose();
      _repository = widget.repository ?? _productionRepository();
      _bindVisit();
      _queue = _load();
    }
  }

  @override
  void dispose() {
    _visit?.dispose();
    super.dispose();
  }

  void _bindVisit() {
    final repository = _repository;
    _visit = repository == null
        ? null
        : CommunityModerationVisit(
            repository: repository,
            isAttached: () => mounted && identical(repository, _repository),
            onRetired: _retireVisit,
          );
  }

  void _retireVisit() {
    if (!mounted) return;
    _busyTargets.clear();
    setState(() {
      _queue = Future<_CommunityModerationQueue>.error(
        const AuthException('Moderator session changed'),
      );
    });
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

  Future<_CommunityModerationQueue> _load() async {
    final repository = _repository;
    final visit = _visit;
    if (repository == null || visit == null || !visit.isCurrent) {
      throw const AuthException('Sign-in required');
    }
    await visit.requireFreshModerator();
    return visit.run(() async {
      final values = await Future.wait<Object>([
        repository.loadPendingPostsForModeration(),
        repository.loadHiddenPostsForModeration(),
        repository.loadOpenModerationReports(),
      ]);
      if (!visit.isCurrent) {
        throw const AuthException('Moderator session changed');
      }
      final posts = values[0] as List<CommunityPost>;
      final hiddenPosts = values[1] as List<CommunityPost>;
      final reports = values[2] as List<Map<String, dynamic>>;
      final reviewContent = await repository.hydrateModerationReviewContents([
        ...posts,
        ...hiddenPosts,
      ]);
      if (!visit.isCurrent) {
        throw const AuthException('Moderator session changed');
      }
      final byId = {for (final post in reviewContent) post.id: post};
      return _CommunityModerationQueue(
        posts: [for (final post in posts) byId[post.id] ?? post],
        hiddenPosts: [for (final post in hiddenPosts) byId[post.id] ?? post],
        reports: reports,
      );
    });
  }

  Future<void> _reloadAndReadback(CommunityModerationVisit visit) async {
    if (!visit.isCurrent || !mounted) return;
    final refreshed = _load();
    setState(() {
      _queue = refreshed;
    });
    await refreshed;
    if (!visit.isCurrent) {
      throw const AuthException('Moderator session changed');
    }
  }

  Future<void> _restorePost(CommunityPost post) async {
    final visit = _visit;
    final repository = _repository;
    if (visit == null ||
        repository == null ||
        !visit.isCurrent ||
        _busyTargets.contains(post.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          communityText(context, 'Restore post?', 'استعادة المنشور؟'),
        ),
        content: Text(
          communityText(
            context,
            'The post will become public again under its original audience rules.',
            'سيظهر المنشور مجددًا وفق إعدادات جمهوره الأصلية.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(communityText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            key: const Key('community-hidden-post-restore-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              communityText(context, 'Restore post', 'استعادة المنشور'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !visit.isCurrent) return;
    setState(() => _busyTargets.add(post.id));
    try {
      await visit.requireFreshModerator();
      await visit.run(
        () => repository.restoreHiddenPostAsModerator(postId: post.id),
      );
      if (!mounted || !visit.isCurrent) return;
      await _reloadAndReadback(visit);
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(context, 'Post restored.', 'تمت استعادة المنشور.'),
          ),
        ),
      );
    } on Object {
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not restore this post safely.',
              'تعذرت استعادة المنشور بأمان.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && visit.isCurrent) {
        setState(() => _busyTargets.remove(post.id));
      }
    }
  }

  Future<void> _refresh() async {
    final refreshed = _load();
    setState(() {
      _queue = refreshed;
    });
    await refreshed;
  }

  Future<bool> _confirmPostDecision(
    CommunityPostModerationDecision decision,
  ) async {
    final approving = decision == CommunityPostModerationDecision.approved;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              communityText(
                context,
                approving ? 'Approve this post?' : 'Reject this post?',
                approving ? 'اعتماد هذا المنشور؟' : 'رفض هذا المنشور؟',
              ),
            ),
            content: Text(
              communityText(
                context,
                approving
                    ? 'Approval makes the post visible under its audience rules. An eligible +5 AI token award is issued only when the server reward receipt confirms it; daily limits may result in no token grant.'
                    : 'The rejected post stays visible only to its author.',
                approving
                    ? 'سيجعل الاعتماد المنشور ظاهرًا وفق نطاق جمهوره. لا تُمنح +5 توكنات AI إلا إذا أكد إيصال المكافأة من الخادم الاستحقاق، وقد تؤدي الحدود اليومية إلى عدم منح توكنات.'
                    : 'سيظل المنشور المرفوض ظاهرًا لصاحبه فقط.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(communityText(context, 'Cancel', 'إلغاء')),
              ),
              FilledButton(
                key: const Key('community-post-moderation-confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  communityText(
                    context,
                    approving ? 'Approve' : 'Reject',
                    approving ? 'اعتماد' : 'رفض',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _decidePost(
    CommunityPost post,
    CommunityPostModerationDecision decision,
  ) async {
    final visit = _visit;
    final repository = _repository;
    if (visit == null ||
        repository == null ||
        !visit.isCurrent ||
        _busyTargets.contains(post.id) ||
        !await _confirmPostDecision(decision) ||
        !mounted ||
        !visit.isCurrent) {
      return;
    }
    setState(() => _busyTargets.add(post.id));
    try {
      await visit.requireFreshModerator();
      final result = await visit.run(
        () => repository.moderatePost(postId: post.id, decision: decision),
      );
      if (!mounted || !visit.isCurrent) return;
      await _reloadAndReadback(visit);
      if (!mounted || !visit.isCurrent) return;
      final approved =
          result.decision == CommunityPostModerationDecision.approved;
      final message = result.duplicate
          ? communityText(
              context,
              'This moderation decision was already saved.',
              'تم حفظ قرار المراجعة هذا من قبل.',
            )
          : approved && result.tokensGranted == 5
          ? communityText(
              context,
              'Post approved. 5 BIL AI Boost tokens were granted once.',
              'تم اعتماد المنشور ومنح 5 رموز BIL AI Boost مرة واحدة.',
            )
          : approved
          ? communityText(
              context,
              'Post approved. No AI token grant was confirmed for this decision.',
              'تم اعتماد المنشور، ولم تُؤكد منحة توكنات AI لهذا القرار.',
            )
          : communityText(
              context,
              'Post rejected. It remains private to its author.',
              'تم رفض المنشور وسيبقى خاصًا بصاحبه.',
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object {
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not save the moderation decision. Refresh and try again.',
              'تعذر حفظ قرار المراجعة. حدّث القائمة وحاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && visit.isCurrent) {
        setState(() => _busyTargets.remove(post.id));
      }
    }
  }

  Future<void> _resolveReport(
    Map<String, dynamic> report, {
    required bool removeContent,
  }) async {
    final id = report['id'];
    final visit = _visit;
    final repository = _repository;
    if (id is! String ||
        visit == null ||
        repository == null ||
        !visit.isCurrent ||
        _busyTargets.contains(id)) {
      return;
    }
    if (removeContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            communityText(
              context,
              'Remove reported content?',
              'إزالة المحتوى المُبلّغ عنه؟',
            ),
          ),
          content: Text(
            communityText(
              context,
              'This closes the report and removes the referenced post or message.',
              'سيؤدي ذلك إلى إغلاق البلاغ وإزالة المنشور أو الرسالة المشار إليها.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                communityText(context, 'Remove content', 'إزالة المحتوى'),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || !visit.isCurrent) return;
    }
    setState(() => _busyTargets.add(id));
    try {
      await visit.requireFreshModerator();
      await visit.run(
        () => repository.moderateReport(
          reportId: id,
          resolution: 'closed',
          action: removeContent ? 'remove_content' : 'none',
        ),
      );
      if (!mounted || !visit.isCurrent) return;
      await _reloadAndReadback(visit);
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Report decision saved.',
              'تم حفظ قرار البلاغ.',
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not resolve the report. Refresh and try again.',
              'تعذر حسم البلاغ. حدّث القائمة وحاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && visit.isCurrent) {
        setState(() => _busyTargets.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        communityText(context, 'Community moderation', 'مراجعة المجتمع'),
      ),
      actions: [
        IconButton(
          onPressed: _busyTargets.isEmpty ? _refresh : null,
          tooltip: communityText(context, 'Refresh', 'تحديث'),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<_CommunityModerationQueue>(
      future: _queue,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ModerationUnavailable(onRetry: _refresh);
        }
        final queue = snapshot.requireData;
        if (queue.posts.isEmpty &&
            queue.hiddenPosts.isEmpty &&
            queue.reports.isEmpty) {
          return Center(
            child: Text(
              communityText(
                context,
                'The moderation queue is clear.',
                'قائمة المراجعة خالية.',
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                communityText(
                  context,
                  'Posts awaiting human review',
                  'منشورات بانتظار المراجعة البشرية',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (queue.posts.isEmpty)
                Text(
                  communityText(
                    context,
                    'No pending posts.',
                    'لا توجد منشورات معلّقة.',
                  ),
                )
              else
                for (final post in queue.posts) ...[
                  _PendingPostCard(
                    post: post,
                    busy: _busyTargets.contains(post.id),
                    onApprove: () => _decidePost(
                      post,
                      CommunityPostModerationDecision.approved,
                    ),
                    onReject: () => _decidePost(
                      post,
                      CommunityPostModerationDecision.rejected,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 14),
              Text(
                communityText(context, 'Hidden posts', 'المنشورات المخفية'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (queue.hiddenPosts.isEmpty)
                Text(
                  communityText(
                    context,
                    'No hidden posts.',
                    'لا توجد منشورات مخفية.',
                  ),
                )
              else
                for (final post in queue.hiddenPosts) ...[
                  _HiddenPostCard(
                    post: post,
                    busy: _busyTargets.contains(post.id),
                    onRestore: () => _restorePost(post),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 14),
              Text(
                communityText(context, 'Open reports', 'البلاغات المفتوحة'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (queue.reports.isEmpty)
                Text(
                  communityText(
                    context,
                    'No open reports.',
                    'لا توجد بلاغات مفتوحة.',
                  ),
                )
              else
                for (final report in queue.reports) ...[
                  _OpenReportCard(
                    report: report,
                    busy: _busyTargets.contains(report['id']),
                    onClose: () => _resolveReport(report, removeContent: false),
                    onRemove: () => _resolveReport(report, removeContent: true),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    ),
  );
}
