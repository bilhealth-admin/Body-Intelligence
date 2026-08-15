part of 'bil_workout_routines_page.dart';

class _WorkoutSegmentsList extends StatelessWidget {
  const _WorkoutSegmentsList({
    required this.segments,
    required this.mediaCache,
    required this.online,
  });
  final List<WellnessWorkoutSegment> segments;
  final WellnessMediaCache mediaCache;
  final bool online;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < segments.length; index++) ...[
        _WorkoutSegmentTile(
          index: index,
          segment: segments[index],
          mediaCache: mediaCache,
          online: online,
        ),
        if (index != segments.length - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

class _WorkoutSegmentTile extends StatelessWidget {
  const _WorkoutSegmentTile({
    required this.index,
    required this.segment,
    required this.mediaCache,
    required this.online,
  });
  final int index;
  final WellnessWorkoutSegment segment;
  final WellnessMediaCache mediaCache;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (segment.repetitions != null)
        _workoutRepetitions(context, segment.repetitions!),
      if (segment.seconds != null) _workoutSeconds(context, segment.seconds!),
      if (segment.restSeconds != null && segment.restSeconds! > 0)
        _workoutRestSeconds(context, segment.restSeconds!),
    ];
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('workout-segment-${segment.id}'),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _WorkoutSegmentVideoPage(
              segment: segment,
              mediaCache: mediaCache,
              online: online,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _SegmentThumbnail(
                segment: segment,
                mediaCache: mediaCache,
                online: online,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${segment.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      details.join(' • '),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (segment.isOptional) ...[
                      const SizedBox(height: 4),
                      Text(
                        _copy(context, 'Optional', 'اختياري'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentThumbnail extends StatelessWidget {
  const _SegmentThumbnail({
    required this.segment,
    required this.mediaCache,
    required this.online,
  });
  final WellnessWorkoutSegment segment;
  final WellnessMediaCache mediaCache;
  final bool online;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    height: 78,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VerifiedCachedImage(
            asset: segment.imageMedia,
            mediaCache: mediaCache,
            online: online,
            fit: BoxFit.cover,
            fallback: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.fitness_center_rounded),
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
          const Center(
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xDFFFFFFF),
              child: Icon(Icons.play_arrow_rounded, color: Colors.black87),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WorkoutSegmentVideoPage extends StatelessWidget {
  const _WorkoutSegmentVideoPage({
    required this.segment,
    required this.mediaCache,
    required this.online,
  });
  final WellnessWorkoutSegment segment;
  final WellnessMediaCache mediaCache;
  final bool online;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(segment.title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _VerifiedCachedVideo(
          asset: segment.videoMedia,
          mediaCache: mediaCache,
          online: online,
          unavailableText: _copy(
            context,
            'This licensed movement video is currently unavailable.',
            'فيديو الحركة المرخّص غير متاح حاليًا.',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          segment.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(segment.instruction),
      ],
    ),
  );
}

class _VerifiedCachedImage extends StatefulWidget {
  const _VerifiedCachedImage({
    required this.asset,
    required this.mediaCache,
    required this.online,
    required this.fit,
    required this.fallback,
  });

  final WellnessMediaAsset asset;
  final WellnessMediaCache mediaCache;
  final bool online;
  final BoxFit fit;
  final Widget fallback;

  @override
  State<_VerifiedCachedImage> createState() => _VerifiedCachedImageState();
}

class _VerifiedCachedImageState extends State<_VerifiedCachedImage> {
  late Future<WellnessMediaCacheResult> _result = _resolve();

  Future<WellnessMediaCacheResult> _resolve() =>
      widget.mediaCache.resolve(widget.asset, online: widget.online);

  @override
  void didUpdateWidget(covariant _VerifiedCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.asset;
    final current = widget.asset;
    if (!identical(oldWidget.mediaCache, widget.mediaCache) ||
        oldWidget.online != widget.online ||
        previous.url != current.url ||
        previous.mimeType != current.mimeType ||
        previous.sha256 != current.sha256 ||
        previous.sizeBytes != current.sizeBytes) {
      _result = _resolve();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WellnessMediaCacheResult>(
    future: _result,
    builder: (context, snapshot) {
      final result = snapshot.data;
      final file = result?.file;
      if (snapshot.hasError || result?.isReady != true || file == null) {
        return widget.fallback;
      }
      return Image.file(
        file,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    },
  );
}

class _WorkoutHeroMedia extends StatelessWidget {
  const _WorkoutHeroMedia({
    required this.item,
    required this.mediaCache,
    required this.online,
  });
  final WellnessContentItem item;
  final WellnessMediaCache mediaCache;
  final bool online;

  @override
  Widget build(BuildContext context) {
    if (item.videoMedia != null) {
      return _VerifiedCachedVideo(
        asset: item.videoMedia!,
        mediaCache: mediaCache,
        online: online,
        unavailableText: _copy(
          context,
          'The verified workout video is currently unavailable.',
          'فيديو التمرين الموثق غير متاح حاليًا.',
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _WorkoutCover(item: item, mediaCache: mediaCache, online: online),
          ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xD9111720),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _copy(
                        context,
                        'No licensed video in this pack',
                        'لا يوجد فيديو مرخّص في هذه الحزمة',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedCachedVideo extends StatefulWidget {
  const _VerifiedCachedVideo({
    required this.asset,
    required this.mediaCache,
    required this.online,
    required this.unavailableText,
  });
  final WellnessMediaAsset asset;
  final WellnessMediaCache mediaCache;
  final bool online;
  final String unavailableText;

  @override
  State<_VerifiedCachedVideo> createState() => _VerifiedCachedVideoState();
}

class _VerifiedCachedVideoState extends State<_VerifiedCachedVideo> {
  VideoPlayerController? _controller;
  late final Future<void> _ready;
  bool _unavailableOffline = false;

  @override
  void initState() {
    super.initState();
    _ready = _prepare();
  }

  Future<void> _prepare() async {
    if (!_workoutVideoPlaybackSupported) return;
    final result = await widget.mediaCache.resolve(
      widget.asset,
      online: widget.online,
    );
    if (!result.isReady || result.file == null) {
      _unavailableOffline = true;
      return;
    }
    final controller = VideoPlayerController.file(result.file!);
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (!_workoutVideoPlaybackSupported) {
          return _VideoUnavailable(
            text: _copy(
              context,
              'Verified workout video playback is available on Android and iOS.',
              'تشغيل فيديو التمرين الموثق متاح على Android وiOS.',
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final controller = _controller;
        if (_unavailableOffline) {
          return _VideoUnavailable(
            text: _copy(
              context,
              'This verified video is not cached on this device. Connect to download it securely.',
              'هذا الفيديو الموثق غير محفوظ على هذا الجهاز. اتصل لتنزيله بأمان.',
            ),
          );
        }
        if (snapshot.hasError ||
            controller == null ||
            !controller.value.isInitialized) {
          return _VideoUnavailable(text: widget.unavailableText);
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            IconButton.filled(
              key: const ValueKey('workout-video-playback'),
              onPressed: () async {
                controller.value.isPlaying
                    ? await controller.pause()
                    : await controller.play();
                if (mounted) setState(() {});
              },
              iconSize: 34,
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _VideoUnavailable extends StatelessWidget {
  const _VideoUnavailable({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}

bool get _workoutVideoPlaybackSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
