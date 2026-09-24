import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/services/runtime_permission_policy.dart';
import '../../shared/widgets/bil_camera_capture_page.dart';
import '../commerce/providers/commerce_providers.dart';
import '../nutrition/presentation/meal_vision_consent_gate.dart';
import '../nutrition/presentation/meal_vision_ui_copy.dart';

/// Direct Quick Add camera boundary. Food Log is mounted only after capture.
class QuickAddMealCameraPage extends ConsumerStatefulWidget {
  const QuickAddMealCameraPage({super.key, this.returnPath});

  final String? returnPath;

  @override
  ConsumerState<QuickAddMealCameraPage> createState() =>
      _QuickAddMealCameraPageState();
}

class _QuickAddMealCameraPageState
    extends ConsumerState<QuickAddMealCameraPage> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    _started = true;
    final copy = MealVisionUiCopy.ofLocale(Localizations.localeOf(context));
    try {
      final available = await ref.read(aiBoostVisionAccessProvider.future);
      if (!mounted) return;
      if (!available) {
        await context.push('/plans?focus=boost');
        if (mounted) context.pop();
        return;
      }
      if (!await ensureMealVisionConsent(context) || !mounted) {
        if (mounted) context.pop();
        return;
      }
      final permission = await const BilRuntimePermissionPolicy().request(
        BilRuntimeCapability.camera,
      );
      if (!mounted) return;
      if (permission != BilRuntimePermissionState.granted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.text('camera_failed'))));
        context.pop();
        return;
      }
      final image = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (_) => BilCameraCapturePage(
            title: copy.text('take'),
            captureLabel: copy.text('take'),
          ),
        ),
      );
      if (!mounted) return;
      if (image == null) {
        context.pop();
        return;
      }
      final from = widget.returnPath == null
          ? ''
          : '&from=${Uri.encodeComponent(widget.returnPath!)}';
      context.replace('/daily-log?foodLog=1&action=photo$from', extra: image);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.text('camera_failed'))));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      key: Key('quick-add-camera-launching'),
      child: CircularProgressIndicator(),
    ),
  );
}
