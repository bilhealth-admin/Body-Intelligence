import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../../../app/localization/app_localizations.dart';
import 'nutrition_copy.dart';

class FoodBarcodeScannerPage extends StatefulWidget {
  const FoodBarcodeScannerPage({super.key, this.scannerEnabled = true});

  /// Allows honest unavailable-state rendering without initializing a camera.
  /// Production routes keep this enabled; deterministic visual evidence can
  /// disable it without mocking a successful scan.
  final bool scannerEnabled;

  @override
  State<FoodBarcodeScannerPage> createState() => _FoodBarcodeScannerPageState();
}

class _FoodBarcodeScannerPageState extends State<FoodBarcodeScannerPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool starting = true;
  bool handled = false;
  Object? startError;
  late final AnimationController _scanBeamController;
  late final Animation<double> _scanBeamProgress;

  bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get mobileScannerSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool get scannerSupported => isWindows || mobileScannerSupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanBeamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _scanBeamProgress = CurvedAnimation(
      parent: _scanBeamController,
      curve: Curves.easeInOutCubic,
    );

    if (!widget.scannerEnabled) {
      starting = false;
      return;
    }

    if (isWindows) {
      starting = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startWindows();
      });
    } else if (mobileScannerSupported) {
      _scanBeamController.repeat(reverse: true);
      _startMobile();
    } else {
      starting = false;
    }
  }

  Future<void> _startWindows() async {
    if (!mounted || handled || starting) return;

    setState(() {
      starting = true;
      startError = null;
    });

    try {
      final result = await SimpleBarcodeScanner.scanBarcode(
        context,
        barcodeAppBar: BarcodeAppBar(
          appBarTitle: context.strings.text('Scan food barcode'),
          centerTitle: true,
          enableBackButton: true,
          backButtonIcon: const Icon(Icons.arrow_back),
        ),
        isShowFlashIcon: false,
        delayMillis: 350,
        cameraFace: CameraFace.back,
      );

      if (!mounted) return;

      final value = result?.trim();

      if (value == null ||
          value.isEmpty ||
          value == '-1' ||
          value.toLowerCase() == 'cancelled') {
        return;
      }

      handled = true;
      Navigator.of(context).pop(value);
    } catch (error) {
      if (mounted) {
        setState(() => startError = error);
      }
    } finally {
      if (mounted) {
        setState(() => starting = false);
      }
    }
  }

  Future<void> _startMobile() async {
    if (!mounted || !mobileScannerSupported || isWindows) return;

    setState(() {
      starting = true;
      startError = null;
    });

    try {
      await controller.start();
    } catch (error) {
      if (mounted) {
        setState(() => startError = error);
      }
    } finally {
      if (mounted) {
        setState(() => starting = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mobileScannerSupported || isWindows) return;

    if (state == AppLifecycleState.resumed && !handled) {
      if (!_scanBeamController.isAnimating) {
        _scanBeamController.repeat(reverse: true);
      }
      _startMobile();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scanBeamController.stop();
      controller.stop();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (handled) return;

    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .firstOrNull;

    if (value == null) return;

    handled = true;
    _scanBeamController.stop();
    controller.stop();
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanBeamController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Scan food barcode')),
        actions: [
          if (mobileScannerSupported && !isWindows)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) => IconButton(
                tooltip: t('Toggle flashlight'),
                onPressed: state.torchState == TorchState.unavailable
                    ? null
                    : controller.toggleTorch,
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
              ),
            ),
        ],
      ),
      body: !widget.scannerEnabled || !scannerSupported
          ? _UnsupportedScanner(
              onManualEntry: () => Navigator.of(context).pop(),
            )
          : isWindows
          ? _WindowsScannerLauncher(
              starting: starting,
              error: startError,
              onScan: _startWindows,
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _ScannerError(
                    message: t('Camera permission or scanner startup failed.'),
                    onRetry: _startMobile,
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    key: const Key('barcode-animated-scan-beam'),
                    painter: _ScanFramePainter(
                      color: Theme.of(context).colorScheme.primary,
                      progress: _scanBeamProgress,
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        t(
                          'Place the product barcode inside the frame. '
                          'Nothing is uploaded.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                if (starting)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (startError != null)
                  _ScannerError(
                    message: t(
                      'Camera permission was denied or the camera is '
                      'unavailable. You can retry or use manual barcode entry.',
                    ),
                    onRetry: _startMobile,
                  ),
              ],
            ),
    );
  }
}

class _WindowsScannerLauncher extends StatelessWidget {
  const _WindowsScannerLauncher({
    required this.starting,
    required this.error,
    required this.onScan,
  });

  final bool starting;
  final Object? error;
  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null
                  ? Icons.qr_code_scanner
                  : Icons.no_photography_outlined,
              size: 72,
            ),
            const SizedBox(height: 20),
            Text(
              error == null
                  ? nutritionText(
                      context,
                      'Hold the product barcode in front of the laptop camera.',
                      'وجّه باركود المنتج إلى كاميرا اللابتوب.',
                    )
                  : nutritionText(
                      context,
                      'Camera failed. Check Windows camera permission and WebView2, then retry.',
                      'تعذر فتح الكاميرا. تحقق من إذن كاميرا Windows وتثبيت WebView2 ثم أعد المحاولة.',
                    ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: starting ? null : onScan,
              icon: starting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(
                nutritionText(
                  context,
                  'Open laptop camera',
                  'فتح كاميرا اللابتوب',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedScanner extends StatelessWidget {
  const _UnsupportedScanner({required this.onManualEntry});

  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 52),
            const SizedBox(height: 16),
            Text(
              nutritionText(
                context,
                'Camera scanning is not supported on this platform. Use manual barcode entry.',
                'المسح بالكاميرا غير مدعوم على هذه المنصة. استخدم الإدخال اليدوي للباركود.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('barcode-manual-entry-return'),
              onPressed: onManualEntry,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: Text(context.strings.text('Enter barcode manually')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.strings.text('Try again')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.color, required this.progress})
    : super(repaint: progress);

  final Color color;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final frameWidth = (shortest * .78).clamp(220.0, 420.0);
    final frameHeight = frameWidth * .55;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 24),
      width: frameWidth,
      height: frameHeight,
    );

    final overlay = Paint()..color = const Color(0x88000000);
    final cutout = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(cutout, overlay);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final beamY = rect.top + 14 + (rect.height - 28) * progress.value;
    final beamRect = Rect.fromLTRB(
      rect.left + 16,
      beamY - 1.5,
      rect.right - 16,
      beamY + 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beamRect, const Radius.circular(999)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: .95),
            Colors.white,
            color.withValues(alpha: .95),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .22, .5, .78, 1],
        ).createShader(beamRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
