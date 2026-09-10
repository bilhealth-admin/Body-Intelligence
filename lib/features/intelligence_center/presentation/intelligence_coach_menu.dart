part of 'intelligence_center_page.dart';

class _CoachMenuSheet extends StatelessWidget {
  const _CoachMenuSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          2,
          18,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intelligenceText(context, 'Your BIL Coach', 'مدرب BIL الخاص بك'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              intelligenceText(
                context,
                'Memory and preferences stay one tap away.',
                'ذاكرتك وتفضيلاتك على بُعد لمسة.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _CoachMenuTile(
              icon: Icons.forum_outlined,
              title: intelligenceText(
                context,
                'Conversation history',
                'سجل المحادثات',
              ),
              subtitle: intelligenceText(
                context,
                'Open an earlier chat or start a new one',
                'افتح محادثة سابقة أو ابدأ محادثة جديدة',
              ),
              onTap: () => Navigator.of(context).pop('history'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.psychology_alt_rounded,
              title: intelligenceText(
                context,
                'What BIL remembers',
                'ماذا يتذكر BIL عني',
              ),
              subtitle: intelligenceText(
                context,
                'Review the context behind your decisions',
                'راجع السياق الذي يبني عليه قراراتك',
              ),
              onTap: () => Navigator.of(context).pop('memory'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.tune_rounded,
              title: intelligenceText(
                context,
                'Coach preferences',
                'تفضيلات المدرب',
              ),
              subtitle: intelligenceText(
                context,
                'Personal AI, voice, and response style',
                'الذكاء الشخصي والصوت وأسلوب الرد',
              ),
              onTap: () => Navigator.of(context).pop('settings'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.delete_sweep_outlined,
              title: intelligenceText(
                context,
                'Clear conversation',
                'مسح المحادثة',
              ),
              subtitle: intelligenceText(
                context,
                'Choose the conversation to delete',
                'اختر المحادثة التي تريد حذفها',
              ),
              onTap: () => Navigator.of(context).pop('clear'),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachMenuTile extends StatelessWidget {
  const _CoachMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = destructive ? scheme.error : const Color(0xFF12394E);
    return Material(
      color: destructive
          ? scheme.errorContainer.withValues(alpha: .22)
          : const Color(0xFFF2F7FA),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
