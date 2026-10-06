part of 'community_hub_page.dart';

class _CommunityCircleDiscoveryHeader extends StatelessWidget {
  const _CommunityCircleDiscoveryHeader({
    required this.controller,
    required this.myCircles,
    required this.onSearch,
    required this.onSelect,
  });

  final TextEditingController controller;
  final bool myCircles;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('community-circles-search'),
          controller: controller,
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: communityText(context, 'Search circles', 'ابحث عن دائرة'),
            prefixIcon: const Icon(Icons.search_rounded, size: 21),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: communityText(
                      context,
                      'Clear search',
                      'مسح البحث',
                    ),
                    onPressed: () => onSearch(''),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.primary.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .12
                  : .04,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          communityText(
            context,
            'Search the circles loaded on this page.',
            'ابحث ضمن الدوائر المحمّلة في هذه الصفحة.',
          ),
          key: const Key('community-circles-search-scope'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: CommunitySapphire.muted(context),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _tab(
                context,
                mine: false,
                text: communityText(context, 'Discover', 'اكتشف'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _tab(
                context,
                mine: true,
                text: communityText(context, 'My circles', 'دوائري'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _tab(
    BuildContext context, {
    required bool mine,
    required String text,
  }) {
    final selected = myCircles == mine;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: Key(
          mine ? 'community-circles-mine' : 'community-circles-discover',
        ),
        onPressed: () => onSelect(mine),
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? CommunitySapphire.blue
              : Theme.of(context).colorScheme.primary.withValues(alpha: .045),
          foregroundColor: selected
              ? Colors.white
              : CommunitySapphire.muted(context),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
