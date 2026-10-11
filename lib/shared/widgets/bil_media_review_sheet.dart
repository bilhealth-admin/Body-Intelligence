import 'dart:typed_data';

import 'package:flutter/material.dart';

enum BilMediaReviewPurpose { meal, communityPost, profilePhoto, coverPhoto }

/// A staged selection, never permission to publish or upload by itself.
@immutable
class BilMediaReviewEntry<T> {
  const BilMediaReviewEntry({required this.value, required this.preview});

  final T value;
  final ImageProvider<Object> preview;
}

/// Review actual photos before returning an accepted selection to the caller.
/// Cancel, Back and dismiss leave the caller's existing draft unchanged.
Future<List<T>?> showBilMediaReviewSheet<T>(
  BuildContext context, {
  required List<BilMediaReviewEntry<T>> entries,
  bool forCommunity = false,
  BilMediaReviewPurpose? purpose,
}) {
  if (entries.isEmpty) return Future<List<T>?>.value(null);
  final scope =
      purpose ??
      (forCommunity
          ? BilMediaReviewPurpose.communityPost
          : BilMediaReviewPurpose.meal);
  final selected = List<BilMediaReviewEntry<T>>.of(entries);
  final ready = <BilMediaReviewEntry<T>>{};
  final failed = <BilMediaReviewEntry<T>>{};
  var accepted = false;

  return showModalBottomSheet<List<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, update) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final arabic =
            Localizations.localeOf(sheetContext).languageCode == 'ar';
        String tr(String en, String ar) => arabic ? ar : en;
        final canConfirm =
            !accepted &&
            selected.isNotEmpty &&
            selected.every((entry) => ready.contains(entry)) &&
            !selected.any((entry) => failed.contains(entry));

        void reportFrame(BilMediaReviewEntry<T> entry, {required bool valid}) {
          if (accepted || !selected.contains(entry)) return;
          if (valid && ready.contains(entry)) return;
          if (!valid && failed.contains(entry)) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!sheetContext.mounted ||
                accepted ||
                !selected.contains(entry)) {
              return;
            }
            if (valid && failed.contains(entry)) return;
            update(() {
              if (valid) {
                ready.add(entry);
              } else {
                ready.remove(entry);
                failed.add(entry);
              }
            });
          });
        }

        Widget preview(int index) {
          final entry = selected[index];
          return Padding(
            padding: EdgeInsetsDirectional.only(
              end: index + 1 < selected.length ? 10 : 0,
            ),
            child: SizedBox(
              width: 158,
              height: 196,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        key: ObjectKey(entry),
                        image: entry.preview,
                        fit: BoxFit.cover,
                        semanticLabel: tr('Selected photo', 'الصورة المحددة'),
                        frameBuilder: (context, child, frame, synchronous) {
                          if (synchronous || frame != null) {
                            reportFrame(entry, valid: true);
                            return child;
                          }
                          // No animation loop: cancellation must remain usable
                          // while the original file is still being decoded.
                          return Center(
                            child: Icon(
                              Icons.photo_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) {
                          reportFrame(entry, valid: false);
                          return Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                      PositionedDirectional(
                        top: 4,
                        end: 4,
                        child: Material(
                          color: scheme.surface.withValues(alpha: .94),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: Key('bil-media-review-remove-$index'),
                            tooltip: tr('Remove photo', 'إزالة الصورة'),
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: accepted
                                ? null
                                : () => update(() {
                                    selected.removeAt(index);
                                    ready.remove(entry);
                                    failed.remove(entry);
                                  }),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 10,
                        bottom: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCC071923),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              (index + 1).toString(),
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      key: const Key('bil-media-review-body'),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  switch (scope) {
                                    BilMediaReviewPurpose.profilePhoto => tr(
                                      'Review your profile photo',
                                      'مراجعة الصورة الشخصية',
                                    ),
                                    BilMediaReviewPurpose.coverPhoto => tr(
                                      'Review your cover photo',
                                      'مراجعة صورة الغلاف',
                                    ),
                                    _ => tr(
                                      'Review selected photos',
                                      'مراجعة الصور المحددة',
                                    ),
                                  },
                                  style: Theme.of(sheetContext).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                key: const Key('bil-media-review-close'),
                                tooltip: tr('Cancel', 'إلغاء'),
                                onPressed: () => Navigator.of(sheetContext).pop(),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            switch (scope) {
                              BilMediaReviewPurpose.communityPost => tr(
                                'Nothing is published until you press Publish in your post.',
                                'لن يُنشر شيء حتى تضغط نشر داخل المنشور.',
                              ),
                              BilMediaReviewPurpose.profilePhoto => tr(
                                'Your current photo remains until you confirm the replacement.',
                                'تبقى صورتك الحالية حتى تؤكد استبدالها.',
                              ),
                              BilMediaReviewPurpose.coverPhoto => tr(
                                'Confirm this image before updating your profile cover.',
                                'أكّد هذه الصورة قبل تحديث غلاف ملفك.',
                              ),
                              BilMediaReviewPurpose.meal => tr(
                                'Confirm this photo before AI analysis. Nothing is saved yet.',
                                'أكّد هذه الصورة قبل التحليل. لم يُحفظ شيء بعد.',
                              ),
                            },
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          // Eagerly build this bounded set so off-screen selected
                          // photos are decoded too; readiness must not require swipes.
                          SingleChildScrollView(
                            key: const Key('bil-media-review-previews'),
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < selected.length; i++) preview(i),
                              ],
                            ),
                          ),
                          if (selected.any((entry) => failed.contains(entry))) ...[
                            const SizedBox(height: 12),
                            Text(
                              tr(
                                'A photo could not be previewed. Remove it or choose another photo.',
                                'تعذرت معاينة إحدى الصور. أزلها أو اختر صورة أخرى.',
                              ),
                              key: const Key('bil-media-review-error'),
                              style: TextStyle(color: scheme.error),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            tr('Selected: ', 'المحدد: ') + selected.length.toString(),
                            key: const Key('bil-media-review-count'),
                            style: Theme.of(sheetContext).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('bil-media-review-confirm'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: !canConfirm
                          ? null
                          : () {
                              if (accepted) return;
                              accepted = true;
                              Navigator.of(sheetContext).pop(
                                List<T>.unmodifiable(
                                  selected.map((entry) => entry.value),
                                ),
                              );
                            },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(switch (scope) {
                        BilMediaReviewPurpose.communityPost => tr(
                          'Add to draft',
                          'إضافة إلى المسودة',
                        ),
                        BilMediaReviewPurpose.profilePhoto => tr(
                          'Update photo',
                          'تحديث الصورة',
                        ),
                        BilMediaReviewPurpose.coverPhoto => tr(
                          'Use cover photo',
                          'استخدام صورة الغلاف',
                        ),
                        BilMediaReviewPurpose.meal => tr(
                          'Use this photo',
                          'استخدام هذه الصورة',
                        ),
                      }, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('bil-media-review-cancel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(tr('Cancel', 'إلغاء')),
                    ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Gallery Cancel never saves or replaces the account's current image.
Future<bool> showBilSingleImageBytesReview(
  BuildContext context, {
  required Uint8List bytes,
  BilMediaReviewPurpose purpose = BilMediaReviewPurpose.profilePhoto,
}) async {
  if (bytes.isEmpty) return false;
  final selected = await showBilMediaReviewSheet<Uint8List>(
    context,
    entries: [
      BilMediaReviewEntry<Uint8List>(value: bytes, preview: MemoryImage(bytes)),
    ],
    purpose: purpose,
  );
  return selected != null && selected.isNotEmpty;
}
