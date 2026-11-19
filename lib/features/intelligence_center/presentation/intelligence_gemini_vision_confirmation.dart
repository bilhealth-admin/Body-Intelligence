part of 'intelligence_center_page.dart';

extension _CoachGeminiVisionConfirmation on _IntelligenceCenterPageState {
  Future<void> _handoffGeminiVisionEstimate(
    _CoachMediaPageRequest request,
    String visionRequestId,
    List<ReviewedGeminiVisionEstimate> estimates,
    MealVisionEstimateVisit visit,
  ) async {
    if (!mounted || !visit.current || !await _mediaRequestCurrent(request)) {
      return;
    }
    // Permission validation awaited above. Recheck widget/owner/attempt lease
    // afterwards before reading providers or opening the confirmation route.
    if (!mounted ||
        !visit.current ||
        !request.attempt.isCurrent ||
        !request.owner.scope.isCurrent) {
      return;
    }
    var day = ref.read(selectedLogDateProvider);
    var meal = 'snack';
    var busy = false;
    var attempted = false;
    int? savedId;
    String? error;
    bool writeAllowed() =>
        mounted &&
        visit.current &&
        request.attempt.isCurrent &&
        request.owner.scope.isCurrent &&
        ref.read(coachActionPermissionModeProvider) !=
            CoachActionPermissionMode.readOnly;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => guardMealVisionReview(
        lifetime: visit.lifetime,
        child: StatefulBuilder(
          builder: (dialog, update) => PopScope(
            canPop: !busy,
            child: BilPearlMaterialAlertDialog(
              key: const Key('coach-gemini-diary-confirm'),
              scrollable: true,
              title: Text(
                geminiVisionText(
                  dialog,
                  savedId == null ? 'Save to diary' : 'Saved',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (savedId == null) ...[
                    DropdownButtonFormField<String>(
                      key: const Key('coach-gemini-meal'),
                      initialValue: meal,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('Meal', 'الوجبة'),
                      ),
                      items: [
                        for (final entry in {
                          'breakfast': tr('Breakfast', 'الفطور'),
                          'lunch': tr('Lunch', 'الغداء'),
                          'dinner': tr('Dinner', 'العشاء'),
                          'snack': tr('Snack', 'وجبة خفيفة'),
                        }.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: busy || attempted
                          ? null
                          : (value) {
                              if (value != null && request.attempt.isCurrent) {
                                update(() => meal = value);
                              }
                            },
                    ),
                    TextButton(
                      key: const Key('coach-gemini-day'),
                      onPressed: busy || attempted
                          ? null
                          : () async {
                              if (!await _mediaRequestCurrent(request) ||
                                  !dialog.mounted) {
                                return;
                              }
                              final next = await showBilCrystalDatePicker(
                                context: dialog,
                                initialDate: day,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (next != null &&
                                  await _mediaRequestCurrent(request) &&
                                  dialog.mounted) {
                                update(() => day = next);
                              }
                            },
                      child: Text(
                        MaterialLocalizations.of(dialog).formatMediumDate(day),
                      ),
                    ),
                    for (final estimate in estimates)
                      Text(
                        '${estimate.estimate.name} · ${estimate.amount} ${estimate.unit}',
                      ),
                    Text(geminiEstimateCopy(dialog, 0)),
                    if (error != null)
                      Semantics(liveRegion: true, child: Text(error!)),
                  ] else
                    Text(
                      tr(
                        'Your reviewed estimates were saved.',
                        'حُفظت التقديرات التي راجعتها.',
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialog),
                  child: Text(
                    geminiVisionText(
                      dialog,
                      savedId == null ? 'Cancel' : 'Close',
                    ),
                  ),
                ),
                if (savedId == null)
                  FilledButton(
                    key: const Key('coach-gemini-save'),
                    onPressed: busy
                        ? null
                        : () async {
                            if (busy ||
                                !visit.current ||
                                !request.attempt.isCurrent) {
                              return;
                            }
                            if (!writeAllowed()) {
                              update(
                                () => error = tr(
                                  'Read-only mode. No food was logged.',
                                  'وضع القراءة فقط. لم يُسجّل أي طعام.',
                                ),
                              );
                              return;
                            }
                            update(() {
                              busy = true;
                              attempted = true;
                            });
                            try {
                              if (!await _mediaRequestCurrent(request) ||
                                  !dialog.mounted ||
                                  !writeAllowed()) {
                                return;
                              }
                              final id = await request.owner.repository
                                  .addGeminiVisionMealAtomically(
                                    date: day,
                                    mealType: meal,
                                    ownerId:
                                        request.owner.database.localOwnerId!,
                                    requestId: visionRequestId,
                                    items: estimates,
                                    isCurrentOwner: writeAllowed,
                                  );
                              if (!await _mediaRequestCurrent(request) ||
                                  !dialog.mounted) {
                                return;
                              }
                              _refreshCommittedCoachMeals();
                              update(() => savedId = id);
                            } on Object {
                              if (dialog.mounted && request.attempt.isCurrent) {
                                update(
                                  () => error = geminiVisionText(
                                    dialog,
                                    'Could not save changes.',
                                  ),
                                );
                              }
                            } finally {
                              if (dialog.mounted) update(() => busy = false);
                            }
                          },
                    child: busy
                        ? const BilFeatureWelcomeStatus()
                        : Text(geminiVisionText(dialog, 'Save')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
