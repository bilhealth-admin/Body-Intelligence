import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A deterministic platform seam, not evidence of a native decoder running.
class FakeWorkoutVideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final sources = <DataSource>[];
  final disposed = <int>[];
  final plays = <int>[];
  final pauses = <int>[];
  final speeds = <double>[];
  bool initializeAutomatically = true;
  bool rejectFastSpeed = false;
  Future<void>? pendingPause;
  Future<void>? pendingPlay;
  Future<void>? pendingSeek;
  Size videoSize = const Size(720, 1280);

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource);
    streams[id] = StreamController<VideoEvent>();
    if (initializeAutomatically) initializePlayer(id);
    return id;
  }

  void initializePlayer(int id) => streams[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      size: videoSize,
      duration: const Duration(minutes: 1),
    ),
  );

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await streams[playerId]?.close();
  }

  @override
  Future<void> play(int playerId) async {
    plays.add(playerId);
    await pendingPlay;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses.add(playerId);
    await pendingPause;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    await pendingSeek;
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds.add(speed);
    if (rejectFastSpeed && speed > 1) throw UnsupportedError('speed');
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.teal);
}
