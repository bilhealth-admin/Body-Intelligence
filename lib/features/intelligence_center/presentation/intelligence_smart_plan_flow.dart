part of 'intelligence_center_page.dart';

extension _SmartPlanCoachFlow on _IntelligenceCenterPageState {
  String? _smartPlanOwnerId() => AppEnvironment.supabaseRuntimeReady
      ? Supabase.instance.client.auth.currentUser?.id
      : null;

  Future<bool> _answerSmartPlanIntent(String text, String locale) async {
    // A weight-chart/report request (including a correction of an unwanted
    // plan) must reach the verified read path, never the Smart Plan editor.
    if (isCoachWeightHistoryReadRequest(text) || isCoachPlanNegated(text)) {
      return false;
    }
    final recentUsers = messages
        .where(
          (m) =>
              m.role == IntelligenceMessageRole.user &&
              DateTime.now().difference(m.createdAt).inMinutes < 15,
        )
        .map((m) => m.text)
        .toList();
    if (recentUsers.isEmpty || recentUsers.last != text) recentUsers.add(text);
    final requestIntent = classifyCoachPlanSequence(recentUsers);
    final intent = requestIntent.createsPlan
        ? BilSmartPlanIntent.open
        : smartPlanIntent(text);
    if (intent == BilSmartPlanIntent.none) return false;
    const engine = IntelligenceCenterEngine();
    if (engine.requiresSafetyResponse(text)) {
      final reply = await engine.answer(
        question: text,
        arabic: locale == 'ar',
        localeCode: locale,
      );
      if (mounted) {
        _appendToolReceipt(reply.message.text, verifiedResult: false);
      }
      return true;
    }
    if (smartPlanGoalNeedsReview(text)) {
      _appendToolReceipt(
        intelligenceTextFor(
          locale,
          'A weight target with a one-week deadline needs an individual safety review. I have not saved it as your current weight or approved that deadline. You can open My Plan to review a general schedule.',
          'الوزن المستهدف خلال أسبوع يحتاج مراجعة سلامة فردية. لم أسجله كوزنك الحالي ولم أعتمد الموعد تلقائيًا. يمكنك فتح «خطتي» لمراجعة جدول عام.',
        ),
        verifiedResult: false,
      );
      return true;
    }
    if (intent == BilSmartPlanIntent.open) {
      final request = requestIntent;
      if (request.createsPlan) {
        final action = const CoachActionAdmission().admitProposal(
          const BilToolRegistry().createAction(
            name: 'create_smart_plan_draft',
            arguments: {
              if (request.horizon != null) 'horizon': request.horizon,
              if (request.planFocus != null) 'focus': request.planFocus,
            },
            label: intelligenceTextFor(
              locale,
              'Review plan draft',
              'مراجعة مسودة الخطة',
            ),
          )!,
        );
        if (action != null) await _executeAction(action);
      } else {
        await context.push('/smart-plan');
      }
      return true;
    }
    final preferences = ref.read(preferencesRepositoryProvider);
    final owner = _smartPlanOwnerId();
    final epoch = conversationPersistenceEpoch;
    final plans = BilSmartPlanRepository(
      preferences: preferences,
      currentOwnerId: () => mounted && conversationPersistenceEpoch == epoch
          ? _smartPlanOwnerId()
          : null,
    );
    if (owner == null) return false;
    final plan = await plans.readFor(owner);
    if (!mounted || conversationPersistenceEpoch != epoch) return true;
    if (intent == BilSmartPlanIntent.today) {
      final action = const BilToolRegistry().createAction(
        name: 'preview_smart_plan_day',
        arguments: const {},
        label: intelligenceTextFor(locale, 'Today’s plan', 'خطة اليوم'),
      )!;
      await _executeAction(action);
      return true;
    }
    if (plan == null) {
      _appendToolReceipt(
        intelligenceTextFor(
          locale,
          'No saved plan yet. Open My Plan to review a draft.',
          'لا توجد خطة محفوظة بعد. افتح «خطتي» لمراجعة مسودة.',
        ),
        verifiedResult: false,
      );
      return true;
    }
    final action = const CoachActionAdmission().admitProposal(
      const BilToolRegistry().createAction(
        name: intent == BilSmartPlanIntent.revise
            ? 'request_smart_plan_revision'
            : 'record_smart_plan_workout',
        arguments: {
          'planId': plan.id,
          'revision': plan.revision,
          if (intent == BilSmartPlanIntent.completedWorkout)
            'date': BilPlanDate.iso(DateTime.now()),
        },
        label: intelligenceTextFor(
          locale,
          'Review plan action',
          'مراجعة إجراء الخطة',
        ),
      )!,
    );
    if (action != null) {
      if (intent == BilSmartPlanIntent.revise) {
        await _executeSmartPlanAction(
          action,
          revisionHint: BilSmartPlanRevisionHint.fromUserText(text),
        );
      } else {
        await _executeAction(action);
      }
    }
    return true;
  }

  Future<bool> _executeSmartPlanAction(
    IntelligenceAction action, {
    BilSmartPlanRevisionHint? revisionHint,
  }) async {
    final owner = _smartPlanOwnerId();
    final epoch = conversationPersistenceEpoch;
    final preferences = ref.read(preferencesRepositoryProvider);
    void check() {
      if (!mounted ||
          epoch != conversationPersistenceEpoch ||
          owner == null ||
          owner != _smartPlanOwnerId() ||
          owner != preferences.localOwnerId) {
        throw StateError('smart_plan_owner_changed');
      }
      final access = ref.read(verifiedSubscriptionAccessProvider);
      // Same fresh server entitlement as the personalPlan route gate.
      if (access.isLoading ||
          access.hasError ||
          access.value?.authority != EntitlementAuthority.verifiedServer ||
          access.value?.plan == CommercePlan.free) {
        throw StateError('smart_plan_verified_subscription_required');
      }
      final binding = const CoachActionAdmission().bind(action);
      if (binding == null ||
          !binding.allows(ref.read(coachActionPermissionModeProvider))) {
        throw const _CoachHealthWritePermissionDenied();
      }
    }

    check();
    final plans = BilSmartPlanRepository(
      preferences: preferences,
      currentOwnerId: () {
        check();
        return owner;
      },
    );
    final plan = await plans.readFor(owner!);
    check();
    if (action.payload['planId'] != null &&
        (plan?.id != action.payload['planId'] ||
            plan?.revision != action.payload['revision'])) {
      throw StateError('smart_plan_revision_conflict');
    }
    if (plan != null) {
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      await const BilSmartPlanCatalog().validate(plan, dietary);
      check();
    }
    if (action.toolId == 'read_active_smart_plan' ||
        action.toolId == 'preview_smart_plan_day') {
      if (!mounted) return false;
      final locale = Localizations.localeOf(context).languageCode;
      final categories = CoachContextPreferences.decode(
        await preferences.get(CoachContextPreferences.storageKey),
      );
      check();
      final date =
          action.payload['date'] as String? ?? BilPlanDate.iso(DateTime.now());
      final day = plan?.onDate(BilPlanDate.parse(date));
      final lines = <String>[
        if (plan == null)
          intelligenceTextFor(locale, 'No saved plan.', 'لا توجد خطة محفوظة.'),
        if (plan != null && plan.status != BilPlanStatus.active)
          intelligenceTextFor(
            locale,
            'The saved plan is not active.',
            'الخطة المحفوظة غير نشطة.',
          ),
        if (plan?.status == BilPlanStatus.active && day == null)
          intelligenceTextFor(
            locale,
            'No scheduled day for this date.',
            'لا يوجد يوم مجدول بهذا التاريخ.',
          ),
        if (plan?.status == BilPlanStatus.active && day != null) ...[
          day.date,
          if (categories.includes(CoachContextFocus.training))
            day.workout == null
                ? intelligenceTextFor(locale, 'Recovery day.', 'يوم راحة.')
                : '${intelligenceTextFor(locale, 'Workout', 'التمرين')}: ${day.workout!.templateId}\n'
                      '${day.workout!.exerciseIds.map(const BilSmartPlanCatalog().exerciseTitle).join(', ')}',
          if (categories.includes(CoachContextFocus.nutrition) &&
              day.meals.isNotEmpty)
            '${intelligenceTextFor(locale, 'Suggested meals', 'وجبات مقترحة')}: '
                '${day.meals.map((m) => const BilSmartPlanCatalog().recipeTitle(m.recipeId)).join(', ')}',
          intelligenceTextFor(
            locale,
            'Suggestions have not been logged as performed or eaten.',
            'المقترحات ليست تسجيلًا لتمرين تم أداؤه أو طعام تم تناوله.',
          ),
        ],
      ];
      _appendToolReceipt(lines.join('\n'), verifiedResult: false);
      check();
      if (mounted && plan != null) {
        await context.push(
          '/smart-plan',
          extra: BilSmartPlanToolRequest(
            action.toolId!,
            action.payload,
            checkAccess: check,
          ),
        );
        check();
      }
      return true;
    }
    if (!mounted) return false;
    final receipt = await context.push<BilActionReceipt>(
      '/smart-plan',
      extra: BilSmartPlanToolRequest(
        action.toolId!,
        action.payload,
        checkAccess: check,
        revisionHint: revisionHint,
      ),
    );
    check();
    if (receipt?.verified != true || receipt?.entityType != 'smart_plan') {
      return false;
    }
    final saved = await plans.readFor(owner);
    check();
    if (receipt!.toolId != action.toolId ||
        saved?.id != receipt.entityId ||
        saved?.revision != receipt.after['revision'] ||
        (action.toolId == 'record_smart_plan_workout' &&
            saved
                    ?.onDate(
                      BilPlanDate.parse(action.payload['date']! as String),
                    )
                    ?.workout
                    ?.completed !=
                true)) {
      return false;
    }
    ref.invalidate(coachContextSnapshotProvider);
    ref.invalidate(latestDailyLogProvider);
    _appendToolReceipt(
      tr('Plan change saved and verified.', 'تم حفظ تغيير الخطة والتحقق منه.'),
      receipt: receipt,
    );
    return true;
  }
}
