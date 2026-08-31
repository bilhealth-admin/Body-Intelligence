part of 'wellness_tools_pages.dart';

class _FastingBenefit extends StatelessWidget {
  const _FastingBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 7),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Fasting-specific hero that keeps long translated titles away from the
/// circular icon instead of squeezing either element into an unreadable row.
class _FastingStatusPanel extends StatelessWidget {
  const _FastingStatusPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('fasting-status-panel'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF071829), Color(0xFF123B54)],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackContent = constraints.maxWidth < 330 || textScale > 1.25;
        final iconWidget = CircleAvatar(
          key: const Key('fasting-status-icon'),
          radius: 28,
          backgroundColor: const Color(0xFF19C6DF),
          child: Icon(icon, color: const Color(0xFF071829)),
        );
        final copy = Column(
          key: const Key('fasting-status-copy'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              key: const Key('fasting-status-title'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFC7D9E6), height: 1.45),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: stackContent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconWidget, const SizedBox(height: 16), copy],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                  ],
                ),
        );
      },
    ),
  );
}
