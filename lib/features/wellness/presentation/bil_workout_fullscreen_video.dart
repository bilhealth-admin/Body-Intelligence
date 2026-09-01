part of 'bil_workout_routines_page.dart';

/// Owns the route-level playback lifecycle separately from cached media
/// resolution and download controls.
class _FullscreenWorkoutVideoPage extends StatefulWidget {
  const _FullscreenWorkoutVideoPage({required this.file});

  final File file;

  @override
  State<_FullscreenWorkoutVideoPage> createState() =>
      _FullscreenWorkoutVideoPageState();
}

class _FullscreenWorkoutVideoPageState
    extends State<_FullscreenWorkoutVideoPage>
    with WidgetsBindingObserver {
  late final VideoPlayerController _videoController;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoController = VideoPlayerController.file(widget.file);
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    await _videoController.initialize();
    await _videoController.play();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _videoController.pause();
    }
  }

  Future<void> _togglePlayback() async {
    if (!_videoController.value.isInitialized) return;
    _videoController.value.isPlaying
        ? await _videoController.pause()
        : await _videoController.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const ValueKey('workout-video-fullscreen-surface'),
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayback,
            child: FutureBuilder<void>(
              future: _ready,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Center(
                  child: AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: IconButton.filledTonal(
              key: const ValueKey('workout-video-fullscreen-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const BackButtonIcon(),
            ),
          ),
          PositionedDirectional(
            bottom: 12,
            start: 0,
            end: 0,
            child: Center(
              child: IconButton.filledTonal(
                key: const ValueKey('workout-video-fullscreen-playback'),
                tooltip: _videoController.value.isPlaying
                    ? wellnessWorkoutVideoAction(context, 'Pause video')
                    : wellnessWorkoutVideoAction(context, 'Play video'),
                onPressed: _togglePlayback,
                icon: Icon(
                  _videoController.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
