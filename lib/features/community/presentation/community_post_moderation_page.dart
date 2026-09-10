import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_copy.dart';

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

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _queue = _load();
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
    if (repository == null) {
      throw const AuthException('Sign-in required');
    }
    final posts = await repository.loadPendingPostsForModeration();
    final reports = await repository.loadOpenModerationReports();
    return _CommunityModerationQueue(posts: posts, reports: reports);
  }

  Future<void> _refresh() async {
    final refreshed = _load();
    setState(() => _queue = refreshed);
    await refreshed;
  }

  void _reload() => setState(() {
    _queue = _load();
  });

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
                    ? 'Approval makes the post visible under its audience rules and grants the author 5 BIL AI Boost tokens once.'
                    : 'The rejected post stays visible only to its author.',
                approving
                    ? 'سيجعل الاعتماد المنشور ظاهرًا وفق نطاق جمهوره، ويمنح صاحبه 5 رموز BIL AI Boost مرة واحدة.'
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
    if (_busyTargets.contains(post.id) ||
        !await _confirmPostDecision(decision) ||
        !mounted) {
      return;
    }
    setState(() => _busyTargets.add(post.id));
    try {
      final result = await _repository!.moderatePost(
        postId: post.id,
        decision: decision,
      );
      if (!mounted) return;
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
              'Post approved. No duplicate token grant was added.',
              'تم اعتماد المنشور دون إضافة منحة رموز مكررة.',
            )
          : communityText(
              context,
              'Post rejected. It remains private to its author.',
              'تم رفض المنشور وسيبقى خاصًا بصاحبه.',
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _reload();
    } on Object {
      if (!mounted) return;
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
      if (mounted) setState(() => _busyTargets.remove(post.id));
    }
  }

  Future<void> _resolveReport(
    Map<String, dynamic> report, {
    required bool removeContent,
  }) async {
    final id = report['id'];
    if (id is! String || _busyTargets.contains(id)) return;
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
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busyTargets.add(id));
    try {
      await _repository!.moderateReport(
        reportId: id,
        resolution: 'closed',
        action: removeContent ? 'remove_content' : 'none',
      );
      if (!mounted) return;
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
      _reload();
    } on Object {
      if (!mounted) return;
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
      if (mounted) setState(() => _busyTargets.remove(id));
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
        if (queue.posts.isEmpty && queue.reports.isEmpty) {
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

class _PendingPostCard extends StatelessWidget {
  const _PendingPostCard({
    required this.post,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final CommunityPost post;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('community-moderation-post-${post.id}'),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BilAccountAvatar(radius: 20, networkUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  post.authorName ??
                      communityText(context, 'BIL member', 'عضو BIL'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(post.createdAt.toLocal()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            post.body,
            textDirection: BilWrittenLanguageResolver.directionFor(
              post.body,
              fallback: Directionality.of(context),
            ),
          ),
          if (post.hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: (post.mediaAspectRatio ?? 1)
                    .clamp(0.8, 1.91)
                    .toDouble(),
                child: post.mediaUrl == null
                    ? const ColoredBox(
                        color: Color(0xFFE8EBF0),
                        child: Icon(Icons.broken_image_outlined),
                      )
                    : Image.network(
                        post.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFE8EBF0),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: Key('community-moderation-approve-${post.id}'),
                onPressed: busy ? null : onApprove,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(communityText(context, 'Approve', 'اعتماد')),
              ),
              OutlinedButton.icon(
                key: Key('community-moderation-reject-${post.id}'),
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(communityText(context, 'Reject', 'رفض')),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OpenReportCard extends StatelessWidget {
  const _OpenReportCard({
    required this.report,
    required this.busy,
    required this.onClose,
    required this.onRemove,
  });

  final Map<String, dynamic> report;
  final bool busy;
  final VoidCallback onClose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final targetKind = report['target_kind']?.toString() ?? 'unknown';
    final canRemove = const {'post', 'message'}.contains(targetKind);
    return Card(
      key: Key('community-moderation-report-${report['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$targetKind · ${report['target_id']}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText(report['reason']?.toString() ?? ''),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: busy ? null : onClose,
                  child: Text(
                    communityText(context, 'Close report', 'إغلاق البلاغ'),
                  ),
                ),
                if (canRemove)
                  OutlinedButton(
                    onPressed: busy ? null : onRemove,
                    child: Text(
                      communityText(
                        context,
                        'Remove reported content',
                        'إزالة المحتوى المُبلّغ عنه',
                      ),
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

class _ModerationUnavailable extends StatelessWidget {
  const _ModerationUnavailable({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 56),
          const SizedBox(height: 14),
          Text(
            communityText(
              context,
              'Moderator access is required.',
              'يتطلب هذا القسم صلاحية مشرف.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            communityText(
              context,
              'The server verifies moderator access before returning any pending content.',
              'يتحقق الخادم من صلاحية المشرف قبل إرجاع أي محتوى معلّق.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );
}

class _CommunityModerationQueue {
  const _CommunityModerationQueue({required this.posts, required this.reports});

  final List<CommunityPost> posts;
  final List<Map<String, dynamic>> reports;
}
