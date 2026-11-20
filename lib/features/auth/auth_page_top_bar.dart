import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/widgets/bil_navigation_feedback.dart';
import '../../shared/widgets/bil_page_heading.dart';
import 'auth_entry_locale_copy.dart';

/// Natural title sizing preserves the complete localized heading at large text.
class AuthPageTopBar extends StatelessWidget {
  const AuthPageTopBar({
    super.key,
    required this.title,
    required this.backKey,
    required this.onBack,
    this.mediaQuery,
  });

  final String title;
  final Key backKey;
  final VoidCallback? onBack;
  final MediaQueryData? mediaQuery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final media = mediaQuery ?? MediaQuery.of(context);
    final available = math.max(
      0.0,
      media.size.height - media.viewInsets.bottom - media.viewPadding.vertical,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: available * .4),
      child: SingleChildScrollView(
        primary: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            color: dark ? scheme.surfaceContainerLow : const Color(0xFFFAFAFC),
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Material(
                color: dark ? scheme.surfaceContainerHighest : Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: const Color(0x1F000000),
                child: IconButton(
                  key: backKey,
                  tooltip: authEntryText(context, AuthEntryCopyKey.back),
                  onPressed: onBack,
                  icon: BilNavigationFeedback(
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      size: 19,
                    ),
                  ),
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    key: const Key('auth-page-title'),
                    textAlign: TextAlign.center,
                    style: bilPageHeadingStyle(
                      context,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 60),
            ],
          ),
        ),
      ),
    );
  }
}
