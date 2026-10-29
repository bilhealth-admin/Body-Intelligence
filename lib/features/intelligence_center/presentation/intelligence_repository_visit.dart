part of 'intelligence_center_page.dart';

/// Retires a repository-bound visit when local storage is reopened for the
/// continuously authenticated owner. A cancelled auth visit is never revived.
class CoachRepositoryVisitBoundary extends ConsumerStatefulWidget {
  const CoachRepositoryVisitBoundary({
    super.key,
    this.startWithVisionCapture = false,
    this.initialBarcode,
  });

  final bool startWithVisionCapture;
  final String? initialBarcode;

  @override
  ConsumerState<CoachRepositoryVisitBoundary> createState() =>
      _CoachRepositoryVisitBoundaryState();
}

class _CoachRepositoryVisitBoundaryState
    extends ConsumerState<CoachRepositoryVisitBoundary> {
  var _pageKey = GlobalKey<_IntelligenceCenterPageState>();
  late final String? _owner;
  late final CoachNativeOwnerWitness? _witness;
  ProviderSubscription<AppDatabase>? _databaseSubscription;
  StreamSubscription<String?>? _ownerSubscription;
  AppDatabase? _pendingDatabase;
  bool _ownerWithdrawn = false;
  int _recoveryGeneration = 0;
  TextEditingValue? _restoredDraft;
  bool? _restoredOverview;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(databaseProvider).localOwnerId;
    _witness = ref.read(coachNativeOwnerWitnessProvider);
    _ownerSubscription = _witness?.changes.listen((owner) {
      if (owner != _owner) _ownerWithdrawn = true;
    }, onError: (Object _, StackTrace _) => _ownerWithdrawn = true);
    _databaseSubscription = ref.listenManual(databaseProvider, (
      previous,
      next,
    ) {
      if (identical(previous, next)) return;
      if (next.localOwnerId != _owner) _ownerWithdrawn = true;
      final generation = ++_recoveryGeneration;
      // The old page's normal database observer first withdraws all old
      // message/action scopes. Recreate it after this provider update unwinds;
      // never reset those cancelled scopes or reuse their callbacks.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _recoveryGeneration ||
            !_ownerIsContinuous() ||
            !identical(ref.read(databaseProvider), next) ||
            next.localOwnerId != _owner) {
          return;
        }
        setState(() => _pendingDatabase = next);
      });
    });
  }

  bool _ownerIsContinuous() {
    if (_witness != null && _witness.readOwner() != _owner) {
      _ownerWithdrawn = true;
    }
    return !_ownerWithdrawn;
  }

  @override
  void dispose() {
    _recoveryGeneration++;
    _databaseSubscription?.close();
    unawaited(_ownerSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _pendingDatabase;
    _pendingDatabase = null;
    // Auth can change between the provider callback and this frame. Recheck
    // the continuous-owner latch at the point that creates the new visit.
    if (next != null &&
        _ownerIsContinuous() &&
        next.localOwnerId == _owner &&
        identical(ref.read(databaseProvider), next)) {
      final previousPage = _pageKey.currentState;
      _restoredDraft = (previousPage?.question.value ?? TextEditingValue.empty)
          .copyWith(composing: TextRange.empty);
      _restoredOverview = previousPage?._referenceOverview ?? true;
      _pageKey = GlobalKey<_IntelligenceCenterPageState>();
    }
    return _restoredDraft == null
        ? IntelligenceCenterPage(
            key: _pageKey,
            startWithVisionCapture: widget.startWithVisionCapture,
            initialBarcode: widget.initialBarcode,
          )
        : IntelligenceCenterPage._restored(
            _restoredDraft!,
            _restoredOverview!,
            key: _pageKey,
            startWithVisionCapture: widget.startWithVisionCapture,
            initialBarcode: widget.initialBarcode,
          );
  }
}
