part of 'intelligence_center_page.dart';

/// Native interaction bounds are independent from the compact visible chrome.
class _CoachHero extends StatelessWidget {
  const _CoachHero({super.key, required this.onBack, required this.onHistory, required this.onMenu, this.interactionEnabled = true});
  final VoidCallback onBack, onHistory, onMenu;
  final bool interactionEnabled;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.3 || MediaQuery.sizeOf(context).width < 380;
    final controls = Row(mainAxisSize: MainAxisSize.min, children: [
      _CoachHeaderAction(icon: Icons.search_rounded, label: intelligenceText(context, 'Search conversations', 'ابحث في محادثاتك'), onPressed: interactionEnabled ? onHistory : null),
      _CoachHeaderAction(icon: Icons.history_rounded, label: intelligenceText(context, 'Conversation history', 'سجل المحادثات'), onPressed: interactionEnabled ? onHistory : null),
      _CoachHeaderAction(icon: Icons.more_horiz_rounded, label: intelligenceText(context, 'Coach controls', 'أدوات المدرب'), onPressed: interactionEnabled ? onMenu : null),
    ]);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C1B2B), Color(0xFF07111B)]), border: Border(bottom: BorderSide(color: Color(0xFF1F344B), width: .6))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox.square(dimension: 48, child: IconButton(onPressed: onBack, tooltip: MaterialLocalizations.of(context).backButtonTooltip, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 48, height: 48), icon: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: const Color(0xFFB1C5E0), size: 24))),
          _CoachHeroPortrait(size: 48, onTap: interactionEnabled ? onHistory : null),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(intelligenceText(context, 'AI Coach', 'المدرب الذكي'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFFF1F6FF))),
            if (!compact) Text(intelligenceText(context, 'Your health partner, always with you', 'شريك صحتك، معك دائمًا'), style: const TextStyle(fontSize: 9, color: Color(0xFFB8C6D8), height: 1.4)),
          ])),
          if (!compact) controls,
        ]),
        if (compact) ...[
          const SizedBox(height: 6),
          Row(children: [
            const SizedBox(width: 8),
            Expanded(child: Text(intelligenceText(context, 'Your health partner, always with you', 'شريك صحتك، معك دائمًا'), style: const TextStyle(fontSize: 10, color: Color(0xFFB8C6D8), height: 1.4))),
            const SizedBox(width: 8),
            controls,
          ]),
        ],
        const Align(alignment: AlignmentDirectional.centerEnd, child: CommunityGoldBalanceAction(compact: true)),
      ]),
    );
  }
}

class _CoachHeaderAction extends StatelessWidget {
  const _CoachHeaderAction({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: 48, child: IconButton(tooltip: label, onPressed: onPressed, padding: const EdgeInsets.all(5), constraints: const BoxConstraints.tightFor(width: 48, height: 48), icon: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF142335), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFF304359), width: .7)), child: Icon(icon, size: 19, color: const Color(0xFFB4C5DA)))));
}
