part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanSyncReview on _BilSmartPlanPageState {
  Future<void> _resolvePlanConflict(
    BilSmartPlanSync sync,
    String owner,
    int epoch,
  ) async {
    final reviewed = await sync.reviewConflict(owner);
    if (!mounted || epoch != _ownerEpoch) return;
    final keepLocal = await _reviewSurface(
      () => showBilModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BilSmartPlanConflictReviewPanel(
          reviewed: reviewed,
          checkAccess: () {
            if (!mounted || epoch != _ownerEpoch || _owner != owner) {
              throw StateError('smart_plan_owner_changed');
            }
            _checkAccess();
          },
          horizonName: _horizonName,
          statusName: _statusName,
        ),
      ),
    );
    if (keepLocal == null || !mounted || epoch != _ownerEpoch) return;
    _checkAccess();
    await sync.resolveConflict(reviewed, keepLocal: keepLocal);
    if (mounted && epoch == _ownerEpoch) {
      ref.invalidate(coachContextSnapshotProvider);
      await _load();
    }
  }
}
