part of 'intelligence_center_page.dart';

extension on _IntelligenceCenterPageState {
  String _coachMessageAnchorIdentity(IntelligenceMessage message) =>
      '$conversationPersistenceEpoch:${activeConversationId ?? ''}:${message.id}';

  GlobalKey _coachMessageReadingAnchor(IntelligenceMessage message) {
    final scope = '$conversationPersistenceEpoch:${activeConversationId ?? ''}';
    if (coachMessageReadingAnchorScope != scope) {
      coachMessageReadingAnchors.clear();
      coachMessageReadingAnchorScope = scope;
    }
    return coachMessageReadingAnchors.putIfAbsent(
      _coachMessageAnchorIdentity(message),
      () => GlobalKey(debugLabel: 'coach-message-reading-start'),
    );
  }

  double _coachLatestReadingOffset(ScrollPosition position) {
    final fallback = position.minScrollExtent;
    // Owner/visit withdrawal can remove a keyed row in the same frame while
    // the viewport's AnimatedBuilder still asks for its latest target.
    if (!_coachMessageVisitIsCurrent()) return fallback;
    if (!position.hasContentDimensions ||
        !position.hasViewportDimension ||
        messages.isEmpty) {
      return fallback;
    }
    final latest = messages.last;
    // Reopened history keeps its existing newest-end position. The measured
    // start belongs to the fresh answer and remains stable after reveal.
    if (latest.role != IntelligenceMessageRole.bil ||
        !animatedResponseIds.contains(latest.id)) {
      return fallback;
    }
    final key = coachMessageReadingAnchors[_coachMessageAnchorIdentity(latest)];
    final anchorContext = key?.currentContext;
    // mounted alone includes inactive Elements. Element.renderObject safely
    // returns null for defunct rows; attached/size guards below reject detached
    // inactive render objects without a debug-only check or blanket catch.
    final render = anchorContext is Element && anchorContext.mounted
        ? anchorContext.renderObject
        : null;
    if (render is! RenderBox ||
        !render.attached ||
        !render.hasSize ||
        render.size.height <= position.viewportDimension) {
      return fallback;
    }
    final viewport = RenderAbstractViewport.maybeOf(render);
    if (viewport == null) return fallback;
    final offset = viewport
        .getOffsetToReveal(
          render,
          axisDirectionIsReversed(position.axisDirection) ? 1 : 0,
          rect: Rect.fromLTWH(0, 0, render.size.width, 1),
          axis: Axis.vertical,
        )
        .offset;
    return offset.isFinite
        ? offset
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble()
        : fallback;
  }

  bool _coachIsNearLatest(ScrollPosition position) =>
      (position.pixels - _coachLatestReadingOffset(position)).abs() <= 72;

  bool _coachMessageVisitIsCurrent() =>
      mounted &&
      conversationReady &&
      !coachMessageVisitCancelled &&
      ref.read(databaseProvider).localOwnerId ==
          conversationPreferences.localOwnerId &&
      identical(
        ref.read(preferencesRepositoryProvider),
        conversationPreferences,
      ) &&
      (coachMessageOwnerWitness == null ||
          coachMessageOwnerWitness!.readOwner() ==
              conversationPreferences.localOwnerId);

  String? _coachPlainMessage(IntelligenceMessage message) {
    final ownerKey = LocalDatabaseScope.keyForOwner(
      conversationPreferences.localOwnerId,
    );
    final copy = CoachMessagePlainCopy(
      context,
      system:
          ref.read(measurementSystemProvider).value ?? MeasurementSystem.metric,
    );
    final plain = copy.plain(
      fallback: message.text,
      presentation: message.presentation,
      expectedOwnerKey: ownerKey,
      archivedOwnerKey: message.presentationOwnerKey,
      ownerVisitIsCurrent: _coachMessageVisitIsCurrent,
    );
    if (plain == null) return null;
    final operation = undoOperations[message.id];
    final commit = operation?.mealCommit, receipt = operation?.receipt;
    if (commit == null ||
        receipt == null ||
        message.presentation != null ||
        commit.ownerScope != ownerKey ||
        !CoachFoodReceiptBinding.matches(commit, receipt) ||
        commit.state != CoachMealResultState.committed) {
      return plain;
    }
    final values = CoachFoodReceiptValues(commit), lines = <String>[plain];
    for (final snapshot in commit.after) {
      lines.add(
        '${copy.food.meal(snapshot.meal.type)} · ${copy.day(snapshot.meal.dayKey)} · ${snapshot.foodName}',
      );
    }
    for (final nutrient in FoodNutrient.values) {
      final value = values.total(nutrient);
      lines.add(
        '${copy.food.nutrient(nutrient)}: ${value == null ? '—' : '${copy.number(value)} ${CoachFoodNutrients.units[nutrient]!}'}',
      );
    }
    return _coachMessageVisitIsCurrent() ? lines.join('\n') : null;
  }

  Future<void> _copyCoachMessage(IntelligenceMessage message) async {
    final plain = _coachPlainMessage(message);
    if (plain != null) await Clipboard.setData(ClipboardData(text: plain));
  }

  Future<void> _shareCoachMessage(
    IntelligenceMessage message,
    BuildContext anchor,
  ) async {
    final plain = _coachPlainMessage(message);
    if (plain == null) return;
    final box = anchor.findRenderObject();
    if (!_coachMessageVisitIsCurrent()) return;
    await SharePlus.instance.share(
      ShareParams(
        text: plain,
        sharePositionOrigin: box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }

  Widget _buildMessage(
    IntelligenceMessage message,
    Map<String, bool> feedback,
  ) {
    final ownerKey = LocalDatabaseScope.keyForOwner(
      conversationPreferences.localOwnerId,
    );
    if (!_coachMessageVisitIsCurrent() ||
        (message.presentationOwnerKey != null &&
            message.presentationOwnerKey != ownerKey)) {
      return Text(CoachMessagePlainCopy(context).ownerChanged);
    }
    final canRate =
        message.role == IntelligenceMessageRole.bil &&
        !message.id.startsWith('welcome') &&
        !message.id.startsWith('tool-');
    return KeyedSubtree(
      key: _coachMessageReadingAnchor(message),
      child: _MessageBubble(
        message: message,
        sentFrom: outgoingMessageOrigins[message.id],
        onSentArrivalFinished: () => outgoingMessageOrigins.remove(message.id),
        feedbackValue: feedback[message.id],
        reported: reportedMessages.contains(message.id),
        expectedOwnerKey: ownerKey,
        ownerVisitIsCurrent: _coachMessageVisitIsCurrent,
        presentationCopy: CoachMessagePlainCopy(
          context,
          system:
              ref.watch(measurementSystemProvider).value ??
              MeasurementSystem.metric,
        ),
        onCopy: () => unawaited(_copyCoachMessage(message)),
        onShare: message.role == IntelligenceMessageRole.bil
            ? (anchor) => unawaited(_shareCoachMessage(message, anchor))
            : null,
        onSpeak:
            message.role == IntelligenceMessageRole.bil &&
                message.modality == IntelligenceMessageModality.voice
            ? () {
                final language = const CoachLanguageResolver()
                    .resolve(
                      input: message.text,
                      uiLocale: Localizations.localeOf(context).toLanguageTag(),
                    )
                    .languageTag;
                unawaited(
                  _speakCoachText(
                    _coachPlainMessage(message) ?? '',
                    language,
                    showFailure: true,
                  ),
                );
              }
            : null,
        onFeedback: canRate
            ? (helpful) => _recordFeedback(message, helpful)
            : null,
        onReport: canRate
            ? (reason) => _reportCoachAnswer(message, reason)
            : null,
        actionPhases: actionExecutionPhases,
        onRetry: retryableErrorMessageIds.contains(message.id)
            ? () => unawaited(_retryFailedCoachRequest())
            : null,
        retryLabel: _coachRetryLabel,
        onUndo: undoOperations.containsKey(message.id)
            ? () => unawaited(_undoCoachAction(message.id))
            : null,
        undoInProgress: undoOperations[message.id]?.running ?? false,
        animateReveal: animatedResponseIds.contains(message.id),
        richContent: _coachFoodReceiptWidget(message),
        onAction: (action) {
          unawaited(_executeAction(action).then<void>((_) {}));
        },
      ),
    );
  }
}
