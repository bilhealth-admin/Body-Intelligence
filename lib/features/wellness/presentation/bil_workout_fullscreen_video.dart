part of 'bil_workout_routines_page.dart';

enum _WorkoutVideoFailure { start, stalled }

/// Owns the route-level playback lifecycle separately from cached media
/// resolution and download controls.
class _FullscreenWorkoutVideoPage extends StatefulWidget {
  const _FullscreenWorkoutVideoPage({
    this.file,
    this.controllerFactory,
    this.initialPosition = Duration.zero,
    this.onPositionChanged,
    this.initializationTimeout = const Duration(seconds: 20),
    this.commandTimeout = const Duration(seconds: 8),
    this.bufferingTimeout = const Duration(seconds: 30),
    this.controlsAutoHideDuration = const Duration(seconds: 3),
  }) : assert(
         (file == null) != (controllerFactory == null),
         'Provide exactly one workout video source.',
       );

  final File? file;
  final Future<VideoPlayerController> Function()? controllerFactory;
  final Duration initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final Duration initializationTimeout;
  final Duration commandTimeout;
  final Duration bufferingTimeout;
  final Duration controlsAutoHideDuration;

  @override
  State<_FullscreenWorkoutVideoPage> createState() =>
      _FullscreenWorkoutVideoPageState();
}

@visibleForTesting
Widget buildWorkoutFullscreenVideoForTest({
  File? file,
  Future<VideoPlayerController> Function()? controllerFactory,
  Duration initialPosition = Duration.zero,
  ValueChanged<Duration>? onPositionChanged,
  Duration initializationTimeout = const Duration(seconds: 20),
  Duration commandTimeout = const Duration(seconds: 8),
  Duration bufferingTimeout = const Duration(seconds: 30),
  Duration controlsAutoHideDuration = const Duration(seconds: 3),
}) => _FullscreenWorkoutVideoPage(
  file: file,
  controllerFactory: controllerFactory,
  initialPosition: initialPosition,
  onPositionChanged: onPositionChanged,
  initializationTimeout: initializationTimeout,
  commandTimeout: commandTimeout,
  bufferingTimeout: bufferingTimeout,
  controlsAutoHideDuration: controlsAutoHideDuration,
);

class _FullscreenWorkoutVideoPageState
    extends State<_FullscreenWorkoutVideoPage>
    with WidgetsBindingObserver {
  static const _controlSeekStep = Duration(seconds: 5);
  static const _playbackSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

  VideoPlayerController? _controller;
  final Map<VideoPlayerController, Set<Future<void>>> _pendingPlayOperations =
      <VideoPlayerController, Set<Future<void>>>{};
  Timer? _controlsTimer;
  Timer? _bufferingTimer;
  int _generation = 0;
  late Duration _latestPosition;
  Duration? _scrubPosition;
  _WorkoutVideoFailure? _failure;
  bool _loading = true;
  bool _controlsVisible = true;
  bool _appIsResumed = true;
  bool _wantsPlayback = true;
  bool _wasPlayingBeforeScrub = false;
  bool _wasBuffering = false;
  double _playbackSpeed = 1;

  @override
  void initState() {
    super.initState();
    _latestPosition = widget.initialPosition.isNegative
        ? Duration.zero
        : widget.initialPosition;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appIsResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _wantsPlayback = _appIsResumed;
    unawaited(_startPlayback(resumeAt: _latestPosition));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _appIsResumed = resumed;
    if (!resumed) {
      // This observer is registered before a controller is created. Updating
      // the controller's playing flag synchronously here also prevents the
      // plugin's own lifecycle observer from resuming playback behind BIL.
      _wantsPlayback = false;
      _controlsTimer?.cancel();
      _bufferingTimer?.cancel();
      final controller = _controller;
      if (controller != null) unawaited(_pauseWithoutFailure(controller));
      if (mounted) setState(() => _controlsVisible = true);
      return;
    }

    // A lifecycle resume never auto-plays. The user must explicitly tap Play.
    if (mounted) setState(() => _controlsVisible = true);
  }

  Future<void> _startPlayback({required Duration resumeAt}) async {
    final generation = ++_generation;
    _controlsTimer?.cancel();
    _bufferingTimer?.cancel();
    final previous = _detachController();
    if (previous != null) unawaited(_disposeController(previous));
    if (mounted) {
      setState(() {
        _loading = true;
        _failure = null;
        _controlsVisible = true;
        _scrubPosition = null;
      });
    }

    VideoPlayerController? candidate;
    try {
      final creation = Future<VideoPlayerController>.sync(() {
        final factory = widget.controllerFactory;
        if (factory != null) return factory();
        return VideoPlayerController.file(
          widget.file!,
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
          ),
        );
      });

      // A factory may resolve after its timeout or after route disposal. Its
      // late controller must never leak or attach to a newer retry generation.
      unawaited(
        creation.then<void>((lateController) {
          if (!mounted || generation != _generation) {
            return _disposeController(lateController);
          }
        }, onError: (Object _, StackTrace _) {}),
      );

      candidate = await creation.timeout(widget.initializationTimeout);
      if (!mounted || generation != _generation) {
        await _disposeController(candidate);
        return;
      }

      _controller = candidate;
      candidate.addListener(_handleControllerChanged);
      await candidate.initialize().timeout(widget.initializationTimeout);
      if (!mounted || generation != _generation) return;

      final target = resumeAt >= candidate.value.duration
          ? Duration.zero
          : _clampPosition(resumeAt, candidate.value.duration);
      if (target > Duration.zero) {
        await _boundedCommand(candidate.seekTo(target));
      }
      if (!mounted || generation != _generation) return;
      _reportPosition(target);

      if (_playbackSpeed != 1) {
        try {
          await _boundedCommand(candidate.setPlaybackSpeed(_playbackSpeed));
        } on Object {
          _playbackSpeed = 1;
          try {
            await _boundedCommand(candidate.setPlaybackSpeed(1));
          } on Object {
            // Speed support is optional. Normal playback remains available.
          }
        }
      }

      if (!mounted || generation != _generation) return;
      if (_wantsPlayback && _appIsResumed) {
        await _playWithSpeedFallback(candidate, generation);
        // Cover the narrow race where the lifecycle changed while play awaited
        // the platform. Resuming later still requires an explicit user tap.
        if (!_appIsResumed || !_wantsPlayback) {
          await _pauseWithoutFailure(candidate);
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      _syncBufferingTimer();
      _scheduleControlsHide();
    } on Object {
      if (!mounted || generation != _generation) return;
      _showFailure(generation, _WorkoutVideoFailure.start);
    }
  }

  void _handleControllerChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    final bufferingEnded = _wasBuffering && !value.isBuffering;
    _wasBuffering = value.isBuffering;
    if (!_loading &&
        value.isInitialized &&
        value.position != _latestPosition &&
        _scrubPosition == null) {
      // A stream that is still advancing is not stalled, even if the native
      // decoder leaves its buffering flag set while filling the next segment.
      _bufferingTimer?.cancel();
      _bufferingTimer = null;
      _reportPosition(value.position);
    }
    if (value.hasError) {
      _showFailure(_generation, _WorkoutVideoFailure.start);
      return;
    }
    if (value.isCompleted) {
      _wantsPlayback = false;
      _controlsTimer?.cancel();
      _controlsVisible = true;
      // A completed workout starts at the beginning on the next visit.
      _reportPosition(Duration.zero);
    }
    _syncBufferingTimer();
    if (bufferingEnded) _scheduleControlsHide();
    setState(() {});
  }

  void _syncBufferingTimer() {
    final value = _controller?.value;
    final shouldWatch =
        !_loading &&
        value != null &&
        value.isInitialized &&
        value.isBuffering &&
        _wantsPlayback &&
        _appIsResumed;
    if (!shouldWatch) {
      _bufferingTimer?.cancel();
      _bufferingTimer = null;
      return;
    }
    if (_bufferingTimer?.isActive ?? false) return;
    final generation = _generation;
    _bufferingTimer = Timer(widget.bufferingTimeout, () {
      if (!mounted || generation != _generation) return;
      final current = _controller?.value;
      if (current?.isBuffering ?? false) {
        _showFailure(generation, _WorkoutVideoFailure.stalled);
      }
    });
  }

  void _showFailure(int generation, _WorkoutVideoFailure failure) {
    if (!mounted || generation != _generation) return;
    _generation += 1;
    _controlsTimer?.cancel();
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    _wantsPlayback = false;
    final controller = _detachController();
    setState(() {
      _loading = false;
      _failure = failure;
      _controlsVisible = true;
      _scrubPosition = null;
    });
    if (controller != null) unawaited(_disposeController(controller));
  }

  VideoPlayerController? _detachController() {
    final controller = _controller;
    if (controller == null) return null;
    if (!_loading && controller.value.isInitialized) {
      _reportPosition(_resumePositionFor(controller));
    }
    controller.removeListener(_handleControllerChanged);
    _controller = null;
    _wasBuffering = false;
    return controller;
  }

  Future<void> _disposeController(VideoPlayerController controller) async {
    try {
      var waitedForPlay = false;
      Future<void>? earlyPause;
      while (true) {
        final pending = _pendingPlayOperations[controller]?.toList(
          growable: false,
        );
        if (pending == null || pending.isEmpty) break;
        waitedForPlay = true;
        // Invoke Pause before waiting: this updates the controller's desired
        // state synchronously even when native Play has not returned yet.
        earlyPause ??= _pauseWithoutFailure(controller);
        await Future.wait<void>(
          pending.map(
            (operation) => operation.then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            ),
          ),
        );
      }
      if (waitedForPlay) {
        // `video_player` starts its periodic position timer only after the
        // native Play future completes. A command timeout cannot cancel that
        // future, so wait for it and synchronously switch the controller back
        // to Pause before disposal; otherwise a late completion can create a
        // timer after VideoPlayerController.dispose has already run.
        await earlyPause;
        await _pauseWithoutFailure(controller);
      }
      await controller.dispose();
    } on Object {
      // Disposal must not block route exit or a fresh retry controller.
    } finally {
      _pendingPlayOperations.remove(controller);
    }
  }

  Future<void> _boundedCommand(Future<void> operation) =>
      operation.timeout(widget.commandTimeout);

  Future<void> _boundedPlay(VideoPlayerController controller, int generation) {
    final operation = Future<void>.sync(controller.play);
    final pending = _pendingPlayOperations.putIfAbsent(
      controller,
      () => <Future<void>>{},
    );
    pending.add(operation);

    void removeOperation() {
      final current = _pendingPlayOperations[controller];
      current?.remove(operation);
      if (current?.isEmpty ?? false) {
        _pendingPlayOperations.remove(controller);
      }
    }

    unawaited(
      operation.then<void>(
        (_) {
          removeOperation();
          // A lifecycle pause can happen while native Play is still pending.
          // Once it eventually completes, cancel the plugin's newly-created
          // position timer while this controller is still attached.
          if (mounted &&
              identical(_controller, controller) &&
              (generation != _generation ||
                  !_appIsResumed ||
                  !_wantsPlayback)) {
            unawaited(_pauseWithoutFailure(controller));
          }
        },
        onError: (Object _, StackTrace _) {
          removeOperation();
        },
      ),
    );
    return operation.timeout(widget.commandTimeout);
  }

  Future<void> _pauseWithoutFailure(VideoPlayerController controller) async {
    try {
      await _boundedCommand(controller.pause());
    } on Object {
      // Lifecycle transitions are best-effort and never become UI errors.
    }
  }

  void _reportPosition(Duration position) {
    final safe = position.isNegative ? Duration.zero : position;
    _latestPosition = safe;
    try {
      widget.onPositionChanged?.call(safe);
    } on Object {
      // The route owns playback; an optional persistence callback cannot break
      // the player or prevent the user from leaving it.
    }
  }

  Duration _resumePositionFor(VideoPlayerController controller) =>
      controller.value.isCompleted ? Duration.zero : controller.value.position;

  Future<void> _retry() async {
    _wantsPlayback = _appIsResumed;
    await _startPlayback(resumeAt: _latestPosition);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _loading ||
        _failure != null) {
      return;
    }
    _revealControls();
    final generation = _generation;
    try {
      if (controller.value.isCompleted) {
        await _replay();
        return;
      }
      if (controller.value.isPlaying) {
        _wantsPlayback = false;
        await _boundedCommand(controller.pause());
      } else if (_appIsResumed) {
        _wantsPlayback = true;
        await _playWithSpeedFallback(controller, generation);
        if (!_appIsResumed || !_wantsPlayback) {
          await _pauseWithoutFailure(controller);
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {});
      _syncBufferingTimer();
      _scheduleControlsHide();
    } on Object {
      if (mounted && generation == _generation) {
        _showFailure(generation, _WorkoutVideoFailure.start);
      }
    }
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _revealControls();
    final generation = _generation;
    try {
      await _boundedCommand(controller.seekTo(Duration.zero));
      if (!mounted || generation != _generation) return;
      _reportPosition(Duration.zero);
      if (_appIsResumed) {
        _wantsPlayback = true;
        await _playWithSpeedFallback(controller, generation);
        if (!_appIsResumed || !_wantsPlayback) {
          await _pauseWithoutFailure(controller);
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {});
      _scheduleControlsHide();
    } on Object {
      if (mounted && generation == _generation) {
        _showFailure(generation, _WorkoutVideoFailure.start);
      }
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final generation = _generation;
    _revealControls();
    final target = _clampPosition(
      controller.value.position + delta,
      controller.value.duration,
    );
    try {
      await _boundedCommand(controller.seekTo(target));
      if (!mounted || generation != _generation) return;
      _reportPosition(target);
      if (mounted) setState(() {});
    } on TimeoutException {
      if (mounted && generation == _generation) {
        _showFailure(generation, _WorkoutVideoFailure.start);
      }
      return;
    } on Object {
      // A transient seek failure does not invalidate otherwise usable media.
    }
    _scheduleControlsHide();
  }

  void _onScrubStart(double _) {
    final controller = _controller;
    if (controller == null) return;
    _revealControls(scheduleHide: false);
    _wasPlayingBeforeScrub = controller.value.isPlaying;
    _wantsPlayback = false;
    if (_wasPlayingBeforeScrub) unawaited(_pauseWithoutFailure(controller));
  }

  void _onScrubChanged(double milliseconds) {
    setState(() {
      _scrubPosition = Duration(milliseconds: milliseconds.round());
    });
  }

  Future<void> _onScrubEnd(double milliseconds) async {
    final controller = _controller;
    if (controller == null) return;
    final generation = _generation;
    final target = _clampPosition(
      Duration(milliseconds: milliseconds.round()),
      controller.value.duration,
    );
    try {
      await _boundedCommand(controller.seekTo(target));
      if (!mounted || generation != _generation) return;
      _reportPosition(target);
      if (_wasPlayingBeforeScrub && _appIsResumed) {
        _wantsPlayback = true;
        await _playWithSpeedFallback(controller, generation);
        if (!_appIsResumed || !_wantsPlayback) {
          await _pauseWithoutFailure(controller);
        }
      }
    } on TimeoutException {
      if (mounted && generation == _generation) {
        _showFailure(generation, _WorkoutVideoFailure.start);
      }
      return;
    } on Object {
      // Keep the current frame and controls usable when a platform rejects a
      // single scrub operation.
    }
    if (!mounted || generation != _generation) return;
    setState(() => _scrubPosition = null);
    _syncBufferingTimer();
    _scheduleControlsHide();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _revealControls();
    final previous = _playbackSpeed;
    final generation = _generation;
    setState(() => _playbackSpeed = speed);
    try {
      await _boundedCommand(controller.setPlaybackSpeed(speed));
    } on Object {
      // iOS can reject speeds that a particular media item cannot sustain.
      // Restore the previous value and keep normal playback alive.
      try {
        await _boundedCommand(controller.setPlaybackSpeed(previous));
      } on Object {
        // The controller value is still reset synchronously by the plugin.
      }
      if (!mounted || generation != _generation) return;
      setState(() => _playbackSpeed = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fullscreenVideoCopy(context, 'speedError'))),
      );
    }
    _scheduleControlsHide();
  }

  /// `video_player` applies a selected speed only when Play reaches the native
  /// platform. On iOS, a speed chosen while paused can therefore fail here
  /// rather than in [VideoPlayerController.setPlaybackSpeed]. Retry once at
  /// normal speed; a second failure remains a real playback failure and is
  /// deliberately propagated to the caller's bounded retry UI.
  Future<void> _playWithSpeedFallback(
    VideoPlayerController controller,
    int generation,
  ) async {
    try {
      await _boundedPlay(controller, generation);
      return;
    } on Object catch (firstError, firstStack) {
      if (!mounted || generation != _generation) {
        Error.throwWithStackTrace(firstError, firstStack);
      }
      if (!_appIsResumed || !_wantsPlayback) {
        await _pauseWithoutFailure(controller);
        return;
      }
      // A timeout leaves native Play running. Starting a second Play while the
      // first is unresolved would create overlapping operations and cannot
      // prove that playback speed was the cause.
      if (_playbackSpeed == 1 || firstError is TimeoutException) {
        Error.throwWithStackTrace(firstError, firstStack);
      }
    }

    _playbackSpeed = 1;
    try {
      // The plugin updates its value synchronously even when the native call
      // rejects, so the following Play also reapplies the restored value.
      await _boundedCommand(controller.setPlaybackSpeed(1));
    } on Object {
      // The single Play retry below is the authoritative capability check.
    }
    if (!mounted ||
        generation != _generation ||
        !_appIsResumed ||
        !_wantsPlayback) {
      await _pauseWithoutFailure(controller);
      return;
    }

    await _boundedPlay(controller, generation);
    if (!mounted || generation != _generation) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_fullscreenVideoCopy(context, 'speedError'))),
    );
  }

  void _revealControls({bool scheduleHide = true}) {
    _controlsTimer?.cancel();
    if (mounted && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    if (scheduleHide) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    final value = _controller?.value;
    if (!mounted ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true ||
        value == null ||
        !value.isPlaying ||
        value.isBuffering ||
        _failure != null) {
      return;
    }
    _controlsTimer = Timer(widget.controlsAutoHideDuration, () {
      if (!mounted || !(_controller?.value.isPlaying ?? false)) return;
      setState(() => _controlsVisible = false);
    });
  }

  Future<void> _exit() {
    final controller = _controller;
    if (controller != null) {
      if (!_loading && controller.value.isInitialized) {
        _reportPosition(_resumePositionFor(controller));
      }
      _wantsPlayback = false;
    }
    if (!mounted) return Future<void>.value();
    final pop = Navigator.of(context).maybePop();
    if (controller != null) unawaited(_pauseWithoutFailure(controller));
    return pop.then<void>((_) {});
  }

  Duration _clampPosition(Duration position, Duration duration) {
    if (position.isNegative) return Duration.zero;
    if (duration <= Duration.zero) return Duration.zero;
    return position > duration ? duration : position;
  }

  @override
  void dispose() {
    _generation += 1;
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _bufferingTimer?.cancel();
    final controller = _detachController();
    if (controller != null) unawaited(_disposeController(controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildFullscreenPlayer(context);
}
