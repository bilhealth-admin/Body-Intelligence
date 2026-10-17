import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/recoverable_image_picker.dart';
import '../services/runtime_permission_policy.dart';
import '../../features/commerce/presentation/optional_access_offer.dart';
import '../../features/commerce/providers/commerce_providers.dart';
import '../../features/nutrition/presentation/meal_vision_consent_gate.dart';
import '../../features/nutrition/presentation/meal_vision_ui_copy.dart';
import '../../shared/widgets/bil_camera_capture_page.dart';
import '../../shared/widgets/bil_media_review_sheet.dart';
import '../../shared/widgets/bil_modal_bottom_sheet.dart';

/// Choose on top of the CURRENT tab, not on a temporary loading page.
/// Cancelling this sheet leaves the caller's current route unchanged.
Future<ImageSource?> chooseBilQuickAddMealPhotoSource(
  BuildContext context,
) async {
  final copy = MealVisionUiCopy.ofLocale(Localizations.localeOf(context));
  return showBilModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        key: const Key('quick-add-meal-photo-source-sheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('quick-add-meal-photo-camera'),
            leading: Icon(
              Theme.of(sheetContext).platform == TargetPlatform.iOS
                  ? CupertinoIcons.camera
                  : Icons.photo_camera_outlined,
            ),
            title: Text(copy.text('take')),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            key: const Key('quick-add-meal-photo-gallery'),
            leading: Icon(
              Theme.of(sheetContext).platform == TargetPlatform.iOS
                  ? CupertinoIcons.photo
                  : Icons.photo_library_outlined,
            ),
            title: Text(copy.text('choose')),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Existing Quick Add sheet has already been dismissed before entering here.
/// Capture/review in place; navigate to Food Log ONLY AFTER the image exists.
/// The unchanged Food Log handles credits, AI analysis, review, and atomic save.
Future<void> openBilQuickAddMealPhoto(
  BuildContext context, {
  required String encodedReturnPath,
}) async {
  final source = await chooseBilQuickAddMealPhotoSource(context);
  if (!context.mounted || source == null) return;

  final copy = MealVisionUiCopy.ofLocale(Localizations.localeOf(context));
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final available = await container.read(aiBoostVisionAccessProvider.future);
    if (!context.mounted) return;
    if (!available) {
      final insufficient =
          container.read(aiVisionCreditStateProvider).asData?.value ==
          AiVisionCreditState.insufficient;
      await showOptionalAccessOfferFromContainer(
        context,
        container,
        verifiedDenied: insufficient,
        focus: 'boost',
      );
      return;
    }
    // Explicit consent is required before any third-party meal-image analysis.
    if (!await ensureMealVisionConsent(context) || !context.mounted) return;

    XFile? image;
    if (source == ImageSource.camera) {
      final permissions = const BilRuntimePermissionPolicy();
      final current = await permissions.status(BilRuntimeCapability.camera);
      if (!context.mounted) return;
      final allowed =
          current == BilRuntimePermissionState.granted ||
          await permissions.request(BilRuntimeCapability.camera) ==
              BilRuntimePermissionState.granted;
      if (!allowed || !context.mounted) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(copy.text('camera_failed'))));
        }
        return;
      }
      image = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (_) => BilCameraCapturePage(
            title: copy.text('take'),
            captureLabel: copy.text('take'),
          ),
        ),
      );
    } else {
      // Photo library needs NO broad storage/gallery permission.
      image = await BilRecoverableImagePicker.instance.pickImage(
        purpose: BilImagePickerPurpose.mealPhoto,
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image != null && context.mounted) {
        final reviewed = await showBilMediaReviewSheet<XFile>(
          context,
          entries: [
            BilMediaReviewEntry<XFile>(
              value: image,
              preview: FileImage(File(image.path)),
            ),
          ],
        );
        if (reviewed == null || reviewed.isEmpty) return;
        image = reviewed.single;
      }
    }
    if (!context.mounted || image == null) return;
    // Return path was allow-listed and encoded by showBilQuickAdd.
    context.push(
      '/daily-log?foodLog=1&action=photo&from=$encodedReturnPath',
      extra: image,
    );
  } on Object {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(copy.text('camera_failed'))));
  }
}
