part of 'bil_workout_routines_page.dart';

extension _FullscreenWorkoutVideoView on _FullscreenWorkoutVideoPageState {
  Widget _buildFullscreenPlayer(BuildContext context) {
    final controller = _controller;
    final ready =
        !_loading &&
        _failure == null &&
        controller != null &&
        controller.value.isInitialized;
    final surfaceLabel = ready && controller.value.isPlaying
        ? wellnessWorkoutVideoAction(context, 'Pause video')
        : wellnessWorkoutVideoAction(context, 'Play video');

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _wantsPlayback = false;
            final current = _controller;
            if (current != null) {
              if (!_loading && current.value.isInitialized) {
                _reportPosition(_resumePositionFor(current));
              }
              unawaited(_pauseWithoutFailure(current));
            }
          }
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.space): () =>
                unawaited(_togglePlayback()),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                unawaited(
                  _seekRelative(
                    -_FullscreenWorkoutVideoPageState._controlSeekStep,
                  ),
                ),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                unawaited(
                  _seekRelative(
                    _FullscreenWorkoutVideoPageState._controlSeekStep,
                  ),
                ),
            const SingleActivator(LogicalKeyboardKey.keyR): () =>
                unawaited(_replay()),
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                unawaited(_exit()),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  container: true,
                  button: ready,
                  enabled: ready,
                  label: ready ? surfaceLabel : null,
                  onTap: ready ? _togglePlayback : null,
                  child: GestureDetector(
                    key: const ValueKey('workout-video-fullscreen-surface'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: _togglePlayback,
                    child: _buildPlaybackSurface(controller, ready),
                  ),
                ),
                if (ready && controller.value.isBuffering && _wantsPlayback)
                  _buildBufferingIndicator(),
                SafeArea(child: _buildControlsOverlay(controller, ready)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackSurface(VideoPlayerController? controller, bool ready) {
    if (_failure case final failure?) {
      final message = _fullscreenVideoCopy(
        context,
        failure == _WorkoutVideoFailure.stalled ? 'stallError' : 'startError',
      );
      return SafeArea(
        child: _WorkoutVideoError(
          message: message,
          retryLabel: _fullscreenVideoCopy(context, 'retry'),
          onRetry: _retry,
        ),
      );
    }
    if (!ready || controller == null) {
      return Semantics(
        liveRegion: true,
        label: _fullscreenVideoCopy(context, 'loading'),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final size = controller.value.size.isEmpty
        ? const Size(16, 9)
        : controller.value.size;
    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: ClipRect(
            child: ImageFiltered(
              key: const ValueKey('workout-video-blurred-background'),
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Transform.scale(
                scale: 1.08,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
        Center(
          child: AspectRatio(
            key: const ValueKey('workout-video-complete-frame'),
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      ],
    );
  }

  Widget _buildBufferingIndicator() => IgnorePointer(
    child: Center(
      child: Semantics(
        liveRegion: true,
        label: _fullscreenVideoCopy(context, 'buffering'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(
            dimension: 48,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildControlsOverlay(VideoPlayerController? controller, bool ready) =>
      AnimatedOpacity(
        key: const ValueKey('workout-video-controls-overlay'),
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PositionedDirectional(
                top: 8,
                start: 8,
                child: SizedBox.square(
                  dimension: 48,
                  child: IconButton.filledTonal(
                    key: const ValueKey('workout-video-fullscreen-back'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => unawaited(_exit()),
                    icon: const BackButtonIcon(),
                  ),
                ),
              ),
              if (ready && controller != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomControls(controller),
                ),
            ],
          ),
        ),
      );

  Widget _buildBottomControls(VideoPlayerController controller) {
    final value = controller.value;
    final duration = value.duration;
    final position = _clampPosition(_scrubPosition ?? value.position, duration);
    final maximum = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final sliderValue = position.inMilliseconds
        .clamp(0, maximum.toInt())
        .toDouble();
    final playLabel = value.isPlaying
        ? wellnessWorkoutVideoAction(context, 'Pause video')
        : wellnessWorkoutVideoAction(context, 'Play video');

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 30, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: _fullscreenVideoCopy(context, 'progress'),
              value:
                  '${_formatVideoTime(position)} / ${_formatVideoTime(duration)}',
              child: SizedBox(
                height: 48,
                child: Slider(
                  key: const ValueKey('workout-video-progress'),
                  value: sliderValue,
                  min: 0,
                  max: maximum,
                  onChangeStart: _onScrubStart,
                  onChanged: _onScrubChanged,
                  onChangeEnd: (next) => unawaited(_onScrubEnd(next)),
                ),
              ),
            ),
            Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: const ValueKey('workout-video-control-replay'),
                    tooltip: _fullscreenVideoCopy(context, 'replay'),
                    color: Colors.white,
                    onPressed: () => unawaited(_replay()),
                    icon: const Icon(Icons.replay_rounded),
                  ),
                ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: const ValueKey('workout-video-control-play-pause'),
                    tooltip: playLabel,
                    color: Colors.white,
                    onPressed: () => unawaited(_togglePlayback()),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_formatVideoTime(position)} / ${_formatVideoTime(duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: _fullscreenVideoCopy(context, 'speed'),
                  child: Semantics(
                    button: true,
                    label: _fullscreenVideoCopy(context, 'speed'),
                    value: _formatPlaybackSpeed(_playbackSpeed),
                    child: PopupMenuButton<double>(
                      key: const ValueKey('workout-video-control-speed'),
                      tooltip: _fullscreenVideoCopy(context, 'speed'),
                      initialValue: _playbackSpeed,
                      onOpened: () => _revealControls(scheduleHide: false),
                      onCanceled: _scheduleControlsHide,
                      onSelected: (speed) =>
                          unawaited(_setPlaybackSpeed(speed)),
                      itemBuilder: (context) => [
                        for (final speed
                            in _FullscreenWorkoutVideoPageState._playbackSpeeds)
                          PopupMenuItem<double>(
                            value: speed,
                            child: Text(_formatPlaybackSpeed(speed)),
                          ),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Center(
                          child: Text(
                            _formatPlaybackSpeed(_playbackSpeed),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatVideoTime(Duration value) {
    final safe = value.isNegative ? Duration.zero : value;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatPlaybackSpeed(double speed) {
    final fixed = speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2);
    return '${fixed.replaceFirst(RegExp(r'0$'), '')}×';
  }
}

class _WorkoutVideoError extends StatelessWidget {
  const _WorkoutVideoError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: const ValueKey('workout-video-fullscreen-retry'),
                      onPressed: () => unawaited(onRetry()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(retryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
