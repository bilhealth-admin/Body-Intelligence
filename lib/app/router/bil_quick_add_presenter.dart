import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/bil_modal_bottom_sheet.dart';
import '../theme/premium_motion_tokens.dart';
import 'bil_quick_add_sheet.dart';

/// Exact internal destinations only. These are return destinations, not the
/// shell's navigation indices, and must never accept a URL or a path prefix.
const bilQuickAddReturnPaths = <String>{
  '/dashboard',
  '/daily-log',
  '/nutrition',
  '/history',
  '/analytics',
  '/settings',
  '/intelligence-center',
  '/community',
  '/community/notifications',
};

String? safeBilQuickAddReturnPath(String? value) =>
    bilQuickAddReturnPaths.contains(value) ? value : null;

/// Present the existing seven Quick Add actions from any primary destination.
/// Await sheet teardown before pushing a capture surface (including on iOS).
Future<void> showBilQuickAdd(
  BuildContext context, {
  required String originPath,
}) async {
  final currentPath = GoRouterState.of(context).uri.path;
  final action = await showBilModalBottomSheet<String>(
    context: context,
    // Keep the sheet dismissible from the dimmed area and draggable from
    // the handle/content on both iOS and Android. The custom sheet owns
    // its visual handle, so the framework handle is intentionally
    // disabled.
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AnimationStyle(
      duration: PremiumMotionTokens.durationFor(
        context,
        PremiumMotionTokens.navigationDuration,
      ),
      reverseDuration: PremiumMotionTokens.durationFor(
        context,
        PremiumMotionTokens.stateChangeDuration,
      ),
    ),
    builder: (sheetContext) {
      return BilQuickAddSheet(
        photoAsset:
            'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
        onFood: () {
          Navigator.of(sheetContext).pop('food');
        },
        onBarcode: () {
          Navigator.of(sheetContext).pop('barcode');
        },
        onVoice: () {
          Navigator.of(sheetContext).pop('voice');
        },
        onPhoto: () {
          Navigator.of(sheetContext).pop('photo');
        },
        onExercise: () {
          Navigator.of(sheetContext).pop('exercise');
        },
        onNotes: () {
          Navigator.of(sheetContext).pop('notes');
        },
        onSearch: () {
          Navigator.of(sheetContext).pop('search');
        },
      );
    },
  );

  // Navigate only after showModalBottomSheet has completed its reverse
  // animation. Starting a shell route from inside the sheet can race its
  // teardown on iOS and leave a blank child, which also prevents Quick Add
  // barcode/photo actions from opening their capture surfaces.
  if (!context.mounted || action == null) return;
  final origin = Uri.encodeComponent(
    safeBilQuickAddReturnPath(originPath) ?? '/dashboard',
  );
  final cancelledTaskReturn = Uri.encodeComponent('/dashboard');
  switch (action) {
    case 'food':
      // Quick Add's Log food action owns a separate entry surface. The
      // legacy Daily Log and its breakfast/lunch/dinner pages stay on
      // their original route and are not rebuilt or altered here.
      // Push the standalone surface after the sheet has fully dismissed.
      // A push gives the shell a distinct child route and avoids the
      // transient blank child that can occur when replacing the sheet's
      // route with `go` on iOS.
      context.push('/daily-log?foodLog=1&from=$origin');
      break;
    case 'barcode':
      context.push(
        '/daily-log?foodLog=1&action=barcode&from=$cancelledTaskReturn',
      );
      break;
    case 'voice':
      context.push(
        '/daily-log?foodLog=1&action=voice&from=$cancelledTaskReturn',
      );
      break;
    case 'photo':
      // Photo analysis uses the standalone Food Log surface and returns to
      // the validated originating destination.
      context.push('/quick-add/meal-camera?from=$origin');
      break;
    case 'exercise':
      context.push('/wellness/workouts');
      break;
    case 'notes':
      context.go('/daily-log/body-context?from=$origin');
      break;
    case 'search':
      if (currentPath != '/nutrition') context.push('/nutrition');
      break;
  }
}
