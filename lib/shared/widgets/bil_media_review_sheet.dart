import 'dart:typed_data';

import 'package:flutter/material.dart';

enum BilMediaReviewPurpose { meal, communityPost, profilePhoto, coverPhoto }

/// A staged media selection. Confirming this sheet only adds files to the
/// local composition or analysis journey; it never publishes or uploads them.
@immutable
class BilMediaReviewEntry<T> {
  const BilMediaReviewEntry({required this.value, required this.preview});

  final T value;
  final ImageProvider<Object> preview;
}

/// Review selected gallery photos with cancel, remove and explicit consent.
///
/// The native picker owns library permissions; this sheet owns the BIL review
/// boundary. A cancelled selection never mutates the caller's existing draft.
Future<List<T>?> showBilMediaReviewSheet<T>(
  BuildContext context, {
  required List<BilMediaReviewEntry<T>> entries,
  bool forCommunity = false,
  BilMediaReviewPurpose? purpose,
}) {
  final scope = purpose ??
      (forCommunity
          ? BilMediaReviewPurpose.communityPost
          : BilMediaReviewPurpose.meal);
  if (entries.isEmpty) return Future<List<T>?>.value(null);
  final selected = List<BilMediaReviewEntry<T>>.of(entries);
  return showModalBottomSheet<List<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, update) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final arabic = Localizations.localeOf(sheetContext).languageCode == 'ar';
        String tr(String en, String ar) => arabic ? ar : en;
        final count = selected.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
              maxWidth: 580,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_library_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        switch (scope) {
                          BilMediaReviewPurpose.profilePhoto =>
                            tr('Review your profile photo', 'مراجعة الصورة الشخصية'),
                          BilMediaReviewPurpose.coverPhoto =>
                            tr('Review your cover photo', 'مراجعة صورة الغلاف'),
                          _ => tr('Review selected photos', 'مراجعة الصور المحددة'),
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
                Flexible(
                  child: ListView.separated(
                    key: const Key('bil-media-review-previews'),
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: selected.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final entry = selected[index];
                      return SizedBox(
                        width: 158,
                        height: 196,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              border: Border.all(
                                color: scheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image(
                                  image: entry.preview,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  semanticLabel: tr('Selected photo', 'الصورة المحددة'),
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    color: scheme.onSurfaceVariant,
                                  ),
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
                                      onPressed: () => update(
                                        () => selected.removeAt(index),
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('Selected: ', 'المحدد: ') + count.toString(),
                  key: const Key('bil-media-review-count'),
                  style: Theme.of(sheetContext).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('bil-media-review-confirm'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(sheetContext).pop(
                              selected.map((entry) => entry.value).toList(
                                growable: false,
                              ),
                            ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      switch (scope) {
                        BilMediaReviewPurpose.communityPost =>
                          tr('Add to draft', 'إضافة إلى المسودة'),
                        BilMediaReviewPurpose.profilePhoto =>
                          tr('Update photo', 'تحديث الصورة'),
                        BilMediaReviewPurpose.coverPhoto =>
                          tr('Use cover photo', 'استخدام صورة الغلاف'),
                        BilMediaReviewPurpose.meal =>
                          tr('Use this photo', 'استخدام هذه الصورة'),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('bil-media-review-cancel'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(tr('Cancel', 'إلغاء')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Shared review boundary for gallery bytes destined for a profile image.
/// Only the original validated bytes leave this sheet; Cancel never saves.
Future<bool> showBilSingleImageBytesReview(
  BuildContext context, {
  required Uint8List bytes,
  BilMediaReviewPurpose purpose = BilMediaReviewPurpose.profilePhoto,
}) async {
  if (bytes.isEmpty) return false;
  final selected = await showBilMediaReviewSheet<Uint8List>(
    context,
    entries: [
      BilMediaReviewEntry<Uint8List>(
        value: bytes,
        preview: MemoryImage(bytes),
      ),
    ],
    purpose: purpose,
  );
  return selected != null && selected.isNotEmpty;
}
