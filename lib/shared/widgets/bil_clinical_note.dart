import 'package:flutter/material.dart';

/// Premium explanatory note for medical/wellness boundaries.
///
/// It adds hierarchy and trust without changing the underlying clinical copy
/// or implying diagnosis, urgency, or medical authority.
class BilClinicalNote extends StatelessWidget {
  const BilClinicalNote({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.health_and_safety_outlined,
  });

  final String? title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF101318) : const Color(0xFFF5F8FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: dark ? const Color(0xFF2A303A) : const Color(0xFFDCE4EF),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: dark ? .17 : .09),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title?.trim().isNotEmpty == true) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.52,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
