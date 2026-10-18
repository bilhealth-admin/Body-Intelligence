part of 'intelligence_center_page.dart';

class _FeedbackReaction extends StatelessWidget {
  const _FeedbackReaction({
    required this.selected,
    required this.positive,
    required this.compact,
    required this.messageId,
    required this.onTap,
  });

  final bool selected;
  final bool positive;
  final bool compact;
  final String messageId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emojiFontFamily = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'Apple Color Emoji',
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux => 'Noto Color Emoji',
      TargetPlatform.windows => 'Segoe UI Emoji',
    };
    final selectedColor = positive
        ? BilFlagshipTokens.emerald500
        : scheme.error;
    final dimension = compact ? 36.0 : 44.0;
    return IconButton(
      key: Key(
        'ai-coach-feedback-${positive ? 'helpful' : 'not-helpful'}-$messageId',
      ),
      tooltip: intelligenceText(
        context,
        positive ? 'Helpful' : 'Not helpful',
        positive ? 'مفيد' : 'غير مفيد',
      ),
      isSelected: selected,
      onPressed: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: dimension, height: dimension),
      style: IconButton.styleFrom(
        foregroundColor: selectedColor,
        backgroundColor: selectedColor.withValues(alpha: selected ? .20 : .09),
        shape: const CircleBorder(),
        overlayColor: selectedColor.withValues(alpha: .12),
      ),
      iconSize: compact ? 18 : 20,
      icon: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.08 : 1,
        child: Text(
          positive ? '👍' : '👎',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 20,
            height: 1,
            fontFamily: emojiFontFamily,
            fontFamilyFallback: const <String>[
              'Segoe UI Emoji',
              'Apple Color Emoji',
              'Noto Color Emoji',
            ],
          ),
        ),
      ),
    );
  }
}
