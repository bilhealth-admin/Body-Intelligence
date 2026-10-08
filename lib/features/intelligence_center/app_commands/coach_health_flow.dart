part of '../presentation/intelligence_center_page.dart';

final class _CoachHealthWritePermissionDenied implements Exception {
  const _CoachHealthWritePermissionDenied();
}

extension _CoachHealthFlow on _IntelligenceCenterPageState {
  CoachHealthCopy get _healthCopy => CoachHealthCopy(
    BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
  );

  CoachHealthAdapters _newCoachHealthAdapters(AppDatabase database) {
    final daily = ref.read(dailyLogRepositoryProvider);
    final life = ref.read(lifeContextRepositoryProvider);
    return CoachHealthAdapters([
      CoachDailyCommandAdapter(
        daily: daily,
        restoreRecord: daily.restoreCoachRecord,
      ),
      CoachLifeContextCommandAdapter(
        repository: life,
        readByUuid: life.getByUuid,
        addWithUuid:
            ({
              required uuid,
              required occurredAt,
              required type,
              required details,
              required useInInsights,
            }) => life.add(
              uuid: uuid,
              occurredAt: occurredAt,
              type: type,
              details: details,
              useInInsights: useInInsights,
            ),
      ),
      CoachFastingCommandAdapter(ref.read(preferencesRepositoryProvider)),
      CoachActivityCommandAdapter(
        dailyLogs: daily,
        restoreDailyLog: daily.restoreCoachRecord,
        weights: ref.read(weightRepositoryProvider),
      ),
      CoachPlanCommandAdapter(
        database: database,
        command: ref.read(dietPlanCommandProvider),
      ),
    ]);
  }

  /// Exact local health intents run before personal-context assembly or any
  /// model call. Rejected health syntax receives clarification, never a write
  /// inferred by another parser from part of the same sentence.
  Future<bool> _answerLocalHealthIntent(
    String text, {
    required String locale,
  }) async {
    const parser = LocalCoachHealthCommandParser();
    final parsed = parser.parse(
      text,
      locale: locale,
      referenceLocal: ref.read(intelligenceConversationClockProvider)(),
    );
    if (parsed == null) {
      if (!parser.recognizesHealthIntent(text)) return false;
      _appendToolReceipt(
        intelligenceTextFor(
          locale,
          'Please give one clear health action with a date and exact value. For example: “I slept 7 hours yesterday”, “log exercise walk 20 minutes today”, or “show sleep history 7 days”. Nothing was changed.',
          'اكتب إجراءً صحيًا واحدًا بوضوح مع التاريخ والقيمة الدقيقة. مثال: «نمت 7 ساعات أمس»، أو «سجل تمرين مشي 20 دقيقة اليوم»، أو «اعرض سجل النوم 7 أيام». لم يتغير شيء.',
        ),
        verifiedResult: false,
      );
      return true;
    }
    final action = const CoachActionAdmission().admitProposal(parsed);
    if (action == null) return true;
    if (action.type == IntelligenceActionType.healthCommand) {
      // A review is a pending human decision, not an in-flight data lookup.
      replyDelayTimer?.cancel();
      _updateState(() {
        sending = false;
        replyPhase = _CoachReplyPhase.idle;
      });
    }
    await _executeAction(action);
    return true;
  }

  /// Uses the existing dialog treatment. Every health mutation gets a fresh
  /// human review, including writeAllowed mode and typed follow-up confirms.
  /// A model-supplied clinician flag cannot check this checkbox for the user.
  Future<IntelligenceAction?> _confirmCoachHealthAction(
    IntelligenceAction action,
    _PreparedCoachNativeAction prepared,
  ) async {
    final command = prepared.command!;
    final before = command.before.receiptPayload(command);
    final clinicianRequired =
        action.toolId == 'activate_plan' &&
        before['safety'] == 'clinicianReview';
    final medicalSupervision =
        action.toolId == 'activate_plan' &&
        before['safety'] == 'medicalSupervision';
    var clinicianChecked = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          icon: Icon(_iconForAction(action.type)),
          title: Text(tr('Confirm action', 'تأكيد الإجراء')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _healthCopy.review(action.toolId!, command.resolved, before),
              ),
              if (clinicianRequired)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: clinicianChecked,
                  onChanged: (value) =>
                      setDialogState(() => clinicianChecked = value == true),
                  title: Text(
                    tr(
                      'I have reviewed this plan with a qualified clinician.',
                      'راجعت هذه الخطة مع مختص صحي مؤهل.',
                    ),
                  ),
                ),
              if (medicalSupervision)
                Text(
                  tr(
                    'This program requires medical supervision and cannot be activated here. Open the program to review its requirements.',
                    'يتطلب هذا البرنامج إشرافًا طبيًا ولا يمكن تفعيله هنا. افتح البرنامج لمراجعة متطلباته.',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed:
                  medicalSupervision || clinicianRequired && !clinicianChecked
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(tr('Continue', 'متابعة')),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return null;
    prepared.scope.check(prepared.database.localOwnerId);
    if (clinicianRequired) {
      return action.copyWith(
        payload: {
          ...action.payload,
          'clinicianReviewConfirmed': clinicianChecked,
        },
      );
    }
    // The reviewed checkbox is the only source of a clinical assertion.
    return action.toolId == 'activate_plan' &&
            action.payload.containsKey('clinicianReviewConfirmed')
        ? action.copyWith(
            payload: {...action.payload, 'clinicianReviewConfirmed': false},
          )
        : action;
  }

  Future<bool> _executeCoachHealthRead(IntelligenceAction action) async {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final copy = CoachHealthCopy(locale);
    final owner = _captureRecoveredCoachNativeOwner();
    CoachHealthReadGuard? guard;
    try {
      final preferences = owner.repository.preferences;
      guard = await CoachHealthReadGuard.capture(
        preferences: preferences,
        focus: coachHealthFocus(action.toolId!, action.payload),
        checkOwner: () => owner.scope.check(owner.database.localOwnerId),
      );
      final access = guard.check;
      final args = action.payload;
      final query = CoachHealthQueries(
        owner.database,
        dailyLogs: ref.read(dailyLogRepositoryProvider),
        weights: owner.repository.weights,
        measurements: owner.repository.measurements,
        catalog: catalogGrounding,
        clock: ref.read(intelligenceConversationClockProvider),
        // The existing connected-health cache has no owner identity. It must
        // not be attached to this owner's answer without a verified scope.
      );
      final Map<String, Object?> result;
      switch (action.toolId) {
        case 'read_health_history':
        case 'read_health_progress':
          result = await query.execute(
            topic: action.toolId == 'read_health_progress'
                ? 'progress'
                : args['topic']! as String,
            from: parseHealthDay(args['from']),
            through: parseHealthDay(args['through']),
            limit: args['limit'] as int? ?? 31,
            checkAccess: access,
          );
        case 'read_fasting':
          result = await CoachFastingCommandAdapter(
            preferences,
          ).read(checkAccess: access);
        case 'preview_plan':
          result =
              await CoachPlanCommandAdapter(
                database: owner.database,
                command: ref.read(dietPlanCommandProvider),
              ).preview(
                pathwayId: args['pathwayId']! as String,
                checkAccess: access,
              );
        case 'search_health_content':
          result = await query.searchContent(
            question: args['question']! as String,
            locale: locale,
            limit: args['limit'] as int? ?? 3,
            checkAccess: access,
          );
        default:
          throw StateError('Unsupported health read');
      }
      await guard.verify();
      access();
      final message = IntelligenceMessage(
        id: 'tool-health-read-${DateTime.now().microsecondsSinceEpoch}',
        role: IntelligenceMessageRole.bil,
        kind: IntelligenceMessageKind.evidence,
        text: copy.read(action.toolId!, result),
        createdAt: ref.read(intelligenceConversationClockProvider)(),
        evidence: [
          jsonEncode({
            'source': 'verified_local_health_read',
            'tool_id': action.toolId,
            'result': result,
            'mutationsPerformed': 0,
          }),
        ],
        confidence: 1,
      );
      _updateState(() => messages.add(message));
      _scrollToLatest();
      unawaited(_saveConversation());
      return true;
    } on CoachHealthContextUnavailable {
      if (mounted && owner.scope.isCurrent) {
        _appendToolReceipt(
          tr(
            'This category is disabled in Coach context settings. Enable it there before asking Coach to read these records.',
            'هذه الفئة معطلة في إعدادات سياق المدرب. فعّلها هناك قبل طلب قراءة هذه السجلات.',
          ),
          verifiedResult: false,
        );
      }
      return false;
    } finally {
      // Revocation is synchronous inside close(). Stream teardown must not
      // keep a completed/denied read in the conversation's loading phase.
      final closing = guard?.close();
      owner.dispose();
      if (closing != null) unawaited(closing.catchError((Object _) {}));
    }
  }

  Future<void> _syncCoachHealthEffects({
    required CoachNativeCommit result,
    required PreferencesRepository preferences,
    required CoachNativeOwnerScope scope,
  }) async {
    if (!const {
          'start_fasting',
          'stop_fasting',
          'adjust_fasting',
        }.contains(result.toolId) ||
        !mounted ||
        !scope.isCurrent) {
      return;
    }
    final outcome = await _reconcileCoachFasting(preferences, scope);
    if (!mounted || !scope.isCurrent || outcome == null) return;
    _appendToolReceipt(
      _coachFastingNotificationText(outcome),
      verifiedResult:
          outcome.status != CoachFastingNotificationStatus.unavailable,
    );
  }

  Future<CoachFastingNotificationResult?> _reconcileCoachFasting(
    PreferencesRepository preferences,
    CoachNativeOwnerScope scope,
  ) async {
    if (!mounted || !scope.isCurrent) return null;
    try {
      final service = CoachFastingNotificationSync(
        preferences: preferences,
        notifications: ref.read(fastingNotificationServiceProvider),
        clock: ref.read(intelligenceConversationClockProvider),
      );
      final completed = Completer<CoachFastingNotificationResult>();
      Timer? timeout;
      var abandoned = false;
      void finish(
        CoachFastingNotificationResult result, {
        bool abandon = false,
      }) {
        if (completed.isCompleted) return;
        abandoned = abandon;
        timeout?.cancel();
        completed.complete(result);
      }

      void cancel() => finish(
        CoachFastingNotificationResult(
          status: CoachFastingNotificationStatus.superseded,
          failedStage: 'route_closed',
        ),
        abandon: true,
      );
      healthEffectCancellers.add(cancel);
      timeout = Timer(
        const Duration(seconds: 5),
        () => finish(
          CoachFastingNotificationResult(
            status: CoachFastingNotificationStatus.unavailable,
            failedStage: 'ui_timeout',
          ),
          abandon: true,
        ),
      );
      unawaited(
        service
            .syncLatest(
              languageCode: BilLocalePolicy.canonicalTag(
                Localizations.localeOf(context),
              ),
              checkAccess: () {
                if (abandoned) {
                  throw StateError('Device reconciliation was cancelled');
                }
                scope.check(preferences.localOwnerId);
              },
            )
            .then(
              finish,
              onError: (Object _) => finish(
                CoachFastingNotificationResult(
                  status: CoachFastingNotificationStatus.unavailable,
                  failedStage: 'device_error',
                ),
              ),
            ),
      );
      try {
        return await completed.future;
      } finally {
        timeout.cancel();
        healthEffectCancellers.remove(cancel);
      }
    } on Object {
      // Session changes have already committed. A device timeout/error cannot
      // turn their truthful receipt into an "unchanged data" failure.
      return CoachFastingNotificationResult(
        status: CoachFastingNotificationStatus.unavailable,
        failedStage: 'ui_reconciliation',
      );
    }
  }

  String _coachFastingNotificationText(
    CoachFastingNotificationResult result,
  ) => switch (result.status) {
    CoachFastingNotificationStatus.synchronized => tr(
      'Session data is saved. Device reminder scheduling was checked; target reminder scheduled: ${result.targetReminderScheduled == true ? 'yes' : 'no'}. Actual delivery depends on the device.',
      'بيانات الجلسة محفوظة. جرى التحقق من جدولة تذكيرات الجهاز؛ تذكير الهدف مجدول: ${result.targetReminderScheduled == true ? 'نعم' : 'لا'}. يعتمد التسليم الفعلي على الجهاز.',
    ),
    CoachFastingNotificationStatus.cancelled => tr(
      'Session data is saved. Fasting reminders were cancelled on the device.',
      'بيانات الجلسة محفوظة. أُلغيت تذكيرات الصيام على الجهاز.',
    ),
    CoachFastingNotificationStatus.targetElapsed => tr(
      'Session data is saved. Its target time has already passed.',
      'بيانات الجلسة محفوظة. انقضى موعدها المستهدف بالفعل.',
    ),
    CoachFastingNotificationStatus.permissionDenied => tr(
      'Session data is saved. The device has not allowed notifications; no permission setting was changed.',
      'بيانات الجلسة محفوظة. لم يسمح الجهاز بالإشعارات؛ لم يتغير إعداد الإذن.',
    ),
    CoachFastingNotificationStatus.unavailable ||
    CoachFastingNotificationStatus.superseded => tr(
      'Session data is saved. Reminder scheduling could not be verified; check fasting reminders in the app.',
      'بيانات الجلسة محفوظة. تعذر التحقق من جدولة التذكيرات؛ راجع تذكيرات الصيام في التطبيق.',
    ),
  };

  String _healthActionFailureText(Object error) {
    if (error is NutritionPathwayActivationException) {
      return switch (error.failure) {
        NutritionPathwayActivationFailure.premiumRequired => tr(
          'This plan requires verified program access. Review your subscription before activating it; the plan was not changed.',
          'تتطلب هذه الخطة صلاحية موثقة للبرامج. راجع اشتراكك قبل تفعيلها؛ لم تتغير الخطة.',
        ),
        NutritionPathwayActivationFailure.clinicianReviewRequired => tr(
          'Review this plan with a qualified clinician before activating it. The plan was not changed.',
          'راجع هذه الخطة مع مختص صحي مؤهل قبل تفعيلها. لم تتغير الخطة.',
        ),
        NutritionPathwayActivationFailure.medicalSupervisionRequired => tr(
          'This program requires medical supervision and cannot be activated from Coach.',
          'يتطلب هذا البرنامج إشرافًا طبيًا ولا يمكن تفعيله من المدرب.',
        ),
        _ => tr(
          'This plan could not be validated. Open the program and review it again.',
          'تعذر التحقق من هذه الخطة. افتح البرنامج وراجعه مجددًا.',
        ),
      };
    }
    final reason = error is StateError ? error.message : null;
    if (const {
      'Reopen this day before changing its health record',
      'Reopen this day before logging exercise',
    }.contains(reason)) {
      return tr(
        'This day is closed. Reopen it before changing sleep, notes, or exercise. Nothing was saved.',
        'هذا اليوم مغلق. أعد فتحه قبل تعديل النوم أو الملاحظات أو التمرين. لم يُحفظ شيء.',
      );
    }
    if (reason == 'A fasting session is already active') {
      return tr(
        'A fasting session is already active. Stop it or correct its target before starting another.',
        'توجد جلسة صيام نشطة بالفعل. أنهِها أو صحح هدفها قبل بدء جلسة أخرى.',
      );
    }
    if (const {
      'There is no active fasting session',
      'The active fasting session is missing',
    }.contains(reason)) {
      return tr(
        'There is no active fasting session to stop or correct.',
        'لا توجد جلسة صيام نشطة لإنهائها أو تصحيحها.',
      );
    }
    if (reason == 'This day has no saved record') {
      return tr(
        'This day has no saved record to reopen.',
        'لا يوجد سجل محفوظ لهذا اليوم لإعادة فتحه.',
      );
    }
    return tr(
      'The health action was not completed. No data was saved; review the date and value, then prepare it again.',
      'لم يكتمل الإجراء الصحي. لم تُحفظ بيانات؛ راجع التاريخ والقيمة ثم جهزه مجددًا.',
    );
  }

  Future<void> _resumeCoachFastingEffects() async {
    if (!mounted) return;
    // Device reminder IDs are global. Reconcile the current account even if
    // the visible conversation still belongs to a previous account. No chat
    // data is read or published from this independent device-only visit.
    final database = ref.read(databaseProvider);
    final preferences = ref.read(preferencesRepositoryProvider);
    final witness = ref.read(coachNativeOwnerWitnessProvider);
    final scope = CoachNativeOwnerScope(
      ownerId: database.localOwnerId,
      isCurrent: () =>
          mounted &&
          identical(ref.read(databaseProvider), database) &&
          identical(ref.read(preferencesRepositoryProvider), preferences) &&
          preferences.localOwnerId == database.localOwnerId &&
          (witness == null || witness.readOwner() == database.localOwnerId),
    );
    final ownerChanges = witness?.changes.listen((next) {
      if (next != database.localOwnerId) scope.cancel();
    }, onError: (Object _, StackTrace _) => scope.cancel());
    final databaseChanges = ref.listenManual(databaseProvider, (
      previous,
      next,
    ) {
      if (!identical(next, database)) scope.cancel();
    });
    try {
      scope.check(database.localOwnerId);
      await _reconcileCoachFasting(preferences, scope);
    } on Object {
      // Resume never invents a successful scheduling result. The next visit
      // or explicit fasting action reconciles the latest persisted state.
    } finally {
      scope.cancel();
      databaseChanges.close();
      await ownerChanges?.cancel();
    }
  }
}
