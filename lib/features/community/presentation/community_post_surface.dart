import 'package:flutter/material.dart';

/// White glass presentation for posts, without pearl or chromatic gradients.
class CommunityPostSurface extends StatelessWidget {
  const CommunityPostSurface({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.compact = false,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF222222) : Colors.white,
        borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(18),
        border: compact
            ? Border(
                bottom: BorderSide(
                  color: highContrast
                      ? (dark ? Colors.white : const Color(0xFF555555))
                      : (dark
                            ? const Color(0xFF383838)
                            : const Color(0xFFEDF0F4)),
                ),
              )
            : Border.all(
                color: highContrast
                    ? (dark ? Colors.white : const Color(0xFF555555))
                    : (dark
                          ? const Color(0xFF464646)
                          : const Color(0xFFE7E7E7)),
              ),
        boxShadow: highContrast || compact
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .12 : .035),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
