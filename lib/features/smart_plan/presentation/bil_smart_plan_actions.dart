part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanActions on _BilSmartPlanPageState {
  Future<void> _createPlan() async {
    if (widget.privacyOnly) return;
    if (_busy || _owner == null) return;
    if (_plan != null && await _repository.readDraft(_owner!) != null) {
      await _openDraft();
      return;
    }
    if (!mounted) return;
    final owner = _owner;
    final epoch = _ownerEpoch;
    final request = await _reviewSurface(
      () => showBilModalBottomSheet<_PlanOptions>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => _PlanCreationSheet(
          initialHorizon:
              BilPlanHorizon.values
                  .where(
                    (value) =>
                        value.name == widget.toolRequest?.arguments['horizon'],
                  )
                  .firstOrNull ??
              _plan?.horizon,
          initialFocus:
              BilPlanFocus.values
                  .where(
                    (value) =>
                        value.name == widget.toolRequest?.arguments['focus'],
                  )
                  .firstOrNull ??
              _plan?.focus,
          initialSetup: _plan?.setup,
          initialSessionsPerWeek: _plan?.days
              .take(7)
              .where((day) => day.workout != null)
              .length,
        ),
      ),
    );
    if (!mounted ||
        request == null ||
        owner == null ||
        owner != _owner ||
        epoch != _ownerEpoch) {
      return;
    }
    _mutate(() => _busy = true);
    try {
      _checkAccess();
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      final catalog = const BilSmartPlanCatalog();
      final gym = request.focus == BilPlanFocus.nutrition
          ? <BilVerifiedWorkout>[]
          : request.setup?.environment == BilPlanEnvironment.home
          ? await catalog.homeSessions(request.setup!)
          : await catalog.gymSessions(
              sessionMinutes: request.setup!.sessionMinutes,
            );
      final recipes = request.focus == BilPlanFocus.training
          ? <BilVerifiedRecipe>[]
          : await catalog.sourcedRecipes(
              dietary: dietary,
              preferences: MealPlanPreferences(diet: request.diet),
            );
      if (!mounted || _owner != owner || epoch != _ownerEpoch) return;
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getProfile();
      if (!mounted || epoch != _ownerEpoch) return;
      final goal = await ref.read(goalRepositoryProvider).getActive();
      if (!mounted || epoch != _ownerEpoch) return;
      final setup = request.setup == null
          ? null
          : BilPlanSetup(
              environment: request.setup!.environment,
              experience: request.setup!.experience,
              sessionMinutes: request.setup!.sessionMinutes,
              equipment: request.setup!.equipment,
              preferredTime: request.setup!.preferredTime,
              goalId: goal?.uuid,
            );
      final start = ref.read(bilSmartPlanClockProvider)();
      final snapshot = await BilSmartPlanNutritionGoals.readSavedSnapshot(
        _repository.preferences,
      );
      final schedule = await ref
          .read(nutritionGoalScheduleRepositoryProvider)
          .read();
      final nutritionTargets = BilSmartPlanNutritionGoals.forPlan(
        start: start,
        horizon: request.horizon,
        snapshot: snapshot,
        schedule: schedule,
      );
      final latestWeight = await ref
          .read(weightRepositoryProvider)
          .watchLatestWeight()
          .first;
      if (!mounted || epoch != _ownerEpoch) return;
      final targetCalories =
          nutritionTargets.values
              .map((target) => target.values['kcal']!)
              .toList()
            ..sort();
      final creation = BilPlanCreationRequest(
        ownerId: owner,
        planId: const Uuid().v4(),
        startOn: start,
        nutritionTargets: nutritionTargets,
        requestedDailyCalories: targetCalories.firstOrNull?.round(),
        targetWeightKg: goal?.targetWeight,
        currentWeightKg: latestWeight?.weight,
        targetBy: goal?.targetDate,
        horizon: request.horizon,
        focus: request.focus,
        workoutsPerWeek: request.focus == BilPlanFocus.nutrition
            ? 0
            : request.workoutsPerWeek,
        confirmedPreferences: request.confirmedPreferences,
        adultConfirmed: request.confirmedPreferences,
        ageYears: profile?.age,
        workoutCatalog: gym,
        recipeCatalog: recipes,
        highRiskSymptoms: request.highRiskSymptoms,
        underMedicalReview: request.needsMedicalReview,
        setup: setup,
        phases:
            request.focus == BilPlanFocus.nutrition ||
                setup?.environment == BilPlanEnvironment.home
            ? const []
            : await const BilSmartPlanPrescriptions().phases(),
      );
      final safety = BilPlanSafety.assess(creation);
      if (safety.result != BilPlanSafetyResult.ready) {
        throw StateError(safety.reasons.join(', '));
      }
      final plan = const BilSmartPlanEngine().generate(
        creation,
        ref.read(bilSmartPlanClockProvider)(),
      );
      await _save(plan, prior: 0);
    } on Object catch (error) {
      if (!mounted || _owner != owner) return;
      _mutate(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeStatus(BilPlanStatus target) async {
    final current = _plan;
    if (current == null || _busy) return;
    final epoch = _ownerEpoch;
    final confirmed = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(_t('Confirm plan change', 'تأكيد تغيير حالة الخطة')),
        content: Text(
          target == BilPlanStatus.active
              ? _t(
                  _reviewingDraft
                      ? 'Replace your current plan with this reviewed draft? The previous plan stays on this device. Diary records will not change.'
                      : 'Activate this draft? Meals remain suggestions; nothing is logged automatically.',
                  _reviewingDraft
                      ? 'استبدال خطتك الحالية بهذه المسودة التي راجعتها؟ تبقى الخطة السابقة على هذا الجهاز ولا تتغير سجلات الدفتر.'
                      : 'اعتماد هذه المسودة؟ الوجبات مقترحات فقط ولن يُسجّل أي شيء تلقائيًا.',
                )
              : _t(
                  'Pause your schedule? Existing records will stay unchanged.',
                  'إيقاف الخطة مؤقتًا؟ لن تتغير سجلاتك السابقة.',
                ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _smartPlanActionInk(context),
            ),
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(_t('Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != _ownerEpoch) return;
    await _save(
      current.withStatus(target, ref.read(bilSmartPlanClockProvider)()),
      prior: current.revision,
    );
  }

  Future<void> _confirmWorkout(BilPlanDay day) async {
    final current = _plan;
    if (current == null || _busy || day.workout == null) return;
    final epoch = _ownerEpoch;
    final completed = day.workout!.completed;
    int actualMinutes = 0;
    final durationForm = GlobalKey<FormState>();
    final confirmed = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(
          completed
              ? _t('Undo completion?', 'التراجع عن إكمال التمرين؟')
              : _t('Did you finish this workout?', 'هل أنهيت هذا التمرين؟'),
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t(
                'Confirm only exercise you actually performed.',
                'أكد فقط التمرين الذي أديته فعليًا.',
              ),
            ),
            if (!completed)
              Form(
                key: durationForm,
                child: TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (text) {
                    final minutes = int.tryParse(text ?? '');
                    return minutes != null && minutes >= 5 && minutes <= 120
                        ? null
                        : _t(
                            'Enter 5–120 minutes.',
                            'أدخل من 5 إلى 120 دقيقة.',
                          );
                  },
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Actual minutes (5–120)',
                      'الدقائق الفعلية (5–120)',
                    ),
                  ),
                  onChanged: (value) =>
                      actualMinutes = int.tryParse(value) ?? 0,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _smartPlanActionInk(context),
            ),
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              if (!completed && durationForm.currentState?.validate() != true) {
                return;
              }
              Navigator.pop(dialog, true);
            },
            child: Text(_t('Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != _ownerEpoch) return;
    _mutate(() => _busy = true);
    try {
      _checkAccess();
      if (current.ownerId != _owner) {
        throw StateError('smart_plan_owner_changed');
      }
      final repository = _repository;
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      await const BilSmartPlanCatalog().validate(current, dietary);
      _checkAccess();
      final saved =
          await BilSmartPlanWorkoutService(
            ref.read(databaseProvider),
            repository,
            () {
              if (epoch != _ownerEpoch) {
                throw StateError('smart_plan_owner_changed');
              }
              _checkAccess();
            },
          ).record(
            expected: current,
            date: day.date,
            now: ref.read(bilSmartPlanClockProvider)(),
            actualMinutes: completed ? 5 : actualMinutes,
            sessionTitle: _workoutTitle(day.workout!.templateId),
            completed: !completed,
          );
      if (!mounted || saved.ownerId != _owner) return;
      _mutate(() {
        _plan = saved;
        _error = null;
      });
      ref.invalidate(coachContextSnapshotProvider);
      _returnReceipt(saved);
    } on Object catch (error) {
      if (!mounted) return;
      _mutate(() => _error = error.toString());
    } finally {
      if (mounted && epoch == _ownerEpoch) _mutate(() => _busy = false);
    }
  }

  Future<void> _exportPlan() async {
    final owner = _owner;
    final repository = _repository;
    if (owner == null) return;
    try {
      final plan = await repository.readFor(owner);
      if (!mounted || owner != _owner) return;
      final receipts = plan == null
          ? <String, Object?>{}
          : await repository.exportWorkoutReceipts(plan);
      if (!mounted || owner != _owner) return;
      final payload = jsonEncode({
        'schema': 'bil.smart-plan.export.v1',
        'plan': plan?.toJson(),
        'workoutReceipts': receipts,
        'localDraft': (await repository.readDraft(owner))?.toJson(),
        'localSyncConflictHistory': await repository.exportConflictHistory(
          owner,
        ),
        'localPreviousPlans': [
          for (final previous in await repository.readArchives(owner))
            {
              'plan': previous.toJson(),
              'workoutReceipts': await repository.exportWorkoutReceipts(
                previous,
              ),
            },
        ],
      });
      if (!mounted || owner != _owner) return;
      await const DataExportService().sharePortableJson(payload);
    } on Object {
      if (mounted && owner == _owner) {
        _mutate(() => _error = 'smart_plan_export_failed');
      }
    }
  }

  Future<void> _sharePlanWithCoach() async {
    final repository = _repository;
    final preferences = repository.preferences;
    final owner = _owner;
    final epoch = _ownerEpoch;
    final existingSharing = await preferences.get(
      'smartPlan.shareWithCoach.v1',
    );
    final enabled = existingSharing == 'true';
    if (!mounted || epoch != _ownerEpoch) return;
    final accepted = enabled
        ? await _confirmDialog(
            context: context,
            builder: (dialog) => BilPearlMaterialAlertDialog(
              scrollable: true,
              title: Text(
                _t('Stop sharing plan context?', 'إيقاف مشاركة سياق الخطة؟'),
              ),
              content: Text(
                _t(
                  'Future Coach requests will omit your saved plan. Your local plan stays available.',
                  'لن تتضمن طلبات المدرب التالية خطتك المحفوظة. تبقى خطتك المحلية متاحة.',
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: _smartPlanActionInk(context),
                  ),
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(_t('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(_t('Stop sharing', 'إيقاف المشاركة')),
                ),
              ],
            ),
          )
        : await showBilPremiumAiConsentSheet(
            context: context,
            title: _t('Use your plan with Coach?', 'استخدام خطتك مع المدرب؟'),
            intro: _t(
              'Choose whether relevant Coach requests may include your saved plan.',
              'اختر السماح بإرفاق خطتك المحفوظة بأسئلة المدرب ذات الصلة.',
            ),
            points: [
              BilPremiumAiConsentPoint(
                icon: Icons.description_outlined,
                title: _t('What is included', 'البيانات المرفقة'),
                body: _t(
                  'Plan ID, revision, selected day, suggested meals and workout progress, within your selected context categories.',
                  'رقم الخطة وإصدارها واليوم المختار والوجبات المقترحة وتقدم التدريب، ضمن فئات السياق التي تختارها.',
                ),
              ),
              BilPremiumAiConsentPoint(
                icon: Icons.psychology_outlined,
                title: _t('Google Gemini', 'Google Gemini'),
                body: _t(
                  'This third-party AI service receives the selected context only after your separate Gemini consent.',
                  'تستقبل خدمة الذكاء الاصطناعي الخارجية السياق المختار بعد موافقتك المنفصلة على Gemini.',
                ),
              ),
              BilPremiumAiConsentPoint(
                icon: Icons.lock_outline_rounded,
                title: _t('Your choice', 'الاختيار لك'),
                body: _t(
                  'Decline or stop sharing in Plan options at any time. Your local plan remains available.',
                  'يمكنك الرفض أو إيقاف المشاركة من خيارات الخطة في أي وقت. تبقى خطتك المحلية متاحة.',
                ),
              ),
            ],
            allowLabel: _t('Allow and continue', 'السماح والمتابعة'),
            declineLabel: _t('Not now', 'ليس الآن'),
            allowKey: const ValueKey('bil-smart-plan-memory-allow'),
            declineKey: const ValueKey('bil-smart-plan-memory-decline'),
          );
    if (accepted != true || !mounted || owner == null || epoch != _ownerEpoch) {
      return;
    }
    try {
      final saved = await preferences.mutateIfUnchanged(
        expected: {'smartPlan.shareWithCoach.v1': existingSharing},
        set: {'smartPlan.shareWithCoach.v1': enabled ? 'false' : 'true'},
        remove: enabled ? ['smartPlan.shareWithCoach.v2'] : const [],
        isCurrent: () => mounted && epoch == _ownerEpoch && owner == _owner,
      );
      if (!saved) throw StateError('smart_plan_memory_changed');
      if (mounted && epoch == _ownerEpoch) {
        ref.invalidate(coachContextSnapshotProvider);
      }
    } on Object {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = 'smart_plan_memory_not_saved');
      }
    }
  }

  Future<void> _reportPlan() async {
    final plan = _plan;
    final epoch = _ownerEpoch;
    if (plan == null) return;
    await showAiCoachAnswerReportSheet(context, (draft) async {
      if (!mounted || epoch != _ownerEpoch || plan.ownerId != _owner) return;
      try {
        await ref
            .read(aiCoachSafetyReportServiceProvider)
            .submit(
              responseId: 'smart-plan-${plan.id}-r${plan.revision}',
              answerText: jsonEncode(
                smartPlanContext(
                  plan,
                  ref.read(bilSmartPlanClockProvider)(),
                  includeTraining: true,
                  includeNutrition: true,
                ),
              ),
              reason: draft.reason,
              explicitConsentAccepted: draft.explicitConsentAccepted,
              locale: Localizations.localeOf(context).languageCode,
              runtime: CoachAnswerRuntime.onDevice,
              userNote: draft.optionalNote,
            );
        if (mounted && epoch == _ownerEpoch) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('Report submitted.', 'تم إرسال البلاغ.')),
            ),
          );
        }
      } on Object {
        if (mounted && epoch == _ownerEpoch) {
          _mutate(() => _error = 'smart_plan_report_not_sent');
        }
      }
    }, subject: AiCoachReportSubject.smartPlan);
  }

  Future<void> _syncPlan({bool revoke = false}) async {
    final epoch = _ownerEpoch;
    final owner = _owner;
    if (owner == null || _busy) return;
    final accepted = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        scrollable: true,
        title: Text(
          revoke
              ? _t('Stop cloud backup?', 'إيقاف النسخ السحابي؟')
              : _t('Sync saved plan?', 'مزامنة الخطة المحفوظة؟'),
        ),
        content: Text(
          _t(
            'Supabase will store your plan, dates, meal suggestions and confirmed workout status for recovery on your devices. Gemini and advertising do not receive this backup. Conflicting edits require review. You can export or delete the plan. Stopping backup deletes its remote payload.',
            'سيحفظ Supabase خطتك وتواريخها ومقترحات الطعام وحالة التمارين المؤكدة لاستعادتها على أجهزتك. لا تصل هذه النسخة إلى Gemini أو الإعلانات. تتطلب التعديلات المتعارضة المراجعة. يمكنك التصدير أو الحذف. إيقاف النسخ يحذف محتوى الخطة السحابي.',
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _smartPlanActionInk(context),
            ),
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(_t('Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || epoch != _ownerEpoch) return;
    final repository = _repository;
    void check() {
      if (!mounted || epoch != _ownerEpoch || _owner != owner) {
        throw StateError('smart_plan_owner_changed');
      }
      if (!revoke) _checkAccess();
    }

    _mutate(() => _busy = true);
    try {
      check();
      final client = Supabase.instance.client;
      await client.rpc(
        'bil_smart_plan_consent_v1',
        params: {'granted': !revoke},
      );
      check();
      if (!revoke) {
        final sync = BilSmartPlanSync(
          local: repository,
          preferences: repository.preferences,
          remote: SupabaseSmartPlanRemote(client),
          checkConsentAndAccess: check,
        );
        try {
          await sync.synchronize(owner);
        } on StateError catch (error) {
          if (!error.toString().contains('smart_plan_sync_conflict')) rethrow;
          await _resolvePlanConflict(sync, owner, epoch);
        }
      }
      if (mounted && epoch == _ownerEpoch) await _load();
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = error.toString());
      }
    } finally {
      if (mounted && epoch == _ownerEpoch) _mutate(() => _busy = false);
    }
  }

  Future<void> _deletePlan() async {
    final plan = _plan;
    final epoch = _ownerEpoch;
    final repository = _repository;
    if (plan == null || _busy) return;
    final confirmed = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        scrollable: true,
        title: Text(_t('Delete saved plan?', 'حذف الخطة المحفوظة؟')),
        content: Text(
          _t(
            'The schedule and its private receipts will be deleted. Actual diary entries remain in your activity history. If cloud sync was enabled, synchronize the deletion before uninstalling.',
            'سيُحذف الجدول وإيصالاته الخاصة. تبقى الأنشطة الفعلية في دفتر الأنشطة. إن فعّلت المزامنة، زامن الحذف قبل إزالة التطبيق.',
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _smartPlanActionInk(context),
            ),
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(_t('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != _ownerEpoch) return;
    try {
      await repository.removeWithConfirmation(
        owner: plan.ownerId,
        expectedId: plan.id,
        expectedRevision: plan.revision,
      );
      if (!mounted || epoch != _ownerEpoch) return;
      ref.invalidate(coachContextSnapshotProvider);
      _mutate(() {
        _plan = null;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) _mutate(() => _error = error.toString());
    }
  }

  Future<void> _openExercise(String id, {bool returnToSession = false}) async {
    try {
      final route = await const BilSmartPlanCatalog().exerciseRoute(
        id,
        bundleId: _plan?.setup?.environment == BilPlanEnvironment.home
            ? 'home-training'
            : 'gym-six-month',
      );
      if (mounted) {
        // Only a live Smart Plan session skips the discovery library on Back.
        // Standalone catalog links retain their normal browsing behavior.
        await context.push(returnToSession ? '$route&returnToSession=1' : route);
      }
    } on Object catch (error) {
      if (mounted) _mutate(() => _error = error.toString());
    }
  }

  Future<void> _startSession(BilPlanDay day) async {
    final plan = _plan;
    final epoch = _ownerEpoch;
    if (plan == null ||
        _busy ||
        day.workout == null ||
        day.workout!.completed ||
        plan.status != BilPlanStatus.active) {
      return;
    }
    try {
      void check() {
        _checkAccess();
        if (epoch != _ownerEpoch ||
            _plan?.id != plan.id ||
            _plan?.revision != plan.revision) {
          throw StateError('smart_plan_revision_conflict');
        }
      }

      check();
      final manager = WellnessContentPackManager();
      final finished = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => BilSmartPlanSessionPage(
            plan: plan,
            day: day,
            checkAccess: check,
            loadItems: (locale) =>
                manager.loadWorkoutLibraryItems(locale: locale),
            openExercise: (id) => _openExercise(id, returnToSession: true),
          ),
        ),
      );
      check();
      if (finished == true && mounted) await _confirmWorkout(day);
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = error.toString());
      }
    }
  }
}
