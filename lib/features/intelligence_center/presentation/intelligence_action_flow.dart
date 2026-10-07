part of 'intelligence_center_page.dart';

extension _IntelligenceActionFlow on _IntelligenceCenterPageState {
  Future<bool> _executeAction(
    IntelligenceAction action, {
    bool confirmationAlreadyProvided = false,
  }) async {
    final binding = const CoachActionAdmission().bind(
      action,
      requireOperationId: true,
    );
    if (binding == null) {
      _appendToolReceipt(
        tr(
          'The action could not be validated. Ask Coach to prepare it again.',
          'تعذر التحقق من الإجراء. اطلب من المدرب إعداده مرة أخرى.',
        ),
        verifiedResult: false,
      );
      return false;
    }
    action = binding.action;
    final permissionMode = ref.read(coachActionPermissionModeProvider);
    if (!_allowsCoachAction(binding, permissionMode)) {
      return false;
    }
    if (action.operationId != null &&
        completedActionOperationIds.contains(action.operationId)) {
      return false;
    }
    final executionKey = _coachActionExecutionKey(action);
    if (!executingActionKeys.add(executionKey)) return false;
    final tracksInlineNavigation = const CoachActionPresentationPolicy()
        .isNavigation(action);
    var succeeded = false;
    try {
      final preparedMeal = await _prepareCoachMealAction(action);
      final preparedNative = await _prepareCoachNativeAction(action);
      if (!mounted) return false;
      final acceptsTypedConfirmation =
          confirmationAlreadyProvided && !action.destructive;
      final requiresConfirmation = binding.requiresConfirmation(
        ref.read(coachActionPermissionModeProvider),
      );
      if (requiresConfirmation &&
          !acceptsTypedConfirmation &&
          !await _confirmAction(action)) {
        return false;
      }
      if (!mounted) return false;
      if (!_allowsCoachAction(
        binding,
        ref.read(coachActionPermissionModeProvider),
      )) {
        return false;
      }
      if (tracksInlineNavigation) {
        _updateState(
          () => actionExecutionPhases[executionKey] =
              _CoachActionExecutionPhase.running,
        );
      }
      switch (action.type) {
        case IntelligenceActionType.navigate:
          final target = action.payload['target']?.toString();
          final path = target == null
              ? null
              : const BilNavigationRegistry().resolve(target);
          if (path == null) throw StateError('invalid_navigation_target');
          await _openCoachRoute(path);
        case IntelligenceActionType.readNutritionRemaining:
          final snapshot = await ref.read(coachContextSnapshotProvider.future);
          final remaining = snapshot.nutritionRemainingFor(DateTime.now());
          if (remaining == null) {
            throw StateError('nutrition_remaining_unavailable');
          }
          if (mounted) {
            _appendToolReceipt(
              tr(
                'Remaining today: ${remaining['caloriesKcal']!.round()} kcal, ${remaining['proteinG']!.round()} g protein, ${remaining['carbsG']!.round()} g carbs, ${remaining['fatG']!.round()} g fat.',
                'المتبقي اليوم: ${remaining['caloriesKcal']!.round()} سعرة، ${remaining['proteinG']!.round()} غ بروتين، ${remaining['carbsG']!.round()} غ كربوهيدرات، ${remaining['fatG']!.round()} غ دهون.',
              ),
            );
          }
        case IntelligenceActionType.readProfileIdentity:
          final snapshot = await ref.read(coachContextSnapshotProvider.future);
          final name = snapshot.minimalIdentity['displayName']?.toString();
          if (mounted) {
            _appendToolReceipt(
              name == null
                  ? tr(
                      'No profile name is saved.',
                      'لا يوجد اسم محفوظ في الملف الشخصي.',
                    )
                  : tr('Profile name: $name', 'اسم الملف الشخصي: $name'),
            );
          }
        case IntelligenceActionType.openDailyLog:
          final requested = action.payload['action']?.toString();
          const supportedActions = {
            'barcode',
            'voice',
            'photo',
            'water',
            'notes',
            'exercise',
          };
          final safeAction = supportedActions.contains(requested)
              ? requested
              : null;
          await _openCoachRoute(
            Uri(
              path: '/daily-log',
              queryParameters: safeAction == null
                  ? null
                  : {'action': safeAction},
            ).toString(),
          );
        case IntelligenceActionType.addWater:
        case IntelligenceActionType.addWeight:
          if (!await _commitPreparedCoachNativeAction(action, preparedNative)) {
            return false;
          }
        case IntelligenceActionType.reviewMeal:
          final dayOffset = action.payload['dayOffset'];
          if (dayOffset is int && dayOffset != 0) {
            ref.read(selectedLogDateProvider.notifier).state = DateTime.now()
                .add(Duration(days: dayOffset));
          }
          await _openCoachRoute('/daily-log?focus=meal');
        case IntelligenceActionType.reviewWorkout:
          await _openCoachRoute('/wellness/workouts/log', push: true);
        case IntelligenceActionType.openPlan:
          await _openCoachRoute('/plan?origin=dashboard');
        case IntelligenceActionType.openReport:
          await _openCoachRoute('/analytics');
        case IntelligenceActionType.openAiCoachSubscription:
          await _openCoachRoute('/plans?focus=ai-coach', push: true);
        case IntelligenceActionType.buyAiBoost:
          await _openCoachRoute('/plans?focus=boost', push: true);
        case IntelligenceActionType.manageSubscription:
          await _openCoachRoute('/plans', push: true);
        case IntelligenceActionType.setThemeMode:
          final mode = action.payload['mode']?.toString();
          if (!const {'dark', 'light', 'system'}.contains(mode)) {
            throw StateError('invalid_theme_mode');
          }
          final previousMode = ref.read(appSettingsProvider).themeMode;
          await ref.read(appSettingsProvider.notifier).setThemeMode(mode!);
          if (mounted) {
            _appendToolReceipt(
              tr('App appearance updated.', 'تم تحديث مظهر التطبيق.'),
              receipt: BilActionReceipt(
                actionId: action.id,
                committed: true,
                completedAt: DateTime.now(),
                entityType: 'app_setting',
                entityId: 'theme_mode',
                before: {'theme_mode': previousMode},
                after: {'theme_mode': mode},
                toolId: action.toolId,
                operationId: action.operationId,
                undoable: true,
              ),
              undo: () => ref
                  .read(appSettingsProvider.notifier)
                  .setThemeMode(previousMode),
            );
            _showActionCompleted(tr('Appearance updated.', 'تم تحديث المظهر.'));
          }
        case IntelligenceActionType.setLanguage:
          final locale = BilLocalePolicy.canonicalSupportedTag(
            action.payload['locale']?.toString(),
          );
          if (locale == null) throw StateError('invalid_locale');
          final previousLocale = ref.read(appSettingsProvider).localeCode;
          await ref.read(appSettingsProvider.notifier).setLocale(locale);
          if (mounted) {
            _appendToolReceipt(
              tr('App language updated.', 'تم تحديث لغة التطبيق.'),
              receipt: BilActionReceipt(
                actionId: action.id,
                committed: true,
                completedAt: DateTime.now(),
                entityType: 'app_setting',
                entityId: 'locale',
                before: {'locale': previousLocale},
                after: {'locale': locale},
                toolId: action.toolId,
                operationId: action.operationId,
                undoable: true,
              ),
              undo: () => ref
                  .read(appSettingsProvider.notifier)
                  .setLocale(previousLocale),
            );
            _showActionCompleted(tr('Language updated.', 'تم تحديث اللغة.'));
          }
        case IntelligenceActionType.updateGoal:
        case IntelligenceActionType.saveMeasurements:
          if (!await _commitPreparedCoachNativeAction(action, preparedNative)) {
            return false;
          }
        case IntelligenceActionType.quickAddMacros:
        case IntelligenceActionType.updateMealItem:
        case IntelligenceActionType.deleteMealItem:
        case IntelligenceActionType.moveMealItem:
          if (!await _commitPreparedCoachMealAction(action, preparedMeal!)) {
            return false;
          }
        case IntelligenceActionType.requestAccountDeletion:
          await _openCoachRoute('/help/delete-account', push: true);
        case IntelligenceActionType.signOut:
          await CloudBeforeSignOutSync.runBounded();
          await Supabase.instance.client.auth.signOut();
          if (Supabase.instance.client.auth.currentSession != null) {
            throw StateError('sign_out_readback_failed');
          }
          if (mounted) {
            _appendToolReceipt(
              tr('Signed out successfully.', 'تم تسجيل الخروج بنجاح.'),
            );
          }
        case IntelligenceActionType.saveMemory:
          if (!await _commitPreparedCoachNativeAction(action, preparedNative)) {
            return false;
          }
      }
      if (action.operationId case final operationId?) {
        completedActionOperationIds.add(operationId);
      }
      succeeded = true;
      return true;
    } on CoachMealConflict catch (error) {
      if (mounted) _showCoachMealConflict(error);
      return false;
    } on CoachNativeConflict catch (error) {
      if (mounted) _showCoachNativeConflict(error);
      return false;
    } on Object {
      if (!mounted) return false;
      if (tracksInlineNavigation) {
        _updateState(
          () => actionExecutionPhases[executionKey] =
              _CoachActionExecutionPhase.failed,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The action was not completed. Your data stayed unchanged; review the value and try again.',
              'لم يُنفذ الإجراء. بقيت بياناتك دون تغيير؛ راجع القيمة وحاول مجددًا.',
            ),
          ),
        ),
      );
      return false;
    } finally {
      executingActionKeys.remove(executionKey);
      if (mounted && succeeded && tracksInlineNavigation) {
        _updateState(() => actionExecutionPhases.remove(executionKey));
      }
    }
  }

  Future<void> _openCoachRoute(String path, {bool push = false}) => ref.read(
    intelligenceCenterNavigationExecutorProvider,
  )(context, path, push);

  Future<void> _retireDurableAction(IntelligenceAction action) async {
    var changed = false;
    void retire() {
      for (var index = 0; index < messages.length; index += 1) {
        final message = messages[index];
        final retained = message.actionLinks
            .where(
              (candidate) => action.operationId != null
                  ? candidate.operationId != action.operationId
                  : candidate.type != action.type || candidate.id != action.id,
            )
            .toList(growable: false);
        if (retained.length == message.actionLinks.length) continue;
        messages[index] = message.copyWith(actionLinks: retained);
        changed = true;
      }
    }

    if (mounted) {
      _updateState(retire);
    } else {
      // The state object and its captured repositories remain valid while an
      // already-started commit finishes. Avoid setState/WidgetRef, but queue a
      // newer action-free snapshot after dispose's best-effort save.
      retire();
    }
    if (changed) await _saveConversation();
  }

  void _showActionCompleted(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _coachDateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void _appendToolReceipt(
    String text, {
    BilActionReceipt? receipt,
    Future<void> Function()? undo,
    Future<BilActionReceipt> Function(void Function() checkWritePermission)?
    undoReadback,
    bool verifiedResult = true,
  }) {
    if (!mounted) return;
    final messageId = 'tool-${DateTime.now().microsecondsSinceEpoch}';
    _updateState(() {
      messages.add(
        IntelligenceMessage(
          id: messageId,
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.action,
          text: text,
          createdAt: DateTime.now(),
          evidence: [
            if (verifiedResult) 'BIL verified tool result',
            if (receipt != null) jsonEncode(receipt.toStructuredPayload()),
          ],
          confidence: 1,
        ),
      );
      if (receipt != null &&
          (undo != null || undoReadback != null) &&
          receipt.undoable) {
        undoOperations[messageId] = _CoachUndoOperation(
          receipt: receipt,
          undo: undo,
          undoReadback: undoReadback,
        );
      }
    });
    _scrollToLatest();
    unawaited(_saveConversation());
  }

  bool _isCoachUndoRequest(String value) {
    final normalized = value.trim().toLowerCase();
    return const {
      'undo',
      'undo that',
      'revert',
      'تراجع',
      'تراجع عن ذلك',
      'الغاء',
      'إلغاء',
    }.contains(normalized);
  }

  Future<void> _undoLatestCoachAction() async {
    final messageId = messages.reversed
        .map((message) => message.id)
        .firstWhere(
          (id) => undoOperations[id]?.completed == false,
          orElse: () => '',
        );
    if (messageId.isEmpty) {
      _appendToolReceipt(
        tr(
          'There is no recent reversible action.',
          'لا يوجد إجراء حديث قابل للتراجع.',
        ),
        verifiedResult: false,
      );
      return;
    }
    await _undoCoachAction(messageId);
  }

  Future<void> _undoCoachAction(String messageId) async {
    final operation = undoOperations[messageId];
    if (operation == null || operation.completed || operation.running) return;
    final epoch = conversationPersistenceEpoch;
    bool stillShowing() =>
        mounted &&
        epoch == conversationPersistenceEpoch &&
        identical(undoOperations[messageId], operation) &&
        messages.any((message) => message.id == messageId);
    bool mayWrite() =>
        mounted &&
        ref.read(coachActionPermissionModeProvider) !=
            CoachActionPermissionMode.readOnly;
    void showPermissionRequired() => _showActionCompleted(
      tr(
        'This action needs write permission. Change the shield setting to continue.',
        'يحتاج هذا الإجراء إلى إذن كتابة. غيّر إعداد الدرع للمتابعة.',
      ),
    );
    if (!mayWrite()) {
      showPermissionRequired();
      return;
    }
    var revoked = false;
    void checkWritePermission() {
      if (revoked || !mayWrite()) throw const _CoachUndoPermissionDenied();
    }

    final permissionSubscription = ref.listenManual(
      coachActionPermissionModeProvider,
      (previous, next) {
        if (next == CoachActionPermissionMode.readOnly) revoked = true;
      },
    );
    _updateState(() => operation.running = true);
    try {
      checkWritePermission();
      final readback = operation.undoReadback;
      final BilActionReceipt receipt;
      if (readback != null) {
        receipt = await readback(checkWritePermission);
      } else {
        await operation.undo!();
        receipt = BilActionReceipt(
          actionId: operation.receipt.actionId,
          operationId: operation.receipt.operationId,
          committed: true,
          completedAt: operation.receipt.completedAt,
          entityType: operation.receipt.entityType,
          entityId: operation.receipt.entityId,
          refreshTargets: operation.receipt.refreshTargets,
          before: operation.receipt.before,
          after: operation.receipt.after,
          toolId: operation.receipt.toolId,
          undoneAt: DateTime.now(),
        );
      }
      if (!stillShowing()) return;
      _updateState(() {
        operation.completed = true;
        undoOperations.remove(messageId);
      });
      _appendToolReceipt(
        tr('The previous action was undone.', 'تم التراجع عن الإجراء السابق.'),
        receipt: receipt,
      );
    } on _CoachUndoPermissionDenied {
      if (stillShowing()) showPermissionRequired();
    } on CoachMealConflict catch (error) {
      if (stillShowing()) _showCoachMealConflict(error);
    } on CoachNativeConflict catch (error) {
      if (stillShowing()) _showCoachNativeConflict(error);
    } on Object {
      if (stillShowing()) {
        _showActionCompleted(
          tr(
            'Undo could not be completed. Review your current data.',
            'تعذر إكمال التراجع. راجع بياناتك الحالية.',
          ),
        );
      }
    } finally {
      permissionSubscription.close();
      if (stillShowing()) _updateState(() => operation.running = false);
    }
  }

  Future<void> _recordFeedback(
    IntelligenceMessage message,
    bool helpful, {
    String? reason,
  }) async {
    final previous = messageFeedback[message.id];
    final wasReported = reportedMessages.contains(message.id);
    _updateState(() {
      if (reason == 'unsafe') {
        reportedMessages.add(message.id);
      } else {
        messageFeedback[message.id] = helpful;
      }
    });
    try {
      await const AiCoachFeedbackService().record(
        responseId: message.id,
        helpful: helpful,
        locale: BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
        runtime:
            messageRuntimes[message.id] ?? CoachAnswerRuntime.localFallback,
        reason: reason,
      );
      if (!mounted) return;
      _showActionCompleted(
        reason == 'unsafe'
            ? tr(
                'Thanks — this answer was reported for safety review.',
                'شكرًا — تم الإبلاغ عن هذه الإجابة لمراجعة السلامة.',
              )
            : tr(
                'Thanks — your feedback was saved.',
                'شكرًا — تم حفظ ملاحظتك.',
              ),
      );
    } on Object {
      if (!mounted) return;
      _updateState(() {
        if (reason == 'unsafe') {
          if (!wasReported) reportedMessages.remove(message.id);
        } else {
          if (previous == null) {
            messageFeedback.remove(message.id);
          } else {
            messageFeedback[message.id] = previous;
          }
        }
      });
      _showActionCompleted(
        tr('Feedback could not be saved right now.', 'تعذر حفظ الملاحظة الآن.'),
      );
    }
  }

  void usePrompt(String value) {
    question.text = value;
    ask();
  }

  Future<void> _openAiCoachSettings() async {
    await context.push('/settings/ai-coach');
    if (!mounted) return;
    _updateState(() {
      lastServiceStatus = CoachServiceStatus.ready;
      lastRuntime = CoachAnswerRuntime.onDevice;
    });
  }
}
