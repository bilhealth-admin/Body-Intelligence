part of 'community_hub_page.dart';

double _communityHubTopTabsHeight(BuildContext context, double width) {
  var height = 48.0;
  // Reserve the actual localized line height. A fixed three-line allowance
  // left a large empty band above single-line Arabic/English tabs at 200%.
  for (final label in [
    communityText(context, 'Explore', 'استكشاف'),
    communityText(context, 'Following', 'المتابَعون'),
    communityText(context, 'Circles', 'الدوائر'),
  ]) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: width / 3);
    if (painter.height + 20 > height) height = painter.height + 20;
    painter.dispose();
  }
  return height;
}

class _CommunityHubTopTab extends StatelessWidget {
  const _CommunityHubTopTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 3,
          width: 56,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    ),
  );
}
