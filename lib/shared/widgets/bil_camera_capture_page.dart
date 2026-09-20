import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// A small, in-app camera surface used by capture journeys that must not
/// launch the operating-system camera application.  The page returns the
/// captured [XFile] and keeps the caller's route mounted underneath it.
class BilCameraCapturePage extends StatefulWidget {
  const BilCameraCapturePage({
    super.key,
    required this.title,
    this.captureLabel = 'Capture',
  });

  final String title;
  final String captureLabel;

  @override
  State<BilCameraCapturePage> createState() => _BilCameraCapturePageState();
}

class _BilCameraCapturePageState extends State<BilCameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _capturing = false;
  bool _cameraShouldRun = true;
  bool _disposed = false;
  Future<void>? _cameraOperation;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _serializeCameraOperation(Future<void> Function() operation) {
    final previous = _cameraOperation;
    late final Future<void> queued;
    queued = () async {
      if (previous != null) {
        try {
          await previous;
        } on Object {
          // The next lifecycle operation must still run after a failed one.
        }
      }
      await operation();
    }();
    _cameraOperation = queued;
    return queued.whenComplete(() {
      if (identical(_cameraOperation, queued)) _cameraOperation = null;
    });
  }

  Future<void> _initialize() =>
      _serializeCameraOperation(_initializeCameraSerially);

  Future<void> _initializeCameraSerially() async {
    if (!mounted || _disposed || !_cameraShouldRun) return;
    if (_controller?.value.isInitialized ?? false) return;
    setState(() => _error = null);
    CameraController? next;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      next = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || _disposed || !_cameraShouldRun) {
        await next.dispose();
        return;
      }
      final previous = _controller;
      _controller = next;
      next = null;
      await previous?.dispose();
      if (mounted) setState(() {});
    } on CameraException catch (error) {
      await next?.dispose();
      if (mounted) {
        setState(() => _error = error.description ?? error.code);
      }
    } on Object catch (error) {
      await next?.dispose();
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _pauseCamera() =>
      _serializeCameraOperation(_disposeCameraSerially);

  Future<void> _disposeCameraSerially() async {
    final active = _controller;
    _controller = null;
    await active?.dispose();
    if (mounted && !_disposed) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!mounted || _disposed) return;
      _cameraShouldRun = true;
      unawaited(_initialize());
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cameraShouldRun = false;
      unawaited(_pauseCamera());
    }
  }

  Future<void> _capture() async {
    final active = _controller;
    if (_capturing ||
        !_cameraShouldRun ||
        active == null ||
        !active.value.isInitialized) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final image = await active.takePicture();
      if (mounted) Navigator.of(context).pop(image);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = error.description ?? error.code;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final active = _controller;
    if (active == null || !active.value.isInitialized) return;
    final next = active.value.flashMode == FlashMode.off
        ? FlashMode.auto
        : FlashMode.off;
    try {
      await active.setFlashMode(next);
      if (mounted) setState(() {});
    } on Object {
      // Flash is optional. The capture remains usable without it.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _cameraShouldRun = false;
    unawaited(_pauseCamera());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _controller;
    final ready = active != null && active.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          if (ready)
            IconButton(
              tooltip: 'Toggle flash',
              onPressed: _toggleFlash,
              icon: Icon(
                active.value.flashMode == FlashMode.off
                    ? Icons.flash_off_rounded
                    : Icons.flash_auto_rounded,
              ),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Center(child: CameraPreview(active))
          else if (_error != null)
            _CameraErrorPanel(
              error: _error!,
              onRetry: () {
                unawaited(_initialize());
                setState(() {});
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: SafeArea(
                child: Column(
                  children: [
                    Text(
                      widget.captureLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      label: widget.captureLabel,
                      child: IconButton(
                        onPressed: _capturing ? null : _capture,
                        iconSize: 76,
                        color: Colors.white,
                        icon: _capturing
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera_rounded),
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

class _CameraErrorPanel extends StatelessWidget {
  const _CameraErrorPanel({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            'Camera unavailable: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
