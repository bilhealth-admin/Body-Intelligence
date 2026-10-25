import '../../../app/theme/bil_flagship_tokens.dart';
import '../../weight/providers/weight_provider.dart';
import '../services/bil_smart_plan_nutrition_goals.dart';
import '../../intelligence_center/services/coach_context_provider.dart';
import '../../../shared/widgets/bil_modal_bottom_sheet.dart';
import '../../../shared/widgets/bil_premium_trust_surface.dart';
import '../services/bil_smart_plan_clock.dart';
import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../intelligence_center/presentation/ai_coach_report_confirmation_sheet.dart';
import '../../intelligence_center/services/ai_coach_safety_report_service.dart';
import '../../intelligence_center/services/local_model_gateway.dart';
import '../data/bil_smart_plan_sync.dart';
import '../../../app/services/data_export_service.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/database/database_provider.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../intelligence_center/domain/bil_action_receipt.dart';
import '../services/bil_smart_plan_coach.dart';
import '../services/bil_smart_plan_workout.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../../meal_planner/domain/meal_plan.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../data/bil_smart_plan_repository.dart';
import '../domain/bil_smart_plan.dart';
import '../domain/bil_smart_plan_engine.dart';
import '../domain/bil_smart_plan_review.dart';
import '../services/bil_smart_plan_catalog.dart';
import '../services/bil_smart_plan_prescriptions.dart';
import 'bil_smart_plan_panel.dart';
import 'bil_smart_plan_load_failure.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bil_smart_plan_phase_copy.dart';
import '../../wellness/domain/wellness_content_pack.dart';
import '../../wellness/services/wellness_content_pack_manager.dart';

part 'bil_smart_plan_actions.dart';
part 'bil_smart_plan_sections.dart';
part 'bil_smart_plan_privacy_surface.dart';
part 'bil_smart_plan_creation_sheet.dart';
part 'bil_smart_plan_session.dart';
part 'bil_smart_plan_meal_flow.dart';
part 'bil_smart_plan_context_consent.dart';
part 'bil_smart_plan_adaptation.dart';
part 'bil_smart_plan_history.dart';
part 'bil_smart_plan_drafts.dart';
part 'bil_smart_plan_sync_review.dart';
part 'bil_smart_plan_conflict_panel.dart';

Color _smartPlanActionInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? BilFlagshipTokens.navy800
    : Theme.of(context).colorScheme.primary;

String _smartPlanText(BuildContext context, String english, String arabic) {
  final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  if (tag == 'ar') return arabic;
  if (tag == 'en') return english;
  final translated = RuntimeCopy.resolve(english, tag);
  if (translated == null) return english;
  // Sentence fragments surround measured values; preserve their spacing even
  // when a translated catalogue entry has been trimmed by its provider.
  final leading = RegExp(r'^\s*').firstMatch(english)!.group(0)!;
  final trailing = RegExp(r'\s*$').firstMatch(english)!.group(0)!;
  return '$leading${translated.trim()}$trailing';
}

/// Local-first plan workspace. The authenticated owner and verified plan gate
/// are provided by AppRouter; no app-store or billing contract is changed.
class BilSmartPlanPage extends ConsumerStatefulWidget {
  const BilSmartPlanPage({
    super.key,
    this.toolRequest,
    this.privacyOnly = false,
  });
  final BilSmartPlanToolRequest? toolRequest;
  final bool privacyOnly;

  @override
  ConsumerState<BilSmartPlanPage> createState() => _BilSmartPlanPageState();
}

class _BilSmartPlanPageState extends ConsumerState<BilSmartPlanPage> {
  void _mutate(VoidCallback update) => setState(update);

  BilSmartPlan? _plan;
  bool _reviewingDraft = false;
  DateTime? _requestedDay;
  bool _busy = true;
  String? _error;
  int _tab = 0;
  int _weekOffset = 0;
  ProviderSubscription<String?>? _authEvents;
  int _ownerEpoch = 0;
  int _loadGeneration = 0;
  Timer? _dayRefresh;
  bool _toolOpened = false;
  bool _catalogBlocked = false;
  bool _confirmationOpen = false;
  int _reviewDepth = 0;

  String _t(String en, String ar) => _smartPlanText(context, en, ar);

  /// Keep a recovered same-owner plan visible, but prohibit writes until the
  /// source and supporting catalog pass an explicit fresh read.
  bool get _unverifiedPlanReadOnly =>
      _plan != null && _catalogBlocked && _error != null;

  Future<T?> _reviewSurface<T>(Future<T?> Function() show) async {
    setState(() => _reviewDepth++);
    try {
      return await show();
    } finally {
      if (mounted) setState(() => _reviewDepth--);
    }
  }

  Future<bool?> _confirmDialog({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    if (_confirmationOpen || !mounted) {
      return null;
    }
    _confirmationOpen = true;
    try {
      return await _reviewSurface(
        () => showDialog<bool>(context: context, builder: builder),
      );
    } finally {
      _confirmationOpen = false;
    }
  }

  String _failureText() => smartPlanLoadFailureMessage(_error ?? '', _t);

  String? get _owner => ref.read(verifiedEntitlementOwnerIdProvider);

  BilSmartPlanRepository get _repository {
    final epoch = _ownerEpoch;
    return BilSmartPlanRepository(
      preferences: ref.read(preferencesRepositoryProvider),
      currentOwnerId: () => mounted && epoch == _ownerEpoch ? _owner : null,
    );
  }

  void _checkAccess() {
    if (_unverifiedPlanReadOnly) {
      throw StateError('smart_plan_catalog_unavailable');
    }
    if (widget.privacyOnly) {
      throw StateError('smart_plan_verified_subscription_required');
    }
    widget.toolRequest?.checkAccess?.call();
    final access = ref.read(verifiedSubscriptionAccessProvider);
    if (!mounted ||
        _owner == null ||
        access.isLoading ||
        access.hasError ||
        access.value?.authority != EntitlementAuthority.verifiedServer ||
        access.value?.plan == CommercePlan.free) {
      throw StateError('smart_plan_verified_subscription_required');
    }
  }

  void _returnReceipt(BilSmartPlan saved) {
    if (widget.toolRequest == null || !mounted) return;
    context.pop(
      BilActionReceipt(
        actionId: saved.id,
        committed: true,
        completedAt: ref.read(bilSmartPlanClockProvider)(),
        entityType: 'smart_plan',
        entityId: saved.id,
        toolId: widget.toolRequest!.toolId,
        after: {'revision': saved.revision},
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _authEvents = ref.listenManual(verifiedEntitlementOwnerIdProvider, (
      _,
      next,
    ) {
      _ownerEpoch++;
      if (!mounted) return;
      final pageRoute = ModalRoute.of(context);
      if (_reviewDepth > 0 && pageRoute != null) {
        Navigator.of(context).popUntil((route) => route == pageRoute);
      }
      setState(() {
        _plan = null;
        _busy = true;
        _error = null;
      });
      unawaited(_load());
    });
    unawaited(_load());
    _dayRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authEvents?.close();
    _dayRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final owner = _owner;
    final currentLocalOwner = ref
        .read(preferencesRepositoryProvider)
        .localOwnerId;
    if (owner == null || currentLocalOwner != owner) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'sign_in_required';
          _plan = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    BilSmartPlan? readPlan;
    var planRead = false;
    try {
      final plan = await _repository.readFor(owner);
      readPlan = plan;
      planRead = true;
      if (!mounted || _owner != owner || generation != _loadGeneration) return;
      var catalogBlocked = false;
      if (plan != null) {
        final dietary = await ref
            .read(dietaryPreferencesRepositoryProvider)
            .read();
        try {
          await const BilSmartPlanCatalog().validate(plan, dietary);
        } on StateError {
          catalogBlocked = true;
        }
      }
      if (!mounted || _owner != owner || generation != _loadGeneration) return;
      final request = widget.privacyOnly ? null : widget.toolRequest;
      if (request?.arguments['planId'] != null &&
          (plan?.id != request!.arguments['planId'] ||
              plan?.revision != request.arguments['revision'])) {
        throw StateError('smart_plan_revision_conflict');
      }
      final selectedDate = request?.toolId == 'preview_smart_plan_day'
          ? BilPlanDate.parse(request!.arguments['date'] as String)
          : null;
      setState(() {
        _requestedDay = selectedDate;
        _plan = plan;
        _reviewingDraft = false;
        _catalogBlocked = catalogBlocked;
        _error = null;
        _busy = false;
      });
      if (!catalogBlocked && !_toolOpened && widget.toolRequest != null) {
        _toolOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || generation != _loadGeneration) return;
          final request = widget.toolRequest!;
          if (request.toolId == 'create_smart_plan_draft') {
            await _createPlan();
          } else if (request.toolId == 'record_smart_plan_workout' &&
              plan != null) {
            final day = plan.onDate(
              BilPlanDate.parse(request.arguments['date']! as String),
            );
            if (day != null && day.workout?.completed == false) {
              await _confirmWorkout(day);
            }
          } else if (request.toolId == 'request_smart_plan_revision') {
            setState(() => _tab = 1);
            final hint = request.revisionHint;
            final selected = hint?.session(
              plan!,
              ref.read(bilSmartPlanClockProvider)(),
            );
            if (selected != null) {
              await _deferDay(selected, initialReason: hint!.reason);
            }
          }
        });
      }
    } on Object catch (error) {
      if (!mounted ||
          _owner != owner ||
          generation != _loadGeneration ||
          ref.read(preferencesRepositoryProvider).localOwnerId != owner) {
        return;
      }
      // Sanitize the failure: do not show raw repository/exception contents.
      // A successful local read may still fail later during catalog/dietary
      // verification. In that case keep the recovered plan in memory, while
      // withholding actions until a fresh verification succeeds.
      final failureCode = classifySmartPlanLoadFailure(
        error,
        duringCatalog: planRead,
      );
      debugPrint('BIL My Plan recoverable load failure: $failureCode');
      setState(() {
        if (failureCode == 'smart_plan_owner_mismatch' ||
            failureCode == 'smart_plan_owner_changed') {
          _plan = null;
          _catalogBlocked = true;
        } else {
          if (readPlan != null) _plan = readPlan;
          // Retain the previous same-owner plan on a transient storage error,
          // but do not act on a copy that has not just passed validation.
          if (_plan != null) _catalogBlocked = true;
        }
        _busy = false;
        _error = failureCode;
      });
    }
  }

  Future<void> _save(BilSmartPlan next, {required int prior}) async {
    final owner = _owner;
    if (owner == null || next.ownerId != owner) return;
    final epoch = _ownerEpoch;
    final repository = _repository;
    setState(() => _busy = true);
    try {
      _checkAccess();
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      await const BilSmartPlanCatalog().validate(next, dietary);
      _checkAccess();
      if (epoch != _ownerEpoch) throw StateError('smart_plan_owner_changed');
      final replacing = prior == 0 && _plan != null && _plan!.id != next.id;
      final saved = replacing
          ? await repository.stageDraft(next, approved: _plan!)
          : _reviewingDraft
          ? await repository.activateDraft(next)
          : await repository.save(next, expectedRevision: prior);
      if (!mounted || _owner != owner) return;
      setState(() {
        _plan = saved;
        _reviewingDraft = replacing;
        _busy = false;
        _error = null;
      });
      ref.invalidate(coachContextSnapshotProvider);
      _returnReceipt(saved);
    } on Object catch (error) {
      if (!mounted || _owner != owner) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
      // Keep the failure visible. Reload is explicit and must not erase it.
    }
  }

  void _selectMenu(String action) {
    if (_unverifiedPlanReadOnly &&
        !const {'refresh', 'export', 'report'}.contains(action)) {
      return;
    }
    switch (action) {
      case 'new-draft':
        unawaited(_createPlan());
      case 'review-draft':
        unawaited(_openDraft());
      case 'approved-plan':
        unawaited(_load());
      case 'previous-plans':
        unawaited(_showPreviousPlans());
      case 'memory':
        unawaited(_sharePlanWithCoach());
      case 'extended-memory':
        unawaited(_shareExtendedPlanContext());
      case 'report':
        unawaited(_reportPlan());
      case 'export':
        unawaited(_exportPlan());
      case 'delete':
        unawaited(_reviewingDraft ? _discardDraft() : _deletePlan());
      case 'refresh':
        unawaited(_load());
      case 'pause':
        unawaited(_changeStatus(BilPlanStatus.paused));
      case 'sync':
        unawaited(_syncPlan());
      case 'revoke':
        unawaited(_syncPlan(revoke: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.privacyOnly) return _privacySurface();
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;
    final readOnly = _unverifiedPlanReadOnly;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('My Plan', 'خطتي')),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('bil-smart-plan-options'),
            enabled: !_busy,
            tooltip: _t('Plan options', 'خيارات الخطة'),
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: _selectMenu,
            itemBuilder: (_) => [
              if (plan != null) ...[
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'new-draft',
                  child: Text(_t('Create another draft', 'إنشاء مسودة أخرى')),
                ),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'review-draft',
                  child: Text(
                    _t('Review pending draft', 'مراجعة المسودة المعلقة'),
                  ),
                ),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'approved-plan',
                  child: Text(
                    _t('Current saved plan', 'الخطة المحفوظة الحالية'),
                  ),
                ),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'previous-plans',
                  child: Text(
                    _t(
                      'Previous plans on this device',
                      'الخطط السابقة على هذا الجهاز',
                    ),
                  ),
                ),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'memory',
                  child: Text(_t('Coach plan memory', 'ذاكرة الخطة للمدرب')),
                ),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'extended-memory',
                  child: Text(
                    _t('Coach context details', 'تفاصيل سياق المدرب'),
                  ),
                ),
                if (plan.status == BilPlanStatus.active)
                  PopupMenuItem(
                    enabled: !readOnly,
                    value: 'pause',
                    child: Text(_t('Pause plan', 'إيقاف مؤقت')),
                  ),
                PopupMenuItem(
                  value: 'export',
                  child: Text(_t('Export plan', 'تصدير الخطة')),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Text(_t('Report plan', 'الإبلاغ عن الخطة')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'delete',
                  child: Text(_t('Delete plan', 'حذف الخطة')),
                ),
              ],
              // The released cloud capability also exposes deletion sync after local removal.
              if (const bool.fromEnvironment(
                'BIL_SMART_PLAN_CLOUD_ENABLED',
              )) ...[
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'sync',
                  child: Text(_t('Sync plan', 'مزامنة الخطة')),
                ),
                PopupMenuItem(
                  enabled: !readOnly,
                  value: 'revoke',
                  child: Text(_t('Stop backup', 'إيقاف النسخ')),
                ),
              ],
              PopupMenuItem(
                value: 'refresh',
                child: Text(_t('Refresh', 'تحديث')),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BilPearlBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  if (_busy && _reviewDepth == 0) _loadingPanel(),
                  if (_error != null)
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _failureText(),
                            key: const ValueKey('bil-smart-plan-error'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const ValueKey('bil-smart-plan-retry'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _smartPlanActionInk(context),
                            ),
                            onPressed: _busy ? null : _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(_t('Try again', 'إعادة المحاولة')),
                          ),
                        ],
                      ),
                    ),
                  if (!_busy && plan == null && _error == null)
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 30,
                            color: _smartPlanActionInk(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _t(
                              'Your next step, made clear.',
                              'خطوتك القادمة أوضح.',
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t(
                              'Choose your duration and focus. Review your draft before activating it.',
                              'اختر المدة والتركيز، ثم راجع مسودة خطتك قبل تفعيلها.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const ValueKey('bil-smart-plan-create'),
                            onPressed: _createPlan,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(_t('Create plan', 'إنشاء خطة')),
                          ),
                        ],
                      ),
                    ),
                  if (plan != null) ...[
                    _overview(plan),
                    if (_reviewingDraft) _draftNotice(),
                    if (_catalogBlocked)
                      _panel(
                        child: Text(
                          _error == 'smart_plan_catalog_unavailable' ||
                                  _error == 'smart_plan_storage_unavailable'
                              ? _t(
                                  'Your previous plan is shown read-only until its data can be verified. Retry to restore full access.',
                                  'تظهر خطتك السابقة للقراءة فقط حتى التحقق من بياناتها. أعد المحاولة لاستعادة الوصول الكامل.',
                                )
                              : _t(
                                  'Your saved plan needs review because the exercise catalog or dietary restrictions changed. Its contents will not be suggested until reviewed. You can export or delete it from Plan options.',
                                  'تحتاج خطتك المحفوظة للمراجعة بسبب تغير كتالوج التمارين أو قيود الطعام. لن تُعرض مقترحاتها قبل المراجعة. يمكنك تصديرها أو حذفها من خيارات الخطة.',
                                ),
                          key: const ValueKey('bil-smart-plan-catalog-review'),
                        ),
                      ),
                    if (!_catalogBlocked)
                      Wrap(
                        key: const ValueKey('bil-smart-plan-tabs'),
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final tab in [
                            (
                              0,
                              _requestedDay == null ||
                                      BilPlanDate.iso(_requestedDay!) ==
                                          BilPlanDate.iso(
                                            ref.read(
                                              bilSmartPlanClockProvider,
                                            )(),
                                          )
                                  ? _t('Today', 'اليوم')
                                  : _t('Selected day', 'اليوم المختار'),
                            ),
                            (1, _t('Schedule', 'الجدول')),
                            (2, _t('Progress', 'التقدم')),
                          ])
                            Semantics(
                              selected: _tab == tab.$1,
                              child: TextButton(
                                key: ValueKey('bil-smart-plan-tab-${tab.$1}'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _tab == tab.$1
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                  backgroundColor: _tab == tab.$1
                                      ? scheme.primary
                                      : Colors.transparent,
                                  minimumSize: const Size(48, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 17,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                                onPressed: () => setState(() => _tab = tab.$1),
                                child: Text(tab.$2),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (!_catalogBlocked && _tab == 0) _today(plan),
                    if (!_catalogBlocked && _tab == 1) _schedule(plan),
                    if (!_catalogBlocked && _tab == 2) _progress(plan),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'BIL helps organize fitness and nutrition. For medical decisions, consult a qualified professional.',
                      'BIL لتنظيم التغذية والرياضة. استشر مختصًا للقرارات الطبية.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
