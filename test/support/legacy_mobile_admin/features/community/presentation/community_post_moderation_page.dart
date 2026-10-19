import 'package:body_intelligence_log/shared/widgets/bil_pearl_material.dart';
import 'dart:async';
import 'package:body_intelligence_log/shared/widgets/bil_glass_press_feedback.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/bil_written_language_resolver.dart';
import 'package:body_intelligence_log/shared/widgets/bil_account_avatar.dart';
import 'package:body_intelligence_log/features/community/activity_rewards/community_moderation_visit.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_review_snapshot.dart';
import 'package:body_intelligence_log/features/safety_moderation/domain/ai_coach_safety_report.dart';
import '../../safety_moderation/presentation/ai_coach_safety_report_queue_section.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_return_button.dart';
part 'community_post_moderation_widgets.dart';
part 'community_post_reward_review.dart';
part 'community_post_moderation_load.dart';
part 'community_report_content_review.dart';
part 'community_ai_coach_report_review.dart';
part 'community_moderation_queue_tabs.dart';

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
  final Set<String> _decisionEditors = <String>{};
  final Map<String, CommunityReviewSnapshot> _reviewedPosts = {};
  final Map<String, String> _decisionIds = {};
  final Map<String, String> _aiCoachDecisionIds = {};
  final Map<String, _PendingReportDecision> _pendingReportDecisions = {};
  CommunityModerationVisit? _visit;
  bool _sessionRetired = false;

  void _updateModerationState(VoidCallback update) => setState(update);

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
    _sessionRetired = false;
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
    _pendingReportDecisions.clear();
    _reviewedPosts.clear();
    _decisionIds.clear();
    setState(() => _sessionRetired = true);
  }

  void _updateReportDecisionUi(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
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
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
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
    if (_sessionRetired) {
      _visit?.dispose();
      _bindVisit();
    }
    final refreshed = _load();
    setState(() {
      _queue = refreshed;
    });
    try {
      await refreshed;
    } on Object {
      // FutureBuilder keeps and displays this failed _queue with Retry.
      // Only a refresh gesture is handled here; decision readback must throw.
    }
  }

  Future<void> _rewardAction(
    CommunityRewardReview review,
    bool? approve,
  ) async {
    final visit = _visit;
    final repository = _repository;
    final postId = review.snapshot.post.id;
    if (visit == null ||
        repository == null ||
        !visit.isCurrent ||
        _busyTargets.contains(postId)) {
      return;
    }
    final reason = approve == false ? await _reviewReason(context) : '';
    final confirmedReason = reason;
    if (confirmedReason == null || !mounted || !visit.isCurrent) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text(
          communityText(
            context,
            'Confirm reward decision',
            'تأكيد قرار المكافأة',
          ),
        ),
        content: Text(
          communityText(
            context,
            'This affects the post author only. The server verifies eligibility, policy limits and the existing receipt before any credit.',
            'يخص القرار صاحب المنشور فقط. يتحقق الخادم من الاستحقاق والحدود وإيصال المنحة السابق قبل إضافة أي رصيد.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(communityText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            key: const Key('community-reward-decision-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(communityText(context, 'Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        !visit.isCurrent ||
        _busyTargets.contains(postId)) {
      return;
    }
    setState(() => _busyTargets.add(postId));
    try {
      await visit.requireFreshModerator();
      final status = await visit.run(
        () => approve == null
            ? repository.requestReviewedReward(review.snapshot)
            : repository.decideReviewedReward(
                review,
                approve: approve,
                reason: confirmedReason,
              ),
      );
      await _reloadAndReadback(visit);
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_rewardStatusText(context, status))),
      );
    } on Object {
      if (!mounted || !visit.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'The reward was not confirmed. Refresh and retry; no duplicate award will be issued.',
              'لم تُؤكد المكافأة. حدّث ثم أعد المحاولة؛ لن تُصرف منحة مكررة.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && visit.isCurrent) {
        setState(() => _busyTargets.remove(postId));
      }
    }
  }

  Future<bool> _confirmPostDecision(
    CommunityPostModerationDecision decision, {
    bool publishOnly = false,
  }) async {
    final approving = decision == CommunityPostModerationDecision.approved;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => BilPearlMaterialAlertDialog(
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
                    ? publishOnly
                          ? 'Publish this post without an AI award. A separate reward request can be reviewed later.'
                          : 'Approval makes the post visible under its audience rules. An eligible +5 AI token award is issued only when the server reward receipt confirms it; daily limits may result in no token grant.'
                    : 'The rejected post stays visible only to its author.',
                approving
                    ? publishOnly
                          ? 'نشر هذا المنشور دون مكافأة AI. يمكن مراجعة طلب مكافأة منفصل لاحقًا.'
                          : 'سيجعل الاعتماد المنشور ظاهرًا وفق نطاق جمهوره. لا تُمنح +5 توكنات AI إلا إذا أكد إيصال المكافأة من الخادم الاستحقاق، وقد تؤدي الحدود اليومية إلى عدم منح توكنات.'
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
    CommunityPostModerationDecision decision, {
    bool publishOnly = false,
  }) async {
    final visit = _visit;
    final repository = _repository;
    final reviewedAtTap = _reviewedPosts[post.id];
    if (visit == null ||
        repository == null ||
        !visit.isCurrent ||
        _busyTargets.contains(post.id) ||
        reviewedAtTap == null ||
        !_decisionEditors.add(post.id)) {
      return;
    }
    String? reason;
    try {
      if (await _confirmPostDecision(decision, publishOnly: publishOnly) &&
          mounted &&
          visit.isCurrent) {
        reason = decision == CommunityPostModerationDecision.rejected
            ? await _reviewReason(context)
            : '';
      }
    } finally {
      _decisionEditors.remove(post.id);
    }
    final confirmedReason = reason;
    if (confirmedReason == null || !mounted || !visit.isCurrent) return;
    setState(() => _busyTargets.add(post.id));
    try {
      await visit.requireFreshModerator();
      final result = await visit.run(
        () => repository.moderateReviewedPost(
          snapshot: reviewedAtTap,
          decision: decision,
          reason: confirmedReason,
          publishOnly: publishOnly,
          operationId: _decisionIds.putIfAbsent(
            '${post.id}:${reviewedAtTap.revision}:${decision.name}:$publishOnly:$confirmedReason',
            () => const Uuid().v4(),
          ),
        ),
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

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: 1,
    child: Scaffold(
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        title: Text(
          communityText(context, 'Community moderation', 'مراجعة المجتمع'),
        ),
        actions: [
          IconButton(
            onPressed: _busyTargets.isEmpty ? _refresh : null,
            tooltip: communityText(context, 'Refresh', 'تحديث'),
            icon: const BilGlassPressFeedback(
              child: Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(
              key: const Key('ai-coach-report-admin-tab'),
              text: communityText(
                context,
                'AI Coach reports',
                'بلاغات AI Coach',
              ),
            ),
            Tab(
              key: const Key('community-report-admin-tab'),
              text: communityText(
                context,
                'Community reports',
                'بلاغات المجتمع',
              ),
            ),
          ],
        ),
      ),
      body: _sessionRetired
          ? _ModerationUnavailable(onRetry: _refresh, accessDenied: true)
          : FutureBuilder<_CommunityModerationQueue>(
              future: _queue,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ModerationUnavailable(
                    onRetry: _refresh,
                    accessDenied:
                        snapshot.error is AuthException ||
                        (snapshot.error is PostgrestException &&
                            (snapshot.error as PostgrestException).code ==
                                '42501'),
                  );
                }
                final queue = snapshot.requireData;
                return TabBarView(
                  children: [
                    _aiCoachReportsTab(queue),
                    _communityReportsTab(queue),
                  ],
                );
              },
            ),
    ),
  );
}
