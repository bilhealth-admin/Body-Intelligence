part of 'bil_smart_plan_repository.dart';

/// A replacement stays separate from the approved schedule until confirmed.
/// Drafts and superseded plans are private local records, not silently added
/// to the active-plan cloud consent or to Gemini context.
extension BilSmartPlanDraftRepository on BilSmartPlanRepository {
  String draftKey(String owner) => 'bil.smart-plan.draft.$owner.v1';
  String archiveKey(String owner) => 'bil.smart-plan.archive.$owner.v1';

  Future<List<Map<String, Object?>>> exportConflictHistory(String owner) async {
    _requireOwner(owner);
    final raw = await preferences.get('bil.smart-plan.conflicts.$owner.v1');
    _requireOwner(owner);
    if (raw == null) return const [];
    final rows = jsonDecode(raw) as List;
    if (rows.length > 10) throw StateError('smart_plan_archive_capacity');
    return List.unmodifiable(
      rows.map((row) {
        final value = Map<String, Object?>.from(row as Map);
        if (value['ownerId'] != owner) {
          throw StateError('smart_plan_foreign_archive');
        }
        for (final key in ['local', 'cloud']) {
          final plan = value[key];
          if (plan != null &&
              BilSmartPlan.decode(plan as String).ownerId != owner) {
            throw StateError('smart_plan_foreign_archive');
          }
        }
        return value;
      }),
    );
  }

  Future<BilSmartPlan?> readDraft(String owner) async {
    _requireOwner(owner);
    final raw = await preferences.get(draftKey(owner));
    _requireOwner(owner);
    if (raw == null) return null;
    final envelope = jsonDecode(raw) as Map;
    final plan = BilSmartPlan.decode(envelope['draft'] as String);
    final base = BilSmartPlan.decode(envelope['base'] as String);
    if (envelope.length != 2 ||
        base.ownerId != owner ||
        base.id == plan.id ||
        plan.ownerId != owner ||
        plan.status != BilPlanStatus.draft ||
        plan.revision != 1) {
      throw StateError('smart_plan_foreign_draft');
    }
    return plan;
  }

  Future<List<BilSmartPlan>> readArchives(String owner) async {
    _requireOwner(owner);
    final raw = await preferences.get(archiveKey(owner));
    _requireOwner(owner);
    final rows = raw == null ? <Object?>[] : jsonDecode(raw) as List;
    if (rows.length > 20) throw StateError('smart_plan_archive_capacity');
    final plans = rows
        .map((row) => BilSmartPlan.decode(row as String))
        .toList();
    if (plans.any((plan) => plan.ownerId != owner) ||
        plans.map((plan) => plan.id).toSet().length != plans.length) {
      throw StateError('smart_plan_foreign_archive');
    }
    return List.unmodifiable(plans);
  }

  Future<BilSmartPlan> stageDraft(
    BilSmartPlan draft, {
    required BilSmartPlan approved,
  }) async {
    final owner = draft.ownerId;
    _requireOwner(owner);
    if (approved.ownerId != owner ||
        draft.id == approved.id ||
        draft.status != BilPlanStatus.draft ||
        draft.revision != 1) {
      throw StateError('smart_plan_invalid_replacement');
    }
    final encoded = draft.encode();
    final success = await preferences.mutateIfUnchanged(
      expected: {storageKey(owner): approved.encode(), draftKey(owner): null},
      set: {
        draftKey(owner): jsonEncode({
          'base': approved.encode(),
          'draft': encoded,
        }),
      },
      isCurrent: () =>
          currentOwnerId() == owner && preferences.localOwnerId == owner,
    );
    _requireOwner(owner);
    if (!success) throw StateError('smart_plan_revision_conflict');
    final saved = await readDraft(owner);
    if (saved?.encode() != encoded ||
        (await readFor(owner))?.encode() != approved.encode()) {
      throw StateError('smart_plan_save_unverified');
    }
    return saved!;
  }

  Future<BilSmartPlan> activateDraft(BilSmartPlan reviewed) async {
    final owner = reviewed.ownerId;
    _requireOwner(owner);
    final raw = await preferences.get(draftKey(owner));
    _requireOwner(owner);
    if (raw == null) throw StateError('smart_plan_revision_conflict');
    final envelope = jsonDecode(raw) as Map;
    final draft = BilSmartPlan.decode(envelope['draft'] as String);
    final base = BilSmartPlan.decode(envelope['base'] as String);
    if (base.ownerId != owner ||
        draft.ownerId != owner ||
        draft.status != BilPlanStatus.draft ||
        draft.revision != 1 ||
        base.id == draft.id ||
        reviewed.encode() !=
            draft
                .withStatus(BilPlanStatus.active, reviewed.updatedAt)
                .encode()) {
      throw StateError('smart_plan_revision_conflict');
    }
    final archiveRaw = await preferences.get(archiveKey(owner));
    final archives = await readArchives(owner);
    if (archives.length >= 20 || archives.any((plan) => plan.id == base.id)) {
      throw StateError('smart_plan_archive_capacity');
    }
    final archiveNext = jsonEncode([
      ...archives.map((plan) => plan.encode()),
      base.encode(),
    ]);
    if (utf8.encode(archiveNext).length > 2000000) {
      throw StateError('smart_plan_archive_capacity');
    }
    final encoded = reviewed.encode();
    final success = await preferences.mutateIfUnchanged(
      expected: {
        storageKey(owner): base.encode(),
        draftKey(owner): raw,
        archiveKey(owner): archiveRaw,
      },
      set: {storageKey(owner): encoded, archiveKey(owner): archiveNext},
      remove: [draftKey(owner)],
      isCurrent: () =>
          currentOwnerId() == owner && preferences.localOwnerId == owner,
    );
    _requireOwner(owner);
    if (!success) throw StateError('smart_plan_revision_conflict');
    final saved = await readFor(owner);
    if (saved?.encode() != encoded ||
        !(await readArchives(
          owner,
        )).any((plan) => plan.encode() == base.encode())) {
      throw StateError('smart_plan_save_unverified');
    }
    return saved!;
  }

  Future<void> discardDraft(BilSmartPlan reviewed) async {
    final owner = reviewed.ownerId;
    _requireOwner(owner);
    final raw = await preferences.get(draftKey(owner));
    _requireOwner(owner);
    if (raw == null ||
        (jsonDecode(raw) as Map)['draft'] != reviewed.encode() ||
        !await preferences.mutateIfUnchanged(
          expected: {draftKey(owner): raw},
          remove: [draftKey(owner)],
          isCurrent: () =>
              currentOwnerId() == owner && preferences.localOwnerId == owner,
        )) {
      throw StateError('smart_plan_revision_conflict');
    }
    _requireOwner(owner);
  }

  Future<void> deleteLocalPreviousPlans({
    required String owner,
    required String? expectedArchives,
    required String? expectedDraft,
    String? expectedConflicts,
  }) async {
    _requireOwner(owner);
    final previous = await readArchives(owner);
    final removed = await preferences.mutateIfUnchanged(
      expected: {
        archiveKey(owner): expectedArchives,
        draftKey(owner): expectedDraft,
        'bil.smart-plan.conflicts.$owner.v1': expectedConflicts,
      },
      remove: [
        archiveKey(owner),
        draftKey(owner),
        'bil.smart-plan.conflicts.$owner.v1',
        for (final plan in previous)
          for (final day in plan.days)
            'bil.smart-plan.workout.${plan.id}.${day.date}',
      ],
      isCurrent: () =>
          currentOwnerId() == owner && preferences.localOwnerId == owner,
    );
    _requireOwner(owner);
    if (!removed) throw StateError('smart_plan_revision_conflict');
  }
}
